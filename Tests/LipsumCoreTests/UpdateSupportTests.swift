import CryptoKit
import XCTest
@testable import LipsumCore

final class UpdateSupportTests: XCTestCase {
    func testVersionParsing() {
        XCTAssertEqual(AppVersion("v1.2.3")?.components, [1, 2, 3])
        XCTAssertEqual(AppVersion(" 1.0 ")?.components, [1, 0])
        XCTAssertNil(AppVersion("1.x"))
        XCTAssertNil(AppVersion(""))
    }

    func testVersionOrdering() {
        XCTAssertTrue(AppVersion("1.0.0")! < AppVersion("1.0.1")!)
        XCTAssertTrue(AppVersion("1.9.0")! < AppVersion("1.10.0")!)
        XCTAssertTrue(AppVersion("1.0")! == AppVersion("1.0.0")!)
        XCTAssertFalse(AppVersion("2.0.0")! < AppVersion("1.99.99")!)
    }

    func testSignatureRoundTrip() throws {
        let key = Curve25519.Signing.PrivateKey()
        let data = Data("pretend zip".utf8)
        let signature = try key.signature(for: data).base64EncodedString()
        let publicKey = key.publicKey.rawRepresentation.base64EncodedString()

        XCTAssertTrue(UpdateSignature.isValid(data: data, signatureBase64: signature + "\n", publicKeyBase64: publicKey))
        XCTAssertFalse(UpdateSignature.isValid(data: Data("tampered".utf8), signatureBase64: signature, publicKeyBase64: publicKey))
        XCTAssertFalse(UpdateSignature.isValid(data: data, signatureBase64: "garbage", publicKeyBase64: publicKey))
    }

    /// The release workflow signs with OpenSSL-compatible raw keys; check that format verifies.
    func testOpenSSLStyleSignatureVerifies() throws {
        let key = Curve25519.Signing.PrivateKey()
        let rebuilt = try Curve25519.Signing.PrivateKey(rawRepresentation: key.rawRepresentation)
        let data = Data(repeating: 7, count: 1000)
        let signature = try rebuilt.signature(for: data).base64EncodedString()
        XCTAssertTrue(UpdateSignature.isValid(
            data: data,
            signatureBase64: signature,
            publicKeyBase64: key.publicKey.rawRepresentation.base64EncodedString()
        ))
    }
}
