import unittest

from app import DEFAULT_OWNER_PI, DEFAULT_PROTOCOL_NUMBER, DEFAULT_ROOM, extract_cage_card_fields


class ScanParserTests(unittest.TestCase):
    def test_lab_specific_raw_ocr_text_maps_to_expected_fields(self):
        parsed = extract_cage_card_fields(
            "\n".join(
                [
                    "Roy, Dheeraj",
                    "room B2126 JSMBS",
                    "030126 saf00544-4",
                    "DOB 2/20/2026",
                    "Calv1 irscre",
                    "Gender Male",
                    "Genotype + positive",
                    "Cage A12",
                    "Rack A1",
                    "202300048",
                ]
            )
        )

        self.assertEqual(parsed["editor"]["strain"], "Calb1-IRES-Cre")
        self.assertEqual(parsed["editor"]["gender"], "MALE")
        self.assertEqual(parsed["editor"]["genotype"], "+ positive")
        self.assertEqual(parsed["editor"]["dob"], "02/20/2026")
        self.assertEqual(parsed["editor"]["cage"], "A12")
        self.assertEqual(parsed["editor"]["rack_location"], "A1")
        self.assertEqual(parsed["editor"]["owner_pi"], DEFAULT_OWNER_PI)
        self.assertEqual(parsed["editor"]["protocol_number"], DEFAULT_PROTOCOL_NUMBER)
        self.assertEqual(parsed["editor"]["room"], DEFAULT_ROOM)
        self.assertEqual(parsed["editor"]["requisition_number"], "030126 SAF00544-4")
        self.assertTrue(parsed["editor"]["age"].endswith("days"))
        self.assertEqual(parsed["warnings"], [])


if __name__ == "__main__":
    unittest.main()
