// Signs an update zip for the in-app updater.
// Usage: UPDATE_SIGNING_KEY=<base64 private key> swift scripts/sign-update.swift <zip> <expected public key>
// Prints the base64 signature. Fails if the key doesn't match the public key built into the app.
import CryptoKit
import Foundation

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

let arguments = CommandLine.arguments
guard arguments.count == 3 else { fail("usage: sign-update.swift <zip> <expected public key>") }
guard let secret = ProcessInfo.processInfo.environment["UPDATE_SIGNING_KEY"],
      let keyData = Data(base64Encoded: secret.trimmingCharacters(in: .whitespacesAndNewlines)),
      let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: keyData)
else { fail("UPDATE_SIGNING_KEY is missing or not a base64 Ed25519 key") }

let publicKey = key.publicKey.rawRepresentation.base64EncodedString()
guard publicKey == arguments[2] else {
    fail("UPDATE_SIGNING_KEY doesn't match the public key in Updater.swift (\(publicKey) vs \(arguments[2]))")
}

guard let zip = FileManager.default.contents(atPath: arguments[1]) else { fail("can't read \(arguments[1])") }
guard let signature = try? key.signature(for: zip) else { fail("signing failed") }
guard key.publicKey.isValidSignature(signature, for: zip) else { fail("signature didn't verify") }
print(signature.base64EncodedString())
