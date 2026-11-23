import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory { name: i18n("General"); icon: "preferences-system-time"; source: "ConfigGeneral.qml" }
    ConfigCategory { name: i18n("Appearance"); icon: "preferences-desktop-color"; source: "ConfigAppearance.qml" }
}
