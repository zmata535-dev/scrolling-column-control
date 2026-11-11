import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui as Ui

Ui.BarWidget {
  id: root
  moduleName: "zm.column-control"

  property bool opened: false
  property bool expanded: false
  property bool pointerVisited: false
  property string targetAddress: ""
  property int narrowPercent: 50
  property int normalPercent: 69
  property int widePercent: 92
  readonly property string configPath: Quickshell.env("HOME") + "/.config/omarchy/column-width.json"
  readonly property string hotCornerConfigPath: Quickshell.env("HOME") + "/.config/omarchy/hot-corners.json"
  readonly property color foreground: bar ? bar.barForeground : Commons.Color.foreground
  readonly property color iconForeground: Commons.Color.popups.text
  property int hotCornerSize: 6
  property int hotCornerDelayMs: 120
  property bool hotCornerConfigLoaded: false
  property var hotCorners: ({ "top-left": { action: "open-column-control" } })

  function clampPercent(value) { return Math.max(25, Math.min(100, Math.round(Number(value) || 50))) }
  function open() {
    var target = Hyprland.activeToplevel
    var workspace = Hyprland.focusedWorkspace
    if (!target || !target.address || !workspace || !target.workspace
        || String(target.workspace.id) !== String(workspace.id)) {
      close()
      return
    }
    targetAddress = target && target.address ? String(target.address) : ""
    pointerVisited = button.tooltipHovered
    expanded = false
    opened = true
  }
  function close() { opened = false; expanded = false; pointerVisited = false; targetAddress = "" }
  function toggle() { opened ? close() : open() }

  function loadConfig(raw) {
    try {
      var data = JSON.parse(String(raw || "{}"))
      if (data && typeof data === "object") {
        if (Number.isFinite(Number(data.narrow))) narrowPercent = clampPercent(data.narrow)
        if (Number.isFinite(Number(data.normal))) normalPercent = clampPercent(data.normal)
        if (Number.isFinite(Number(data.wide))) widePercent = clampPercent(data.wide)
      }
    } catch (e) {
      console.warn("Column width settings could not be read:", e)
    }
  }
  function saveConfig() {
    configFile.setText(JSON.stringify({ narrow: narrowPercent, normal: normalPercent, wide: widePercent }, null, 2) + "\n")
  }
  function setPercent(kind, value) {
    var percent = clampPercent(value)
    if (kind === "narrow") narrowPercent = percent
    else if (kind === "normal") normalPercent = percent
    else widePercent = percent
    saveConfig()
  }
  function loadHotCornerConfig(raw) {
    try {
      var data = JSON.parse(String(raw || "{}"))
      if (!data || typeof data !== "object") return
      if (Number.isFinite(Number(data.size)) && Number(data.size) > 0)
        hotCornerSize = Math.max(1, Math.min(64, Math.round(Number(data.size))))
      if (Number.isFinite(Number(data.delayMs)) && Number(data.delayMs) >= 0)
        hotCornerDelayMs = Math.max(0, Math.min(5000, Math.round(Number(data.delayMs))))
      if (data.corners && typeof data.corners === "object") hotCorners = data.corners
    } catch (e) {
      console.warn("Hot corner settings could not be read:", e)
    }
  }
  function saveHotCornerConfig() {
    hotCornerFile.setText(JSON.stringify({
      size: hotCornerSize,
      delayMs: hotCornerDelayMs,
      corners: hotCorners
    }, null, 2) + "\n")
  }
  function hotCornerAction(key) {
    var entry = hotCorners ? hotCorners[key] : null
    if (typeof entry === "string") return entry
    return entry && typeof entry === "object" ? String(entry.action || "") : "disabled"
  }
  function hotCornerActionLabel(key) {
    var action = hotCornerAction(key)
    if (action === "open-column-control") return "Open Column Control"
    if (action === "show-desktop") return "Show desktop"
    if (action === "focus-left") return "Focus Left"
    if (action === "focus-right") return "Focus Right"
    if (action === "center-focused") return "Center Focused"
    if (action === "command") return "Custom command"
    return "Disabled"
  }
  function cycleHotCornerAction(key) {
    var order = ["disabled", "open-column-control", "show-desktop", "focus-left", "focus-right", "center-focused"]
    var current = hotCornerAction(key)
    var next = order[(order.indexOf(current) + 1) % order.length]
    var updated = Object.assign({}, hotCorners || {})
    if (next === "disabled") delete updated[key]
    else updated[key] = { action: next }
    hotCorners = updated
    saveHotCornerConfig()
  }
  function setHotCornerSize(value) {
    hotCornerSize = Math.max(1, Math.min(64, Math.round(Number(value) || 1)))
    saveHotCornerConfig()
  }
  function setHotCornerDelay(value) {
    hotCornerDelayMs = Math.max(0, Math.min(5000, Math.round(Number(value) || 0)))
    saveHotCornerConfig()
  }
  function applyColumn(percent) {
    if (!targetAddress || !Hyprland.activeToplevel || String(Hyprland.activeToplevel.address) !== targetAddress) {
      close()
      return
    }
    var ratio = (clampPercent(percent) / 100).toFixed(2)
    Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.layout(\"colresize " + ratio + "\")"])
    close()
  }
  function applyFullscreen() {
    if (!targetAddress || !Hyprland.activeToplevel || String(Hyprland.activeToplevel.address) !== targetAddress) {
      close()
      return
    }
    Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.window.fullscreen({ mode = \"fullscreen\", action = \"set\" })"])
    close()
  }

  FileView {
    id: configFile
    path: root.configPath
    watchChanges: true
    printErrors: false
    onLoaded: root.loadConfig(text())
    onFileChanged: reload()
  }

  FileView {
    id: hotCornerFile
    path: root.hotCornerConfigPath
    watchChanges: true
    printErrors: false
    onLoaded: {
      root.loadHotCornerConfig(text())
      root.hotCornerConfigLoaded = true
    }
    onLoadFailed: root.hotCornerConfigLoaded = true
    onFileChanged: reload()
  }

  Timer {
    interval: 150
    repeat: true
    running: root.opened
    onTriggered: {
      var active = Hyprland.activeToplevel
      if (!active || !root.targetAddress || String(active.address) !== root.targetAddress) root.close()
    }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Ui.BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰆾"
    textRotation: 45
    tooltipText: "Column width"
    active: root.opened
    onTooltipHoveredChanged: if (tooltipHovered) root.pointerVisited = true
    onPressed: root.toggle()
  }

  IpcHandler {
    target: root.moduleName
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
  }

  Ui.PopupCard {
    id: popup
    anchorItem: button
    bar: root.bar
    owner: root
    open: root.opened
    centerOnBar: false
    contentWidth: popup.fittedContentWidth(root.expanded ? Style.space(450) : Style.space(300))
    contentHeight: popup.fittedContentHeight(content.implicitHeight)
    onContainsMouseChanged: if (containsMouse) root.pointerVisited = true

    Column {
      id: content
      width: parent.width
      spacing: Style.space(12)

      Text {
        visible: root.expanded
        text: "Column width"
        textFormat: Text.PlainText
        color: root.foreground
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.subtitle
        font.bold: true
      }

      Row {
        visible: !root.expanded
        width: parent.width
        spacing: Style.space(4)

        Repeater {
          model: [
            { label: "Narrow " + root.narrowPercent + "%", kind: "narrow", percent: root.narrowPercent },
            { label: "Normal " + root.normalPercent + "%", kind: "normal", percent: root.normalPercent },
            { label: "Wide " + root.widePercent + "%", kind: "wide", percent: root.widePercent },
            { label: "Full width", kind: "fullwidth", icon: "fullscreen", percent: 100 },
            { label: "Fullscreen", kind: "fullscreen", icon: "expand", fullscreen: true }
          ]

          delegate: Rectangle {
            required property var modelData
            width: Style.space(42)
            height: Style.space(42)
            radius: Style.cornerRadius
            color: actionMouse.containsMouse ? Style.hoverFillFor(root.iconForeground, Commons.Color.accent) : "transparent"

            Canvas {
              id: actionCanvas
              anchors.centerIn: parent
              width: parent.width
              height: parent.height
              property var action: modelData
              onActionChanged: requestPaint()
              onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                ctx.scale(width / 24, height / 24)
                ctx.strokeStyle = root.iconForeground.toString()
                ctx.lineWidth = 1.7
                ctx.lineCap = "round"
                ctx.lineJoin = "round"
                if (action.icon !== "expand") ctx.strokeRect(1.5, 1.5, 21, 21)

                if (action.icon === "fullscreen") {
                  ctx.beginPath()
                  ctx.moveTo(8, 1.5); ctx.lineTo(1.5, 1.5); ctx.lineTo(1.5, 8)
                  ctx.moveTo(16, 1.5); ctx.lineTo(22.5, 1.5); ctx.lineTo(22.5, 8)
                  ctx.moveTo(1.5, 16); ctx.lineTo(1.5, 22.5); ctx.lineTo(8, 22.5)
                  ctx.moveTo(22.5, 16); ctx.lineTo(22.5, 22.5); ctx.lineTo(16, 22.5)
                  ctx.stroke()
                } else if (action.icon === "expand") {
                  ctx.beginPath()
                  ctx.moveTo(10, 10); ctx.lineTo(3.5, 3.5)
                  ctx.moveTo(3.5, 3.5); ctx.lineTo(8, 3.5)
                  ctx.moveTo(3.5, 3.5); ctx.lineTo(3.5, 8)
                  ctx.moveTo(14, 10); ctx.lineTo(20.5, 3.5)
                  ctx.moveTo(20.5, 3.5); ctx.lineTo(16, 3.5)
                  ctx.moveTo(20.5, 3.5); ctx.lineTo(20.5, 8)
                  ctx.moveTo(10, 14); ctx.lineTo(3.5, 20.5)
                  ctx.moveTo(3.5, 20.5); ctx.lineTo(8, 20.5)
                  ctx.moveTo(3.5, 20.5); ctx.lineTo(3.5, 16)
                  ctx.moveTo(14, 14); ctx.lineTo(20.5, 20.5)
                  ctx.moveTo(20.5, 20.5); ctx.lineTo(16, 20.5)
                  ctx.moveTo(20.5, 20.5); ctx.lineTo(20.5, 16)
                  ctx.stroke()
                } else {
                  var ratio = action.kind === "fullwidth" ? 1 : Number(action.percent) / 100
                  var windowWidth = 21 * ratio
                  var x = 1.5 + (21 - windowWidth) / 2
                  var y = action.kind === "fullwidth" ? 7 : 3.5
                  var h = action.kind === "fullwidth" ? 10 : 18
                  ctx.strokeRect(x, y, windowWidth, h)
                }
              }
            }

            MouseArea {
              id: actionMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (modelData.fullscreen) root.applyFullscreen()
                else root.applyColumn(modelData.percent)
              }
            }

            Ui.PanelToolTip { visible: actionMouse.containsMouse; text: modelData.label }
          }
        }

        Rectangle {
          id: expandButton
          width: Style.space(42)
          height: Style.space(42)
          radius: Style.cornerRadius
          color: expandMouse.containsMouse ? Style.hoverFillFor(root.iconForeground, Commons.Color.accent) : "transparent"

          Text {
            anchors.centerIn: parent
            text: "󱁤"
            color: root.iconForeground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.subtitle * 2
          }

          MouseArea {
            id: expandMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = true
          }

          Ui.PanelToolTip { visible: expandMouse.containsMouse; text: "More options" }
        }
      }

      Row {
        visible: root.expanded
        width: parent.width
        spacing: Style.space(8)

        Ui.Button {
          text: "Compact view"
          foreground: root.foreground
          onClicked: root.expanded = false
        }
      }

      Text {
        visible: root.expanded
        text: "Hot corners"
        textFormat: Text.PlainText
        color: root.foreground
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.body
        font.bold: true
      }

      Row {
        visible: root.expanded
        enabled: root.hotCornerConfigLoaded
        width: parent.width
        spacing: Style.space(8)

        Text {
          width: Style.space(112)
          height: Style.space(36)
          text: "Trigger size  " + root.hotCornerSize + " px"
          color: root.foreground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
          verticalAlignment: Text.AlignVCenter
        }

        Ui.PanelSlider {
          width: parent.width - Style.space(120)
          bar: root.bar
          minimum: 1
          maximum: 32
          step: 1
          integer: true
          value: root.hotCornerSize
          onMoved: function(nextValue) { root.setHotCornerSize(nextValue) }
        }
      }

      Row {
        visible: root.expanded
        enabled: root.hotCornerConfigLoaded
        width: parent.width
        spacing: Style.space(8)

        Text {
          width: Style.space(112)
          height: Style.space(36)
          text: "Delay  " + root.hotCornerDelayMs + " ms"
          color: root.foreground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
          verticalAlignment: Text.AlignVCenter
        }

        Ui.PanelSlider {
          width: parent.width - Style.space(120)
          bar: root.bar
          minimum: 0
          maximum: 1000
          step: 10
          integer: true
          value: root.hotCornerDelayMs
          onMoved: function(nextValue) { root.setHotCornerDelay(nextValue) }
        }
      }

      Repeater {
        visible: root.expanded
        enabled: root.hotCornerConfigLoaded
        model: ["top-left", "top-right", "bottom-left", "bottom-right"]

        delegate: Row {
          required property string modelData
          visible: root.expanded
          width: content.width
          spacing: Style.space(8)

          Text {
            width: Style.space(112)
            height: Style.space(36)
            text: modelData.replace("-", " ").replace(/^./, function(c) { return c.toUpperCase() })
            color: root.foreground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
            verticalAlignment: Text.AlignVCenter
          }

          Ui.Button {
            width: parent.width - Style.space(120)
            text: root.hotCornerActionLabel(modelData)
            foreground: root.foreground
            onClicked: root.cycleHotCornerAction(modelData)
          }
        }
      }

      Row {
        visible: root.expanded
        width: parent.width
        spacing: Style.space(8)

        Repeater {
          model: 3

          delegate: Rectangle {
            required property int index
            readonly property string key: ["narrow", "normal", "wide"][index]
            readonly property string label: ["Narrow", "Normal", "Wide"][index]
            readonly property int percent: index === 0 ? root.narrowPercent
              : (index === 1 ? root.normalPercent : root.widePercent)
            width: (content.width - Style.space(16)) / 3
            height: Style.space(84)
            radius: Style.space(8)
            color: Commons.Color.popups.background
            border.width: 1
            border.color: Commons.Color.popups.border

            Column {
              anchors.fill: parent
              anchors.margins: Style.space(6)
              spacing: Style.space(4)

              Ui.Button {
                width: parent.width
                text: parent.parent.label + "  " + parent.parent.percent + "%"
                foreground: root.foreground
                onClicked: root.applyColumn(parent.parent.percent)
              }

              Ui.PanelSlider {
                width: parent.width
                bar: root.bar
                minimum: 25
                maximum: 100
                step: 1
                integer: true
                value: parent.parent.percent
                onMoved: function(nextValue) { root.setPercent(parent.parent.key, nextValue) }
              }
            }
          }
        }
      }

    }
  }

  Timer {
    interval: 3000
    running: root.opened && !root.expanded && root.pointerVisited
      && !button.tooltipHovered && !popup.containsMouse
    onTriggered: {
      if (root.opened && !root.expanded && root.pointerVisited
          && !button.tooltipHovered && !popup.containsMouse) root.close()
    }
  }
}
