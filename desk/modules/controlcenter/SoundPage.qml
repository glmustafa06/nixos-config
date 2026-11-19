import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.theme
import qs.components
import qs.services

// Ayrıntılı ses menüsü: çıkış düzeyi ve aygıtı, mikrofon düzeyi ve aygıtı, uygulama başına ses.
ColumnLayout {
    id: root

    required property var center

    readonly property bool hasEasyEffects: AudioStatus.sinks.some(n => /easyeffects/i.test(n.name))

    spacing: 8

    function deviceName(node) {
        return /easyeffects/i.test(node.name) ? "EasyEffects (efektli)" : AudioStatus.nodeName(node);
    }

    PageHeader {
        Layout.fillWidth: true
        title: "Ses"
        showBack: root.center.canGoBack
        onBack: root.center.back()
    }

    Flickable {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, 720)
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: content
            width: parent.width
            spacing: 8

            // Listeler ScriptModel'le: bir uygulama ses çalmaya başlayınca ya da bir aygıt
            // takılınca bütün satırlar baştan kurulmaz, yalnızca değişen satır eklenir/çıkar.

            // ---------- Çıkış ----------
            SectionTitle {
                text: "Çıkış"
            }

            Tile {
                Layout.fillWidth: true
                padding: 10

                ColumnLayout {
                    width: parent.width
                    spacing: 6

                    Slider {
                        Layout.fillWidth: true
                        Layout.margins: 2
                        icon: AudioStatus.icon
                        value: AudioStatus.muted ? 0 : AudioStatus.volume
                        onMoved: value => AudioStatus.setVolume(value)
                    }

                    Repeater {
                        model: ScriptModel {
                            values: AudioStatus.sinks
                        }

                        delegate: ListRow {
                            required property var modelData

                            Layout.fillWidth: true
                            implicitHeight: 38
                            icon: /head/i.test(AudioStatus.nodeName(modelData)) ? "headphones" : "speaker"
                            title: root.deviceName(modelData)
                            active: modelData === AudioStatus.sink
                            checked: modelData === AudioStatus.sink
                            onClicked: AudioStatus.setOutput(modelData)
                        }
                    }
                }
            }

            // EasyEffects kuruluysa: sesin nereden geçtiği ve EasyEffects'i açma düğmesi
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 8
                visible: root.hasEasyEffects
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: AudioStatus.throughEasyEffects ? `Ses EasyEffects'ten geçip ${AudioStatus.outputName} aygıtına gidiyor.` : "EasyEffects seçili değil; ses efektleri devre dışı."
                    color: Colors.textFaint
                    font.family: Typography.family
                    font.pixelSize: Typography.small
                    wrapMode: Text.WordWrap
                }
                TextButton {
                    text: "EasyEffects"
                    onClicked: {
                        root.center.close();
                        Commands.open(["easyeffects"]);
                    }
                }
            }

            // ---------- Giriş ----------
            SectionTitle {
                text: "Giriş (mikrofon)"
            }

            Tile {
                Layout.fillWidth: true
                padding: 10

                ColumnLayout {
                    width: parent.width
                    spacing: 6

                    Slider {
                        Layout.fillWidth: true
                        Layout.margins: 2
                        icon: "mic"
                        value: AudioStatus.inputMuted ? 0 : AudioStatus.inputVolume
                        onMoved: value => AudioStatus.setInputVolume(value)
                    }

                    Repeater {
                        model: ScriptModel {
                            values: AudioStatus.sources
                        }

                        delegate: ListRow {
                            required property var modelData

                            Layout.fillWidth: true
                            implicitHeight: 38
                            icon: "mic"
                            title: root.deviceName(modelData)
                            active: modelData === AudioStatus.source
                            checked: modelData === AudioStatus.source
                            onClicked: AudioStatus.setInput(modelData)
                        }
                    }
                }
            }

            // ---------- Uygulamalar ----------
            SectionTitle {
                text: "Uygulamalar"
            }

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 8
                visible: AudioStatus.appStreams.length === 0
                text: "Şu an ses çalan uygulama yok."
                color: Colors.textFaint
                font.family: Typography.family
                font.pixelSize: Typography.small
            }

            Tile {
                Layout.fillWidth: true
                visible: AudioStatus.appStreams.length > 0
                padding: 12

                ColumnLayout {
                    width: parent.width
                    spacing: 12

                    Repeater {
                        model: ScriptModel {
                            values: AudioStatus.appStreams
                        }

                        delegate: ColumnLayout {
                            id: app

                            required property var modelData

                            Layout.fillWidth: true
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Text {
                                    text: AudioStatus.appName(app.modelData)
                                    color: Colors.text
                                    font.family: Typography.family
                                    font.pixelSize: Typography.small + 1
                                    font.weight: Font.DemiBold
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: AudioStatus.appDetail(app.modelData)
                                    color: Colors.textFaint
                                    font.family: Typography.family
                                    font.pixelSize: Typography.small
                                    elide: Text.ElideRight
                                }
                            }

                            Slider {
                                Layout.fillWidth: true
                                implicitHeight: 22
                                icon: app.modelData.audio?.muted ? "volume-x" : "volume-2"
                                value: app.modelData.audio?.muted ? 0 : (app.modelData.audio?.volume ?? 0)
                                onMoved: value => {
                                    if (!app.modelData.audio)
                                        return;
                                    app.modelData.audio.muted = false;
                                    app.modelData.audio.volume = value;
                                }
                            }
                        }
                    }
                }
            }

        }
    }
}
