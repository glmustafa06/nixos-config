import QtQuick
import qs.theme

// Bardaki yazıların ortak biçimi
Text {
    color: Colors.barText // duvar kâğıdına göre açık ya da koyu
    font.family: Typography.family
    font.pixelSize: Typography.bar
    font.weight: Font.Medium
    font.features: { "tnum": 1 } // rakamlar eşit genişlikte: saat değişirken yazı kaymaz
    renderType: Text.NativeRendering
}
