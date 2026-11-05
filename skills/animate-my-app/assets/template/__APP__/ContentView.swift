import SwiftUI

/// Laid out on the Figma canvas in points and scaled to the device. The three.js timeline is the single
/// source of truth: it sends cues ("headline", "button", …) and SwiftUI animates the native UI on them.
struct ContentView: View {

    // Design canvas = the Figma frame (iPhone 17 Pro logical size).
    private let CW: CGFloat = 402
    private let CH: CGFloat = 874

    private let bridge = SceneBridge.shared
    @State private var headIn = false
    @State private var btnIn = false
    @State private var veil = false        // content fades to white while a replay resets behind it
    @State private var replaying = false

    private let brand = Color(red: 8 / 255, green: 118 / 255, blue: 255 / 255)
    private let ink = Color(red: 26 / 255, green: 26 / 255, blue: 26 / 255)

    /// Primary action sits in the thumb zone: 16pt above the bottom safe area (Apple HIG), never in the
    /// home-indicator area. Keep the designed spacing between headline and button.
    private let buttonGapAboveSafeArea: CGFloat = 16

    private var bottomSafeInset: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?.safeAreaInsets.bottom ?? 34
    }

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width / CW, geo.size.height / CH)
            ZStack {
                Color.white

                SceneLayer(bridge: bridge)
                    .frame(width: CW, height: CH)
                    .allowsHitTesting(false)
                    .opacity(veil ? 0 : 1)

                // tap anywhere (except the button) to replay; the web view would otherwise swallow touches
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { replay() }

                VStack(spacing: 32) {
                    Text("Replace with the design's headline")
                        .font(.system(size: 34, weight: .bold))
                        .multilineTextAlignment(.center)
                        .foregroundColor(ink)
                        .frame(width: 360)
                        .allowsHitTesting(false)
                        .opacity(headIn ? 1 : 0)
                        .offset(y: headIn ? 0 : 26)

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Text("Get started")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 354, height: 58)
                            .background(Capsule().fill(brand))
                    }
                    .buttonStyle(PressScaleStyle())
                    .allowsHitTesting(btnIn)
                    .opacity(btnIn ? 1 : 0)
                    .offset(y: btnIn ? 0 : 26)
                    .scaleEffect(btnIn ? 1 : 0.9)
                }
                .padding(.bottom, bottomSafeInset / s + buttonGapAboveSafeArea)
                .frame(width: CW, height: CH, alignment: .bottom)
                .opacity(veil ? 0 : 1)
            }
            .frame(width: CW, height: CH)
            .scaleEffect(s)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .ignoresSafeArea()
        .background(Color.white.ignoresSafeArea())
        .onReceive(NotificationCenter.default.publisher(for: .replayRequested)) { _ in replay() }
        .onAppear {
            bridge.onEvent = { event in
                switch event {
                case "headline": withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { headIn = true }
                case "button": withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { btnIn = true }
                case "reset" where replaying:
                    // the scene is blank again; lift the veil a beat later so no old frame can show
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withTransaction(Transaction(animation: nil)) { veil = false }
                        replaying = false
                    }
                default: break
                }
            }
        }
    }

    /// Restart the intro from its first frame: fade to white, reset behind the veil, start warm.
    private func replay() {
        guard !replaying else { return }
        replaying = true
        withAnimation(.easeOut(duration: 0.18)) { veil = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withTransaction(Transaction(animation: nil)) {
                headIn = false
                btnIn = false
            }
            bridge.replay()
        }
    }
}

/// Pressables acknowledge the touch immediately: a quick 0.97 scale-down, released with a soft spring.
private struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(configuration.isPressed ? .easeOut(duration: 0.1) : .spring(response: 0.3, dampingFraction: 0.6),
                       value: configuration.isPressed)
    }
}
