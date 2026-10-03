import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "custom.network-activity"
  ipcTarget: "custom.network-activity"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property var historyDown: hostWidget ? hostWidget.historyDown : []
  readonly property var historyUp: hostWidget ? hostWidget.historyUp : []
  readonly property string currentDown: hostWidget ? hostWidget.currentDown : "0 B/s"
  readonly property string currentUp: hostWidget ? hostWidget.currentUp : "0 B/s"
  readonly property string peakSpeed: hostWidget ? hostWidget.peakSpeedStr : "0 B/s"

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(mainColumn.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent

      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onMoveRequested: function(dx, dy) { if (dx !== 0) root.switchPanel(dx) }
      onTextKey: function(text) {
        if (text === "r" || text === "R") {
          if (root.hostWidget && typeof root.hostWidget.resetPeak === "function") {
            root.hostWidget.resetPeak()
          }
        }
      }

      ColumnLayout {
        id: mainColumn
        anchors.fill: parent
        spacing: Style.space(12)

        // Header row
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(8)

          Text {
            text: "󰛳  Network Traffic"
            color: root.bar ? root.bar.barForeground : Color.foreground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.subtitle
            font.bold: true
          }

          Item { Layout.fillWidth: true }

          Text {
            text: "Peak: " + root.peakSpeed
            color: root.bar ? root.bar.barForeground : Color.foreground
            opacity: 0.65
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
          }
        }

        // Live rate badges
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(16)

          // Download badge
          Row {
            spacing: Style.space(6)
            Rectangle {
              width: Style.space(8)
              height: Style.space(8)
              radius: Style.space(4)
              color: Color.accent
              anchors.verticalCenter: parent.verticalCenter
            }
            Text {
              text: "Download: " + root.currentDown
              color: root.bar ? root.bar.barForeground : Color.foreground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.bodySmall
              font.bold: true
            }
          }

          // Upload badge
          Row {
            spacing: Style.space(6)
            Rectangle {
              width: Style.space(8)
              height: Style.space(8)
              radius: Style.space(4)
              color: Color.urgent
              anchors.verticalCenter: parent.verticalCenter
            }
            Text {
              text: "Upload: " + root.currentUp
              color: root.bar ? root.bar.barForeground : Color.foreground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.bodySmall
              font.bold: true
            }
          }
        }

        // Graph area
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: Style.space(130)
          implicitHeight: Style.space(130)
          color: Qt.rgba(0, 0, 0, 0.25)
          radius: Style.space(6)
          clip: true

          Canvas {
            id: graphCanvas
            anchors.fill: parent
            anchors.margins: Style.space(6)
            antialiasing: true

            property var downData: root.historyDown
            property var upData: root.historyUp

            onDownDataChanged: requestPaint()
            onUpDataChanged: requestPaint()

            onPaint: {
              var ctx = getContext("2d")
              ctx.reset()

              var w = width
              var h = height
              if (w <= 0 || h <= 0) return

              // Grid lines
              ctx.lineWidth = 1
              ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.08)
              ctx.beginPath()
              for (var yStep = 0.25; yStep < 1.0; yStep += 0.25) {
                var gy = Math.round(h * yStep) + 0.5
                ctx.moveTo(0, gy)
                ctx.lineTo(w, gy)
              }
              ctx.stroke()

              var pointsDown = downData || []
              var pointsUp = upData || []
              var count = Math.max(pointsDown.length, pointsUp.length)
              if (count < 2) return

              // Determine peak for Y-scaling (minimum 10 KB/s floor)
              var maxVal = 10240
              for (var i = 0; i < pointsDown.length; i++) {
                if (pointsDown[i] > maxVal) maxVal = pointsDown[i]
              }
              for (var j = 0; j < pointsUp.length; j++) {
                if (pointsUp[j] > maxVal) maxVal = pointsUp[j]
              }

              // Draw area + line helper
              function drawSeries(series, strokeColor, fillColor) {
                if (!series || series.length < 2) return
                var len = series.length
                var step = w / (len - 1)

                // Fill path
                ctx.beginPath()
                ctx.moveTo(0, h)
                for (var idx = 0; idx < len; idx++) {
                  var x = idx * step
                  var norm = Math.min(1.0, series[idx] / maxVal)
                  var y = h - (norm * (h - 4))
                  ctx.lineTo(x, y)
                }
                ctx.lineTo((len - 1) * step, h)
                ctx.closePath()
                ctx.fillStyle = fillColor
                ctx.fill()

                // Stroke line
                ctx.beginPath()
                for (var k = 0; k < len; k++) {
                  var px = k * step
                  var py = h - (Math.min(1.0, series[k] / maxVal) * (h - 4))
                  if (k === 0) ctx.moveTo(px, py)
                  else ctx.lineTo(px, py)
                }
                ctx.lineWidth = 2
                ctx.strokeStyle = strokeColor
                ctx.stroke()
              }

              // Upload (Urgent / Orange-Red)
              var upColor = Color.urgent
              drawSeries(pointsUp,
                upColor,
                Qt.rgba(upColor.r, upColor.g, upColor.b, 0.18))

              // Download (Accent / Cyan-Green)
              var downColor = Color.accent
              drawSeries(pointsDown,
                downColor,
                Qt.rgba(downColor.r, downColor.g, downColor.b, 0.28))
            }
          }
        }

        // Footer
        RowLayout {
          Layout.fillWidth: true

          Text {
            text: "Real-time activity (last 45s)"
            color: root.bar ? root.bar.barForeground : Color.foreground
            opacity: 0.45
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
          }

          Item { Layout.fillWidth: true }

          Text {
            text: "Press [R] to reset peak"
            color: root.bar ? root.bar.barForeground : Color.foreground
            opacity: 0.45
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
          }
        }
      }
    }
  }
}
