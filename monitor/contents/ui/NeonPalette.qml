import QtQuick

// Colors and fonts shared by every Neon Glass widget, read from the
// "Appearance" config group. Empty font settings fall back to the preferred
// families when installed, then to the system font.
QtObject {
    id: pal
    required property var cfg

    readonly property color accent: cfg.accentColor
    readonly property color accent2: cfg.secondaryColor
    readonly property color accent3: cfg.tertiaryColor
    readonly property color text: cfg.textColor
    readonly property color muted: cfg.mutedColor
    readonly property color faint: cfg.faintColor
    readonly property color edge: withAlpha(cfg.edgeColor, cfg.edgeOpacity)
    readonly property color glass: withAlpha(cfg.glassColor, cfg.glassOpacity)
    readonly property real radius: cfg.cornerRadius
    readonly property url backgroundImage: cfg.backgroundImage ? toUrl(cfg.backgroundImage) : ""
    readonly property real blurAmount: cfg.blurAmount

    readonly property string sans: pick(cfg.sansFont, ["Inter", "Inter Variable"], Qt.application.font.family)
    readonly property string mono: pick(cfg.monoFont, ["JetBrains Mono", "JetBrainsMono Nerd Font", "Hack", "DejaVu Sans Mono"], "monospace")

    function withAlpha(c, a) { const q = Qt.color(c); return Qt.rgba(q.r, q.g, q.b, a) }
    function toUrl(path) { return path.indexOf("://") > 0 ? path : "file://" + path }
    function pick(user, preferred, fallback) {
        if (user) return user
        const installed = Qt.fontFamilies()
        for (const f of preferred) if (installed.indexOf(f) >= 0) return f
        return fallback
    }
    // linear blend between two palette colors, t in 0..1
    function mix(a, b, t) {
        t = Math.max(0, Math.min(1, t))
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t)
    }
}
