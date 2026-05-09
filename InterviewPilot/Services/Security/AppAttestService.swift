import CryptoKit
import DeviceCheck
import Foundation
import Observation

/// Manages a per-install Apple App Attest key and emits assertions that the
/// backend uses to bind authenticated requests to a real iOS install.
///
/// Lifecycle:
/// 1. First launch after sign-in: generate a key with DCAppAttestService, ask
///    the backend for a fresh challenge, attest the key, ship the attestation
///    blob to /attest/register.
/// 2. Each subsequent protected request: build a clientData blob from the
///    request, ask DCAppAttestService.generateAssertion, send the assertion
///    + keyId + nonce in headers.
///
/// The keyId is persisted in the iOS Keychain. Sign-out clears it so the next
/// account on the same device gets its own key, and revocation on the server
/// is a single row delete.
@Observable
final class AppAttestService {
    static let shared = AppAttestService()

    @ObservationIgnored private let attestService = DCAppAttestService.shared

    enum AttestError: Error, LocalizedError {
        case unsupported
        case backendRefused(String)
        case challengeMissing
        case keyGenerationFailed(Error)
        case attestationFailed(Error)
        case assertionFailed(Error)

        var errorDescription: String? {
            switch self {
            case .unsupported: return "App Attest is not available on this device."
            case .backendRefused(let msg): return "Backend rejected attestation: \(msg)"
            case .challengeMissing: return "Backend did not return an attestation challenge."
            case .keyGenerationFailed(let err): return "Could not generate attestation key: \(err.localizedDescription)"
            case .attestationFailed(let err): return "Could not attest key: \(err.localizedDescription)"
            case .assertionFailed(let err): return "Could not sign request: \(err.localizedDescription)"
            }
        }
    }

    private init() {}

    var isSupported: Bool { attestService.isSupported }

    var hasRegisteredKey: Bool {
        KeychainService.hasKey(.appAttestKeyId)
    }

    /// Wipe the key on sign-out. Backend cleanup happens via cascade delete on the user.
    func clearKey() {
        _ = KeychainService.delete(key: .appAttestKeyId)
    }

    /// Ensures a key exists and is registered with the backend. Idempotent — if
    /// the key is already in the keychain we assume the server has it.
    func ensureRegistered(apiClient: AuthenticatedAPIClient) async throws {
        guard isSupported else { throw AttestError.unsupported }
        if hasRegisteredKey { return }

        let keyId: String
        do {
            keyId = try await attestService.generateKey()
        } catch {
            throw AttestError.keyGenerationFailed(error)
        }

        let challenge = try await fetchChallenge(apiClient: apiClient)
        guard let challengeData = Data(base64Encoded: challenge) else {
            throw AttestError.challengeMissing
        }
        let clientDataHash = Data(SHA256.hash(data: challengeData))

        let attestation: Data
        do {
            attestation = try await attestService.attestKey(keyId, clientDataHash: clientDataHash)
        } catch {
            throw AttestError.attestationFailed(error)
        }

        try await register(
            apiClient: apiClient,
            keyId: keyId,
            attestation: attestation.base64EncodedString(),
            challenge: challenge
        )

        _ = KeychainService.save(key: .appAttestKeyId, value: keyId)
    }

    /// Build the headers a protected request needs. `clientData` should be
    /// `<METHOD>|<path>|<nonce>|<sha256(body)hex>` — same recipe the server uses.
    func makeAssertionHeaders(
        method: String,
        path: String,
        body: Data?
    ) async throws -> [String: String]? {
        guard isSupported, let keyId = KeychainService.load(key: .appAttestKeyId) else {
            return nil
        }

        let nonce = UUID().uuidString
        let bodyHashHex = (body.map { Data(SHA256.hash(data: $0)) } ?? Data())
            .map { String(format: "%02x", $0) }
            .joined()
        let clientData = "\(method)|\(path)|\(nonce)|\(bodyHashHex)".data(using: .utf8) ?? Data()
        let clientDataHash = Data(SHA256.hash(data: clientData))

        let assertion: Data
        do {
            assertion = try await attestService.generateAssertion(keyId, clientDataHash: clientDataHash)
        } catch {
            throw AttestError.assertionFailed(error)
        }

        return [
            "x-attest-key-id": keyId,
            "x-attest-assertion": assertion.base64EncodedString(),
            "x-attest-nonce": nonce,
        ]
    }

    private struct ChallengeResponse: Decodable { let challenge: String }
    private struct OkResponse: Decodable { let ok: Bool }

    private func fetchChallenge(apiClient: AuthenticatedAPIClient) async throws -> String {
        let response: ChallengeResponse = try await apiClient.post(
            "/api/v1/attest/challenge",
            body: EmptyBody()
        )
        return response.challenge
    }

    private struct RegisterBody: Encodable {
        let keyId: String
        let attestation: String
        let challenge: String
    }

    private func register(
        apiClient: AuthenticatedAPIClient,
        keyId: String,
        attestation: String,
        challenge: String
    ) async throws {
        let body = RegisterBody(keyId: keyId, attestation: attestation, challenge: challenge)
        let _: OkResponse = try await apiClient.post(
            "/api/v1/attest/register",
            body: body
        )
    }
}

private struct EmptyBody: Encodable {}
