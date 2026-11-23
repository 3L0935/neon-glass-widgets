import QtQuick

// The day drawn left to right (00:00 → 24:00): a gradient arc above the
// horizon between sunrise and sunset, a dotted dip below it at night, and the
// sun riding on it at the current hour.
Item {
    id: path
    required property var pal
    property real s: 1
    property real rise: 6
    property real set: 18
    property real hour: 12
    property bool isDay: true

    readonly property real horizonY: Math.round(height * 0.8) + 0.5
    readonly property real amp: horizonY - 14 * s
    readonly property real dip: Math.min(16 * s, height - horizonY - 4 * s)
    readonly property bool hasDay: set > rise
    readonly property bool allDay: set - rise >= 24

    function xAt(h) { return h / 24 * width }
    function yAt(h) {
        if (hasDay && h >= rise && h <= set) {
            if (allDay) return horizonY - amp * (0.55 + 0.45 * Math.cos((h - 12) / 12 * Math.PI))
            const noon = (rise + set) / 2, half = (set - rise) / 2
            return horizonY - amp * Math.cos((h - noon) / half * Math.PI / 2)
        }
        const nightLen = 24 - (set - rise)
        const d = h < rise ? h + 24 : h
        return horizonY + dip * Math.sin((d - set) / nightLen * Math.PI)
    }

    onRiseChanged: curve.requestPaint()
    onSetChanged: curve.requestPaint()
    onWidthChanged: curve.requestPaint()
    onHeightChanged: curve.requestPaint()
    Connections {
        target: path.pal
        function onAccentChanged() { curve.requestPaint() }
        function onAccent2Changed() { curve.requestPaint() }
        function onAccent3Changed() { curve.requestPaint() }
        function onFaintChanged() { curve.requestPaint() }
        function onEdgeChanged() { curve.requestPaint() }
    }

    Canvas {
        id: curve
        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d"), s = path.s, w = width, hy = path.horizonY
            ctx.reset()
            if (w <= 0 || height <= 0) return
            const step = 0.05
            const rgba = (c, a) => "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + a + ")"

            // night: dotted dip under the horizon
            if (!path.allDay) {
                ctx.save()
                ctx.strokeStyle = rgba(path.pal.faint, 0.55)
                ctx.lineWidth = 1.2 * s
                ctx.setLineDash([2, 5])
                ctx.beginPath()
                let started = false
                for (let h = 0; h <= 24.0001; h += step) {
                    const night = !path.hasDay || h < path.rise || h > path.set
                    if (!night) { started = false; continue }
                    const x = path.xAt(h), y = path.yAt(h)
                    if (!started) { ctx.moveTo(x, y); started = true } else ctx.lineTo(x, y)
                }
                ctx.stroke()
                ctx.restore()
            }

            // day: soft fill + gradient arc
            if (path.hasDay) {
                const r0 = Math.max(0, path.rise), r1 = Math.min(24, path.set)
                const grad = ctx.createLinearGradient(path.xAt(r0), 0, path.xAt(r1), 0)
                grad.addColorStop(0, path.pal.accent); grad.addColorStop(0.5, path.pal.accent2); grad.addColorStop(1, path.pal.accent3)
                const fill = ctx.createLinearGradient(0, hy - path.amp, 0, hy)
                fill.addColorStop(0, rgba(path.pal.accent2, 0.22)); fill.addColorStop(1, rgba(path.pal.accent2, 0))

                ctx.beginPath()
                ctx.moveTo(path.xAt(r0), hy)
                for (let h = r0; h <= r1 + 0.0001; h += step) ctx.lineTo(path.xAt(h), path.yAt(h))
                ctx.lineTo(path.xAt(r1), hy)
                ctx.closePath()
                ctx.fillStyle = fill
                ctx.fill()

                ctx.beginPath()
                for (let h = r0; h <= r1 + 0.0001; h += step) {
                    const x = path.xAt(h), y = path.yAt(h)
                    if (h === r0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
                }
                ctx.strokeStyle = grad
                ctx.lineWidth = 2 * s
                ctx.lineCap = "round"
                ctx.stroke()
            }

            // horizon + 6-hour marks
            ctx.strokeStyle = rgba(path.pal.edge, Math.min(1, path.pal.edge.a * 1.75))
            ctx.lineWidth = 1
            ctx.beginPath(); ctx.moveTo(0, hy); ctx.lineTo(w, hy); ctx.stroke()
            ctx.strokeStyle = rgba(path.pal.edge, Math.min(1, path.pal.edge.a * 2.25))
            for (const h of [0, 6, 12, 18, 24]) {
                const x = Math.min(w - 0.5, Math.max(0.5, Math.round(path.xAt(h)) + 0.5))
                ctx.beginPath(); ctx.moveTo(x, hy - 3 * s); ctx.lineTo(x, hy + 3 * s); ctx.stroke()
            }
        }
    }

    // the sun: soft glow + bright core
    Item {
        id: sunDot
        readonly property real sx: path.xAt(path.hour)
        readonly property real sy: path.yAt(path.hour)
        x: sx; y: sy
        Behavior on x { NumberAnimation { duration: 900; easing.type: Easing.InOutSine } }
        Behavior on y { NumberAnimation { duration: 900; easing.type: Easing.InOutSine } }

        Canvas {
            id: glow
            readonly property real r: 16 * path.s
            readonly property color c: path.isDay ? path.pal.accent3 : path.pal.accent
            onCChanged: requestPaint()
            onRChanged: requestPaint()
            width: r * 2; height: r * 2
            x: -r; y: -r
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const g = ctx.createRadialGradient(r, r, 0, r, r, r)
                const rgb = Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255)
                g.addColorStop(0, "rgba(" + rgb + ",0.75)")
                g.addColorStop(0.4, "rgba(" + rgb + ",0.35)")
                g.addColorStop(1, "rgba(" + rgb + ",0)")
                ctx.fillStyle = g
                ctx.fillRect(0, 0, width, height)
            }
        }
        Rectangle {
            readonly property real d: 10 * path.s
            width: d; height: d; radius: d / 2
            x: -d / 2; y: -d / 2
            color: path.isDay ? path.pal.mix(path.pal.text, path.pal.accent3, 0.25) : path.pal.muted
        }
    }
}
