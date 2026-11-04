import SwiftUI
import UIKit

/// One cover owns entry and exit. The runtime warms without gameplay, and the
/// native destination stays hidden until its original orientation is restored.
struct TuvloWorldEntry<Content: View>: View {
    let isVisible: Bool
    let onTasks: () -> Void
    var nativeRecoveryReady = false
    @ViewBuilder let content: (Bool, Binding<Bool>, @escaping () -> Void) -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var entered = false
    @State private var ready = false
    @State private var leaving = false
    @State private var restoringOrientation = false
    @State private var coverPresented = false
    var body: some View {
        ZStack {
            content(isVisible && entered && !restoringOrientation, $ready, beginLeaving)
                .allowsHitTesting(isVisible && entered && !leaving)
                .accessibilityHidden(!isVisible || !entered || leaving)
            if isVisible && !entered && !leaving {
                TuvloWorldOpening(isReady: ready || nativeRecoveryReady, onTasks: beginLeaving) {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { entered = true }
                }
                .background(WorldCoverDisplayBoundary { coverPresented = true })
                .transition(.opacity)
            }
            if leaving {
                TuvloWorldLoadingSurface(returning: true)
                    .background(WorldCoverDisplayBoundary {
                        if leaving { restoringOrientation = true }
                    })
                    .accessibilityIdentifier("world.returning")
            }
        }
        .statusBarHidden(isVisible)
        .dynamicTypeSize(.large)
        .background(LivingWorldOrientationAnchor(active: isVisible && (coverPresented || entered) && !restoringOrientation, onRestored: {
            guard leaving else { return }
            onTasks()
            leaving = false
            restoringOrientation = false
            entered = false
        }).frame(width: 0, height: 0))
        .onChange(of: isVisible) { _, visible in if !visible { entered = false; leaving = false; restoringOrientation = false; coverPresented = false } }
        .onChange(of: ready) { _, ready in if !ready { entered = false } }
        .onChange(of: nativeRecoveryReady) { _, recovery in
            if !recovery && !ready { entered = false }
        }
    }
    private func beginLeaving() {
        guard !leaving else { return }
        // Opaque immediately; do not dissolve a landscape screen into portrait.
        var transaction = Transaction(); transaction.disablesAnimations = true
        withTransaction(transaction) { leaving = true }
    }
}

/// A display boundary, rather than a timed hold: orientation may change only
/// after the new opaque cover has had a frame on screen. Cancels on removal.
private struct WorldCoverDisplayBoundary: UIViewRepresentable {
    let displayed: () -> Void
    func makeUIView(context: Context) -> Boundary { Boundary() }
    func updateUIView(_ view: Boundary, context: Context) { view.displayed = displayed }
    final class Boundary: UIView {
        var displayed: (() -> Void)?
        private var link: CADisplayLink?
        private var sawDisplayBoundary = false
        override init(frame: CGRect) { super.init(frame: frame); isUserInteractionEnabled = false }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        override func didMoveToWindow() {
            super.didMoveToWindow()
            link?.invalidate(); link = nil
            guard window != nil else { return }
            sawDisplayBoundary = false
            let link = CADisplayLink(target: self, selector: #selector(frameDisplayed))
            self.link = link
            link.add(to: .main, forMode: .common)
        }
        @objc private func frameDisplayed() {
            guard sawDisplayBoundary else { sawDisplayBoundary = true; return }
            link?.invalidate(); link = nil
            displayed?()
        }
    }
}

/// A stable composition through changing bounds, without a branding timer.
private struct TuvloWorldLoadingSurface: View {
    var returning = false
    private let logoBounds = CGRect(x: 38.75, y: 3.1, width: 518.59, height: 256.9)
    var body: some View {
        GeometryReader { area in
            let width = min(min(area.size.width, area.size.height) * 0.62, 320)
            ZStack {
                LinearGradient(colors: [Color(red: 0.95, green: 0.94, blue: 0.88), Color(red: 0.85, green: 0.89, blue: 0.82)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                VStack(spacing: 12) {
                    TuvloLogoArtwork(frame: OpeningLogoFrame(time: 3, reduceMotion: true))
                        .frame(width: 600, height: 300)
                        .offset(x: -logoBounds.minX, y: -logoBounds.minY)
                        .frame(width: logoBounds.width, height: logoBounds.height, alignment: .topLeading)
                        .scaleEffect(width / logoBounds.width, anchor: .topLeading)
                        .frame(width: width, height: width * logoBounds.height / logoBounds.width, alignment: .topLeading)
                        .accessibilityHidden(true)
                    TuvloWorldWordmark().frame(width: width, height: width * 613 / 2023)
                    ProgressView()
                        .tint(Color(red: 0.09, green: 0.29, blue: 0.28))
                        .accessibilityLabel(returning ? "Returning to Tuvlo" : "Loading your World")
                        .accessibilityIdentifier("world.intro.loading")
                    if !returning && area.size.width <= area.size.height {
                        Text("Turn to landscape").font(.headline)
                        Text("On iPad, expand this window for your World.")
                            .font(.subheadline).multilineTextAlignment(.center)
                    }
                }
                .foregroundStyle(Color(red: 0.09, green: 0.29, blue: 0.28))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(24)
            }
        }
    }
}

/// Errors reveal their native recovery UI rather than waiting for a scene frame.
struct TuvloWorldOpening: View {
    var isReady = true
    let onTasks: () -> Void
    let onFinished: () -> Void
    @Environment(\.scenePhase) private var phase
    @State private var exitRequested = false
    @State private var finished = false
    @State private var hasLandscapeSpace = false
    var body: some View {
        GeometryReader { area in
            TuvloWorldLoadingSurface()
                .overlay(alignment: .topLeading) {
                    HomesteadReturnButton(identifier: "world.intro.tasks") { exitRequested = true }
                        .padding(12)
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("world.intro")
                .accessibilityLabel("Tuvlo World")
                .onChange(of: area.size, initial: true) { _, size in hasLandscapeSpace = size.width > size.height }
        }
        .onChange(of: hasLandscapeSpace, initial: true) { _, _ in finishIfReady() }
        .onChange(of: phase) { _, _ in finishIfReady() }
        .onChange(of: isReady) { _, _ in finishIfReady() }
        .onChange(of: exitRequested) { _, _ in finishIfReady() }
        .worldExitConfirmation(isPresented: $exitRequested, leave: onTasks)
    }
    private func finishIfReady() {
        guard !finished, !exitRequested, isReady, hasLandscapeSpace, phase == .active else { return }
        finished = true; onFinished()
    }
}

/// Fit visible lettering, rather than the differently padded source canvases.
struct TuvloWorldWordmark: View {
    var body: some View {
        GeometryReader { area in
            Image("WorldWordmark").resizable()
                .frame(width: area.size.width * 2064 / 2023, height: area.size.height * 762 / 613)
                .offset(x: -area.size.width * 23 / 2023, y: -area.size.height * 59 / 613)
        }.clipped().accessibilityHidden(true)
    }
}

/// Shared by the loading screen and the live World; choosing Stay changes no game state.
extension View {
    func worldExitConfirmation(isPresented: Binding<Bool>, leave: @escaping () -> Void) -> some View {
        modifier(HomesteadWorldExitDialog(presented: isPresented, leave: leave))
    }
}
