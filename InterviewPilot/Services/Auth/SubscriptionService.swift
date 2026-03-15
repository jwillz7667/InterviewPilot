import Foundation
import StoreKit

struct BillingCatalogProduct: Codable, Sendable, Identifiable {
    let product: String
    let productId: String
    let tier: String
    let displayName: String
    let billingLabel: String
    let features: [String]

    var id: String { productId }
}

struct BillingEntitlement: Codable, Sendable {
    let tier: String
    let status: String
    let accessSource: String
    let product: String
    let productId: String?
    let features: [String]
    let featureFlags: [String: Bool]
    let sandboxFullAccess: Bool
    let trialInterviewLimit: Int
    let trialInterviewsUsed: Int
    let interviewsRemaining: Int
    let hasActiveSubscription: Bool
    let paywallRequired: Bool
    let appAccountToken: String
    let currentPeriodEndsAt: String?
    let gracePeriodEndsAt: String?
    let catalog: [BillingCatalogProduct]

    var canStartLiveInterview: Bool {
        featureFlags["live_interview"] == true &&
        (hasActiveSubscription || sandboxFullAccess || interviewsRemaining > 0)
    }

    var hasVoicePrep: Bool {
        featureFlags["voice_prep"] == true
    }

    var hasPriorityModels: Bool {
        featureFlags["priority_models"] == true
    }

    var hasUnlimitedInterviews: Bool {
        hasActiveSubscription || sandboxFullAccess
    }

    var trialInterviewsRemaining: Int {
        max(interviewsRemaining, 0)
    }

    var planTitle: String {
        switch tier {
        case "sandbox":
            return "Sandbox"
        case "pro":
            return "Pro"
        case "plus":
            return "Plus"
        default:
            return "Trial"
        }
    }

    var statusDetail: String {
        if sandboxFullAccess {
            return "Full feature access for sandbox testing."
        }

        if hasActiveSubscription {
            return currentPeriodEndsAt.map { "Renews through \(formattedDate($0))" } ?? "Subscription active"
        }

        return "\(trialInterviewsRemaining) of \(trialInterviewLimit) trial interviews remaining"
    }

    private func formattedDate(_ iso8601: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: iso8601) else { return iso8601 }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

struct BillingAccessClaim: Codable, Sendable {
    let sessionClientId: String
    let sessionMode: String
    let accessSource: String
    let accessTier: String
    let consumedTrial: Bool
    let trialInterviewNumber: Int?
    let entitlement: BillingEntitlement
}

struct SubscriptionStoreProduct: Identifiable, Sendable {
    let id: String
    let productId: String
    let tier: String
    let displayName: String
    let displayPrice: String
    let billingLabel: String
    let features: [String]
    let description: String
}

private struct BillingEntitlementEnvelope: Codable {
    let entitlement: BillingEntitlement
}

private struct BillingAccessClaimEnvelope: Codable {
    let claim: BillingAccessClaim
}

private struct PaymentAPIError: Decodable {
    let error: String?
    let message: String?
}

@MainActor
@Observable
final class SubscriptionService {
    static let shared = SubscriptionService()

    private(set) var entitlement: BillingEntitlement?
    private(set) var products: [SubscriptionStoreProduct] = []
    private(set) var isLoading: Bool = false
    private(set) var isPurchasing: Bool = false
    var errorMessage: String?

    private var storeProductsById: [String: Product] = [:]
    private var transactionUpdatesTask: Task<Void, Never>?
    private let baseURL = AppEnvironment.backendBaseURL

    private init() {
        startTransactionObserver()
    }

    func reset() {
        entitlement = nil
        products = []
        storeProductsById = [:]
        errorMessage = nil
        isLoading = false
        isPurchasing = false
    }

    var currentEntitlement: BillingEntitlement? {
        developerOverrideEntitlement(from: entitlement)
    }

    func refresh(forceStoreKitSync: Bool = true) async {
        guard AuthService.shared.isAuthenticated else {
            reset()
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            if forceStoreKitSync {
                try await syncCurrentTransactionsToBackend()
            }

            let response: BillingEntitlementEnvelope = try await sendAuthenticatedRequest(
                path: "/api/v1/billing/entitlements",
                method: "GET",
                body: Optional<String>.none
            )

            entitlement = response.entitlement
            try await loadStoreProducts(from: response.entitlement.catalog)
        } catch let error as BillingClientError {
            if case .unauthenticated = error {
                reset()
            } else if hasDeveloperFullAccess {
                entitlement = developerOverrideEntitlement(from: entitlement)
                errorMessage = nil
            } else {
                errorMessage = error.localizedDescription
            }
        } catch {
            if hasDeveloperFullAccess {
                entitlement = developerOverrideEntitlement(from: entitlement)
                errorMessage = nil
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    func claimInterviewAccess(
        sessionClientId: UUID,
        sessionMode: SessionMode
    ) async throws -> BillingAccessClaim {
        if let entitlement = currentEntitlement, hasDeveloperFullAccess {
            return BillingAccessClaim(
                sessionClientId: sessionClientId.uuidString,
                sessionMode: sessionMode.rawValue,
                accessSource: "developer_override",
                accessTier: entitlement.tier,
                consumedTrial: false,
                trialInterviewNumber: nil,
                entitlement: entitlement
            )
        }

        let response: BillingAccessClaimEnvelope = try await sendAuthenticatedRequest(
            path: "/api/v1/billing/access-claims",
            method: "POST",
            body: [
                "sessionClientId": sessionClientId.uuidString,
                "sessionMode": sessionMode.rawValue,
            ]
        )

        entitlement = response.claim.entitlement
        return response.claim
    }

    func purchase(productId: String) async throws {
        guard let product = storeProductsById[productId] else {
            throw BillingClientError.storeKit("This subscription product is not available on this device.")
        }

        guard let tokenString = currentAppAccountToken,
              let appAccountToken = UUID(uuidString: tokenString) else {
            throw BillingClientError.server("Your account is missing an App Store purchase token.")
        }

        isPurchasing = true
        defer { isPurchasing = false }

        let result = try await product.purchase(options: [.appAccountToken(appAccountToken)])

        switch result {
        case .success(let verification):
            let signedTransaction = try verifiedTransaction(verification)
            try await syncTransactionsToBackend([signedTransaction.jwsRepresentation])
            await signedTransaction.transaction.finish()
            await refresh(forceStoreKitSync: false)
        case .userCancelled:
            break
        case .pending:
            throw BillingClientError.storeKit("Purchase is pending approval.")
        @unknown default:
            throw BillingClientError.storeKit("Unexpected purchase result.")
        }
    }

    func restorePurchases() async throws {
        try await AppStore.sync()
        try await syncCurrentTransactionsToBackend()
        await refresh(forceStoreKitSync: false)
    }

    private var currentAppAccountToken: String? {
        currentEntitlement?.appAccountToken ?? AuthService.shared.currentUser?.appAccountToken
    }

    private func loadStoreProducts(from catalog: [BillingCatalogProduct]) async throws {
        guard !catalog.isEmpty else {
            products = []
            storeProductsById = [:]
            return
        }

        do {
            let storeProducts = try await Product.products(for: catalog.map(\.productId))
            storeProductsById = Dictionary(uniqueKeysWithValues: storeProducts.map { ($0.id, $0) })

            products = catalog.map { item in
                let product = storeProductsById[item.productId]
                return SubscriptionStoreProduct(
                    id: item.productId,
                    productId: item.productId,
                    tier: item.tier,
                    displayName: product?.displayName ?? item.displayName,
                    displayPrice: product?.displayPrice ?? item.billingLabel,
                    billingLabel: item.billingLabel,
                    features: item.features,
                    description: product?.description ?? item.features.joined(separator: ", ")
                )
            }
        } catch {
            // Keep the paywall usable even if StoreKit product metadata fails to load.
            products = catalog.map { item in
                SubscriptionStoreProduct(
                    id: item.productId,
                    productId: item.productId,
                    tier: item.tier,
                    displayName: item.displayName,
                    displayPrice: item.billingLabel,
                    billingLabel: item.billingLabel,
                    features: item.features,
                    description: item.features.joined(separator: ", ")
                )
            }
        }
    }

    private func startTransactionObserver() {
        transactionUpdatesTask = Task { [weak self] in
            guard let self else { return }

            for await update in Transaction.updates {
                do {
                    let signedTransaction = try self.verifiedTransaction(update)
                    try await self.syncTransactionsToBackend([signedTransaction.jwsRepresentation])
                    await signedTransaction.transaction.finish()
                } catch {
                    await MainActor.run {
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }

    private func syncCurrentTransactionsToBackend() async throws {
        var signedTransactions: [String] = []

        for await result in Transaction.currentEntitlements {
            let transaction = try verifiedTransaction(result)
            signedTransactions.append(transaction.jwsRepresentation)
        }

        guard !signedTransactions.isEmpty else { return }
        try await syncTransactionsToBackend(signedTransactions)
    }

    private func syncTransactionsToBackend(_ signedTransactions: [String]) async throws {
        let response: BillingEntitlementEnvelope = try await sendAuthenticatedRequest(
            path: "/api/v1/billing/app-store/sync",
            method: "POST",
            body: ["signedTransactions": signedTransactions]
        )

        entitlement = response.entitlement
        try await loadStoreProducts(from: response.entitlement.catalog)
    }

    private func sendAuthenticatedRequest<Body: Encodable, Response: Decodable>(
        path: String,
        method: String,
        body: Body?
    ) async throws -> Response {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw BillingClientError.invalidResponse
        }

        guard var request = await AuthService.shared.authenticatedRequest(url: url) else {
            throw BillingClientError.unauthenticated
        }

        request.httpMethod = method
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BillingClientError.invalidResponse
        }

        if httpResponse.statusCode >= 400 {
            throw decodeBillingError(data: data, statusCode: httpResponse.statusCode)
        }

        return try JSONDecoder().decode(Response.self, from: data)
    }

    private func decodeBillingError(data: Data, statusCode: Int) -> BillingClientError {
        let decoded = try? JSONDecoder().decode(PaymentAPIError.self, from: data)
        let message = decoded?.message ?? "Request failed (\(statusCode))"

        switch statusCode {
        case 401:
            return .unauthenticated
        case 402:
            return .paymentRequired(message)
        case 403:
            return .featureUnavailable(message)
        default:
            return .server(message)
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let signedType):
            return signedType
        case .unverified(_, let error):
            throw BillingClientError.storeKit(error.localizedDescription)
        }
    }

    private func verifiedTransaction(
        _ result: VerificationResult<Transaction>
    ) throws -> (transaction: Transaction, jwsRepresentation: String) {
        switch result {
        case .verified(let transaction):
            return (transaction, result.jwsRepresentation)
        case .unverified(_, let error):
            throw BillingClientError.storeKit(error.localizedDescription)
        }
    }

    private var hasDeveloperFullAccess: Bool {
        AuthService.shared.hasDeveloperFullAccess
    }

    private func developerOverrideEntitlement(from base: BillingEntitlement?) -> BillingEntitlement? {
        guard hasDeveloperFullAccess else { return base }

        let appAccountToken = base?.appAccountToken
            ?? AuthService.shared.currentUser?.appAccountToken
            ?? UUID().uuidString

        var featureFlags = base?.featureFlags ?? [:]
        featureFlags["live_interview"] = true
        featureFlags["voice_prep"] = true
        featureFlags["priority_models"] = true

        let features = Array(
            Set((base?.features ?? []) + [
                "Unlimited live interviews",
                "Voice prep",
                "Priority models",
                "Developer full access"
            ])
        ).sorted()

        return BillingEntitlement(
            tier: "sandbox",
            status: "active",
            accessSource: "developer_override",
            product: "developer_override",
            productId: base?.productId,
            features: features,
            featureFlags: featureFlags,
            sandboxFullAccess: true,
            trialInterviewLimit: base?.trialInterviewLimit ?? 0,
            trialInterviewsUsed: base?.trialInterviewsUsed ?? 0,
            interviewsRemaining: max(base?.interviewsRemaining ?? 0, 9_999),
            hasActiveSubscription: true,
            paywallRequired: false,
            appAccountToken: appAccountToken,
            currentPeriodEndsAt: base?.currentPeriodEndsAt,
            gracePeriodEndsAt: base?.gracePeriodEndsAt,
            catalog: base?.catalog ?? []
        )
    }
}

enum BillingClientError: LocalizedError {
    case unauthenticated
    case paymentRequired(String)
    case featureUnavailable(String)
    case invalidResponse
    case storeKit(String)
    case server(String)

    var errorDescription: String? {
        switch self {
        case .unauthenticated:
            return "Please sign in again."
        case .paymentRequired(let message):
            return message
        case .featureUnavailable(let message):
            return message
        case .invalidResponse:
            return "Invalid billing response."
        case .storeKit(let message):
            return message
        case .server(let message):
            return message
        }
    }
}
