import CryptoKit
import Foundation

/// A dotted version number like "1.2.0" (a leading "v", as in tags, is ignored).
public struct AppVersion: Comparable, CustomStringConvertible {
    public let components: [Int]

    public init?(_ string: String) {
        var text = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("v") || text.hasPrefix("V") { text.removeFirst() }
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard !parts.isEmpty else { return nil }
        var numbers: [Int] = []
        for part in parts {
            guard let number = Int(part), number >= 0 else { return nil }
            numbers.append(number)
        }
        components = numbers
    }

    public var description: String { components.map(String.init).joined(separator: ".") }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)
        for index in 0..<count {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right { return left < right }
        }
        return false
    }

    public static func == (lhs: AppVersion, rhs: AppVersion) -> Bool {
        !(lhs < rhs) && !(rhs < lhs)
    }
}

/// Ed25519 signatures on update downloads. The release workflow signs the zip with the
/// private key (repo secret UPDATE_SIGNING_KEY); the app only installs zips that verify
/// against the public key built into it.
public enum UpdateSignature {
    public static func isValid(data: Data, signatureBase64: String, publicKeyBase64: String) -> Bool {
        let trimmedSignature = signatureBase64.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedKey = publicKeyBase64.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let signature = Data(base64Encoded: trimmedSignature),
            let keyData = Data(base64Encoded: trimmedKey),
            let key = try? Curve25519.Signing.PublicKey(rawRepresentation: keyData)
        else { return false }
        return key.isValidSignature(signature, for: data)
    }
}
