import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import org.kde.plasma.plasmoid
import org.kde.plasma.private.mpris as Mpris
import org.kde.kirigami as Kirigami

// Desktop card (also used as the taskbar popup).
Item {
    id: card
    // the playlist/tools row must fit (it sets the width of the taskbar popup)
    Layout.preferredWidth: Math.max(560, Layout.minimumWidth)
    Layout.preferredHeight: 232
    Layout.minimumWidth: mcRow ? Math.max(420, Math.ceil(shortcuts.implicitWidth + 34 * s)) : 420
    Layout.minimumHeight: 196

    readonly property var pal: root.pal
    readonly property real s: Math.max(0.6, Math.min(width / 560, height / 232))
    readonly property bool mc: root.isMusicCli
    // the playlist row also shows while music-cli is stopped, to start it
    readonly property bool mcRow: root.isMusicCli || root.canStartCli
    property bool moreOpen: false

    GlassCard {
        anchors.fill: parent
        pal: card.pal
        s: card.s
        blurBehind: root.onDesktop
        bare: !root.onDesktop

        leftLabel: Text {
            textFormat: Text.StyledText
            text: root.cfg.title + (root.identity ? " <font color='" + card.pal.faint + "'>· </font><font color='" + card.pal.muted + "'>" + root.identity.toLowerCase() + "</font>" : "")
            color: card.pal.accent3
            font { family: card.pal.mono; pixelSize: 11.5 * card.s; letterSpacing: 0.6 }
        }
        rightLabelVisible: root.cfg.showSourceSwitcher && root.players.length > 1 && !card.moreOpen
        rightLabel: Row {
            spacing: 9 * card.s
            Repeater {
                model: [{ index: 0, identity: "auto" }].concat(root.players)
                Text {
                    required property var modelData
                    readonly property bool on: mpris.currentIndex === modelData.index
                    text: modelData.identity.toLowerCase()
                    color: on ? card.pal.accent : (srcMa.containsMouse ? card.pal.text : card.pal.faint)
                    font { family: card.pal.mono; pixelSize: 10.5 * card.s; bold: on }
                    MouseArea { id: srcMa; anchors.fill: parent; anchors.margins: -3; hoverEnabled: true; onClicked: mpris.currentIndex = parent.modelData.index }
                }
            }
        }

        // ── body (hidden while the playlist browser is open) ──
        ColumnLayout {
            anchors { fill: parent; topMargin: 28 * card.s; leftMargin: 16 * card.s; rightMargin: 18 * card.s; bottomMargin: 12 * card.s }
            spacing: 10 * card.s
            opacity: card.moreOpen ? 0 : 1
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 160 } }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 16 * card.s

                Cover {
                    // sized from the card, not the row, to avoid a layout loop
                    Layout.preferredWidth: Math.min(card.height - (card.mcRow ? 72 : 46) * card.s, card.width * 0.34)
                    Layout.preferredHeight: Layout.preferredWidth
                    Layout.alignment: Qt.AlignVCenter
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    // fill the space left by the cover instead of growing to the title's width
                    Layout.preferredWidth: 1
                    Layout.minimumWidth: 0
                    spacing: 0

                    Text {
                        Layout.fillWidth: true
                        text: root.has ? root.title : "Nothing playing"
                        color: root.has ? card.pal.text : card.pal.muted
                        wrapMode: Text.Wrap; elide: Text.ElideRight; maximumLineCount: 2
                        lineHeight: 1.05
                        font { family: card.pal.sans; pixelSize: 15.5 * card.s; weight: Font.DemiBold }
                    }
                    Text {
                        Layout.fillWidth: true
                        Layout.topMargin: 2 * card.s
                        text: root.has ? root.artist : (card.mcRow ? (root.canStartCli && !root.loading ? "▶ to start music-cli, or pick a playlist ↓" : "pick a playlist below ↓") : "start something in a music app")
                        color: card.pal.muted
                        elide: Text.ElideRight; maximumLineCount: 1
                        font { family: card.pal.sans; pixelSize: 12.5 * card.s }
                    }
                    UpNext { Layout.fillWidth: true; Layout.fillHeight: true; Layout.topMargin: 8 * card.s; Layout.bottomMargin: 6 * card.s }

                    ProgressLine { Layout.fillWidth: true; Layout.preferredHeight: 12 * card.s }
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 3 * card.s
                        Text { text: root.has ? root.fmt(root.position) : "-:--"; color: card.pal.muted; font { family: card.pal.mono; pixelSize: 10.5 * card.s } }
                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: root.loading ? "loading" + (root.loadingLabel ? " · " + root.loadingLabel : "…") : root.toast
                            color: card.pal.accent; elide: Text.ElideRight
                            opacity: (root.loading || root.toast) ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 250 } }
                            font { family: card.pal.mono; pixelSize: 10.5 * card.s }
                        }
                        Text { text: root.length > 0 ? root.fmt(root.length) : "-:--"; color: card.pal.muted; font { family: card.pal.mono; pixelSize: 10.5 * card.s } }
                    }

                    // transport
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 6 * card.s
                        spacing: 14 * card.s
                        IconButton {
                            icon: root.player && root.player.loopStatus === Mpris.LoopStatus.Track ? "media-playlist-repeat-song" : "media-playlist-repeat"
                            on: !!root.player && (root.player.loopStatus === Mpris.LoopStatus.Track || root.player.loopStatus === Mpris.LoopStatus.Playlist)
                            tip: "Loop"
                            onTap: root.cycleLoop()
                        }
                        IconButton { visible: card.mc && root.has; icon: "media-playlist-shuffle"; tip: "Reshuffle the up-next list"; onTap: root.reshuffle() }
                        IconButton { icon: "media-skip-backward"; tip: "Previous"; onTap: root.player && root.player.Previous() }
                        Rectangle {
                            Layout.preferredWidth: 34 * card.s; Layout.preferredHeight: 34 * card.s
                            radius: width / 2
                            color: playMa.containsMouse ? Qt.lighter(card.pal.accent, 1.15) : card.pal.accent
                            NIcon {
                                anchors.centerIn: parent
                                width: 18 * card.s; height: width
                                name: root.playing ? "media-playback-pause" : "media-playback-start"
                                color: Qt.darker(card.pal.glass, 2.5)
                            }
                            MouseArea { id: playMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.togglePlay() }
                        }
                        IconButton { icon: "media-skip-forward"; tip: "Next"; on: root.loading; onColor: card.pal.accent; onTap: root.next() }
                        IconButton {
                            visible: card.mc && root.has
                            icon: "love"; tip: root.liked ? "Unlike" : "Like"
                            on: root.liked; onColor: card.pal.accent3
                            onTap: root.like()
                        }
                        Item { Layout.fillWidth: true }
                        Item {
                            visible: root.has
                            implicitWidth: volRow.implicitWidth; implicitHeight: volRow.implicitHeight
                            Row {
                                id: volRow
                                spacing: 4 * card.s
                                NIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 14 * card.s; height: width
                                    name: "audio-volume-high"
                                    color: volMa.containsMouse ? card.pal.text : card.pal.muted
                                }
                                Text {
                                    text: Math.round((root.player ? root.player.volume : 0) * 100)
                                    color: volMa.containsMouse ? card.pal.text : card.pal.muted
                                    font { family: card.pal.mono; pixelSize: 11 * card.s }
                                }
                            }
                            MouseArea {
                                id: volMa
                                anchors.fill: parent; anchors.margins: -6
                                hoverEnabled: true
                                onWheel: (w) => root.wheelVolume(w, false)
                            }
                        }
                    }
                }
            }

            // playlists to play (left) │ tools (right): music-cli only
            RowLayout {
                id: shortcuts
                visible: card.mcRow
                Layout.fillWidth: true
                Layout.maximumWidth: parent.width
                spacing: 5 * card.s
                Text {
                    visible: card.width > 640 * card.s
                    text: "play"; color: card.pal.faint
                    font { family: card.pal.mono; pixelSize: 10 * card.s; letterSpacing: 1.2 }
                }
                Chip { icon: "view-media-playlist"; label: "all music"; onTap: root.playShortcut("all") }
                Chip { icon: "starred";             label: "discover";  onTap: root.playShortcut("discover") }
                Chip { icon: "media-album-track";   label: "supermix";  onTap: root.playShortcut("supermix") }
                Chip { icon: "love";                label: "likes";     onTap: root.playShortcut("liked") }
                Chip { icon: "view-more-horizontal-symbolic"; label: "more"; onTap: { card.moreOpen = true; root.loadPlaylists() } }
                Item { Layout.fillWidth: true; Layout.minimumWidth: 0 }
                Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 14 * card.s; color: card.pal.edge }
                Tool { icon: "view-refresh";       label: "refresh"; busy: root.refreshing; onTap: root.refreshMixes() }
                Tool { icon: "utilities-terminal"; label: "tui";     onTap: root.openTui() }
                Tool { visible: card.mc; icon: "system-shutdown"; label: "quit"; onTap: root.quitCli() }
            }
        }

        PlaylistBrowser {
            anchors { fill: parent; topMargin: 16 * card.s; leftMargin: 4 * card.s; rightMargin: 6 * card.s; bottomMargin: 4 * card.s }
            opacity: card.moreOpen ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 160 } }
        }
    }

    // ── pieces ───────────────────────────────────────────────────────

    component Cover: Item {
        Rectangle {
            anchors.fill: parent; radius: 9 * card.s
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.lighter(card.pal.glass, 2.2) }
                GradientStop { position: 1; color: card.pal.mix(Qt.lighter(card.pal.glass, 2.2), card.pal.accent2, 0.25) }
            }
            NIcon {
                anchors.centerIn: parent; visible: art.status !== Image.Ready
                width: parent.width * 0.32; height: width
                name: "audio-x-generic"; color: card.pal.faint
            }
        }
        Image {
            id: art
            anchors.fill: parent
            source: root.art
            fillMode: Image.PreserveAspectCrop
            asynchronous: true; smooth: true; mipmap: true
            sourceSize: Qt.size(480, 480)
            visible: false
        }
        Item { id: artMask; anchors.fill: parent; layer.enabled: true; visible: false
            Rectangle { anchors.fill: parent; radius: 9 * card.s; color: "black" } }
        MultiEffect {
            anchors.fill: parent; source: art; visible: art.status === Image.Ready
            maskEnabled: true; maskSource: artMask; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0
        }
        Rectangle { anchors.fill: parent; radius: 9 * card.s; color: "transparent"; border.color: card.pal.edge; border.width: 1 }
        // breathes while the next track loads
        SequentialAnimation on opacity {
            running: root.loading; loops: Animation.Infinite
            onRunningChanged: if (!running) parent.opacity = 1
            NumberAnimation { to: 0.45; duration: 700; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutSine }
        }
    }

    // music-cli's queue, clipped to the lines that fit
    component UpNext: Item {
        id: upBox
        clip: true
        readonly property int fit: Math.max(0, Math.min(3, Math.floor((height - 15 * card.s) / (19 * card.s))))
        Column {
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: 4 * card.s
            visible: card.mc && root.cfg.showUpNext && root.upNext.length > 0 && upBox.fit > 0
            Text {
                text: "up next" + (root.queueCount ? "  ·  " + root.queueCount + " queued" : "")
                color: card.pal.faint
                font { family: card.pal.mono; pixelSize: 10 * card.s; letterSpacing: 1.2 }
            }
            Repeater {
                model: root.upNext.slice(0, upBox.fit)
                Text {
                    required property var modelData
                    required property int index
                    width: parent.width
                    textFormat: Text.StyledText
                    elide: Text.ElideRight; maximumLineCount: 1
                    text: "<font color='" + (index === 0 ? card.pal.accent : card.pal.faint) + "'>" + String(index + 1).padStart(2, "0") + "</font>&nbsp;&nbsp;"
                          + esc(modelData.title) + (modelData.artist ? " <font color='" + card.pal.faint + "'>· " + esc(modelData.artist) + "</font>" : "")
                    color: index === 0 ? card.pal.text : card.pal.muted
                    opacity: 1 - index * 0.18
                    font { family: card.pal.sans; pixelSize: 12 * card.s }
                    function esc(t) { return String(t).replace(/&/g, "&amp;").replace(/</g, "&lt;") }
                }
            }
        }
    }

    // thin neon progress line, click to seek
    component ProgressLine: Item {
        id: seg
        property real p: root.progress
        Behavior on p { NumberAnimation { duration: 500; easing.type: Easing.Linear } }

        Rectangle {   // rail
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width; height: Math.max(1, 1.5 * card.s); radius: height / 2
            color: Qt.rgba(1, 1, 1, 0.08)
        }
        Item {   // loading: a comet sweeping the rail
            anchors.fill: parent; clip: true
            visible: root.loading
            Item {
                id: comet
                anchors.verticalCenter: parent.verticalCenter
                width: seg.width * 0.22; height: 8 * card.s
                property real t: 0
                x: (seg.width + width) * t - width
                NumberAnimation on t { running: root.loading; from: 0; to: 1; duration: 1400; loops: Animation.Infinite; easing.type: Easing.InOutSine }
                Glow { width: comet.width; from: "transparent"; mid: card.pal.accent2; to: card.pal.accent }
            }
        }
        Item {   // the played part: a full-width gradient clipped to the progress
            visible: !root.loading
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
            width: parent.width * seg.p
            clip: true
            Glow { width: seg.width; from: card.pal.accent; mid: card.pal.accent2; to: card.pal.accent3 }
        }
        Item {   // glowing head
            visible: root.has && seg.p > 0 && !root.loading
            x: seg.width * seg.p - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: 12 * card.s; height: width
            readonly property color c: seg.p < 0.6 ? card.pal.mix(card.pal.accent, card.pal.accent2, seg.p / 0.6)
                                                   : card.pal.mix(card.pal.accent2, card.pal.accent3, (seg.p - 0.6) / 0.4)
            Rectangle { anchors.centerIn: parent; width: parent.width; height: width; radius: width / 2; color: parent.c; opacity: 0.18 }
            Rectangle { anchors.centerIn: parent; width: parent.width * 0.45; height: width; radius: width / 2; color: Qt.lighter(parent.c, 1.25) }
        }
        MouseArea {
            anchors.fill: parent; anchors.margins: -4
            enabled: root.has
            cursorShape: Qt.PointingHandCursor
            onClicked: (m) => root.seekTo(Math.max(0, Math.min(1, (m.x - 4) / seg.width)))
        }
    }

    // a gradient line drawn three times (wide/faint → thin/solid) for a soft halo
    component Glow: Item {
        id: glow
        property color from
        property color mid
        property color to
        height: parent.height
        anchors.verticalCenter: parent.verticalCenter
        Repeater {
            model: [{ h: 8, o: 0.10 }, { h: 4.5, o: 0.22 }, { h: 2, o: 1.0 }]
            Rectangle {
                required property var modelData
                anchors.verticalCenter: parent.verticalCenter
                width: glow.width; height: modelData.h * card.s; radius: height / 2
                opacity: modelData.o
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: glow.from }
                    GradientStop { position: 0.6; color: glow.mid }
                    GradientStop { position: 1.0; color: glow.to }
                }
            }
        }
    }

    // every library playlist, grouped (music-cli)
    component PlaylistBrowser: Item {
        MouseArea { anchors.fill: parent }   // swallow clicks meant for the hidden body
        RowLayout {
            id: head
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 * card.s }
            IconButton { icon: "go-previous"; tip: "Back"; onTap: card.moreOpen = false }
            Text { text: "playlists"; color: card.pal.text; font { family: card.pal.mono; pixelSize: 12 * card.s; letterSpacing: 0.6 } }
            Text {
                text: root.playlistsLoading ? "loading…" : root.allPlaylists.length + " in library"
                color: card.pal.faint; font { family: card.pal.mono; pixelSize: 10 * card.s }
            }
            Item { Layout.fillWidth: true }
            IconButton { icon: "window-close"; tip: "Close"; onTap: card.moreOpen = false }
        }
        Flickable {
            anchors { left: parent.left; right: parent.right; top: head.bottom; bottom: parent.bottom; margins: 12 * card.s; topMargin: 8 * card.s }
            clip: true
            contentHeight: groups.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: groups
                width: parent.width
                spacing: 10 * card.s
                Repeater {
                    model: [
                        { key: "liked",   label: "liked",             icon: "love" },
                        { key: "mine",    label: "by genre",          icon: "view-media-playlist" },
                        { key: "radar",   label: "radar · new music", icon: "network-wireless-hotspot" },
                        { key: "youtube", label: "youtube mixes",     icon: "starred" },
                        { key: "library", label: "library",           icon: "view-media-playlist" }
                    ]
                    Column {
                        id: group
                        required property var modelData
                        readonly property var items: root.allPlaylists.filter(p => p.group === modelData.key)
                        visible: items.length > 0
                        width: groups.width
                        spacing: 5 * card.s
                        Text { text: group.modelData.label; color: card.pal.faint; font { family: card.pal.mono; pixelSize: 10 * card.s; letterSpacing: 1.2 } }
                        Flow {
                            id: flow
                            width: parent.width
                            spacing: 2 * card.s
                            readonly property int cols: width > 560 * card.s ? 3 : 2
                            readonly property real colW: (width - spacing * (cols - 1)) / cols
                            Repeater {
                                model: group.items
                                MenuRow {
                                    required property var modelData
                                    width: flow.colW
                                    icon: group.modelData.icon
                                    label: modelData.title.replace("Radar · ", "")
                                    onTap: { root.playId(modelData.id, modelData.title); card.moreOpen = false }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component IconButton: NIcon {
        id: ib
        property string icon
        property string tip
        property bool on: false
        property color onColor: card.pal.accent2
        signal tap()
        name: icon
        implicitWidth: 18 * card.s; implicitHeight: implicitWidth
        color: on ? onColor : (ibMa.containsMouse ? card.pal.text : card.pal.muted)
        MouseArea { id: ibMa; anchors.fill: parent; anchors.margins: -5; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ib.tap() }
    }

    // a playlist shortcut: outlined
    component Chip: Rectangle {
        id: chip
        property string icon
        property string label
        signal tap()
        implicitWidth: chipRow.implicitWidth + 10 * card.s
        implicitHeight: 20 * card.s
        radius: 5 * card.s
        color: cma.containsMouse ? card.pal.withAlpha(card.pal.accent, 0.14) : "transparent"
        border.width: 1
        border.color: cma.containsMouse ? card.pal.withAlpha(card.pal.accent, 0.55) : card.pal.edge
        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 3 * card.s
            NIcon {
                anchors.verticalCenter: parent.verticalCenter
                width: 11 * card.s; height: width
                name: chip.icon
                color: cma.containsMouse ? card.pal.accent : card.pal.accent2
            }
            Text {
                text: chip.label
                color: cma.containsMouse ? card.pal.text : card.pal.muted
                font { family: card.pal.mono; pixelSize: 10.5 * card.s }
            }
        }
        MouseArea { id: cma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: chip.tap() }
    }

    // a tool (an action, not a playlist): borderless, pulses while busy
    component Tool: Rectangle {
        id: tool
        property string icon
        property string label
        property bool busy: false
        signal tap()
        implicitWidth: toolRow.implicitWidth + 8 * card.s
        implicitHeight: 20 * card.s
        radius: 5 * card.s
        color: tma.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
        Row {
            id: toolRow
            anchors.centerIn: parent
            spacing: 3 * card.s
            NIcon {
                anchors.verticalCenter: parent.verticalCenter
                width: 11 * card.s; height: width
                name: tool.icon; color: card.pal.accent
            }
            Text {
                text: tool.label
                color: tma.containsMouse ? card.pal.text : card.pal.muted
                font { family: card.pal.mono; pixelSize: 10.5 * card.s }
            }
            SequentialAnimation on opacity {
                running: tool.busy; loops: Animation.Infinite
                onRunningChanged: if (!running) toolRow.opacity = 1
                NumberAnimation { to: 0.3; duration: 600; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
            }
        }
        MouseArea { id: tma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: tool.tap() }
    }

    // a line of the playlist browser
    component MenuRow: Rectangle {
        id: mrow
        property string icon
        property string label
        signal tap()
        height: 26 * card.s
        radius: 6 * card.s
        color: rma.containsMouse ? card.pal.withAlpha(card.pal.accent, 0.12) : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }
        Rectangle {   // neon tick on hover
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            width: 2; height: parent.height * 0.55; radius: 1
            color: card.pal.accent
            opacity: rma.containsMouse ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120 } }
        }
        Row {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 10 * card.s }
            width: parent.width - 16 * card.s
            spacing: 8 * card.s
            NIcon {
                anchors.verticalCenter: parent.verticalCenter
                width: 14 * card.s; height: width
                name: mrow.icon
                color: rma.containsMouse ? card.pal.accent : card.pal.accent2
            }
            Text {
                width: parent.width - 22 * card.s
                text: mrow.label; elide: Text.ElideRight
                color: rma.containsMouse ? card.pal.text : card.pal.muted
                font { family: card.pal.sans; pixelSize: 12.5 * card.s }
            }
        }
        MouseArea { id: rma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: mrow.tap() }
    }
}
