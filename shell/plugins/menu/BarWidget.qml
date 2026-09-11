import QtQuick
import qs.Ui

BarWidget {
  id: root
  moduleName: "hexarchy.menu"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\ue900"
    fontFamily: "hexarchy"
    horizontalMargin: 7.5
    onPressed: function(button) {
      if (!root.bar) return
      if (button === Qt.RightButton) root.bar.run("xdg-terminal-exec")
      else root.bar.run("hexarchy-shell shell toggle hexarchy.menu '{\"menu\":\"root\"}'")
    }
  }
}
