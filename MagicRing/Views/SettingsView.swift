import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: PanelSettings

    private var appearance: PanelAppearance {
        settings.style.appearance
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            styleGrid
            livePreview
        }
        .padding(20)
        .frame(width: 390, height: 330)
        .background(.regularMaterial)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(.primary.opacity(0.06))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("MagicRing")
                    .font(.system(size: 18, weight: .semibold))

                Text("Panel Style")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
    }

    private var styleGrid: some View {
        LazyVGrid(columns: styleColumns, spacing: 10) {
            ForEach(PanelStyle.allCases) { style in
                StyleOptionButton(
                    style: style,
                    isSelected: settings.style == style
                ) {
                    settings.style = style
                }
            }
        }
    }

    private var styleColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]
    }

    private var livePreview: some View {
        HStack(spacing: 14) {
            MiniPanelPreview(appearance: appearance)

            VStack(alignment: .leading, spacing: 5) {
                Text(settings.style.title)
                    .font(.system(size: 13, weight: .semibold))

                HStack(spacing: 6) {
                    Label("Glass", systemImage: "circle.lefthalf.filled")
                    Label("Live", systemImage: "bolt.fill")
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.primary.opacity(0.045))
        )
    }
}

private struct StyleOptionButton: View {
    let style: PanelStyle
    let isSelected: Bool
    let action: () -> Void

    private var appearance: PanelAppearance {
        style.appearance
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 9) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [appearance.overlayStart, appearance.overlayEnd],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(previewBars)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                            .padding(6)
                    }
                }
                .frame(height: 58)

                Text(style.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .padding(9)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.13) : Color.primary.opacity(0.035))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor.opacity(0.55) : Color.primary.opacity(0.08), lineWidth: isSelected ? 1.2 : 0.8)
            )
        }
        .buttonStyle(.plain)
    }

    private var previewBars: some View {
        VStack(alignment: .leading, spacing: 6) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(.white.opacity(0.55))
                .frame(width: 34, height: 4)

            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(.white.opacity(0.24))
                .frame(width: 50, height: 4)

            Spacer(minLength: 0)
        }
        .padding(10)
    }
}

private struct MiniPanelPreview: View {
    let appearance: PanelAppearance

    var body: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(.thinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [appearance.overlayStart, appearance.overlayEnd],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                HStack(spacing: 8) {
                    ForEach([Color.green, Color.mint, Color.orange], id: \.self) { color in
                        Circle()
                            .trim(from: 0.12, to: 0.82)
                            .stroke(color.gradient, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 28, height: 28)
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.white.opacity(appearance.borderOpacity), lineWidth: 0.8)
            )
            .shadow(color: .black.opacity(appearance.shadowOpacity), radius: 8, y: 4)
            .frame(width: 112, height: 56)
    }
}
