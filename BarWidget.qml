import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "custom.network-activity"

  property string speedText: "↓ 0 B/s ↑ 0 B/s"
  property string speedTooltip: "Network Activity (Click for graph)\nRight-click: Toggle icon-only\nMiddle-click: Reset peak"
  property string currentDown: "0 B/s"
  property string currentUp: "0 B/s"
  property string peakSpeedStr: "0 B/s"
  property real peakSpeedVal: 0

  property var historyDown: []
  property var historyUp: []
  readonly property int maxHistory: 45

  readonly property string glyph: "󰛳"

  // Shape contract for shell.summon/hide/toggle routing
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function toggle() { if (panelLoader.item) panelLoader.item.toggle() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }
  function switchPanel(direction) {
    if (panelLoader.item && typeof panelLoader.item.switchPanel === "function")
      return panelLoader.item.switchPanel(direction)
    return false
  }

  // Underline indicator on the bar
  readonly property real openPanelIndicatorWidth: {
    if (root.iconOnly && !root.vertical && iconGlyph)
      return Math.max(1, Math.round(iconGlyph.tightWidth))
    return button.labelWidth
  }
  readonly property real openPanelIndicatorHeight: Math.max(Style.space(10), Math.round(Style.bar.iconSlot * 0.55))

  // Icon-only mode toggle
  readonly property bool iconOnly: {
    var v = root.setting("iconOnly", false)
    return v === true || v === "true"
  }

  function toggleIconOnly() {
    var next = !root.iconOnly
    var entry = { id: root.moduleName }
    for (var key in root.settings) if (key !== "id") entry[key] = root.settings[key]
    entry.iconOnly = next
    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  // Vertical bar lines
  readonly property var verticalLines: {
    if (!root.vertical) return []
    var lines = [root.glyph]
    if (!root.iconOnly && root.speedText) {
      if (root.currentDown) lines.push("↓" + root.currentDown.replace("/s", ""))
      if (root.currentUp) lines.push("↑" + root.currentUp.replace("/s", ""))
    }
    return lines
  }

  function resetPeak() {
    peakSpeedVal = 0
    peakSpeedStr = "0 B/s"
  }

  function formatBytes(bytes) {
    var b = Number(bytes) || 0
    if (b < 1024) return b.toFixed(0) + " B/s"
    if (b < 1048576) return (b / 1024).toFixed(1) + " KB/s"
    if (b < 1073741824) return (b / 1048576).toFixed(1) + " MB/s"
    return (b / 1073741824).toFixed(1) + " GB/s"
  }

  function addSample(downBps, upBps) {
    var d = Number(downBps) || 0
    var u = Number(upBps) || 0

    if (d > peakSpeedVal) {
      peakSpeedVal = d
      peakSpeedStr = formatBytes(d)
    }
    if (u > peakSpeedVal) {
      peakSpeedVal = u
      peakSpeedStr = formatBytes(u)
    }

    var nextDown = historyDown.slice()
    var nextUp = historyUp.slice()

    nextDown.push(d)
    nextUp.push(u)

    while (nextDown.length > maxHistory) nextDown.shift()
    while (nextUp.length > maxHistory) nextUp.shift()

    historyDown = nextDown
    historyUp = nextUp
  }

  Component.onCompleted: {
    var initDown = []
    var initUp = []
    for (var i = 0; i < maxHistory; i++) {
      initDown.push(0)
      initUp.push(0)
    }
    historyDown = initDown
    historyUp = initUp
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  readonly property string scriptPath: {
    var url = Qt.resolvedUrl("scripts/network-speed").toString()
    if (url.indexOf("file://") === 0) return url.substring(7)
    return url
  }

  Process {
    id: speedProc
    command: [root.scriptPath]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var data = Util.parseModuleJson(text)
        if (data && data.text) {
          root.speedText = data.text
          root.currentDown = data.downStr || "0 B/s"
          root.currentUp = data.upStr || "0 B/s"
          root.speedTooltip = (data.tooltip || "Network Activity") + "\nRight-click: Toggle icon-only\nMiddle-click: Reset peak"
          root.addSample(data.downRate, data.upRate)
        }
      }
    }
  }

  Timer {
    interval: 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      speedProc.running = true
    }
  }

  IpcHandler {
    target: "custom.network-activity"
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function resetPeak(): void { root.resetPeak() }
    function toggleIconOnly(): void { root.toggleIconOnly() }
    function status(): void {
      console.log("custom.network-activity status: opened=" + root.opened
        + " down=" + root.currentDown + " up=" + root.currentUp + " peak=" + root.peakSpeedStr)
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.vertical
      ? ""
      : (root.iconOnly ? root.glyph : root.glyph + " " + root.speedText)
    labelVisible: !root.vertical && !root.iconOnly
    hasVisualContent: root.vertical ? root.verticalLines.length > 0 : text !== ""
    fixedHeight: root.vertical ? root.verticalLines.length * Style.bar.iconSlot : -1
    fontFamily: bar ? bar.fontFamily : Style.font.family
    fontSize: Style.font.bodySmall
    horizontalMargin: 8.5
    verticalPadding: 6
    tooltipText: root.speedTooltip

    onPressed: function(b) {
      if (b === Qt.RightButton) {
        root.toggleIconOnly()
      } else if (b === Qt.MiddleButton) {
        root.resetPeak()
      } else {
        root.toggle()
      }
    }

    OpticalGlyph {
      id: iconGlyph
      visible: !root.vertical && root.iconOnly
      anchors.fill: parent
      text: root.glyph
      fontFamily: button.fontFamily
      fontSize: button.fontSize
      color: button.foreground
    }

    Column {
      visible: root.vertical
      anchors.fill: parent

      Repeater {
        model: root.verticalLines

        OpticalGlyph {
          required property string modelData
          width: button.width
          height: Style.bar.iconSlot
          text: modelData
          fontFamily: button.fontFamily
          fontSize: modelData === root.glyph
            ? Style.font.icon
            : (modelData.length > 4 ? button.fontSize * 0.75 : button.fontSize * 0.85)
          color: button.foreground
        }
      }
    }
  }
}
