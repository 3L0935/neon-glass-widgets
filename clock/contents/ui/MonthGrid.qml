import QtQuick
import QtQuick.Layouts

// Month view shown in place of the clock face: month name and navigation on
// the left, week numbers + day grid on the right. Wheel or arrows change the
// month; a click on the left side (or the timeout in main.qml) goes back.
Item {
    id: view
    required property var pal
    required property var loc
    property date today: new Date()
    property int month: today.getMonth()
    property int year: today.getFullYear()
    readonly property int firstDay: Qt.locale().firstDayOfWeek   // 0 = Sunday, follows the system
    signal back()
    signal interacted()

    function shift(n) {
        let m = month + n, y = year
        while (m < 0) { m += 12; y-- }
        while (m > 11) { m -= 12; y++ }
        month = m; year = y
        interacted()
    }
    function reset() { month = today.getMonth(); year = today.getFullYear() }
    function isoWeek(d) {
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()))
        const n = t.getUTCDay() || 7
        t.setUTCDate(t.getUTCDate() + 4 - n)
        const y = new Date(Date.UTC(t.getUTCFullYear(), 0, 1))
        return Math.ceil(((t - y) / 86400000 + 1) / 7)
    }
    // 6 weeks of cells: [{date, inMonth}]
    readonly property var cells: {
        const first = new Date(year, month, 1)
        const off = (first.getDay() - firstDay + 7) % 7
        const out = []
        for (let i = 0; i < 42; i++) {
            const d = new Date(year, month, 1 - off + i)
            out.push({ d: d, inMonth: d.getMonth() === month })
        }
        // drop a trailing week that is entirely outside the month
        return out[35].inMonth ? out : out.slice(0, 35)
    }
    readonly property int rows: cells.length / 7

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (ev) => view.shift(ev.angleDelta.y > 0 ? -1 : 1)
    }

    RowLayout {
        anchors.fill: parent
        spacing: 24 * pal.ts

        // left: month, year, navigation
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: view.back() }
            Column {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                spacing: 6 * pal.ts
                Text {
                    text: view.loc.standaloneMonthName(view.month, Locale.LongFormat).toLowerCase()
                    color: pal.text
                    font { family: pal.mono; weight: Font.ExtraLight; pixelSize: 30 * pal.ts }
                }
                Text {
                    text: view.year
                    color: pal.muted
                    font { family: pal.mono; pixelSize: 13 * pal.ts }
                }
                Row {
                    topPadding: 10 * pal.ts
                    spacing: 8 * pal.ts
                    Repeater {
                        model: [{ t: "‹", n: -1 }, { t: "today", n: 0 }, { t: "›", n: 1 }]
                        Rectangle {
                            required property var modelData
                            width: lbl.implicitWidth + 16 * pal.ts
                            height: lbl.implicitHeight + 6 * pal.ts
                            radius: 5
                            color: ma.containsMouse ? pal.withAlpha(pal.accent, 0.14) : "transparent"
                            border { width: 1; color: ma.containsMouse ? pal.accent : pal.edge }
                            Text {
                                id: lbl
                                anchors.centerIn: parent
                                text: modelData.t
                                color: ma.containsMouse ? pal.accent : pal.muted
                                font { family: pal.mono; pixelSize: 11.5 * pal.ts }
                            }
                            MouseArea {
                                id: ma
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { if (modelData.n === 0) { view.reset(); view.interacted() } else view.shift(modelData.n) }
                            }
                        }
                    }
                }
            }
        }

        // right: week numbers + days
        GridLayout {
            id: grid
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
            columns: 8
            rowSpacing: 0; columnSpacing: 0
            readonly property real cell: Math.min(view.height / (view.rows + 1), 40 * pal.ts)

            Text {
                Layout.preferredWidth: grid.cell; Layout.preferredHeight: grid.cell
                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                text: "wk"; color: pal.faint
                font { family: pal.mono; pixelSize: 10.5 * pal.ts }
            }
            Repeater {
                model: 7
                Text {
                    required property int index
                    Layout.preferredWidth: grid.cell; Layout.preferredHeight: grid.cell
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    text: view.loc.dayName((view.firstDay + index) % 7, Locale.ShortFormat).slice(0, 2).toLowerCase()
                    color: pal.faint
                    font { family: pal.mono; pixelSize: 10.5 * pal.ts }
                }
            }
            Repeater {
                model: view.cells
                delegate: Item {
                    id: cellItem
                    required property var modelData
                    required property int index
                    readonly property date d: modelData.d
                    readonly property bool isToday: d.getDate() === view.today.getDate() && d.getMonth() === view.today.getMonth() && d.getFullYear() === view.today.getFullYear()
                    readonly property bool weekend: d.getDay() === 0 || d.getDay() === 6
                    Layout.preferredWidth: grid.cell; Layout.preferredHeight: grid.cell
                    Layout.row: Math.floor(index / 7) + 1
                    Layout.column: index % 7 + 1
                    Rectangle {
                        anchors.centerIn: parent
                        visible: cellItem.isToday
                        width: grid.cell * 0.86; height: grid.cell * 0.72
                        radius: 6
                        color: pal.accent
                    }
                    Text {
                        anchors.centerIn: parent
                        text: cellItem.d.getDate()
                        color: cellItem.isToday ? Qt.darker(pal.glass, 3) : (!modelData.inMonth ? pal.withAlpha(pal.faint, 0.45) : cellItem.weekend ? pal.withAlpha(pal.muted, 0.6) : pal.text)
                        font { family: pal.mono; pixelSize: 11.5 * pal.ts; weight: cellItem.isToday ? Font.DemiBold : Font.Normal }
                    }
                }
            }
            Repeater {
                model: view.rows
                Text {
                    required property int index
                    Layout.row: index + 1; Layout.column: 0
                    Layout.preferredWidth: grid.cell; Layout.preferredHeight: grid.cell
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    text: view.isoWeek(view.cells[index * 7].d)
                    color: pal.accent2
                    font { family: pal.mono; pixelSize: 10.5 * pal.ts }
                }
            }
        }
    }
}
