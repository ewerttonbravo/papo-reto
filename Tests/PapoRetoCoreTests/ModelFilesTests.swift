import Testing
import PapoRetoCore

private let encoder = ParakeetModel.files[0]
private let decoder = ParakeetModel.files[1]

@Test func fileWithTheManifestHashIsValid() {
    for file in ParakeetModel.files {
        #expect(file.isValid(sha256: file.sha256))
    }
}

@Test func absentOrDifferentHashIsInvalid() {
    #expect(!encoder.isValid(sha256: nil))
    #expect(!encoder.isValid(sha256: decoder.sha256))
}

@Test func fileOfTheManifestSizeIsComplete() {
    #expect(encoder.isComplete(bytes: encoder.bytes))
}

/// The launch check: a truncated file (what makes sherpa abort) or one grown by an append fails it.
@Test(arguments: [nil, encoder.bytes - 1, encoder.bytes + 1])
func absentOrDifferentSizeIsIncomplete(bytes: Int64?) {
    #expect(!encoder.isComplete(bytes: bytes))
}

@Test func manifestTotalsTheModelSize() {
    #expect(ParakeetModel.files.map(\.name) == ["encoder.int8.onnx", "decoder.int8.onnx", "joiner.int8.onnx", "tokens.txt"])
    #expect(ParakeetModel.bytes == 670_576_784)
}

@Test(arguments: [(Int64(0), "0%"), (ParakeetModel.bytes - 1, "99%"), (ParakeetModel.bytes, "100%")])
func downloadStatusTruncatesThePercent(received: Int64, percent: String) {
    #expect(downloadStatus(received: received, total: ParakeetModel.bytes) == "Downloading model: \(percent) of 671 MB")
}
