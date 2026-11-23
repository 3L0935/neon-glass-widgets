import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Dialogs
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.kquickcontrols as KQuickControls

// "Appearance" settings shared by every Neon Glass widget.
KCM.SimpleKCM {
    id: page

    property alias cfg_accentColor: accent.color
    property alias cfg_secondaryColor: secondary.color
    property alias cfg_tertiaryColor: tertiary.color
    property alias cfg_textColor: textColor.color
    property alias cfg_mutedColor: muted.color
    property alias cfg_faintColor: faint.color
    property alias cfg_glassColor: glass.color
    property alias cfg_edgeColor: edge.color
    property alias cfg_glassOpacity: glassOpacity.value
    property alias cfg_edgeOpacity: edgeOpacity.value
    property alias cfg_cornerRadius: cornerRadius.value
    property alias cfg_labelSize: labelSize.value
    property alias cfg_sansFont: sansFont.text
    property alias cfg_monoFont: monoFont.text
    property alias cfg_backgroundImage: backgroundImage.text
    property alias cfg_blurAmount: blurAmount.value

    // the default "Neon Glass" palette (keep in sync with config/main.xml)
    function resetPalette() {
        accent.color = "#46b5e7"; secondary.color = "#a55ae9"; tertiary.color = "#e45ad8"
        textColor.color = "#e8e6ff"; muted.color = "#9a94d0"; faint.color = "#5d579a"
        glass.color = "#120f2e"; edge.color = "#8c82e6"
        glassOpacity.value = 0.62; edgeOpacity.value = 0.20; cornerRadius.value = 12; labelSize.value = 17
    }

    Kirigami.FormLayout {
        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Colors") }
        KQuickControls.ColorButton { id: accent;    Kirigami.FormData.label: i18n("Accent:") }
        KQuickControls.ColorButton { id: secondary; Kirigami.FormData.label: i18n("Secondary accent:") }
        KQuickControls.ColorButton { id: tertiary;  Kirigami.FormData.label: i18n("Third accent:") }
        KQuickControls.ColorButton { id: textColor; Kirigami.FormData.label: i18n("Text:") }
        KQuickControls.ColorButton { id: muted;     Kirigami.FormData.label: i18n("Muted text:") }
        KQuickControls.ColorButton { id: faint;     Kirigami.FormData.label: i18n("Faint text:") }
        QQC2.Button {
            text: i18n("Reset to the Neon Glass palette")
            icon.name: "edit-reset"
            onClicked: page.resetPalette()
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Glass") }
        KQuickControls.ColorButton { id: glass; Kirigami.FormData.label: i18n("Glass tint:") }
        RowLayout {
            Kirigami.FormData.label: i18n("Glass opacity:")
            QQC2.Slider { id: glassOpacity; from: 0; to: 1; stepSize: 0.01; Layout.preferredWidth: Kirigami.Units.gridUnit * 10 }
            QQC2.Label { text: Math.round(glassOpacity.value * 100) + " %" }
        }
        KQuickControls.ColorButton { id: edge; Kirigami.FormData.label: i18n("Border:") }
        RowLayout {
            Kirigami.FormData.label: i18n("Border opacity:")
            QQC2.Slider { id: edgeOpacity; from: 0; to: 1; stepSize: 0.01; Layout.preferredWidth: Kirigami.Units.gridUnit * 10 }
            QQC2.Label { text: Math.round(edgeOpacity.value * 100) + " %" }
        }
        QQC2.SpinBox { id: cornerRadius; Kirigami.FormData.label: i18n("Corner radius:"); from: 0; to: 32 }
        QQC2.SpinBox { id: labelSize; Kirigami.FormData.label: i18n("Text size:"); from: 8; to: 24 }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Fonts") }
        QQC2.TextField {
            id: sansFont
            Kirigami.FormData.label: i18n("Text font:")
            placeholderText: i18n("Inter, else the system font")
        }
        QQC2.TextField {
            id: monoFont
            Kirigami.FormData.label: i18n("Numbers font:")
            placeholderText: i18n("JetBrains Mono, else a monospace font")
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Blur behind (desktop only)") }
        RowLayout {
            Kirigami.FormData.label: i18n("Image:")
            QQC2.TextField {
                id: backgroundImage
                Layout.preferredWidth: Kirigami.Units.gridUnit * 16
                placeholderText: i18n("None: plain translucent glass")
            }
            QQC2.Button { icon.name: "document-open"; onClicked: imageDialog.open(); QQC2.ToolTip.text: i18n("Browse…"); QQC2.ToolTip.visible: hovered }
            QQC2.Button { icon.name: "edit-clear"; enabled: backgroundImage.text !== ""; onClicked: backgroundImage.text = "" }
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: i18n("Widgets on the desktop can't be blurred by KWin. Pick the same image as your wallpaper (in \"Scaled and cropped\" mode) and the widget blurs it under itself.")
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Blur strength:")
            enabled: backgroundImage.text !== ""
            QQC2.Slider { id: blurAmount; from: 0; to: 1; stepSize: 0.05; Layout.preferredWidth: Kirigami.Units.gridUnit * 10 }
        }
    }

    FileDialog {
        id: imageDialog
        title: i18n("Choose your wallpaper image")
        nameFilters: [i18n("Images (*.png *.jpg *.jpeg *.webp *.avif)")]
        onAccepted: backgroundImage.text = selectedFile.toString().replace(/^file:\/\//, "")
    }
}
