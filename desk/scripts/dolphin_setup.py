#!/usr/bin/env python3
"""Dolphin'i desk'e uydurur (bir kez çalıştırılır; tekrar çalıştırmak zararsız).

    python3 scripts/dolphin_setup.py

Renkler ve stil ayrı: scripts/apps_theme.py (duvar kâğıdı değişince çalışır).
Burada kullanım ayarları var; hepsi aşağıdaki sabitlerde. Dosyalardaki başka ayarlara dokunulmaz:

  ~/.config/kdeglobals            simge teması, çift tık, terminal (Shift+F4 → kitty)
  ~/.config/dolphinrc             açılış klasörü, önizlemeler, araç çubuğu, kenar çubuğu simgeleri,
                                  renk şeması (Desk; Dolphin'in menüsünde başka seçilmiş olsa da)
  ~/.local/share/dolphin/view_properties/global/.directory
                                  bütün klasörlerde aynı görünüm (liste, klasörler önce)
  ~/.local/share/user-places.xbel kenar çubuğu: sade yerler, gereksiz gruplar gizli
                                  (sağ tık → "Gizli Yerleri Göster" ile geri gelir)

Dolphin açıkken çalışmaz: kapanırken kendi ayarlarını yazar ve bunları ezerdi.
"""

import os
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
from urllib.parse import quote

from apps_theme import update_ini, write_if_changed

HOME = Path.home()

# ---------- Kararlar ----------
ICON_THEME = "Colloid-Dark"
VIEW_MODE = 1            # 0: simgeler, 1: ayrıntılı liste, 2: sıkışık
SINGLE_CLICK = False     # çift tıkla aç
TERMINAL = "kitty"
# Kenar çubuğunda gizlenen gruplar: Uzak (Ağ), Son kullanılanlar, Arama, Etiketler
HIDDEN_GROUPS = ["Remote", "RecentlySaved", "SearchFor", "Tags"]
# Gizlenen hazır yerler (xdg-user-dirs anahtarı)
HIDDEN_DIRS = ["DESKTOP", "MUSIC", "VIDEOS"]
# Eklenen yerler: (başlık, ev klasörüne göre yol, simge); klasör yoksa eklenmez
EXTRA_PLACES = [
    ("Projeler", "projects", "folder-development"),
    ("Veri", "Veri", "folder-documents"),
]
# Önizlemesi olan dosyalar: resim, video, PDF, belge, e-kitap, müzik kapağı, yazı tipi
# (kdegraphics-thumbnailers ve ffmpegthumbs kurulu olmalı: home.nix). Klasörün içini ve yazı
# dosyalarını gösteren önizlemeler bilerek yok: listede küçücük, karışık görünüyorlar.
PREVIEW_PLUGINS = [
    "imagethumbnail", "jpegthumbnail", "svgthumbnail", "rawthumbnail", "exrthumbnail",
    "windowsimagethumbnail", "kraorathumbnail", "ffmpegthumbs", "gsthumbnail",
    "opendocumentthumbnail", "comicbookthumbnail", "ebookthumbnail", "mobithumbnail",
    "audiothumbnail", "fontthumbnail",
]


def user_dirs():
    """~/.config/user-dirs.dirs → {"DOCUMENTS": "/home/…/Belgeler", …}"""
    dirs = {}
    try:
        for line in (HOME / ".config/user-dirs.dirs").read_text().splitlines():
            if line.startswith("XDG_") and "=" in line:
                key, value = line.split("=", 1)
                dirs[key[4:-4]] = value.strip().strip('"').replace("$HOME", str(HOME))
    except OSError:
        pass
    return dirs


def file_url(path):
    return "file://" + quote(str(path))


# ---------- Kenar çubuğu ----------
KDE = "http://www.kde.org"
FDO = "http://freedesktop.org"
NS = {"bookmark": "http://www.freedesktop.org/standards/desktop-bookmarks"}


def kde_metadata(element):
    info = element.find("info")
    if info is None:
        info = ET.SubElement(element, "info")
    for metadata in info.findall("metadata"):
        if metadata.get("owner") == KDE:
            return metadata
    return ET.SubElement(info, "metadata", owner=KDE)


def set_child(parent, tag, text):
    child = parent.find(tag)
    if child is None:
        child = ET.SubElement(parent, tag)
    child.text = text


def setup_places():
    path = HOME / ".local/share/user-places.xbel"
    if not path.exists():
        print("Kenar çubuğu: user-places.xbel yok; Dolphin'i bir kez açıp kapat, sonra yeniden çalıştır.",
              file=sys.stderr)
        return False
    ET.register_namespace("bookmark", NS["bookmark"])
    ET.register_namespace("mime", "http://www.freedesktop.org/standards/shared-mime-info")
    ET.register_namespace("kdepriv", "http://www.kde.org/kdepriv")
    try:
        tree = ET.parse(path)
    except ET.ParseError as error:
        print(f"Kenar çubuğu atlandı: {path} okunamadı ({error}).", file=sys.stderr)
        return False
    root = tree.getroot()

    meta = kde_metadata(root)
    for group in HIDDEN_GROUPS:
        set_child(meta, f"GroupState-{group}-IsHidden", "true")

    dirs = user_dirs()
    hidden_urls = {file_url(dirs[k]) for k in HIDDEN_DIRS if k in dirs}
    existing = set()
    for bookmark in root.findall("bookmark"):
        href = bookmark.get("href", "")
        existing.add(href)
        if href in hidden_urls:
            set_child(kde_metadata(bookmark), "IsHidden", "true")

    # Eklenecek yerler, Çöp'ün önüne
    trash = next((b for b in root.findall("bookmark") if b.get("href") == "trash:/"), None)
    position = list(root).index(trash) if trash is not None else len(root)
    for title, relative, icon in EXTRA_PLACES:
        folder = HOME / relative
        url = file_url(folder)
        if not folder.is_dir() or url in existing:
            continue
        bookmark = ET.Element("bookmark", href=url)
        ET.SubElement(bookmark, "title").text = title
        info = ET.SubElement(bookmark, "info")
        fdo = ET.SubElement(info, "metadata", owner=FDO)
        ET.SubElement(fdo, f"{{{NS['bookmark']}}}icon", name=icon)
        kde = ET.SubElement(info, "metadata", owner=KDE)
        ET.SubElement(kde, "ID").text = f"desk/{relative}"
        root.insert(position, bookmark)
        position += 1

    ET.indent(tree, space=" ")
    text = '<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE xbel>\n' + ET.tostring(root, encoding="unicode") + "\n"
    return write_if_changed(path, text)


def dolphin_running():
    # NixOS'ta süreç adı ".dolphin-wrapped" (15 harfe kısaltılmış: ".dolphin-wrappe")
    found = subprocess.run(["pgrep", "-x", "-u", str(os.getuid()), r"\.?dolphin(-wrapped?)?"],
                           capture_output=True)
    return found.returncode == 0


def main():
    if dolphin_running():
        print("Dolphin açık, ayarları atlandı (kapanırken ezerdi): Dolphin'i kapatıp yeniden çalıştır "
              "ya da bir sonraki updatenix'te yapılır.", file=sys.stderr)
        return 1

    changed = []

    def ini(path, groups):
        if update_ini(path, groups):
            changed.append(path)

    ini(HOME / ".config/kdeglobals", {
        "Icons": {"Theme": ICON_THEME},
        "KDE": {"SingleClick": "true" if SINGLE_CLICK else "false"},
        "General": {"TerminalApplication": TERMINAL, "TerminalService": f"{TERMINAL}.desktop"},
    })
    ini(HOME / ".config/dolphinrc", {
        "General": {
            "GlobalViewProps": "true",          # her klasörde aynı görünüm
            "RememberOpenedTabs": "false",      # her açılışta ev klasörü
            "ShowZoomSlider": "false",          # büyütme: Ctrl + tekerlek
            "BrowseThroughArchives": "true",    # zip'in içine klasör gibi girilir
            "UseTabForSwitchingSplitView": "true",
            "ConfirmClosingMultipleTabs": "false",
        },
        "UiSettings": {"ColorScheme": "Desk"},  # renkler: apps_theme.py (Dolphin'in menüsündeki seçimi ezer)
        "PreviewSettings": {"Plugins": ",".join(PREVIEW_PLUGINS), "MaximumRemoteSize": "0"},
        "DetailsMode": {"PreviewSize": "22", "ExpandableFolders": "true"},
        "IconsMode": {"PreviewSize": "80"},
        "PlacesPanel": {"IconSize": "16"},     # kenar çubuğu Finder gibi küçük simgeli
        "MainWindow][Toolbar mainToolBar": {"ToolButtonStyle": "IconOnly"},  # araç çubuğunda yazı yok
    })
    ini(HOME / ".local/share/dolphin/view_properties/global/.directory", {
        "Dolphin": {
            "ViewMode": str(VIEW_MODE),
            "SortFoldersFirst": "true",
            "PreviewsShown": "true",
            "VisibleRoles": "Details_text,Details_size,Details_modificationtime",
            "Version": "4",
            "Timestamp": "2026,11,19,12,0,0.000",
        },
        "Settings": {"HiddenFilesShown": "false"},
    })
    if setup_places():
        changed.append(HOME / ".local/share/user-places.xbel")
    if changed:
        print("Dolphin ayarlandı (açınca görünür):", *(f"  {p}" for p in changed), sep="\n", file=sys.stderr)
    else:
        print("Dolphin zaten ayarlı.", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
