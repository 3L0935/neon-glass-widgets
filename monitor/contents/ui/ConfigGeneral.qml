import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_title: title.text
    property alias cfg_showHostname: showHostname.checked
    property alias cfg_showUptime: showUptime.checked
    property alias cfg_gpuIndex: gpuIndex.value
    property alias cfg_showGpu: showGpu.checked
    property alias cfg_showLoadGraph: showLoadGraph.checked
    property alias cfg_historySeconds: historySeconds.value
    property alias cfg_showRam: showRam.checked
    property alias cfg_cpuShowTemp: cpuShowTemp.checked
    property alias cfg_gpuShowTemp: gpuShowTemp.checked
    property alias cfg_showVram: showVram.checked

    Kirigami.FormLayout {
        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Header") }
        QQC2.TextField { id: title; Kirigami.FormData.label: i18n("Title:") }
        QQC2.CheckBox { id: showHostname; text: i18n("Show the host name") }
        QQC2.CheckBox { id: showUptime; text: i18n("Show the uptime") }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Sections") }
        QQC2.CheckBox { id: showGpu; Kirigami.FormData.label: i18n("Show:"); text: i18n("GPU ring") }
        QQC2.CheckBox { id: showLoadGraph; text: i18n("Load history graph") }
        QQC2.CheckBox { id: showRam; text: i18n("RAM bar") }
        QQC2.CheckBox { id: showVram; text: i18n("VRAM bar"); enabled: showGpu.checked }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Rings") }
        QQC2.CheckBox { id: cpuShowTemp; Kirigami.FormData.label: i18n("Big number:"); text: i18n("CPU temperature instead of usage (or click the ring)") }
        QQC2.CheckBox { id: gpuShowTemp; text: i18n("GPU temperature instead of usage"); enabled: showGpu.checked }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Sensors") }
        QQC2.SpinBox {
            id: gpuIndex
            Kirigami.FormData.label: i18n("GPU:")
            from: 0; to: 7
            textFromValue: (v) => "gpu" + v
            valueFromText: (t) => parseInt(t.replace("gpu", "")) || 0
        }
        QQC2.Label {
            text: i18n("Same numbering as System Monitor (gpu0 is usually your main GPU).")
            font: Kirigami.Theme.smallFont; opacity: 0.7
        }
        QQC2.SpinBox { id: historySeconds; Kirigami.FormData.label: i18n("Graph length (seconds):"); from: 20; to: 300; stepSize: 10 }
    }
}
