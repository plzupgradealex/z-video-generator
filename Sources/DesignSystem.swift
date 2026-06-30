import SwiftUI
import CoreText

// MARK: - Design system
//
// A focused port of the Mach (NSXMPP) design language: IBM Plex typography,
// Carbon spacing/radii, a dark "smoke" backdrop, and Liquid Glass used correctly
// (floating layer only — never on scrolling content). Glass surfaces float over
// `SmokeBackground`; cards that scroll use the solid `Surface` panel instead.
// See Apple WWDC25 sessions 219/323 for the Liquid Glass rules this follows.

// MARK: - Spacing (Carbon 8px base)

enum Spacing {
    static let s1: CGFloat = 2
    static let s2: CGFloat = 4
    static let s3: CGFloat = 8
    static let s4: CGFloat = 12
    static let s5: CGFloat = 16
    static let s6: CGFloat = 24
    static let s7: CGFloat = 32
    static let s9: CGFloat = 48
}

// MARK: - Radii (softened for Liquid Glass)

enum Radius {
    /// Controls — fields, buttons, chips.
    static let small: CGFloat = 12
    /// Cards and grouped surfaces.
    static let medium: CGFloat = 18
    /// Large surfaces / sheets.
    static let large: CGFloat = 26
}

// MARK: - App limits

enum AppLimits {
    /// Mirrors the Z.AI web app's 2048-character prompt ceiling.
    static let prompt = 2048
    /// Concurrent in-flight generations (the API, not the Mac, is the limit).
    static let maxConcurrent = 8
    /// Hard cap on queued jobs in the gallery.
    static let maxJobs = 24
}

// MARK: - Color

extension Color {
    /// Parse a hex string like "#0f62fe" or "0f62fe" into an sRGB Color.
    init(hex: String, opacity: Double = 1) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r = Double((v & 0xFF0000) >> 16) / 255
        let g = Double((v & 0x00FF00) >> 8) / 255
        let b = Double(v & 0x0000FF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}

/// Semantic color set for one appearance (light or dark).
struct AppColorSet {
    let background, surface, surfaceAlt, field, border, borderStrong: Color
    let text, textSecondary, textPlaceholder, textOnColor: Color
    let interactive, interactiveHover, interactiveSoft: Color
    let success, danger, warning: Color
}

/// Resolves the active color set. Dark is the "smoke" Carbon-g100 set; light is g10.
enum AppTheme {
    static func resolve(_ scheme: ColorScheme) -> AppColorSet {
        scheme == .dark ? dark : light
    }

    static let dark = AppColorSet(
        background: Color(hex: "0b0d12"), surface: Color(hex: "15171d"), surfaceAlt: Color(hex: "1d1f27"), field: Color(hex: "12141a"),
        border: Color(hex: "2a2d36"), borderStrong: Color(hex: "3a3e4a"),
        text: Color(hex: "efeff1"), textSecondary: Color(hex: "b4b4bc"), textPlaceholder: Color(hex: "86868f"), textOnColor: .white,
        interactive: Color(hex: "4f8dff"), interactiveHover: Color(hex: "3a78f2"), interactiveSoft: Color(hex: "223452"),
        success: Color(hex: "42be65"), danger: Color(hex: "fa4d56"), warning: Color(hex: "f1c21b"))

    static let light = AppColorSet(
        background: Color(hex: "f4f4f4"), surface: .white, surfaceAlt: Color(hex: "f4f4f4"), field: .white,
        border: Color(hex: "e0e0e0"), borderStrong: Color(hex: "c6c6c6"),
        text: Color(hex: "161616"), textSecondary: Color(hex: "525252"), textPlaceholder: Color(hex: "8d8d8d"), textOnColor: .white,
        interactive: Color(hex: "0f62fe"), interactiveHover: Color(hex: "0353e9"), interactiveSoft: Color(hex: "edf5ff"),
        success: Color(hex: "24a148"), danger: Color(hex: "da1e28"), warning: Color(hex: "f1c21b"))
}

// MARK: - Smoke background
//
// The window backdrop is smoke, not glass — full-screen glass is forbidden by
// Apple's Liquid Glass guidance (floating layer only). A vertical near-black ramp
// with a faint IBM-blue glow pooling at the top; glass floats above it.

enum Smoke {
    static let top = Color(hex: "10131a")
    static let bottom = Color(hex: "070809")
    static let base = Color(hex: "0b0d12")
    static let glow = Color(hex: "4f8dff")
    static let glowSpread: CGFloat = 1.4
}

struct SmokeBackground: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if reduceTransparency {
            (colorScheme == .dark ? Smoke.base : AppTheme.light.background)
                .ignoresSafeArea()
        } else {
            GeometryReader { proxy in
                let glowRadius = max(proxy.size.width, proxy.size.height) * Smoke.glowSpread
                ZStack {
                    if colorScheme == .dark {
                        LinearGradient(colors: [Smoke.top, Smoke.bottom], startPoint: .top, endPoint: .bottom)
                        RadialGradient(colors: [Smoke.glow.opacity(0.09), .clear], center: .top, startRadius: 0, endRadius: glowRadius)
                    } else {
                        LinearGradient(colors: [Color(hex: "f5f8fd"), Color(hex: "e7ebf2")], startPoint: .top, endPoint: .bottom)
                        RadialGradient(colors: [AppTheme.light.interactive.opacity(0.10), .clear], center: .top, startRadius: 0, endRadius: glowRadius)
                        RadialGradient(colors: [Color(hex: "0f62fe").opacity(0.05), .clear], center: UnitPoint(x: 0.85, y: 0.05), startRadius: 0, endRadius: glowRadius * 0.7)
                    }
                }
            }
            .ignoresSafeArea()
        }
    }
}

// MARK: - Typography (IBM Plex)

/// One entry in the Plex type ramp.
struct AppTypeStyle: Equatable {
    let size: CGFloat
    let weight: AppWeight
    let family: AppFontFamily
}

enum AppFontFamily: String {
    case sans = "IBM Plex Sans"
    case mono = "IBM Plex Mono"
}

enum AppWeight: String {
    case regular = "Regular"
    case medium = "Medium"
    case semibold = "SemiBold"
    case bold = "Bold"

    var swiftUI: Font.Weight {
        switch self {
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        }
    }
}

enum AppType {
    /// Uppercase eyebrow / label (Plex Mono, medium).
    static let label = AppTypeStyle(size: 12, weight: .medium, family: .mono)
    /// Secondary metadata (Plex Mono, regular).
    static let caption = AppTypeStyle(size: 12, weight: .regular, family: .mono)
    /// Tag/chip text (Plex Mono, medium, a touch larger).
    static let tag = AppTypeStyle(size: 11, weight: .medium, family: .mono)
    /// Body copy (Plex Sans).
    static let body = AppTypeStyle(size: 14, weight: .regular, family: .sans)
    /// Long-form body (Plex Sans).
    static let bodyLong = AppTypeStyle(size: 16, weight: .regular, family: .sans)
    /// Heading (Plex Sans, semibold).
    static let heading01 = AppTypeStyle(size: 20, weight: .semibold, family: .sans)
    /// Display heading (Plex Sans, semibold).
    static let heading02 = AppTypeStyle(size: 28, weight: .semibold, family: .sans)
    /// The wordmark (Plex Sans, semibold).
    static let wordmark = AppTypeStyle(size: 56, weight: .semibold, family: .sans)
}

extension AppTypeStyle {
    /// The exact bundled Plex PostScript name for this style. IBM Plex abbreviates
    /// weights in its PostScript names (`-Medm`, `-SmBld`); unbundled weights fall
    /// back to the nearest bundled face so `Font.custom` still resolves to Plex.
    var postScriptName: String {
        switch (family, weight) {
        case (.sans, .regular):   return "IBMPlexSans"
        case (.sans, .medium):    return "IBMPlexSans-Medm"
        case (.sans, .semibold):  return "IBMPlexSans-SmBld"
        case (.sans, .bold):      return "IBMPlexSans-Bold"
        case (.mono, .regular):   return "IBMPlexMono"
        case (.mono, .medium):    return "IBMPlexMono-Medm"
        case (.mono, .semibold):  return "IBMPlexMono-Medm"   // not bundled; nearest
        case (.mono, .bold):      return "IBMPlexMono"        // not bundled; nearest
        }
    }

    /// Resolve to a SwiftUI `Font` using the bundled Plex PostScript name.
    var font: Font {
        AppFont.ensureRegistered()
        return Font.custom(postScriptName, size: size)
    }
}

extension Font {
    /// Build a SwiftUI `Font` from an `AppTypeStyle`.
    static func app(_ style: AppTypeStyle) -> Font { style.font }
}

/// Loads and registers the bundled IBM Plex TTFs with CoreText so they resolve by
/// PostScript name. Idempotent and thread-safe (dispatch-once via a `static let`).
enum AppFont {
    /// The bundled Plex TTF basenames (file names, which differ from the internal
    /// PostScript names — see `AppTypeStyle.postScriptName`).
    static let bundledFontFiles: [String] = [
        "IBMPlexSans-Regular", "IBMPlexSans-Medium", "IBMPlexSans-SemiBold", "IBMPlexSans-Bold",
        "IBMPlexMono-Regular", "IBMPlexMono-Medium",
    ]

    private static let _registrationDone: Bool = {
        _ = registerBundledFonts()
        return true
    }()

    /// Ensure registration has run at least once (lazy, thread-safe).
    static func ensureRegistered() {
        _ = _registrationDone
    }

    /// Register every bundled Plex face into the current process.
    @discardableResult
    static func registerBundledFonts() -> Bool {
        var registered = 0
        for name in bundledFontFiles {
            let url = Bundle.main.url(forResource: name, withExtension: "ttf")
                ?? Bundle.main.url(forResource: name, withExtension: "ttf", subdirectory: "Fonts")
                ?? Bundle.main.url(forResource: name, withExtension: "ttf", subdirectory: "Resources/Fonts")
            guard let url else { continue }
            if CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil) {
                registered += 1
            }
        }
        return registered > 0
    }
}

// MARK: - Layout helpers

/// Resolve the active `AppColorSet` and hand it to a builder. Use so color
/// selection stays environment-driven rather than scattered through bodies.
struct Themed<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    private let content: (AppColorSet) -> Content

    init(@ViewBuilder _ content: @escaping (AppColorSet) -> Content) {
        self.content = content
    }

    var body: some View {
        content(AppTheme.resolve(scheme))
    }
}

// MARK: - Surface (solid panel for scrolling content — NOT glass)
//
// Per Apple's Liquid Glass guidance, glass belongs on the floating/navigation
// layer only; never on scrolling content. Cards that live in a scroll view use
// this solid, lightly translucent panel with a 1px border instead.

struct Surface<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    var radius: CGFloat
    var padding: CGFloat
    private let content: Content

    init(radius: CGFloat = Radius.medium, padding: CGFloat = Spacing.s5, @ViewBuilder content: () -> Content) {
        self.radius = radius
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        let set = AppTheme.resolve(scheme)
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(set.surface.opacity(scheme == .dark ? 0.72 : 0.9))
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(set.border, lineWidth: 1)
            )
            .shadow(color: scheme == .dark ? .clear : Color.black.opacity(0.06), radius: 3, x: 0, y: 2)
    }
}

/// An uppercase Plex-Mono section label.
struct Eyebrow: View {
    @Environment(\.colorScheme) private var scheme
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.app(AppType.label))
            .foregroundStyle(AppTheme.resolve(scheme).textSecondary)
            .tracking(0.8)
            .textCase(.uppercase)
    }
}

/// A small Plex-Mono metadata chip.
struct Chip: View {
    @Environment(\.colorScheme) private var scheme
    let text: String
    var tone: Tone = .neutral

    enum Tone { case neutral, accent, success, danger }

    /// Resolve the chip's foreground/background pair (a plain method, not in the
    /// `@ViewBuilder` body, so the `switch` returns a tuple rather than a view).
    private func colors(in set: AppColorSet) -> (foreground: Color, background: Color) {
        switch tone {
        case .neutral: return (set.textSecondary, set.field)
        case .accent:  return (set.interactive, set.interactiveSoft)
        case .success: return (set.success, set.success.opacity(0.16))
        case .danger:  return (set.danger, set.danger.opacity(0.16))
        }
    }

    var body: some View {
        let set = AppTheme.resolve(scheme)
        let c = colors(in: set)
        Text(text)
            .font(.app(AppType.tag))
            .foregroundStyle(c.foreground)
            .padding(.horizontal, Spacing.s2)
            .padding(.vertical, 3)
            .background(Capsule().fill(c.background.opacity(scheme == .dark ? 0.6 : 0.5)))
    }
}

// MARK: - Carbon ghost button
//
// Carbon "ghost/tertiary" idiom: borderless and transparent at rest, a subtle
// interactive-tinted fill on hover. Reserve for low-emphasis row actions
// (sidebar footer, list-row chevrons) — never for primary CTAs (use .glass /
// .glassProminent). A `ButtonStyle` is rebuilt every render, so hover state is
// driven by the call site and passed in as `hovered`.

struct CarbonGhostButtonStyle: ButtonStyle {
    let hovered: Bool
    @Environment(\.colorScheme) private var scheme

    func makeBody(configuration: Configuration) -> some View {
        let set = AppTheme.resolve(scheme)
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                    .fill(hovered ? set.interactive.opacity(scheme == .dark ? 0.12 : 0.08) : .clear)
            )
            .opacity(configuration.isPressed ? 0.65 : 1)
    }
}

extension ButtonStyle where Self == CarbonGhostButtonStyle {
    /// Carbon ghost button. Pass the owning view's `hovered` state.
    static func carbonGhost(hovered: Bool) -> CarbonGhostButtonStyle { .init(hovered: hovered) }
}

// MARK: - Carbon icon
//
// Renders a genuine IBM Carbon icon (bundled SVG from @carbon/icons, MIT) as a
// tintable vector. The asset is marked template, so tint it with
// `.foregroundStyle(...)` (or let the surrounding context, e.g. a List row,
// drive it). Carbon ships 32px glyphs; this scales them to the requested edge.

struct CarbonIcon: View {
    /// Asset name, e.g. "carbon-library".
    let name: String
    /// Rendered edge length in points.
    var size: CGFloat = 16

    var body: some View {
        Image(name)
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
            .frame(width: size, height: size)
    }
}

// MARK: - Liquid Glass helper (floating layer only)

extension View {
    /// Apply the real Liquid Glass material. Reserve for the floating/navigation
    /// layer (toolbars, floating cards, sheets) — never on scrolling content and
    /// never stacked on another glass surface (use a `GlassEffectContainer`).
    func glassSurface<S: Shape>(in shape: S, tint: Color? = nil) -> some View {
        self.glassEffect(tint.map { .regular.tint($0) } ?? .regular, in: shape)
    }

    /// A themed input-field background — solid field fill + 1px border at
    /// `Radius.small`. Adapts to light/dark so text fields read cleanly in both
    /// appearances instead of the dark-only `.white.opacity()` look.
    func fieldBackground() -> some View {
        modifier(ThemedFieldModifier())
    }
}

private struct ThemedFieldModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        let set = AppTheme.resolve(scheme)
        return content
            .background(
                RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                    .fill(set.field)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                    .strokeBorder(set.border, lineWidth: 1)
            )
    }
}
