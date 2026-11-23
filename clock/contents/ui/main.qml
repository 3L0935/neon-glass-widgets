import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support

PlasmoidItem {
    id: root

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    readonly property var cfg: Plasmoid.configuration
    property NeonPalette pal: NeonPalette { cfg: Plasmoid.configuration }

    readonly property var loc: cfg.locale ? Qt.locale(cfg.locale) : Qt.locale()
    readonly property string digits: cfg.digitsFont || pal.mono

    property date now: new Date()

    // month view shown in place of the clock face (click the date side)
    property bool calOpen: false
    onCalOpenChanged: if (calOpen) calTimeout.restart()
    Timer { id: calTimeout; interval: 45000; onTriggered: root.calOpen = false }
    readonly property real hourF: now.getHours() + now.getMinutes() / 60 + now.getSeconds() / 3600

    // one tick per second, re-aligned on the second boundary every time
    Timer {
        id: tick
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            const d = new Date()
            root.now = d
            interval = 1000 - d.getMilliseconds() + 5
            if (d.getDate() !== root.dayKey) root.dayKey = d.getDate()
        }
    }

    // ---- sun ---------------------------------------------------------------
    property int dayKey: -1
    // sunrise / sunset in local hours; polar night: rise == set, midnight sun: 0 / 24
    readonly property var sun: { dayKey; return sunTimes(new Date(), cfg.latitude, cfg.longitude) }
    readonly property bool isDay: hourF >= sun.rise && hourF <= sun.set && sun.set > sun.rise

    // NOAA approximation, good to a minute or two
    function sunTimes(d, lat, lon) {
        const rad = Math.PI / 180
        const start = new Date(d.getFullYear(), 0, 0)
        const n = Math.floor((d - start) / 86400000)
        const g = 2 * Math.PI / 365 * (n - 1)
        const eqt = 229.18 * (0.000075 + 0.001868 * Math.cos(g) - 0.032077 * Math.sin(g)
                              - 0.014615 * Math.cos(2 * g) - 0.040849 * Math.sin(2 * g))
        const decl = 0.006918 - 0.399912 * Math.cos(g) + 0.070257 * Math.sin(g) - 0.006758 * Math.cos(2 * g)
                   + 0.000907 * Math.sin(2 * g) - 0.002697 * Math.cos(3 * g) + 0.00148 * Math.sin(3 * g)
        const c = Math.cos(90.833 * rad) / (Math.cos(lat * rad) * Math.cos(decl)) - Math.tan(lat * rad) * Math.tan(decl)
        const tz = -d.getTimezoneOffset() / 60
        if (c > 1) return { rise: 12, set: 12 }          // polar night
        if (c < -1) return { rise: 0, set: 24 }          // midnight sun
        const ha = Math.acos(c) / rad
        const rise = (720 - 4 * (lon + ha) - eqt) / 60 + tz
        const set = (720 - 4 * (lon - ha) - eqt) / 60 + tz
        return { rise: rise, set: set }
    }
    function hhmm(h) {
        h = ((h % 24) + 24) % 24
        let H = Math.floor(h), M = Math.round((h - H) * 60)
        if (M === 60) { H = (H + 1) % 24; M = 0 }
        return fmtClock(H, M)
    }
    function pad(n) { return (n < 10 ? "0" : "") + n }
    function fmtClock(H, M) {
        if (cfg.use24h) return pad(H) + ":" + pad(M)
        return pad(H % 12 === 0 ? 12 : H % 12) + ":" + pad(M)
    }

    // ---- world times -------------------------------------------------------
    readonly property var zoneList: {
        const out = []
        for (const part of String(cfg.zones).split(",")) {
            const p = part.trim(); if (!p) continue
            const eq = p.indexOf("=")
            const tz = (eq > 0 ? p.slice(0, eq) : p).trim()
            const label = eq > 0 ? p.slice(eq + 1).trim() : (tz.split("/").pop().replace(/_/g, " "))
            out.push({ tz: tz, label: label })
        }
        return out
    }
    P5Support.DataSource {
        id: timeEngine
        engine: "time"
        connectedSources: root.cfg.showZones ? root.zoneList.map(z => z.tz) : []
        interval: 60000
    }
    function zoneTime(tz) {
        const data = timeEngine.data[tz]
        if (!data || data["Offset"] === undefined) return "--:--"
        const local = -now.getTimezoneOffset() * 60
        const t = new Date(now.getTime() + (data["Offset"] - local) * 1000)
        return fmtClock(t.getHours(), t.getMinutes())
    }

    function isoWeek(d) {
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()))
        const n = t.getUTCDay() || 7
        t.setUTCDate(t.getUTCDate() + 4 - n)
        const y = new Date(Date.UTC(t.getUTCFullYear(), 0, 1))
        return Math.ceil(((t - y) / 86400000 + 1) / 7)
    }
    readonly property string dateText: {
        const s = now.toLocaleDateString(loc, cfg.dateFormat)
        return cfg.lowercaseDate ? s.toLowerCase() : s
    }
    readonly property string sunLabel: {
        if (sun.set <= sun.rise) return "polar night"
        if (sun.set - sun.rise >= 24) return "midnight sun"
        return isDay ? "daylight " + Math.round((hourF - sun.rise) / (sun.set - sun.rise) * 100) + "%" : "night"
    }

    fullRepresentation: Item {
        id: full
        Layout.preferredWidth: 736
        Layout.preferredHeight: 304
        Layout.minimumWidth: 360
        Layout.minimumHeight: 150

        readonly property real s: Math.max(0.5, width / 736)

        GlassCard {
            anchors.fill: parent
            pal: root.pal
            s: full.s
            blurBehind: Plasmoid.formFactor === PlasmaCore.Types.Planar

            leftLabel: Text {
                text: root.cfg.title
                color: pal.accent3
                font { family: pal.mono; pixelSize: pal.labelSize; letterSpacing: 0.6 }
            }
            rightLabelVisible: root.cfg.rightLabel !== "none"
            rightLabel: Text {
                text: root.cfg.rightLabel === "date" ? root.dateText : root.sunLabel
                color: pal.muted
                font { family: pal.mono; pixelSize: pal.labelSize * 0.96 }
            }

            MonthGrid {
                id: month
                anchors { fill: parent; topMargin: 30 * full.s; leftMargin: 28 * full.s; rightMargin: 28 * full.s; bottomMargin: 16 * full.s }
                pal: root.pal
                loc: root.loc
                today: root.now
                opacity: root.calOpen ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.InOutQuad } }
                onBack: root.calOpen = false
                onInteracted: calTimeout.restart()
            }

            ColumnLayout {
                anchors { fill: parent; topMargin: 26 * full.s; leftMargin: 28 * full.s; rightMargin: 28 * full.s; bottomMargin: 18 * full.s }
                spacing: 0
                opacity: root.calOpen ? 0 : 1
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.InOutQuad } }

                SunPath {
                    visible: root.cfg.showSun
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    pal: root.pal
                    s: full.s
                    rise: root.sun.rise
                    set: root.sun.set
                    hour: root.hourF
                    isDay: root.isDay
                }
                Item { visible: !root.cfg.showSun; Layout.fillHeight: true }

                // time + date column
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 8 * full.s
                    spacing: 24 * full.s

                    Item {
                        Layout.alignment: Qt.AlignBottom
                        implicitWidth: hm.implicitWidth + (secs.visible ? secs.implicitWidth + 8 * full.s : 0)
                        implicitHeight: hm.implicitHeight
                        // click the time: 24 h <-> 12 h (same setting as in the config dialog)
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: Plasmoid.configuration.use24h = !Plasmoid.configuration.use24h }
                        Text {
                            id: hm
                            text: root.fmtClock(root.now.getHours(), root.now.getMinutes())
                            color: pal.text
                            font { family: root.digits; weight: root.cfg.digitsWeight; pixelSize: 66 * full.s; letterSpacing: -1 * full.s }
                        }
                        Text {
                            id: secs
                            visible: root.cfg.showSeconds || !root.cfg.use24h
                            anchors { left: hm.right; leftMargin: 8 * full.s; baseline: hm.baseline }
                            text: (root.cfg.showSeconds ? root.pad(root.now.getSeconds()) : "")
                                  + (!root.cfg.use24h ? (root.cfg.showSeconds ? " " : "") + (root.now.getHours() < 12 ? "am" : "pm") : "")
                            color: pal.muted
                            font { family: pal.mono; weight: Font.Light; pixelSize: 22 * full.s }
                        }
                    }
                    Item { Layout.fillWidth: true }
                    Column {
                        Layout.alignment: Qt.AlignBottom
                        Layout.bottomMargin: 6 * full.s
                        spacing: 4 * full.s
                        // click the date side: open the month view
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: { month.reset(); root.calOpen = true } }
                        Text {
                            anchors.right: parent.right
                            text: root.dateText
                            color: pal.muted
                            font { family: pal.mono; pixelSize: 12.5 * pal.ts }
                        }
                        Text {
                            anchors.right: parent.right
                            visible: root.cfg.showWeekDay
                            text: "week " + root.isoWeek(root.now)
                            color: pal.faint
                            font { family: pal.mono; pixelSize: 12.5 * pal.ts }
                        }
                        Text {
                            anchors.right: parent.right
                            visible: root.cfg.showSun && root.sun.set > root.sun.rise && root.sun.set - root.sun.rise < 24
                            textFormat: Text.StyledText
                            text: "<font color='" + pal.accent3 + "'>↑ " + root.hhmm(root.sun.rise) + "</font>"
                                  + "<font color='" + pal.faint + "'> · </font>"
                                  + "<font color='" + pal.accent2 + "'>↓ " + root.hhmm(root.sun.set) + "</font>"
                            font { family: pal.mono; pixelSize: 12.5 * pal.ts }
                        }
                    }
                }

                // seconds strip: 60 notches, a taller one every 5 s
                Row {
                    id: ticks
                    visible: root.cfg.showTicks
                    Layout.fillWidth: true
                    Layout.topMargin: 14 * full.s
                    Layout.preferredHeight: 11 * full.s
                    readonly property real gap: 2 * full.s
                    readonly property real w: (width - 59 * gap) / 60
                    spacing: gap
                    Repeater {
                        model: 60
                        Rectangle {
                            required property int index
                            readonly property bool filled: index <= root.now.getSeconds()
                            width: ticks.w
                            height: (index % 5 === 0 ? 11 : 6) * full.s
                            anchors.bottom: parent.bottom
                            radius: 1
                            color: filled ? pal.mix(pal.accent, pal.accent2, index / 59) : pal.withAlpha(pal.faint, 0.30)
                        }
                    }
                }

                // world times
                RowLayout {
                    visible: root.cfg.showZones && root.zoneList.length > 0
                    Layout.fillWidth: true
                    Layout.topMargin: 12 * full.s
                    spacing: 0
                    Repeater {
                        model: root.zoneList
                        delegate: RowLayout {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: index > 0
                            spacing: 0
                            Item { visible: index > 0; Layout.fillWidth: true }
                            Text {
                                textFormat: Text.StyledText
                                text: modelData.label + " <font color='" + pal.text + "'>" + root.zoneTime(modelData.tz) + "</font>"
                                color: pal.muted
                                font { family: pal.mono; pixelSize: 12 * pal.ts }
                            }
                        }
                    }
                }
            }
        }
    }
}
