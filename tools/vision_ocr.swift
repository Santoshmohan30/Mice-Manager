#!/usr/bin/env swift

import CoreGraphics
import Foundation
import ImageIO
import Vision

struct OcrResult: Encodable {
    let engine: String
    let confidence: Double
    let text: String
}

struct LineObservation {
    let text: String
    let confidence: Double
    let minX: CGFloat
    let midY: CGFloat
}

let arguments = CommandLine.arguments
guard arguments.count >= 2 else {
    FileHandle.standardError.write(Data("Usage: vision_ocr.swift <image-path>\n".utf8))
    exit(1)
}

let imageUrl = URL(fileURLWithPath: arguments[1])
guard let imageSource = CGImageSourceCreateWithURL(imageUrl as CFURL, nil),
      let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
    FileHandle.standardError.write(Data("Unable to load image for Vision OCR.\n".utf8))
    exit(1)
}

let request = VNRecognizeTextRequest()
request.recognitionLevel = .accurate
request.usesLanguageCorrection = true
request.recognitionLanguages = ["en-US"]
request.minimumTextHeight = 0.01

let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
do {
    try handler.perform([request])
} catch {
    FileHandle.standardError.write(Data("Vision OCR request failed: \(error.localizedDescription)\n".utf8))
    exit(1)
}

let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
let lines = observations.compactMap { observation -> LineObservation? in
    guard let candidate = observation.topCandidates(1).first else {
        return nil
    }
    return LineObservation(
        text: candidate.string,
        confidence: Double(candidate.confidence),
        minX: observation.boundingBox.minX,
        midY: observation.boundingBox.midY
    )
}

let sortedLines = lines.sorted { left, right in
    if abs(left.midY - right.midY) > 0.02 {
        return left.midY > right.midY
    }
    return left.minX < right.minX
}

let averageConfidence = sortedLines.isEmpty ? 0.0 : sortedLines.map(\.confidence).reduce(0, +) / Double(sortedLines.count)
let text = sortedLines.map(\.text).joined(separator: "\n")
let result = OcrResult(engine: "vision", confidence: averageConfidence, text: text)

let encoder = JSONEncoder()
encoder.outputFormatting = [.withoutEscapingSlashes]

do {
    let data = try encoder.encode(result)
    FileHandle.standardOutput.write(data)
} catch {
    FileHandle.standardError.write(Data("Unable to encode Vision OCR result: \(error.localizedDescription)\n".utf8))
    exit(1)
}
