pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Ses: varsayılan çıkışın düzeyi ve mikrofonun kullanılıp kullanılmadığı
Singleton {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false

    readonly property string icon: {
        if (muted || volume <= 0.001)
            return "volume-x";
        if (volume < 0.34)
            return "volume-0";
        if (volume < 0.67)
            return "volume-1";
        return "volume-2";
    }

    // Bir uygulama mikrofonu dinliyor mu? Bir uygulamanın kayıt akışına giden
    // etkin bir bağlantı varsa evet.
    //  - Kayıt akışı: akış (isStream) ama ses çalan değil (isSink değil)
    //  - Kaynak bir hoparlör çıkışı (isSink) olmamalı; yoksa ses görselleştiriciler
    //    de mikrofon sayılırdı
    //  - EasyEffects'in kendi akışları sayılmaz; yoksa mikrofon efektleri açıkken
    //    nokta hiç sönmezdi
    // Not: node.type yerine isStream/isSink kullanılıyor; type QML'de güvenilir
    // biçimde karşılaştırılamıyor.
    readonly property var micStreams: {
        const list = [];
        for (const group of Pipewire.linkGroups.values) {
            const source = group.source;
            const target = group.target;
            if (group.state === PwLinkState.Active
                    && target !== null && target.isStream && !target.isSink
                    && source !== null && !source.isSink
                    && !/easyeffects|^ee_/i.test(target.name)
                    && !list.includes(target))
                list.push(target);
        }
        return list;
    }
    readonly property bool micInUse: micStreams.length > 0

    // Mikrofonu kullanan uygulamaların adları ("Telegram" gibi; kontrol merkezinde yazar)
    readonly property var micApps: {
        const names = [];
        for (const node of micStreams) {
            const name = (node.properties ?? {})["application.name"] || nodeName(node);
            if (name && !names.includes(name))
                names.push(name);
        }
        return names;
    }

    // --- Çıkış aygıtları (kontrol merkezindeki "Ses" başlığı ve listesi)
    // Ses çalınabilen aygıtlar: donanım ve sanal çıkışlar (EasyEffects gibi)
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio !== null)

    function nodeName(node) {
        return node?.nickname || node?.description || node?.name || "";
    }

    // EasyEffects varsayılan çıkışsa ses önce ondan geçer; asıl aygıt onun bağlı olduğu donanım
    readonly property bool throughEasyEffects: /easyeffects/i.test(sink?.name ?? "")
    readonly property var outputDevice: {
        if (!throughEasyEffects)
            return sink;
        const group = Pipewire.linkGroups.values.find(g => g.source !== null && /easyeffects|^ee_/i.test(g.source.name)
                && g.target !== null && g.target.isSink && !g.target.isStream);
        return group?.target ?? sink;
    }
    readonly property string outputName: nodeName(outputDevice)

    function setOutput(node) {
        Pipewire.preferredDefaultAudioSink = node;
    }

    // --- Giriş (mikrofon)
    readonly property var source: Pipewire.defaultAudioSource
    readonly property real inputVolume: source?.audio?.volume ?? 0
    readonly property bool inputMuted: source?.audio?.muted ?? false
    // Kayıt yapılabilen aygıtlar: mikrofonlar ve sanal girişler (EasyEffects gibi)
    readonly property var sources: Pipewire.nodes.values.filter(n => !n.isSink && !n.isStream && n.audio !== null)

    function setInput(node) {
        Pipewire.preferredDefaultAudioSource = node;
    }
    function setInputVolume(value) {
        if (!source?.audio)
            return;
        source.audio.muted = false;
        source.audio.volume = Math.max(0, Math.min(1, value));
    }
    function toggleInputMute() {
        if (source?.audio)
            source.audio.muted = !source.audio.muted;
    }

    // --- Uygulamalar: şu an ses çalan programlar (her birinin kendi düzeyi var).
    // Quickshell'de uygulamanın çalma akışı hem "akış" hem "sink" sayılıyor.
    readonly property var appStreams: Pipewire.nodes.values.filter(n => n.isStream && n.isSink && n.audio !== null
            && !/easyeffects|^ee_/i.test(n.name))

    function appName(node) {
        const props = node?.properties ?? {};
        return props["application.name"] || nodeName(node);
    }
    function appDetail(node) {
        const props = node?.properties ?? {};
        return props["media.name"] || "";
    }

    // Düzeyleri ve adları okunabilsin diye uygulama akışları da izlenir
    PwObjectTracker {
        objects: root.appStreams
    }

    function toggleMute() {
        if (sink?.audio)
            sink.audio.muted = !sink.audio.muted;
    }

    // value: 0..1
    function setVolume(value) {
        if (!sink?.audio)
            return;
        sink.audio.muted = false;
        sink.audio.volume = Math.max(0, Math.min(1, value));
    }

    // Sesi değiştir (delta: 0.05 = %5). Başka bir program sesi %100'ün üstüne
    // çıkardıysa yukarı kaydırmak onu %100'e düşürmesin diye üst sınır en az mevcut düzey.
    function changeVolume(delta) {
        if (!sink?.audio)
            return;
        const limit = Math.max(1, volume);
        sink.audio.muted = false;
        sink.audio.volume = Math.min(Math.max(volume + delta, 0), limit);
    }

    // Ses düzeyi ve sessiz durumu okunabilsin diye çıkış ve giriş izleniyor
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }
    // Bağlantıların durumu (etkin / duraklatılmış) yalnızca izlenen bağlantılar
    // için güncelleniyor; izlenmeyen bağlantı her zaman "bağlı değil" görünür.
    // Mikrofon noktasının hiç yanmamasının asıl nedeni buydu.
    PwObjectTracker {
        objects: Pipewire.linkGroups.values
    }

    // Mikrofonu kullanan uygulamanın adı da yalnızca izlenen akışlarda okunabiliyor
    PwObjectTracker {
        objects: root.micStreams
    }
}
