import SwiftUI

/// Reusable empty-state view for sub-pages (library lists, queue,
/// recently deleted, smart playlist no-match, etc.). Three goals:
///
/// 1. **Visual consistency** — every empty state across the app
///    looks like it came from the same designer instead of N
///    different `ContentUnavailableView` flavors.
/// 2. **Asset-optional** — the call site names an image asset (e.g.
///    "EmptyStateNoSongs"); if that asset is in the bundle, it
///    renders. If not, the matching SF Symbol shows. So we can
///    ship code first and add custom illustrations later without a
///    second pass.
/// 3. **Action-aware** — supports an optional CTA button so views
///    that have a recovery path ("add a source", "create a
///    playlist") get a single tap to fix the empty state.
///
/// Use this in preference to `ContentUnavailableView` whenever the
/// empty state is content-related ("no songs in library", "smart
/// playlist matched nothing"). Keep `ContentUnavailableView.search`
/// for the system-styled search empty state — Apple's version
/// already has the perfect treatment for that one specific case.
struct EmptyStateView: View {
    let titleKey: LocalizedStringKey
    let descriptionKey: LocalizedStringKey?
    let imageName: String?
    let systemImage: String
    let actionLabel: LocalizedStringKey?
    let action: (() -> Void)?

    init(
        titleKey: LocalizedStringKey,
        descriptionKey: LocalizedStringKey? = nil,
        imageName: String? = nil,
        systemImage: String,
        actionLabel: LocalizedStringKey? = nil,
        action: (() -> Void)? = nil
    ) {
        self.titleKey = titleKey
        self.descriptionKey = descriptionKey
        self.imageName = imageName
        self.systemImage = systemImage
        self.actionLabel = actionLabel
        self.action = action
    }

    var body: some View {
        VStack(spacing: 18) {
            illustration
            VStack(spacing: 6) {
                Text(titleKey)
                    .font(.title3).fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                if let descriptionKey {
                    Text(descriptionKey)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            }
            if let actionLabel, let action {
                Button(action: action) {
                    Text(actionLabel)
                        .fontWeight(.medium)
                        .padding(.horizontal, 22).padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .clipShape(Capsule())
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    /// Try the named asset first. `UIImage(named:)` is bundle-checked
    /// so a missing asset cleanly falls through to the SF Symbol —
    /// this is what lets us merge the empty-state code before all
    /// the AI illustrations exist.
    @ViewBuilder
    private var illustration: some View {
        if let imageName, UIImage(named: imageName) != nil {
            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 180)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: .black.opacity(0.10), radius: 10, y: 5)
        } else {
            Image(systemName: systemImage)
                .font(.system(size: 52))
                .foregroundStyle(.tertiary)
                .frame(width: 88, height: 88)
        }
    }
}
