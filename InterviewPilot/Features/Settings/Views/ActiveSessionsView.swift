import SwiftUI

struct ActiveSessionsView: View {
    @State private var sessions: [AuthSession] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var pendingRevocation: AuthSession?
    @State private var confirmRevokeAll = false
    @State private var workingDeviceId: String?
    @State private var isRevokingAll = false
    @State private var revokedCountToast: Int?

    private let service: SessionsService

    init(service: SessionsService = .shared) {
        self.service = service
    }

    var body: some View {
        ZStack {
            IAAppBackground().ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: IATheme.spacing20) {
                    header

                    if isLoading && sessions.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else if let error = errorMessage, sessions.isEmpty {
                        errorBanner(error)
                    } else {
                        sessionList
                        if sessions.contains(where: { !$0.current }) {
                            revokeAllButton
                        }
                    }
                }
                .padding(.horizontal, IATheme.spacing20)
                .padding(.vertical, IATheme.spacing20)
            }
        }
        .navigationTitle("Active Sessions")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .alert("Sign out other devices?", isPresented: $confirmRevokeAll) {
            Button("Sign Out Others", role: .destructive) {
                Task { await revokeAllOthers() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will sign you out of every device except this one.")
        }
        .alert(
            "Revoke this session?",
            isPresented: Binding(
                get: { pendingRevocation != nil },
                set: { if !$0 { pendingRevocation = nil } }
            )
        ) {
            Button("Revoke", role: .destructive) {
                if let target = pendingRevocation { Task { await revoke(target) } }
                pendingRevocation = nil
            }
            Button("Cancel", role: .cancel) { pendingRevocation = nil }
        } message: {
            if let target = pendingRevocation {
                Text("\(target.deviceLabel) will be signed out immediately.")
            }
        }
        .overlay(alignment: .bottom) {
            if let count = revokedCountToast {
                toast("Signed out \(count) session\(count == 1 ? "" : "s")")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Devices signed in")
                .font(IATypography.headlineLarge)
                .foregroundStyle(IATheme.textPrimary)

            Text("If you don't recognize a device, revoke it. Revoked sessions are signed out within 15 minutes.")
                .font(IATypography.bodySmall)
                .foregroundStyle(IATheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var sessionList: some View {
        VStack(spacing: 10) {
            ForEach(sessions) { session in
                row(for: session)
            }
        }
    }

    private func row(for session: AuthSession) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: session.current ? "checkmark.circle.fill" : "iphone")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(session.current ? IATheme.success : IATheme.accent)
                .frame(width: 36, height: 36)
                .background(
                    (session.current ? IATheme.success : IATheme.accent).opacity(0.10),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(session.deviceLabel)
                        .font(IATypography.headlineSmall)
                        .foregroundStyle(IATheme.textPrimary)
                    if session.current {
                        Text("Current")
                            .font(IATypography.labelSmall)
                            .foregroundStyle(IATheme.success)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(IATheme.success.opacity(0.10), in: Capsule())
                    }
                }

                Text("Last active \(session.lastUsedAt.formatted(.relative(presentation: .named)))")
                    .font(IATypography.bodySmall)
                    .foregroundStyle(IATheme.textSecondary)

                if let ua = session.userAgent, !ua.isEmpty, !session.current {
                    Text(ua)
                        .font(IATypography.bodySmall)
                        .foregroundStyle(IATheme.textSecondary)
                        .lineLimit(2)
                        .truncationMode(.tail)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !session.current, let deviceId = session.deviceId {
                Button {
                    pendingRevocation = session
                } label: {
                    if workingDeviceId == deviceId {
                        ProgressView().tint(IATheme.error)
                    } else {
                        Text("Revoke")
                            .font(IATypography.labelLarge)
                            .foregroundStyle(IATheme.error)
                    }
                }
                .disabled(workingDeviceId != nil)
                .accessibilityLabel("Revoke \(session.deviceLabel)")
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: IATheme.radiusLarge, style: .continuous)
                .fill(IATheme.surfaceWhite)
        )
        .overlay(
            RoundedRectangle(cornerRadius: IATheme.radiusLarge, style: .continuous)
                .stroke(IATheme.outlineVariant, lineWidth: 1)
        )
    }

    private var revokeAllButton: some View {
        Button {
            confirmRevokeAll = true
        } label: {
            HStack(spacing: 10) {
                if isRevokingAll {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "rectangle.portrait.and.arrow.right.fill")
                    Text("Sign out of all other devices")
                }
            }
        }
        .buttonStyle(IAPrimaryButtonStyle(isEnabled: !isRevokingAll))
        .disabled(isRevokingAll)
    }

    private func errorBanner(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(IATypography.bodySmall)
            .foregroundStyle(IATheme.error)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(IATheme.error.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func toast(_ text: String) -> some View {
        Text(text)
            .font(IATypography.labelLarge)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(IATheme.textPrimary.opacity(0.90), in: Capsule())
            .padding(.bottom, 24)
            .transition(.opacity)
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            sessions = try await service.listSessions()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func revoke(_ session: AuthSession) async {
        guard let deviceId = session.deviceId else { return }
        workingDeviceId = deviceId
        defer { workingDeviceId = nil }
        do {
            let count = try await service.revokeSession(deviceId: deviceId)
            withAnimation { revokedCountToast = count }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation { revokedCountToast = nil }
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func revokeAllOthers() async {
        isRevokingAll = true
        defer { isRevokingAll = false }
        do {
            let count = try await service.revokeAllOtherSessions()
            withAnimation { revokedCountToast = count }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation { revokedCountToast = nil }
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview("Active Sessions") {
    NavigationStack {
        ActiveSessionsView()
    }
}
