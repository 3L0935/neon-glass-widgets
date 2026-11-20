import QtQuick
import org.kde.kirigami as Kirigami

// An icon named after the freedesktop icon theme ("media-skip-forward"…), drawn
// either as a Nerd Font glyph or as the (recolored) symbolic theme icon,
// following root.useNerdFont.
Item {
    id: icon
    property string name
    property color color: "white"
    implicitWidth: 16; implicitHeight: 16

    // freedesktop icon name → Nerd Font (Material Design) code point
    readonly property var glyphs: ({
        "media-skip-backward": 0xF04AE, "media-skip-forward": 0xF04AD,
        "media-playback-start": 0xF040A, "media-playback-pause": 0xF03E4,
        "media-playlist-repeat": 0xF0456, "media-playlist-repeat-song": 0xF0458,
        "media-playlist-shuffle": 0xF049D, "love": 0xF02D1, "starred": 0xF04CE,
        "media-album-track": 0xF075A, "view-media-playlist": 0xF0CB8,
        "view-more-horizontal-symbolic": 0xF01D8, "view-refresh": 0xF0450,
        "utilities-terminal": 0xF018D, "audio-volume-high": 0xF057E,
        "audio-x-generic": 0xF0387, "go-previous": 0xF004D, "window-close": 0xF0156,
        "network-wireless-hotspot": 0xF0437
    })
    readonly property bool glyph: root.useNerdFont && glyphs[name] !== undefined

    Text {
        anchors.centerIn: parent
        visible: icon.glyph
        text: icon.glyph ? String.fromCodePoint(icon.glyphs[icon.name]) : ""
        color: icon.color
        font { family: root.nerdFont; pixelSize: Math.min(icon.width, icon.height) * 1.05 }
    }
    Kirigami.Icon {
        anchors.fill: parent
        visible: !icon.glyph
        source: icon.name
        isMask: true
        color: icon.color
    }
}
