pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Arka planda komut çalıştırıp çıktısını almak için (nmcli gibi).
// Kullanım: Commands.run(["nmcli", "-t", ...], (code, out, err) => { ... })
// Çıktı her zaman İngilizce gelir (LC_ALL=C); ayrıştırması kolay olsun diye.
//
// Uygulama açmak için launch(entry[, action]) ve open(komut): oturum uwsm'le açıldıysa her uygulama
// kendi systemd biriminde başlar ("uwsm app"). desk bir servis; yeniden başlarken ya da çökerken
// açtığı uygulamalar kapanmaz, terminalde açılması gerekenler (Terminal=true) terminalde açılır.
// uwsm yoksa uygulama desk'in altında açılır (eski yol).
Singleton {
    id: root

    property bool uwsm: false

    Component.onCompleted: run(["uwsm", "check", "is-active"], code => root.uwsm = code === 0)

    function launch(entry, action) {
        if (!entry)
            return;
        if (uwsm)
            Quickshell.execDetached(["uwsm", "app", "--", entry.id + ".desktop" + (action ? ":" + action.id : "")]);
        else
            (action ?? entry).execute();
    }

    function open(command) {
        Quickshell.execDetached(uwsm ? ["uwsm", "app", "--"].concat(command) : command);
    }

    function run(command, callback) {
        const process = runner.createObject(root, {
            command: command
        });
        process.done.connect((code, out, err) => {
            if (callback)
                callback(code, out, err);
            process.destroy();
        });
        process.running = true;
    }

    // nmcli -t çıktısında alanlar ":" ile ayrılır, değerdeki ":" ve "\" önüne "\" konur.
    // "a\:b:c" → ["a:b", "c"]
    function splitTerse(line) {
        const fields = [];
        let current = "";
        for (let i = 0; i < line.length; i++) {
            const ch = line[i];
            if (ch === "\\" && i + 1 < line.length) {
                current += line[++i];
            } else if (ch === ":") {
                fields.push(current);
                current = "";
            } else {
                current += ch;
            }
        }
        fields.push(current);
        return fields;
    }

    Component {
        id: runner

        Process {
            id: process

            signal done(int code, string out, string err)

            environment: ({
                    "LC_ALL": "C"
                })
            stdout: StdioCollector {
                id: out
            }
            stderr: StdioCollector {
                id: err
            }
            // Çıktılar "exited"dan önce tamamlanıyor (Quickshell sırası)
            onExited: code => process.done(code, out.text, err.text)
        }
    }
}
