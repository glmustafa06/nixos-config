// desk — kilit ekranı (ayrı bir Quickshell örneği)
//
// Bar ve dock'un çalıştığı örnekten ayrı çalışır: desk düzenlenirken ya da çökerken kilit
// etkilenmez. Kilit açılınca program kapanır. Elle denemek için:
//     qs -n -p ~/.config/quickshell/desk/lock.qml
// Normalde hypridle açar: `loginctl lock-session` (Super+Esc, kapak, uykudan önce, boşta kalınca).
// Kurtarma (kilit çökerse ekran düz renkte kalır): plan → Sorun 26.
import QtQuick
import Quickshell
import qs.modules.lock

ShellRoot {
    // Kilitliyken dosya değişince yeniden yüklenmesin: yarım kalmış bir düzenleme kilidi bozmasın
    Component.onCompleted: Quickshell.watchFiles = false

    LockScreen {}
}
