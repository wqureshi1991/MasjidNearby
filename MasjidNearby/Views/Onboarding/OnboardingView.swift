import SwiftUI

/// Placeholder until Phase 3 adds real sign-in.
struct OnboardingView: View {
    let coordinator: AppCoordinator

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "building.columns")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("Masjid Nearby")
                .font(.largeTitle.bold())
            Text("Prayer times from masjids near you.")
                .foregroundStyle(.secondary)

            #if DEBUG
            VStack(spacing: 12) {
                Button("Continue as User") {
                    Task { await coordinator.debugSignIn(as: .user) }
                }
                .buttonStyle(.borderedProminent)

                Button("Continue as Masjid Admin") {
                    Task { await coordinator.debugSignIn(as: .masjidAdmin) }
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, 24)
            #endif
        }
        .padding()
    }
}
