import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// Hot corners for the Omarchy shell. Pushing the pointer into a configured
// screen corner runs an action — showing the desktop, or any command you like.
//
// The trigger is an invisible layer-shell window a few pixels square, pinned to
// each corner of each screen, with a HoverHandler on it. The compositor tells us
// when the pointer arrives, so nothing polls the cursor position and nothing
// runs between visits to a corner.
//
// Settings live in ~/.config/omarchy/hot-corners.json so they survive
// `omarchy plugin update`, and are re-read the moment that file changes.
Item {
  id: root

  // Injected by omarchy-shell.
  property var shell: null

  // The helper ships alongside this file, so it resolves wherever the plugin is
  // installed. Qt.resolvedUrl gives a file:// URL; exec needs a plain path.
  readonly property string showDesktopScript: {
    var u = Qt.resolvedUrl("show-desktop").toString()
    return u.indexOf("file://") === 0 ? u.substring(7) : u
  }

  readonly property string configPath: Quickshell.env("HOME") + "/.config/omarchy/hot-corners.json"
  readonly property var cornerKeys: ["top-left", "top-right", "bottom-left", "bottom-right"]

  readonly property int defaultSize: 8
  readonly property int defaultDelayMs: 120
  function defaultCorners() {
    return {
      "top-left": { action: "open-column-control" },
      "top-right": { action: "center-focused" },
      "bottom-left": { action: "focus-left" },
      "bottom-right": { action: "focus-right" }
    }
  }

  property int cornerSize: defaultSize
  property int triggerDelayMs: defaultDelayMs
  property var corners: defaultCorners()

  function applyConfig(raw) {
    var parsed = null
    if (raw && String(raw).trim() !== "") {
      try { parsed = JSON.parse(raw) } catch (e) { parsed = null }
    }
    if (!parsed || typeof parsed !== "object") {
      root.cornerSize = root.defaultSize
      root.triggerDelayMs = root.defaultDelayMs
      root.corners = root.defaultCorners()
      return
    }
    root.cornerSize = (typeof parsed.size === "number" && parsed.size > 0)
      ? Math.round(parsed.size) : root.defaultSize
    root.triggerDelayMs = (typeof parsed.delayMs === "number" && parsed.delayMs >= 0)
      ? Math.round(parsed.delayMs) : root.defaultDelayMs
    root.corners = (parsed.corners && typeof parsed.corners === "object")
      ? parsed.corners : {}
  }

  // A corner may be given as a bare action string or as an object.
  function entryFor(key) {
    var e = root.corners ? root.corners[key] : null
    if (!e) return null
    if (typeof e === "string") return { action: e }
    if (typeof e === "object") return e
    return null
  }

  function trigger(key) {
    var e = root.entryFor(key)
    if (!e) return
    if (e.action === "open-column-control") {
      Quickshell.execDetached(["omarchy-shell", "shell", "summon", "zm.column-control"])
    } else if (e.action === "focus-left") {
      Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ direction = 'l' })"])
    } else if (e.action === "focus-right") {
      Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ direction = 'r' })"])
    } else if (e.action === "center-focused") {
      Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.layout('center')"])
    } else if (e.action === "show-desktop") {
      Quickshell.execDetached([root.showDesktopScript])
    } else if (e.action === "command" && Array.isArray(e.command) && e.command.length > 0) {
      // An argument list, never a shell string: nothing is word-split or globbed.
      Quickshell.execDetached(e.command)
    }
  }

  property FileView configFile: FileView {
    path: root.configPath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.applyConfig(text())
    onLoadFailed: root.applyConfig("")
  }

  // The first read can race shell startup, leaving defaults in place until the
  // next write. One delayed reload self-corrects and is a no-op if it was fine.
  Timer {
    interval: 1500
    running: true
    onTriggered: root.configFile.reload()
  }

  Variants {
    model: Quickshell.screens

    Scope {
      id: screenScope
      required property var modelData

      Instantiator {
        model: root.cornerKeys

        delegate: Scope {
          id: cornerScope
          required property var modelData

          readonly property string key: cornerScope.modelData
          readonly property bool enabled: !!root.entryFor(cornerScope.key)

          Timer {
            id: armTimer
            interval: root.triggerDelayMs
            onTriggered: root.trigger(cornerScope.key)
          }

          PanelWindow {
            screen: screenScope.modelData
            visible: cornerScope.enabled
            color: "transparent"
            implicitWidth: root.cornerSize
            implicitHeight: root.cornerSize
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "omarchy-hot-corner"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            anchors {
              left: cornerScope.key.indexOf("left") >= 0
              right: cornerScope.key.indexOf("right") >= 0
              top: cornerScope.key.indexOf("top") >= 0
              bottom: cornerScope.key.indexOf("bottom") >= 0
            }

            Item {
              anchors.fill: parent

              HoverHandler {
                // Arm on arrival, disarm on leave: one fire per visit to the
                // corner, and nothing at all while the pointer is elsewhere.
                onHoveredChanged: {
                  if (hovered) armTimer.restart()
                  else armTimer.stop()
                }
              }
            }
          }
        }
      }
    }
  }
}
