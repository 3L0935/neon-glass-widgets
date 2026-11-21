import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

// Taskbar version: cover · title/artist + hairline progress · prev/play/next.
// Click = popup card, middle click = play/pause, wheel = volume (Shift = fine).
Item {
    id: compact
    readonly property var pal: root.pal
    readonly property real h: Math.max(16, Math.min(parent ? parent.height : 32, 40))
    Layout.preferredWidth: row.implicitWidth + 12
    Layout.minimumWidth: Layout.preferredWidth
    Layout.fillHeight: true

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: (m) => {
            if (m.button === Qt.MiddleButton) root.togglePlay()
            else root.expanded = !root.expanded
        }
        onWheel: (w) => root.wheelVolume(w, true)
    }

    Rectangle {
        anchors { fill: parent; topMargin: 4; bottomMargin: 4 }
        radius: 7
        color: compact.pal.withAlpha(compact.pal.glass, Math.max(0.55, compact.pal.glass.a))
        border.color: compact.pal.edge; border.width: 1
        visible: root.has
    }

    RowLayout {
        id: row
        anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 7 }
        spacing: 8

        Item {
            Layout.preferredWidth: compact.h - 14; Layout.preferredHeight: compact.h - 14
            visible: root.has
            Rectangle { anchors.fill: parent; radius: 4; color: Qt.lighter(compact.pal.glass, 2.2) }
            Image { id: art; anchors.fill: parent; source: root.art; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize: Qt.size(64, 64); visible: false }
            Item { id: artMask; anchors.fill: parent; layer.enabled: true; visible: false
                Rectangle { anchors.fill: parent; radius: 4; color: "black" } }
            MultiEffect { anchors.fill: parent; source: art; visible: art.status === Image.Ready
                maskEnabled: true; maskSource: artMask; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0 }
        }

        ColumnLayout {
            spacing: 2
            visible: root.has
            Text {
                Layout.maximumWidth: 230
                textFormat: Text.StyledText
                text: esc(root.title) + " <font color='" + compact.pal.muted + "'>· " + esc(root.artist) + "</font>"
                color: compact.pal.text; elide: Text.ElideRight; maximumLineCount: 1
                font { family: compact.pal.sans; pixelSize: 12 }
                function esc(t) { return String(t).replace(/&/g, "&amp;").replace(/</g, "&lt;") }
            }
            Rectangle {
                id: miniBar
                Layout.fillWidth: true; Layout.preferredHeight: 2; radius: 1
                color: root.loading ? compact.pal.accent : compact.pal.faint
                // blinks while music-cli loads the next track
                SequentialAnimation on opacity {
                    running: root.loading; loops: Animation.Infinite
                    onRunningChanged: if (!running) miniBar.opacity = 1
                    NumberAnimation { to: 0.25; duration: 600; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
                }
                Rectangle {
                    width: parent.width * root.progress; height: parent.height; radius: 1
                    visible: !root.loading
                    gradient: Gradient { orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: compact.pal.accent }
                        GradientStop { position: 1; color: compact.pal.accent2 } }
                }
            }
        }

        Row {
            spacing: 8
            Repeater {
                model: [
                    { icon: "media-skip-backward", a: "prev" },
                    { icon: root.playing ? "media-playback-pause" : "media-playback-start", a: "pp" },
                    { icon: "media-skip-forward", a: "next" }
                ]
                NIcon {
                    required property var modelData
                    width: 16; height: 16
                    name: modelData.icon
                    visible: root.has || modelData.a === "pp"
                    color: modelData.a === "pp" ? compact.pal.accent : (bma.containsMouse ? compact.pal.text : compact.pal.muted)
                    MouseArea {
                        id: bma; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true
                        onClicked: {
                            if (parent.modelData.a === "pp" && (root.player || root.canStartCli)) { root.togglePlay(); return }
                            if (!root.player) { root.expanded = true; return }
                            if (parent.modelData.a === "prev") root.player.Previous()
                            else root.next()
                        }
                    }
                }
            }
        }
    }
}
