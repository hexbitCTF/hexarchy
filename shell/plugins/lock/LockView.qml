import QtQuick
import QtQuick.Effects
import qs.Commons
import qs.Ui
import "Wordmark.js" as Wordmark

// Minimal Hexarchy lock screen: the block wordmark, a username chooser, and a
// password field. Kept deliberately simple and theme-aware via qs.Commons.
Item {
  id: root

  property string backgroundPath: ""
  property int backgroundVersion: 0
  property bool fingerprintConfigured: false
  property bool authenticatingPassword: false
  property string failureMessage: ""
  property int failedAttempts: 0
  property bool inputEnabled: true
  property bool loadBackground: true
  property string passwordText: ""
  property var users: []
  property string selectedUser: ""

  // Hexarchy block-wordmark, the same art `hexarchy ascii hexarchy` draws in
  // the terminal. Rendered as monospace text so it follows the active theme's
  // lock text colour instead of a static bitmap.
  readonly property string wordmark: Wordmark.wordmark
  readonly property int wordmarkLines: Wordmark.wordmarkLines
  readonly property int wordmarkColumns: Wordmark.wordmarkColumns
  readonly property real wordmarkPixelSize: Math.min(
    root.width * 0.94 / root.wordmarkColumns,
    root.height * 0.22 / root.wordmarkLines,
    Style.font.heading * 1.9
  )

  readonly property string placeholderText: "Password"
  readonly property int fieldWidth: 340
  readonly property int fieldHeight: 52

  readonly property bool errorState: failureMessage.length > 0
  readonly property var inputBorderSpec: errorState
    ? Border.surfaceSpec("lock", "border-error", Color.lock.borderError, 1, "border-alpha")
    : Border.surfaceSpec("lock", "border-active", Color.lock.borderActive, 1, "border-alpha")

  signal submitPassword(string password)
  signal passwordTextEdited(string password)
  signal clearFailureRequested()
  signal wakeRequested()
  signal userSelected(string user)

  function fileUrl(path) {
    if (!path) return ""
    var encoded = String(path).split("/").map(encodeURIComponent).join("/")
    return "file://" + encoded + "?v=" + backgroundVersion
  }

  function forcePasswordFocus() {
    if (inputEnabled) passwordField.forceActiveFocus()
  }

  function clearPassword() {
    passwordTextEdited("")
  }

  function syncPasswordText() {
    if (passwordField.text === passwordText) return
    syncingPasswordText = true
    passwordField.text = passwordText
    syncingPasswordText = false
  }

  property bool syncingPasswordText: false

  onPasswordTextChanged: syncPasswordText()
  onInputEnabledChanged: {
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
  }
  onSelectedUserChanged: Qt.callLater(forcePasswordFocus)
  Component.onCompleted: {
    syncPasswordText()
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
  }

  Rectangle {
    anchors.fill: parent

    // Subtle vertical gradient from the theme backdrop tones, so the screen
    // stays opaque and simple rather than showing a translucent wallpaper.
    gradient: Gradient {
      GradientStop { position: 0.0; color: Qt.darker(Color.background, 1.15) }
      GradientStop { position: 0.55; color: Color.background }
      GradientStop { position: 1.0; color: Qt.darker(Color.background, 1.45) }
    }

    // Faint accent bloom near the top joins the theme's signature colour
    // without overpowering the wordmark.
    Rectangle {
      anchors.top: parent.top
      width: parent.width
      height: parent.height * 0.42
      gradient: Gradient {
        GradientStop { position: 0.0; color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.18) }
        GradientStop { position: 1.0; color: "transparent" }
      }
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      onClicked: { root.wakeRequested(); root.forcePasswordFocus() }
      onPositionChanged: root.wakeRequested()
    }

    Column {
      anchors.centerIn: parent
      spacing: Style.spacing.xl

      Text {
        id: wordmarkText
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.wordmark
        color: Color.lock.text
        opacity: 0.85
        font.family: Style.font.family
        font.pixelSize: root.wordmarkPixelSize
        horizontalAlignment: Text.AlignHCenter
        lineHeight: 1.0
      }

      Text {
        id: userNameLabel
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.selectedUser
        color: Color.lock.text
        font.family: Style.font.family
        font.pixelSize: Math.round(Style.font.heading * 1.4)
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
      }

      Row {
        id: userRow
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.spacing.sm
        visible: root.users.length > 1

        Repeater {
          model: root.users

          delegate: Button {
            id: chip
            required property string modelData
            text: modelData
            selected: modelData === root.selectedUser
            focusable: false
            fontSize: Style.font.body
            horizontalPadding: Style.spacing.controlPaddingX + 2
            verticalPadding: Style.spacing.controlPaddingY
            onClicked: {
              if (modelData !== root.selectedUser) root.userSelected(modelData)
              root.wakeRequested()
            }
          }
        }
      }

      BorderSurface {
        id: inputField
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.fieldWidth
        height: root.fieldHeight
        color: Color.lock.background
        borderSpec: inputBorderSpec
        radius: Style.cornerRadius
        clip: true

        TextField {
          id: passwordField
          anchors.fill: parent
          anchors.leftMargin: inputField.borderLeft + Style.spacing.lg
          anchors.rightMargin: inputField.borderRight + Style.spacing.lg
          anchors.topMargin: inputField.borderTop
          anchors.bottomMargin: inputField.borderBottom
          password: true
          activeFocusOnPress: true
          enabled: root.inputEnabled && !root.authenticatingPassword
          readOnly: root.authenticatingPassword
          color: Color.lock.text
          selectionColor: Color.lock.selection
          selectedTextColor: Color.lock.text
          placeholderTextColor: Color.lock.placeholder
          placeholderText: root.authenticatingPassword ? "" : root.placeholderText
          background: Item {}
          font.family: Style.font.family
          font.pixelSize: Style.font.heading
          leftPadding: 0
          rightPadding: 0
          topPadding: 0
          bottomPadding: 0
          verticalAlignment: TextInput.AlignVCenter

          onTextEdited: {
            if (!root.syncingPasswordText) root.passwordTextEdited(text)
            root.wakeRequested()
            if (text.length > 0 && root.failureMessage.length > 0) root.clearFailureRequested()
          }

          onAccepted: {
            var submitted = root.passwordText
            root.passwordTextEdited("")
            if (submitted.length > 0) root.submitPassword(submitted)
          }

          Keys.onPressed: function(event) {
            root.wakeRequested()
            if (event.key === Qt.Key_Escape || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_U)) {
              root.passwordTextEdited("")
              event.accepted = true
            }
          }
        }

        // Status line: only reason overlay text over the field. The idle
        // placeholder comes from the TextField itself, so it isn't duplicated.
        Text {
          id: statusText
          anchors.centerIn: passwordField
          visible: !root.authenticatingPassword && root.failureMessage.length > 0
          text: root.failureMessage
          color: Color.lock.textError
          font.family: Style.font.family
          font.pixelSize: Style.font.heading
          font.italic: true
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
          elide: Text.ElideRight
        }
      }
    }
  }
}
