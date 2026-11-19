pragma Singleton

import QtQuick
import Quickshell

// Yazı tipleri ve boyutlar
Singleton {
    readonly property string family: "Inter"
    readonly property string mono: "JetBrains Mono"

    readonly property int small: 12   // ikincil bilgiler, klavye dili
    readonly property int bar: 14     // üst bar
    readonly property int body: 14
    readonly property int title: 16
}
