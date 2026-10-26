import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.Commons
import qs.Ui

// Now Playing: the current track's cover and a live cava waveform.
//
//   Cover     - click to jump to the player: its workspace, its window and,
//               for players that support MPRIS Raise (Chromium), its tab.
//   Waveform  - click to drop a small card with previous / play-pause / next.
//               The widget exposes open / close / opened, so bars that open
//               panels on hover open it on hover too.
//
// Hidden while no MPRIS player is running.
BarWidget {
  id: root
  moduleName: "jaideepo7.now-playing"

  readonly property int barCount: 10
  property var levels: new Array(barCount).fill(0)

  // A playing player first, else the first one that has art, else the first.
  readonly property var activePlayer: {
    var list = Mpris.players.values
    var withArt = null
    for (var i = 0; i < list.length; i++) {
      var p = list[i]
      if (!p) continue
      if (p.isPlaying) return p
      if (!withArt && p.trackArtUrl) withArt = p
    }
    return withArt || (list.length > 0 ? list[0] : null)
  }
  readonly property string artUrl: activePlayer && activePlayer.trackArtUrl ? activePlayer.trackArtUrl : ""
  readonly property real artSize: Math.round(barSize * 0.7)

  // Overall size of the controls card; everything in it scales with this.
  readonly property real popupScale: 1.35

  // ---- Popup contract the bar looks for (open / close / opened).
  property bool popupOpen: false
  readonly property bool opened: popupOpen
  function open() { if (activePlayer) popupOpen = true }
  function close() { popupOpen = false }
  function toggle() { popupOpen ? close() : open() }

  onActivePlayerChanged: if (!activePlayer) close()

  visible: activePlayer !== null
  implicitWidth: visible ? content.implicitWidth + 14 : 0
  implicitHeight: barSize

  function pluginPath(name) {
    return Qt.resolvedUrl(name).toString().replace("file://", "")
  }

  Process {
    id: cava
    command: ["cava", "-p", root.pluginPath("cava.conf")]
    running: root.visible
    stdout: SplitParser {
      onRead: function(line) {
        var parts = line.split(";")
        var next = []
        for (var i = 0; i < root.barCount; i++) next.push(Math.min(100, parseInt(parts[i]) || 0) / 100)
        root.levels = next
      }
    }
  }

  Process {
    id: focusProc
    command: ["bash", root.pluginPath("focus-player.sh"),
      root.activePlayer ? String(root.activePlayer.dbusName || "") : "",
      root.activePlayer ? String(root.activePlayer.desktopEntry || "") : "",
      root.activePlayer ? String(root.activePlayer.trackTitle || "") : ""]
  }

  Row {
    id: content
    anchors.centerIn: parent
    spacing: 8

    // ---- Cover
    Item {
      visible: root.artUrl !== ""
      width: root.artSize
      height: root.barSize

      Rectangle {
        anchors.centerIn: parent
        width: root.artSize
        height: root.artSize
        radius: 4
        color: "transparent"
        clip: true

        Image {
          anchors.fill: parent
          source: root.artUrl
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          sourceSize.width: 64
          sourceSize.height: 64
        }
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: if (root.activePlayer && !focusProc.running) focusProc.running = true
      }
    }

    // ---- Waveform
    Item {
      width: wave.implicitWidth
      height: root.barSize

      Row {
        id: wave
        anchors.centerIn: parent
        spacing: 2

        Repeater {
          model: root.barCount
          Rectangle {
            required property int index
            width: 3
            height: Math.max(2, (root.barSize * 0.6) * root.levels[index])
            radius: 1.5
            anchors.verticalCenter: parent.verticalCenter
            color: root.bar ? root.bar.barForeground : "white"
            opacity: 0.85
            Behavior on height { NumberAnimation { duration: 60 } }
          }
        }
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggle()
      }
    }
  }

  // One compact transport button: a glyph, a soft hover wash, nothing else.
  component MediaButton: Item {
    id: btn
    property string glyph: ""
    signal activated()
    width: Math.round(Style.space(26) * root.popupScale)
    height: Math.round(Style.space(24) * root.popupScale)
    opacity: enabled ? 1.0 : 0.35

    Rectangle {
      anchors.fill: parent
      radius: Style.cornerRadius
      color: root.bar.foreground
      opacity: btnMouse.pressed ? 0.16 : btnMouse.containsMouse ? 0.08 : 0
      Behavior on opacity { NumberAnimation { duration: 100 } }
    }

    Text {
      anchors.centerIn: parent
      text: btn.glyph
      color: root.bar.foreground
      font.family: root.bar.fontFamily
      font.pixelSize: Math.round(Style.font.body * root.popupScale)
    }

    MouseArea {
      id: btnMouse
      anchors.fill: parent
      enabled: btn.enabled
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: btn.activated()
    }
  }

  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    padding: Math.round(Style.space(4) * root.popupScale)
    contentWidth: controls.implicitWidth + popup.padding * 2 + 2 * Math.max(1, Style.space(2))
    contentHeight: popup.fittedContentHeight(controls.implicitHeight)

    Row {
      id: controls
      anchors.centerIn: parent
      spacing: Math.round(Style.space(2) * root.popupScale)

      MediaButton {
        glyph: "󰒮"
        enabled: !!root.activePlayer && root.activePlayer.canGoPrevious
        onActivated: root.activePlayer.previous()
      }

      MediaButton {
        glyph: root.activePlayer && root.activePlayer.isPlaying ? "󰏤" : "󰐊"
        enabled: !!root.activePlayer && root.activePlayer.canTogglePlaying
        onActivated: root.activePlayer.togglePlaying()
      }

      MediaButton {
        glyph: "󰒭"
        enabled: !!root.activePlayer && root.activePlayer.canGoNext
        onActivated: root.activePlayer.next()
      }
    }
  }
}
