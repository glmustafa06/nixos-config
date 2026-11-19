pragma Singleton

import QtQuick
import Quickshell

// Dosya adından simge adı (İndirilenler menüsü ve aramadaki dosyalar)
Singleton {
    // Dosya türüne göre simge adı (simge temasındaki genel türler)
    function iconFor(name, isDir) {
        if (isDir)
            return "folder";
        const match = name.match(/\.([^.]+)$/);
        const ext = (match ? match[1] : "").toLowerCase();
        if (["png", "jpg", "jpeg", "gif", "webp", "svg", "bmp", "heic", "avif"].includes(ext))
            return "image-x-generic";
        if (["mp4", "mkv", "webm", "mov", "avi"].includes(ext))
            return "video-x-generic";
        if (["mp3", "flac", "ogg", "wav", "m4a", "opus"].includes(ext))
            return "audio-x-generic";
        if (ext === "pdf")
            return "application-pdf";
        if (["zip", "tar", "gz", "xz", "zst", "7z", "rar", "bz2"].includes(ext))
            return "package-x-generic";
        if (["doc", "docx", "odt", "rtf"].includes(ext))
            return "x-office-document";
        if (["xls", "xlsx", "ods", "csv"].includes(ext))
            return "x-office-spreadsheet";
        if (["ppt", "pptx", "odp"].includes(ext))
            return "x-office-presentation";
        if (["iso", "img"].includes(ext))
            return "media-optical";
        return "text-x-generic";
    }
}
