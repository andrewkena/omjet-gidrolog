import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import QGroundControl
import QGroundControl.FactControls
import QGroundControl.Controls

Item {
    id: root

    default property alias contentItem: mainLayout.data
    property int sectionFilter: -1

    QGCFlickable {
        objectName:     "settingsPageFlickable"
        anchors.fill:   parent
        contentWidth:   mainLayout.width
        contentHeight:  mainLayout.height

        ColumnLayout {
            id:         mainLayout
            x:          Math.max(0, root.width / 2 - width / 2)
            // GidroLog: one fixed, compact width for every settings page
            width:      Math.min(root.width, ScreenTools.defaultFontPixelWidth * 70)
            spacing:    ScreenTools.defaultFontPixelHeight
        }
    }
}
