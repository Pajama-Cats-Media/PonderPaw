import Foundation

struct Base64Utils {
    /// Encodes a string to a Base64 representation while preserving UTF-8 encoding.
    static func utoa(data: String) -> String? {
        guard let utf8Data = data.data(using: .utf8) else {
            return nil
        }
        return utf8Data.base64EncodedString()
    }

    /// Decodes a Base64 string back to its original UTF-8 representation.
    static func atou(base64: String) -> String? {
        guard let decodedData = Data(base64Encoded: base64) else {
            return nil
        }
        return String(data: decodedData, encoding: .utf8)
    }
}
