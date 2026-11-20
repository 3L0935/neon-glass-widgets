import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.ksysguard.sensors as Sensors

PlasmoidItem {
    id: root

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    readonly property var cfg: Plasmoid.configuration
    property NeonPalette pal: NeonPalette { cfg: Plasmoid.configuration }

    readonly property string gpu: "gpu/gpu" + cfg.gpuIndex + "/"
    readonly property bool showGpu: cfg.showGpu
    readonly property int historyLength: Math.max(10, cfg.historySeconds)

    property var cpuHistory: []
    property var gpuHistory: []
    property double lastSample: 0
    // the graph ceiling follows the recent peak (25 % minimum), rounded to a clean step
    readonly property real scaleTarget: {
        const peak = Math.max(1, Math.max.apply(null, cpuHistory.concat(showGpu ? gpuHistory : []).concat([0])))
        return Math.min(100, Math.max(25, Math.ceil(peak * 1.25 / 25) * 25))
    }
    property real scaleMax: scaleTarget
    Behavior on scaleMax { NumberAnimation { duration: 1200; easing.type: Easing.InOutCubic } }

    // eased copies of the slow sensors, so the numbers glide instead of jumping
    property real cpuTempS: num(cpuTemp.value)
    property real gpuTempS: num(gpuTemp.value)
    property real cpuFreqS: num(cpuFreq.value)
    property real gpuFreqS: num(gpuFreq.value)
    Behavior on cpuTempS { NumberAnimation { duration: 1800; easing.type: Easing.InOutSine } }
    Behavior on gpuTempS { NumberAnimation { duration: 1800; easing.type: Easing.InOutSine } }
    Behavior on cpuFreqS { NumberAnimation { duration: 900; easing.type: Easing.OutCubic } }
    Behavior on gpuFreqS { NumberAnimation { duration: 900; easing.type: Easing.OutCubic } }

    Sensors.Sensor { id: cpuUsage;  sensorId: "cpu/all/usage";              updateRateLimit: 1000 }
    Sensors.Sensor { id: cpuTemp;   sensorId: "cpu/all/averageTemperature"; updateRateLimit: 2000 }
    Sensors.Sensor { id: cpuFreq;   sensorId: "cpu/all/averageFrequency";   updateRateLimit: 1000 }
    Sensors.Sensor { id: gpuUsage;  sensorId: root.showGpu ? root.gpu + "usage" : "";         updateRateLimit: 1000 }
    Sensors.Sensor { id: gpuTemp;   sensorId: root.showGpu ? root.gpu + "temperature" : "";   updateRateLimit: 2000 }
    Sensors.Sensor { id: gpuFreq;   sensorId: root.showGpu ? root.gpu + "coreFrequency" : ""; updateRateLimit: 1000 }
    Sensors.Sensor { id: vramUsed;  sensorId: root.showGpu ? root.gpu + "usedVram" : "";      updateRateLimit: 2000 }
    Sensors.Sensor { id: vramTotal; sensorId: root.showGpu ? root.gpu + "totalVram" : "";     updateRateLimit: 60000 }
    Sensors.Sensor { id: ramUsed;   sensorId: "memory/physical/used";       updateRateLimit: 2000 }
    Sensors.Sensor { id: ramTotal;  sensorId: "memory/physical/total";      updateRateLimit: 60000 }
    Sensors.Sensor { id: hostname;  sensorId: "os/system/hostname";         updateRateLimit: 600000 }
    Sensors.Sensor { id: uptime;    sensorId: "os/system/uptime";           updateRateLimit: 30000 }

    function num(v) { const n = Number(v); return isFinite(n) ? n : 0 }
    function ghz(mhz) { return (num(mhz) / 1000).toFixed(2) + " GHz" }
    function gib(bytes) { return num(bytes) / 1073741824 }
    function fmtUptime(s) {
        s = Math.floor(num(s))
        const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60)
        return "up " + (d > 0 ? d + "d " + h + "h" : h + "h " + (m < 10 ? "0" : "") + m + "m")
    }

    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            const c = root.cpuHistory.slice(), g = root.gpuHistory.slice()
            const cv = root.num(cpuUsage.value), gv = root.num(gpuUsage.value)
            // first sample: fill the whole window so the graph never starts half empty
            if (c.length === 0) for (let i = 0; i < root.historyLength + 2; i++) { c.push(cv); g.push(gv) }
            else { c.push(cv); g.push(gv) }
            while (c.length > root.historyLength + 2) c.shift()
            while (g.length > root.historyLength + 2) g.shift()
            root.cpuHistory = c; root.gpuHistory = g
            root.lastSample = Date.now()
        }
    }

    fullRepresentation: Item {
        id: full
        readonly property int memRows: (root.cfg.showRam ? 1 : 0) + (root.cfg.showVram && root.showGpu ? 1 : 0)
        Layout.preferredWidth: 400
        Layout.preferredHeight: 46 + 150 + (root.cfg.showLoadGraph ? 96 : 0) + (memRows > 0 ? memRows * 17 + 6 : 0)
        Layout.minimumWidth: 280
        Layout.minimumHeight: Layout.preferredHeight * 0.75

        // everything scales with the widget width
        readonly property real s: Math.max(0.6, width / 400)

        GlassCard {
            anchors.fill: parent
            pal: root.pal
            s: full.s
            blurBehind: Plasmoid.formFactor === PlasmaCore.Types.Planar

            leftLabel: Text {
                textFormat: Text.StyledText
                text: root.cfg.title + (root.cfg.showHostname
                      ? " <font color='" + pal.faint + "'>· </font><font color='" + pal.muted + "'>" + (hostname.value || "localhost") + "</font>" : "")
                color: pal.accent3
                font { family: pal.mono; pixelSize: 11.5 * full.s; letterSpacing: 0.6 }
            }
            rightLabelVisible: root.cfg.showUptime
            rightLabel: Text {
                text: root.fmtUptime(uptime.value)
                color: pal.muted
                font { family: pal.mono; pixelSize: 11 * full.s }
            }

            ColumnLayout {
                anchors { fill: parent; topMargin: 30 * full.s; leftMargin: 18 * full.s; rightMargin: 18 * full.s; bottomMargin: 16 * full.s }
                spacing: 14 * full.s

                // rings
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 136 * full.s
                    spacing: 6 * full.s
                    Ring {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        label: "CPU"; accent: pal.accent
                        value: root.num(cpuUsage.value)
                        detail: "<b><font color='" + pal.accent + "'>" + Math.round(root.cpuTempS) + "°C</font></b> · " + root.ghz(root.cpuFreqS)
                    }
                    Ring {
                        visible: root.showGpu
                        Layout.fillWidth: true; Layout.fillHeight: true
                        label: "GPU"; accent: pal.accent2
                        value: root.num(gpuUsage.value)
                        detail: "<b><font color='" + pal.accent2 + "'>" + Math.round(root.gpuTempS) + "°C</font></b> · " + root.ghz(root.gpuFreqS)
                    }
                }

                // load history
                ColumnLayout {
                    visible: root.cfg.showLoadGraph
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 2 * full.s
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "LOAD · " + root.historyLength + "s · 0–" + Math.round(root.scaleTarget) + "%"
                            color: pal.faint; font { family: pal.mono; pixelSize: 10 * full.s; letterSpacing: 1.4 }
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            textFormat: Text.StyledText
                            text: "<font color='" + pal.accent + "'>━ cpu</font>" + (root.showGpu ? "  <font color='" + pal.accent2 + "'>━ gpu</font>" : "")
                            font { family: pal.mono; pixelSize: 10 * full.s; letterSpacing: 1.4 }
                        }
                    }
                    Canvas {
                        id: spark
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: 40 * full.s
                        // ~30 fps: scroll between samples so the graph glides instead of jumping
                        Timer { interval: 33; repeat: true; running: spark.visible; onTriggered: spark.requestPaint() }
                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.reset()
                            const max = root.scaleMax, pad = 4
                            const step = width / (root.historyLength - 1)
                            const phase = Math.max(0, Math.min(1, (Date.now() - root.lastSample) / 1000))
                            // faint guide at 50 %
                            ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.05); ctx.lineWidth = 1
                            ctx.beginPath(); ctx.moveTo(0, Math.round(height / 2) + 0.5); ctx.lineTo(width, Math.round(height / 2) + 0.5); ctx.stroke()
                            function trace(pts) {
                                ctx.beginPath(); ctx.moveTo(pts[0].x, pts[0].y)
                                for (let i = 1; i < pts.length - 1; i++)
                                    ctx.quadraticCurveTo(pts[i].x, pts[i].y, (pts[i].x + pts[i + 1].x) / 2, (pts[i].y + pts[i + 1].y) / 2)
                                ctx.lineTo(pts[pts.length - 1].x, pts[pts.length - 1].y)
                            }
                            function line(arr, color, w, area) {
                                const n = arr.length
                                if (n < 3) return
                                const pts = []
                                for (let i = 0; i < n; i++) {
                                    const age = n - 1 - i
                                    pts.push({ x: width - (age - 1 + phase) * step,
                                               y: height - pad - Math.min(arr[i], max) / max * (height - 2 * pad) })
                                }
                                if (area) {   // soft gradient under the line
                                    trace(pts)
                                    ctx.lineTo(pts[n - 1].x, height); ctx.lineTo(pts[0].x, height); ctx.closePath()
                                    const g = ctx.createLinearGradient(0, 0, 0, height)
                                    g.addColorStop(0, Qt.rgba(color.r, color.g, color.b, 0.22))
                                    g.addColorStop(1, Qt.rgba(color.r, color.g, color.b, 0.0))
                                    ctx.fillStyle = g; ctx.fill()
                                }
                                trace(pts)
                                ctx.strokeStyle = color; ctx.lineWidth = w
                                ctx.shadowColor = color; ctx.shadowBlur = 6
                                ctx.lineJoin = "round"; ctx.lineCap = "round"
                                ctx.stroke()
                                ctx.shadowBlur = 0
                            }
                            if (root.showGpu) line(root.gpuHistory, pal.accent2, 1.2)
                            line(root.cpuHistory, pal.accent, 1.4, true)
                        }
                    }
                }
                Item { visible: !root.cfg.showLoadGraph; Layout.fillHeight: true }

                // memory
                ColumnLayout {
                    visible: full.memRows > 0
                    Layout.fillWidth: true
                    spacing: 8 * full.s
                    MemRow { visible: root.cfg.showRam; label: "ram"; used: root.gib(ramUsed.value); total: root.gib(ramTotal.value); accent: pal.accent3; s: full.s }
                    MemRow { visible: root.cfg.showVram && root.showGpu; label: "vram"; used: root.gib(vramUsed.value); total: root.gib(vramTotal.value); accent: pal.accent2; s: full.s }
                }
            }
        }
    }

    component Ring: Item {
        id: ring
        property string label
        property color accent
        property real value
        property string detail
        // eased copy of the sensor value: glides between 1 s samples
        property real shown: value
        Behavior on shown { NumberAnimation { duration: 950; easing.type: Easing.OutCubic } }
        onShownChanged: arc.requestPaint()
        onAccentChanged: arc.requestPaint()
        Canvas {
            id: arc
            readonly property real size: Math.min(parent.width, parent.height)
            width: size; height: size
            anchors.centerIn: parent
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const lw = Math.max(2, size * 0.024), r = size / 2 - lw - 6, cx = size / 2, cy = size / 2
                const start = 0.75 * Math.PI, sweep = 1.5 * Math.PI
                ctx.lineCap = "round"; ctx.lineWidth = lw
                ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.06)
                ctx.beginPath(); ctx.arc(cx, cy, r, start, start + sweep); ctx.stroke()
                const frac = Math.max(0, Math.min(1, ring.shown / 100))
                if (frac > 0.003) {
                    ctx.strokeStyle = ring.accent
                    ctx.shadowColor = ring.accent; ctx.shadowBlur = 8
                    ctx.beginPath(); ctx.arc(cx, cy, r, start, start + sweep * frac); ctx.stroke()
                }
            }
        }
        Column {
            anchors.centerIn: parent
            spacing: 2
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: ring.label; color: pal.muted
                font { family: pal.mono; pixelSize: Math.max(8, arc.size * 0.075); letterSpacing: 2 }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                textFormat: Text.StyledText
                text: Math.round(ring.shown) + "<font size='2' color='" + pal.muted + "'>%</font>"
                color: pal.text
                font { family: pal.sans; pixelSize: arc.size * 0.26; weight: Font.ExtraLight }
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true; shadowColor: ring.accent
                    shadowBlur: 0.8; shadowOpacity: 0.55
                    shadowHorizontalOffset: 0; shadowVerticalOffset: 0
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                textFormat: Text.StyledText
                // never wider than the ring's inner chord: shrink instead of clipping
                width: Math.min(implicitWidth, arc.size * 0.64)
                horizontalAlignment: Text.AlignHCenter
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: 7
                text: ring.detail; color: pal.muted
                font { family: pal.mono; pixelSize: Math.max(8, arc.size * 0.072) }
            }
        }
    }

    component MemRow: RowLayout {
        id: mem
        property string label
        property real used
        property real total
        property color accent
        property real s: 1
        property real usedS: used
        Behavior on usedS { NumberAnimation { duration: 1500; easing.type: Easing.InOutCubic } }
        readonly property real frac: total > 0 ? Math.min(1, usedS / total) : 0
        readonly property int segments: 24
        Layout.fillWidth: true
        spacing: 10 * s
        Text {
            Layout.preferredWidth: 38 * mem.s
            text: mem.label; color: pal.muted
            font { family: pal.mono; pixelSize: 12 * mem.s; letterSpacing: 0.7 }
        }
        Row {
            id: segRow
            Layout.fillWidth: true
            Layout.preferredHeight: 9 * mem.s
            spacing: 2 * mem.s
            readonly property real segW: (width - spacing * (mem.segments - 1)) / mem.segments
            Repeater {
                model: mem.segments
                Rectangle {
                    required property int index
                    // 0..1 how lit this segment is: the boundary one fills progressively
                    readonly property real lit: Math.max(0, Math.min(1, mem.frac * mem.segments - index))
                    width: segRow.segW; height: segRow.height
                    radius: 1.5 * mem.s
                    color: Qt.rgba(1, 1, 1, 0.07)
                    Rectangle {
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                        width: parent.width * parent.lit
                        radius: parent.radius
                        color: mem.accent
                        opacity: 0.55 + 0.45 * (parent.index + 1) / Math.max(1, mem.frac * mem.segments)
                        visible: parent.lit > 0
                    }
                }
            }
        }
        Text {
            Layout.preferredWidth: 86 * mem.s
            horizontalAlignment: Text.AlignRight
            textFormat: Text.StyledText
            text: mem.usedS.toFixed(1) + "<font color='" + pal.faint + "'> / " + Math.ceil(mem.total - 0.05) + "G</font>"
            color: pal.text
            font { family: pal.mono; pixelSize: 12 * mem.s }
        }
    }
}
