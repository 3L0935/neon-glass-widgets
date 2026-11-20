import QtQuick
import QtQuick.Effects
import QtQuick.Window

// A glass panel: translucent fill, hairline frame, and two labels set into the
// top edge (the frame is cut where they sit).
//
// Optional fake "blur behind": widgets on the desktop share the wallpaper's
// surface, so KWin cannot blur what is under them. When `blurBehind` is on and
// the palette has a background image, the image is drawn under the card with
// the same crop as the desktop wallpaper, then blurred. Use the same image as
// your wallpaper (set to "Scaled and cropped") for the illusion to line up.
Item {
    id: card
    required property var pal
    property real s: 1                       // scale factor, from the widget size
    property bool blurBehind: false
    property alias leftLabel: leftSlot.data
    property alias rightLabel: rightSlot.data
    property bool rightLabelVisible: true
    default property alias content: body.data

    readonly property real inset: 9 * s   // the frame starts this far down, under the labels
    readonly property bool imageBlur: blurBehind && pal.backgroundImage != ""

    // where the card sits on its screen, polled cheaply so moving it keeps the illusion
    property point screenPos: Qt.point(0, 0)
    function updatePos() {
        const p = card.mapToItem(null, 0, 0)
        if (p.x !== screenPos.x || p.y !== screenPos.y) screenPos = p
    }
    Timer { interval: 1500; running: card.imageBlur; repeat: true; triggeredOnStart: true; onTriggered: card.updatePos() }
    onWidthChanged: { updatePos(); frame.requestPaint() }
    onHeightChanged: { updatePos(); frame.requestPaint() }

    Item {
        id: blurLayer
        visible: card.imageBlur
        readonly property real pad: 48
        x: 1; y: card.inset + 1
        width: card.width - 2; height: card.height - y - 1
        layer.enabled: visible
        layer.effect: MultiEffect { maskEnabled: true; maskSource: blurMask; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0 }
        Item {
            id: wallSrc
            x: -blurLayer.pad; y: -blurLayer.pad
            width: blurLayer.width + 2 * blurLayer.pad; height: blurLayer.height + 2 * blurLayer.pad
            clip: true; visible: false
            Image {
                source: card.imageBlur ? card.pal.backgroundImage : ""
                asynchronous: true; fillMode: Image.PreserveAspectCrop; smooth: true
                readonly property var win: card.Window.window
                width: win ? win.width : 1920; height: win ? win.height : 1080
                sourceSize: Qt.size(width / 4, height / 4)   // blurred anyway: decode small
                x: -(card.screenPos.x + blurLayer.x - blurLayer.pad)
                y: -(card.screenPos.y + blurLayer.y - blurLayer.pad)
            }
        }
        MultiEffect {
            source: wallSrc
            x: wallSrc.x; y: wallSrc.y; width: wallSrc.width; height: wallSrc.height
            autoPaddingEnabled: false; blurEnabled: true; blurMax: 64
            blur: card.pal.blurAmount; saturation: 0.15
        }
    }
    Item {
        id: blurMask
        width: blurLayer.width; height: blurLayer.height
        layer.enabled: true; visible: false
        Rectangle { anchors.fill: parent; radius: card.pal.radius * card.s; color: "black" }
    }

    Canvas {
        id: frame
        anchors.fill: parent
        Component.onCompleted: requestPaint()
        Connections {
            target: card.pal
            function onEdgeChanged() { frame.requestPaint() }
            function onGlassChanged() { frame.requestPaint() }
            function onRadiusChanged() { frame.requestPaint() }
        }
        onPaint: {
            const ctx = getContext("2d"), s = card.s
            const top = card.inset, r = card.pal.radius * s, w = width - 1, h = height - 1
            ctx.reset()
            function rr(x, y, ww, hh, rad) {
                ctx.beginPath()
                ctx.moveTo(x + rad, y); ctx.lineTo(x + ww - rad, y); ctx.arcTo(x + ww, y, x + ww, y + rad, rad)
                ctx.lineTo(x + ww, y + hh - rad); ctx.arcTo(x + ww, y + hh, x + ww - rad, y + hh, rad)
                ctx.lineTo(x + rad, y + hh); ctx.arcTo(x, y + hh, x, y + hh - rad, rad)
                ctx.lineTo(x, y + rad); ctx.arcTo(x, y, x + rad, y, rad); ctx.closePath()
            }
            ctx.strokeStyle = card.pal.edge; ctx.lineWidth = 1
            rr(0.5, top + 0.5, w, h - top, r); ctx.stroke()
            if (leftBox.width > 0) ctx.clearRect(leftBox.x, 0, leftBox.width, top * 2)
            if (rightBox.visible && rightBox.width > 0) ctx.clearRect(rightBox.x, 0, rightBox.width, top * 2)
            ctx.fillStyle = card.pal.glass
            rr(1, top + 1, w - 1, h - top - 1, r); ctx.fill()
        }
    }

    Item {
        id: leftBox
        x: 14 * card.s; y: 0
        width: leftSlot.childrenRect.width > 0 ? leftSlot.childrenRect.width + 16 * card.s : 0
        height: 18 * card.s
        onWidthChanged: frame.requestPaint()
        Item { id: leftSlot; anchors.centerIn: parent; width: childrenRect.width; height: childrenRect.height }
    }
    Item {
        id: rightBox
        visible: card.rightLabelVisible && rightSlot.childrenRect.width > 0
        x: card.width - width - 14 * card.s; y: 0
        width: rightSlot.childrenRect.width + 16 * card.s
        height: 18 * card.s
        onWidthChanged: frame.requestPaint()
        onXChanged: frame.requestPaint()
        onVisibleChanged: frame.requestPaint()
        Item { id: rightSlot; anchors.centerIn: parent; width: childrenRect.width; height: childrenRect.height }
    }

    Item { id: body; anchors.fill: parent }
}
