import base64
import io
import json
import os
import re
import subprocess
import tempfile
from pathlib import Path

from PIL import Image, ImageFilter, ImageOps, ImageStat


class ScanService:
    def __init__(
        self,
        *,
        config,
        logger,
        mouse_label_options,
        canonical_mouse_label,
        infer_group_type_from_label,
        normalize_date,
        normalize_gender,
        normalize_species,
        normalize_text_value,
        calculate_age_from_dob,
        display_date_us,
        defaults,
        strain_aliases,
    ):
        self.config = config
        self.logger = logger
        self.mouse_label_options = mouse_label_options
        self.canonical_mouse_label = canonical_mouse_label
        self.infer_group_type_from_label = infer_group_type_from_label
        self.normalize_date = normalize_date
        self.normalize_gender = normalize_gender
        self.normalize_species = normalize_species
        self.normalize_text_value = normalize_text_value
        self.calculate_age_from_dob = calculate_age_from_dob
        self.display_date_us = display_date_us
        self.defaults = defaults
        self.strain_aliases = strain_aliases
        self.vision_ocr_script = Path(__file__).resolve().parents[1] / "tools" / "vision_ocr.swift"
        self.vision_ocr_binary = Path(__file__).resolve().parents[1] / "tools" / ".cache" / "vision_ocr"
        self.scan_field_specs = [
            ("strain", ["STRAIN"], "text"),
            ("gender", ["GENDER", "SEX"], "gender"),
            ("genotype", ["GENOTYPE", "GT"], "text"),
            ("dob", ["DOB", "DATE OF BIRTH", "BORN"], "date"),
            ("cage", ["CAGE", "CAGE NUMBER", "CAGE NO", "BOX"], "text"),
            ("rack_location", ["RACK", "RACK LOCATION"], "text"),
            ("owner_pi", ["OWNER", "PI", "LAB CONTACT", "INVESTIGATOR"], "text"),
            ("protocol_number", ["PROTOCOL", "PROTOCOL NUMBER", "IACUC"], "text"),
            ("age", ["AGE"], "text"),
            ("room", ["ROOM"], "text"),
            ("requisition_number", ["REQUISITION NUMBER", "REQUISITION"], "text"),
            ("notes", ["NOTES"], "text"),
        ]

    def empty_scan_field(self):
        return {"value": "", "confidence": 0.0, "source": "none"}

    def set_scan_field(self, fields, key, value, confidence, source):
        value = value if not isinstance(value, str) else self.normalize_text_value(value)
        if value in {None, ""}:
            return
        if confidence > fields[key]["confidence"]:
            fields[key] = {"value": value, "confidence": round(confidence, 2), "source": source}

    def clean_ocr_text(self, text):
        return "\n".join(self.normalize_text_value(line) for line in (text or "").splitlines() if self.normalize_text_value(line))

    def normalize_scan_value(self, field, value):
        raw = self.normalize_text_value(value)
        if not raw:
            return ""
        if field == "dob":
            return self.normalize_date(raw)
        if field == "gender":
            return self.normalize_gender(raw)
        if field == "strain":
            return self.canonical_mouse_label(raw)
        if field == "cage":
            return raw.replace(" ", "")
        return raw

    def infer_known_strain_from_text(self, text):
        if not text:
            return ""
        normalized = " ".join((text or "").strip().upper().replace("-", " ").split())
        compact = normalized.replace(" ", "")
        for alias, canonical in self.strain_aliases.items():
            if alias in normalized or alias in compact:
                return canonical
        return ""

    def extract_label_value_pairs(self, lines):
        pairs = []
        normalized_labels = {}
        for field, labels, _kind in self.scan_field_specs:
            for label in labels:
                normalized_labels[" ".join(label.strip().upper().replace("-", " ").split())] = (field, label)

        for index, line in enumerate(lines):
            stripped = line.strip()
            if not stripped:
                continue
            normalized_line = " ".join(stripped.strip().upper().replace("-", " ").split())
            for normalized_label, (field, original_label) in sorted(normalized_labels.items(), key=lambda item: len(item[0]), reverse=True):
                if normalized_line.startswith(normalized_label):
                    remainder = stripped[len(original_label):].strip(" :.-")
                    if remainder:
                        pairs.append((field, remainder, index))
                        break
                if ":" in stripped:
                    label_part, value_part = stripped.split(":", 1)
                    if " ".join(label_part.strip().upper().replace("-", " ").split()) == normalized_label and value_part.strip():
                        pairs.append((field, value_part.strip(), index))
                        break
        return pairs

    def infer_fields_from_text(self, text, source, base_confidence):
        fields = {field: self.empty_scan_field() for field, _labels, _kind in self.scan_field_specs}
        cleaned_text = self.clean_ocr_text(text)
        lines = cleaned_text.splitlines()

        for field, value, _index in self.extract_label_value_pairs(lines):
            normalized_value = self.normalize_scan_value(field, value)
            confidence = base_confidence + 0.18
            if normalized_value:
                self.set_scan_field(fields, field, normalized_value, min(confidence, 0.98), f"{source}_label_match")

        full_text = cleaned_text.upper()
        label_options = self.mouse_label_options()
        for canonical in label_options["genetic_strain"]:
            normalized = " ".join(canonical.strip().upper().replace("-", " ").split())
            if normalized in full_text:
                self.set_scan_field(fields, "strain", canonical, 0.96, "rule_match")
        for canonical in label_options["procedure_cohort"]:
            normalized = " ".join(canonical.strip().upper().replace("-", " ").split())
            if normalized in full_text:
                self.set_scan_field(fields, "strain", canonical, 0.94, "rule_match")

        inferred_strain = self.infer_known_strain_from_text(cleaned_text)
        if inferred_strain:
            self.set_scan_field(fields, "strain", inferred_strain, 0.95, "alias_match")

        if re.search(r"\bMALE\b|\bSEX\s*[:\-]?\s*M\b|\bGENDER\s*[:\-]?\s*M\b", cleaned_text, flags=re.IGNORECASE):
            self.set_scan_field(fields, "gender", "MALE", 0.9, "rule_match")
        if re.search(r"\bFEMALE\b|\bSEX\s*[:\-]?\s*F\b|\bGENDER\s*[:\-]?\s*F\b", cleaned_text, flags=re.IGNORECASE):
            self.set_scan_field(fields, "gender", "FEMALE", 0.9, "rule_match")

        genotype_match = re.search(r"\b(?:GENOTYPE|GT)\s*[:\-]?\s*([A-Z0-9+/_. -]+)", cleaned_text, flags=re.IGNORECASE)
        if genotype_match:
            self.set_scan_field(fields, "genotype", genotype_match.group(1), 0.84, "rule_match")

        date_matches = re.findall(r"\b(?:\d{4}-\d{2}-\d{2}|\d{1,2}[/-]\d{1,2}[/-]\d{2,4})\b", cleaned_text)
        if date_matches and not fields["dob"]["value"]:
            normalized_date = self.normalize_date(date_matches[0])
            if normalized_date:
                self.set_scan_field(fields, "dob", normalized_date, 0.72, "ocr")

        cc_cage_matches = re.findall(r"\bCC00[A-Z0-9-]*\d\b", cleaned_text, flags=re.IGNORECASE)
        if cc_cage_matches:
            self.set_scan_field(fields, "cage", cc_cage_matches[-1].upper(), 0.99, "lab_rule")

        cage_match = re.search(r"\b(?:CAGE(?: NUMBER| NO)?|BOX)\s*[:#\-]?\s*([A-Z0-9-]+)\b", cleaned_text, flags=re.IGNORECASE)
        if cage_match:
            self.set_scan_field(fields, "cage", cage_match.group(1), 0.88, "rule_match")

        rack_match = re.search(r"\bRACK(?: LOCATION)?\s*[:\-]?\s*([A-Z0-9- ]+)\b", cleaned_text, flags=re.IGNORECASE)
        if rack_match:
            self.set_scan_field(fields, "rack_location", rack_match.group(1), 0.84, "rule_match")

        owner_match = re.search(r"\b(?:LAB CONTACT|OWNER|PI)\s*[:\-]?\s*([A-Z ,.-]+)", cleaned_text, flags=re.IGNORECASE)
        if owner_match:
            self.set_scan_field(fields, "owner_pi", owner_match.group(1), 0.9, "label_match")
        elif re.search(r"\bDHEERAJ\b", cleaned_text, flags=re.IGNORECASE) and re.search(r"\bROY\b", cleaned_text, flags=re.IGNORECASE):
            self.set_scan_field(fields, "owner_pi", self.defaults["owner_pi"], 0.9, "rule_match")

        requisition_match = re.search(r"\b\d{6}\s+[A-Z]{2,5}\d{4,6}-\d+\b", cleaned_text, flags=re.IGNORECASE)
        if requisition_match:
            self.set_scan_field(fields, "requisition_number", requisition_match.group(0).upper(), 0.95, "rule_match")
        else:
            requisition_match = re.search(r"\b20\d{6,}\b", cleaned_text)
            if requisition_match:
                self.set_scan_field(fields, "requisition_number", requisition_match.group(0), 0.9, "rule_match")

        room_match = re.search(r"\bB2126\s+JSMBS\b", cleaned_text, flags=re.IGNORECASE)
        if room_match:
            self.set_scan_field(fields, "room", self.defaults["room"], 0.99, "rule_match")

        return fields

    def merge_scan_fields(self, *field_maps):
        merged = {field: self.empty_scan_field() for field, _labels, _kind in self.scan_field_specs}
        for field_map in field_maps:
            for key, payload in field_map.items():
                if payload["confidence"] > merged[key]["confidence"]:
                    merged[key] = payload
        if merged["gender"]["value"] not in {"MALE", "FEMALE", "UNKNOWN", ""}:
            merged["gender"] = self.empty_scan_field()
        return merged

    def extract_cage_card_fields(self, raw_text, diagnostics=None):
        text = self.clean_ocr_text(raw_text)
        full_pass = self.infer_fields_from_text(text, "ocr", 0.56)

        lines = text.splitlines()
        top_half = "\n".join(lines[: max(1, len(lines) // 2)])
        bottom_half = "\n".join(lines[max(1, len(lines) // 2):])
        second_pass = self.merge_scan_fields(
            self.infer_fields_from_text(top_half, "second_pass", 0.5),
            self.infer_fields_from_text(bottom_half, "second_pass", 0.5),
        )

        fields = self.merge_scan_fields(full_pass, second_pass)
        warnings = list((diagnostics or {}).get("warnings", []))

        if not fields["room"]["value"]:
            self.set_scan_field(fields, "room", self.defaults["room"], 1.0, "default")
        if not fields["protocol_number"]["value"]:
            self.set_scan_field(fields, "protocol_number", self.defaults["protocol_number"], 1.0, "default")
        if not fields["age"]["value"] and fields["dob"]["value"]:
            self.set_scan_field(fields, "age", self.calculate_age_from_dob(fields["dob"]["value"]), 0.98, "derived")
        if not fields["owner_pi"]["value"]:
            self.set_scan_field(fields, "owner_pi", self.defaults["owner_pi"], 0.92, "default")

        required_review_fields = ["strain", "gender", "dob", "cage", "rack_location", "requisition_number"]
        for field in required_review_fields:
            if not fields[field]["value"]:
                warnings.append(f"{field.replace('_', ' ').title()} not found")
            elif fields[field]["confidence"] < 0.65:
                warnings.append(f"{field.replace('_', ' ').title()} found in text but confidence is low")

        overall_confidence = round(
            sum(fields[field]["confidence"] for field in required_review_fields) / len(required_review_fields),
            2,
        )
        if overall_confidence < 0.8:
            warnings.append("Some details need review before storing.")

        notes_fallback = " | ".join(line for line in lines[:8] if line)[:350]
        mouse_id_match = re.search(r"\bMOUSE(?:\s*ID|#)?\s*[:\-]?\s*([0-9]+)\b", text, flags=re.IGNORECASE)

        return {
            "raw_text": text,
            "mouse_id": int(mouse_id_match.group(1)) if mouse_id_match else None,
            "fields": fields,
            "overall_confidence": overall_confidence,
            "warnings": list(dict.fromkeys(warnings)),
            "editor": {
                "strain": fields["strain"]["value"],
                "gender": fields["gender"]["value"] or "UNKNOWN",
                "genotype": fields["genotype"]["value"],
                "dob": self.display_date_us(fields["dob"]["value"]),
                "cage": fields["cage"]["value"],
                "rack_location": fields["rack_location"]["value"],
                "owner_pi": fields["owner_pi"]["value"] or self.defaults["owner_pi"],
                "protocol_number": fields["protocol_number"]["value"],
                "age": fields["age"]["value"],
                "room": fields["room"]["value"],
                "requisition_number": fields["requisition_number"]["value"],
                "notes": fields["notes"]["value"] or notes_fallback,
                "group_type": self.infer_group_type_from_label(fields["strain"]["value"]) if fields["strain"]["value"] else "genetic_strain",
                "project": "",
                "animal_count": None,
                "received_date": "",
                "vendor": "",
                "weight": "",
                "species": "Mouse",
                "cost_center": "",
                "training": False,
            },
        }

    def image_to_data_url(self, image, format_name="PNG"):
        buffer = io.BytesIO()
        image.save(buffer, format=format_name)
        encoded = base64.b64encode(buffer.getvalue()).decode("ascii")
        return f"data:image/{format_name.lower()};base64,{encoded}"

    def analyze_image_quality(self, image):
        grayscale = image.convert("L")
        stat = ImageStat.Stat(grayscale)
        mean_brightness = stat.mean[0]
        variance = stat.var[0]
        bright_pixels = sum(1 for pixel in grayscale.getdata() if pixel > 245)
        dark_pixels = sum(1 for pixel in grayscale.getdata() if pixel < 35)
        total_pixels = max(1, grayscale.width * grayscale.height)
        warnings = []
        if mean_brightness < 70:
            warnings.append("Image is too dark")
        if variance < 180:
            warnings.append("Image may be blurry")
        if bright_pixels / total_pixels > 0.18:
            warnings.append("Glare detected")
        if dark_pixels / total_pixels > 0.4:
            warnings.append("Image has heavy shadows")
        return {
            "warnings": warnings,
            "mean_brightness": mean_brightness,
            "variance": variance,
        }

    def preprocess_ocr_image(self, image):
        image = ImageOps.exif_transpose(image)
        image = image.convert("L")
        image = ImageOps.autocontrast(image)

        bbox = ImageOps.invert(image).point(lambda value: 255 if value > 10 else 0).getbbox()
        cut_off_edges = False
        if bbox:
            cut_off_edges = bbox[0] <= 2 or bbox[1] <= 2 or bbox[2] >= image.width - 2 or bbox[3] >= image.height - 2
            image = image.crop(bbox)

        max_dimension = self.config["OCR_MAX_DIMENSION"]
        if max(image.size) > max_dimension:
            scale = max_dimension / max(image.size)
            image = image.resize((max(1, int(image.width * scale)), max(1, int(image.height * scale))))

        if max(image.size) < self.config["OCR_MIN_TARGET_DIMENSION"]:
            upscale = min(1.5, self.config["OCR_MAX_DIMENSION"] / max(image.size))
            image = image.resize((max(1, int(image.width * upscale)), max(1, int(image.height * upscale))))
        image = image.filter(ImageFilter.MedianFilter(size=3))
        image = image.filter(ImageFilter.SHARPEN)
        image = ImageOps.autocontrast(image)
        diagnostics = self.analyze_image_quality(image)
        if cut_off_edges:
            diagnostics["warnings"].append("Card edges may be cut off")
        return image, diagnostics

    def score_ocr_text(self, text):
        if not text:
            return 0
        useful_keywords = ["CAGE", "STRAIN", "SEX", "DOB", "PI", "PROTOCOL", "OWNER"]
        score = len(text)
        score += sum(20 for keyword in useful_keywords if keyword in text.upper())
        score -= text.count("?") * 5
        return score

    def macos_sdk_path(self):
        try:
            result = subprocess.run(
                ["/usr/bin/xcrun", "--show-sdk-path", "--sdk", "macosx"],
                capture_output=True,
                text=True,
                timeout=self.config["OCR_TIMEOUT_SECONDS"],
                check=False,
            )
        except subprocess.TimeoutExpired as error:
            raise RuntimeError("macOS SDK lookup timed out before OCR could start.") from error
        if result.returncode != 0:
            raise RuntimeError(result.stderr.strip() or "macOS SDK path is unavailable.")
        return result.stdout.strip()

    def ensure_compiled_vision_ocr(self):
        self.vision_ocr_binary.parent.mkdir(parents=True, exist_ok=True)
        if self.vision_ocr_binary.exists() and self.vision_ocr_binary.stat().st_mtime >= self.vision_ocr_script.stat().st_mtime:
            return self.vision_ocr_binary

        swift_cache_dir = Path(tempfile.gettempdir()) / "mice_manager_swift_cache"
        swift_cache_dir.mkdir(parents=True, exist_ok=True)
        env = os.environ.copy()
        env["CLANG_MODULE_CACHE_PATH"] = str(swift_cache_dir)
        env["SWIFT_MODULECACHE_PATH"] = str(swift_cache_dir)

        try:
            result = subprocess.run(
                [
                    "/usr/bin/xcrun",
                    "swiftc",
                    "-O",
                    "-sdk",
                    self.macos_sdk_path(),
                    str(self.vision_ocr_script),
                    "-o",
                    str(self.vision_ocr_binary),
                ],
                capture_output=True,
                text=True,
                env=env,
                timeout=self.config["OCR_COMPILE_TIMEOUT_SECONDS"],
                check=False,
            )
        except subprocess.TimeoutExpired as error:
            raise RuntimeError("Vision OCR compile timed out. Falling back to secondary OCR.") from error
        if result.returncode != 0:
            raise RuntimeError(result.stderr.strip() or "Vision OCR helper could not be compiled.")
        return self.vision_ocr_binary

    def run_vision_ocr_on_image(self, path):
        if not self.vision_ocr_script.exists():
            raise RuntimeError("Vision OCR helper script is missing.")
        executable = self.ensure_compiled_vision_ocr()
        try:
            result = subprocess.run(
                [str(executable), str(path)],
                capture_output=True,
                text=True,
                timeout=self.config["OCR_TIMEOUT_SECONDS"],
                check=False,
            )
        except subprocess.TimeoutExpired as error:
            raise RuntimeError("Primary OCR timed out. Falling back to secondary OCR.") from error
        if result.returncode != 0:
            raise RuntimeError(result.stderr.strip() or "Vision OCR could not read the image.")
        payload = json.loads(result.stdout or "{}")
        return {
            "text": str(payload.get("text") or "").strip(),
            "confidence": float(payload.get("confidence") or 0.0),
            "engine": str(payload.get("engine") or "vision"),
        }

    def run_tesseract_on_image(self, path, psm_mode):
        try:
            result = subprocess.run(
                [
                    "/opt/homebrew/bin/tesseract",
                    str(path),
                    "stdout",
                    "--psm",
                    str(psm_mode),
                ],
                capture_output=True,
                text=True,
                timeout=self.config["OCR_TIMEOUT_SECONDS"],
                check=False,
            )
        except subprocess.TimeoutExpired as error:
            raise RuntimeError("Fallback OCR timed out.") from error
        if result.returncode != 0:
            raise RuntimeError(result.stderr.strip() or "OCR could not read the image.")
        return result.stdout.strip()

    def ocr_uploaded_image(self, file_storage):
        if not file_storage or not getattr(file_storage, "filename", ""):
            raise ValueError("No image was uploaded.")

        original_extension = Path(file_storage.filename).suffix.lower() or ".img"
        with tempfile.NamedTemporaryFile(suffix=original_extension, delete=False) as uploaded_image:
            uploaded_path = Path(uploaded_image.name)
            uploaded_image.write(file_storage.read())

        converted_path = None
        try:
            try:
                with Image.open(uploaded_path) as image:
                    original = ImageOps.exif_transpose(image).convert("RGB")
            except Exception:
                if original_extension not in {".heic", ".heif"}:
                    raise
                with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as converted_file:
                    converted_path = Path(converted_file.name)
                try:
                    conversion = subprocess.run(
                        ["/usr/bin/sips", "-s", "format", "png", str(uploaded_path), "--out", str(converted_path)],
                        capture_output=True,
                        text=True,
                        timeout=self.config["IMAGE_CONVERT_TIMEOUT_SECONDS"],
                        check=False,
                    )
                except subprocess.TimeoutExpired as error:
                    raise RuntimeError("HEIC image conversion timed out before OCR could start.") from error
                if conversion.returncode != 0:
                    raise RuntimeError("HEIC image conversion failed before OCR.")
                with Image.open(converted_path) as image:
                    original = ImageOps.exif_transpose(image).convert("RGB")

            cleaned, diagnostics = self.preprocess_ocr_image(original)

            with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as temp_image:
                temp_path = Path(temp_image.name)
            try:
                cleaned.save(temp_path)
                candidates = []
                try:
                    vision_result = self.run_vision_ocr_on_image(temp_path)
                    if vision_result["text"]:
                        self.logger.info("Vision OCR succeeded")
                        candidates.append(
                            {
                                "text": vision_result["text"],
                                "score": self.score_ocr_text(vision_result["text"]) + int(vision_result["confidence"] * 100) + 40,
                                "engine": vision_result["engine"],
                            }
                        )
                except Exception as error:
                    self.logger.warning("Primary OCR failed, attempting fallback: %s", error)

                if not candidates:
                    for psm_mode in [6]:
                        try:
                            text = self.run_tesseract_on_image(temp_path, psm_mode)
                        except RuntimeError:
                            continue
                        if text:
                            self.logger.info("Fallback OCR succeeded with tesseract psm %s", psm_mode)
                            candidates.append(
                                {
                                    "text": text,
                                    "score": self.score_ocr_text(text),
                                    "engine": f"tesseract_psm_{psm_mode}",
                                }
                            )

                best_candidate = max(candidates, key=lambda candidate: candidate["score"]) if candidates else None
                text = best_candidate["text"] if best_candidate else ""
                if not text:
                    raise RuntimeError("OCR did not find readable text on this card.")
                diagnostics["ocr_engine"] = best_candidate["engine"] if best_candidate else "unknown"
                self.logger.info("OCR completed with engine=%s score=%s", diagnostics["ocr_engine"], best_candidate["score"] if best_candidate else "n/a")
                return {
                    "raw_text": text,
                    "diagnostics": diagnostics,
                    "original_preview": self.image_to_data_url(
                        original.resize((min(900, original.width), max(1, int(original.height * min(900, original.width) / original.width))))
                        if original.width > 900
                        else original
                    ),
                    "processed_preview": self.image_to_data_url(cleaned),
                }
            finally:
                temp_path.unlink(missing_ok=True)
        finally:
            uploaded_path.unlink(missing_ok=True)
            if converted_path is not None:
                converted_path.unlink(missing_ok=True)
