import SwiftUI

struct DashboardSyncBanner: View {
    let done: Int
    let total: Int
    let inFlight: Int
    let phase: CGFloat

    private var progress: CGFloat {
        guard total > 0 else { return 0 }
        return CGFloat(done) / CGFloat(total)
    }

    private var title: String {
        if total == 0 { return "All changes are up to date" }
        if done >= total { return "All changes uploaded" }
        if inFlight > 0 { return "Uploading… (\(inFlight) in progress)" }
        return "Syncing changes…"
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.76))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )

            GeometryReader { _ in
                ZStack {
                    WaterWave(progress: progress, phase: phase, amplitude: 6)
                        .fill(Color.accentColor.opacity(0.55))
                        .blur(radius: 0.4)
                    WaterWave(progress: progress, phase: phase * 1.6 + 0.2, amplitude: 4)
                        .fill(Color.accentColor.opacity(0.75))
                }
                .mask(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
            }

            HStack(spacing: JTSpacing.sm) {
                Image(systemName: "arrow.up.arrow.down.circle.fill")
                    .imageScale(.medium)
                    .foregroundStyle(Color.white.opacity(0.95))
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text("\(max(done, 0))/\(max(total, 0))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.9))
                    .padding(.horizontal, JTSpacing.sm)
                    .padding(.vertical, JTSpacing.xs)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, JTSpacing.md)
        }
        .frame(height: 44)
        .padding(.horizontal, JTSpacing.lg)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }
}

struct WaterWave: Shape {
    var progress: CGFloat
    var phase: CGFloat
    var amplitude: CGFloat

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let twoPi = CGFloat.pi * 2
        let level = rect.height * (1 - max(0, min(progress, 1)))
        let wavelength = max(rect.width / 1.2, 1)
        let radians = phase * twoPi

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: level))

        var x: CGFloat = 0
        while x <= rect.width {
            let relative = x / wavelength
            let y = level + sin(relative * twoPi + radians) * amplitude
            path.addLine(to: CGPoint(x: rect.minX + x, y: y))
            x += 1
        }

        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview("Sync Banner – Uploading") {
    DashboardSyncBanner(done: 2, total: 5, inFlight: 1, phase: 0.3)
        .padding(.vertical)
        .background(JTGradients.background.ignoresSafeArea())
}

#Preview("Sync Banner – Complete") {
    DashboardSyncBanner(done: 5, total: 5, inFlight: 0, phase: 0.9)
        .padding(.vertical)
        .background(JTGradients.background.ignoresSafeArea())
        .frame(maxWidth: 600)
}
