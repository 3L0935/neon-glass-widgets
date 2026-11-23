import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_title: title.text
    property string cfg_rightLabel
    property alias cfg_use24h: use24h.checked
    property alias cfg_showSeconds: showSeconds.checked
    property alias cfg_locale: locale.text
    property alias cfg_dateFormat: dateFormat.text
    property alias cfg_lowercaseDate: lowercaseDate.checked
    property alias cfg_showWeekDay: showWeekDay.checked
    property alias cfg_digitsFont: digitsFont.text
    property alias cfg_digitsWeight: digitsWeight.value
    property alias cfg_showSun: showSun.checked
    property real cfg_latitude
    property real cfg_longitude
    property alias cfg_showTicks: showTicks.checked
    property alias cfg_showZones: showZones.checked
    property alias cfg_zones: zones.text

    Kirigami.FormLayout {
        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Header") }
        QQC2.TextField { id: title; Kirigami.FormData.label: i18n("Title:") }
        QQC2.ComboBox {
            Kirigami.FormData.label: i18n("Right label:")
            textRole: "text"; valueRole: "value"
            model: [
                { text: i18n("Daylight / night"), value: "sun" },
                { text: i18n("Date"), value: "date" },
                { text: i18n("None"), value: "none" }
            ]
            Component.onCompleted: currentIndex = Math.max(0, indexOfValue(cfg_rightLabel))
            onActivated: cfg_rightLabel = currentValue
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Time") }
        QQC2.CheckBox { id: use24h; Kirigami.FormData.label: i18n("Format:"); text: i18n("24-hour clock (click the time to switch)") }
        QQC2.CheckBox { id: showSeconds; text: i18n("Show the seconds") }
        QQC2.TextField {
            id: digitsFont
            Kirigami.FormData.label: i18n("Digits font:")
            placeholderText: i18n("Numbers font from Appearance")
        }
        QQC2.SpinBox { id: digitsWeight; Kirigami.FormData.label: i18n("Digits weight:"); from: 100; to: 900; stepSize: 100 }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Date") }
        QQC2.TextField { id: locale; Kirigami.FormData.label: i18n("Language:"); placeholderText: i18n("System (e.g. en_US, fr_FR)") }
        QQC2.TextField { id: dateFormat; Kirigami.FormData.label: i18n("Date format:") }
        QQC2.Label {
            text: i18n("Qt format: ddd = short day, dddd = day, MMM = short month, MMMM = month, d = day number, yyyy = year.")
            font: Kirigami.Theme.smallFont; opacity: 0.7; wrapMode: Text.WordWrap
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
        }
        QQC2.CheckBox { id: lowercaseDate; text: i18n("Lowercase") }
        QQC2.CheckBox { id: showWeekDay; text: i18n("Show the week number") }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Sun path") }
        QQC2.CheckBox { id: showSun; Kirigami.FormData.label: i18n("Show:"); text: i18n("Sun path over the day") }
        QQC2.TextField {
            Kirigami.FormData.label: i18n("Latitude:")
            enabled: showSun.checked
            text: cfg_latitude
            validator: DoubleValidator { bottom: -90; top: 90; notation: DoubleValidator.StandardNotation }
            onTextEdited: if (acceptableInput) cfg_latitude = parseFloat(text.replace(",", "."))
        }
        QQC2.TextField {
            Kirigami.FormData.label: i18n("Longitude:")
            enabled: showSun.checked
            text: cfg_longitude
            validator: DoubleValidator { bottom: -180; top: 180; notation: DoubleValidator.StandardNotation }
            onTextEdited: if (acceptableInput) cfg_longitude = parseFloat(text.replace(",", "."))
        }
        QQC2.Label {
            text: i18n("Decimal degrees, east and north positive. Sunrise and sunset are computed locally.")
            font: Kirigami.Theme.smallFont; opacity: 0.7; wrapMode: Text.WordWrap
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Bottom") }
        QQC2.CheckBox { id: showTicks; Kirigami.FormData.label: i18n("Show:"); text: i18n("Seconds strip") }
        QQC2.CheckBox { id: showZones; text: i18n("World times") }
        QQC2.TextField {
            id: zones
            Kirigami.FormData.label: i18n("Time zones:")
            enabled: showZones.checked
            Layout.minimumWidth: Kirigami.Units.gridUnit * 22
        }
        QQC2.Label {
            text: i18n("Comma separated, Area/City=LABEL, for example: Europe/London=LDN, Asia/Tokyo=TYO, UTC")
            font: Kirigami.Theme.smallFont; opacity: 0.7; wrapMode: Text.WordWrap
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
        }
    }
}
