import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_title: title.text
    property alias cfg_showSourceSwitcher: showSourceSwitcher.checked
    property alias cfg_iconStyle: iconStyle.currentIndex
    property alias cfg_volumeStep: volumeStep.value
    property alias cfg_fineVolumeStep: fineVolumeStep.value
    property alias cfg_musicCli: musicCli.checked
    property alias cfg_helperCommand: helperCommand.text
    property alias cfg_tuiCommand: tuiCommand.text
    property alias cfg_showUpNext: showUpNext.checked

    Kirigami.FormLayout {
        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Card") }
        QQC2.TextField { id: title; Kirigami.FormData.label: i18n("Title:") }
        QQC2.CheckBox { id: showSourceSwitcher; text: i18n("Show the player switcher when several players run") }
        QQC2.ComboBox {
            id: iconStyle
            Kirigami.FormData.label: i18n("Icons:")
            model: [i18n("Automatic (Nerd Font if installed)"), i18n("Nerd Font glyphs"), i18n("Icon theme")]
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Volume") }
        QQC2.SpinBox { id: volumeStep; Kirigami.FormData.label: i18n("Wheel step (%):"); from: 1; to: 25 }
        QQC2.SpinBox { id: fineVolumeStep; Kirigami.FormData.label: i18n("Shift + wheel step (%):"); from: 1; to: 10 }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("music-cli") }
        QQC2.CheckBox { id: musicCli; text: i18n("Enable music-cli integration") }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont; opacity: 0.7
            text: i18n("Adds playlist shortcuts, a playlist browser, like and reshuffle buttons and the up-next list for the music-cli player. Needs the scripts from extras/music-cli (see the README).")
        }
        QQC2.TextField { id: helperCommand; enabled: musicCli.checked; Kirigami.FormData.label: i18n("Helper command:") }
        QQC2.TextField { id: tuiCommand; enabled: musicCli.checked; Kirigami.FormData.label: i18n("Open the TUI with:") }
        QQC2.CheckBox { id: showUpNext; enabled: musicCli.checked; text: i18n("Show the up-next list") }
    }
}
