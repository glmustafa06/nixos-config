#!/usr/bin/env python3
"""Giriş ekranı (SDDM, desk/sddm) için duvar kâğıdı ve kişi resmi.

SDDM kendi kullanıcısıyla çalışır, ev klasörünü okuyamaz. desk ona gerekenleri ortak bir klasöre koyar:

  /var/lib/desk/login.jpg                 duvar kâğıdının bulanık, karartılmış hâli (kilit ekranıyla aynı:
                                          aynı bulanıklık, colors.json'daki lockDim kadar karartma)
  /var/lib/desk/avatar-<kullanıcı>.png    ~/.face varsa; yoksa giriş ekranı adın baş harfini gösterir

Klasörü sistem kurar (desk/nix/nixos.nix → systemd.tmpfiles; sahibi bu kullanıcı, herkes okuyabilir).
colors.sh duvar kâğıdı değişince çağırır; updatenix'te de bir kez çalışır (desk/nix/home.nix).

    python3 scripts/login_screen.py [resim]      # resim yoksa: ~/.local/state/desk/wallpaper.json
"""

import getpass
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

SHARED = Path(os.environ.get("DESK_SHARED", "/var/lib/desk"))
STATE = Path.home() / ".local/state/desk"
SIZE = "960x540"          # ekranın dörtte biri: bulanık resim büyütülünce yumuşak görünür (kilit de böyle)
BLUR = "0x7"
# Colors.qml → lockDim: ölçülmemişse güvenli değer, ölçülmüşse sınırlar içinde
DIM_SAFE, DIM_MIN = 0.45, 0.30


def magick():
    for name in ("magick", "convert"):
        if shutil.which(name):
            return [name]
    return None


def current_wallpaper():
    try:
        return json.loads((STATE / "wallpaper.json").read_text()).get("path") or None
    except (OSError, ValueError):
        return None


def lock_dim():
    try:
        dim = float(json.loads((STATE / "colors.json").read_text()).get("lockDim", 0))
    except (OSError, ValueError, TypeError):
        dim = 0
    return min(max(dim, DIM_MIN), DIM_SAFE) if dim > 0 else DIM_SAFE


def write_image(tool, args, target):
    """Önce geçici dosyaya, sonra yerine: giriş ekranı yarım dosya görmesin."""
    temp = target.with_name(f".{target.name}.tmp{target.suffix}")
    result = subprocess.run(tool + args + [str(temp)], capture_output=True, text=True)
    if result.returncode != 0:
        temp.unlink(missing_ok=True)
        print(f"login_screen: {target.name} yazılamadı: {result.stderr.strip()}", file=sys.stderr)
        return False
    temp.chmod(0o644)
    os.replace(temp, target)
    return True


def main():
    if not SHARED.is_dir() or not os.access(SHARED, os.W_OK):
        print(f"login_screen: {SHARED} yok ya da yazılamıyor (desk/nix/nixos.nix etkin mi?); atlandı",
              file=sys.stderr)
        return 0
    tool = magick()
    if tool is None:
        print("login_screen: ImageMagick yok; atlandı", file=sys.stderr)
        return 0

    image = sys.argv[1] if len(sys.argv) > 1 else current_wallpaper()
    if image and Path(image).is_file():
        dim = lock_dim()
        write_image(tool, [image + "[0]", "-auto-orient", "-resize", SIZE + "^", "-gravity", "center",
                           "-extent", SIZE, "-blur", BLUR, "-modulate", "100,110",
                           "-fill", "black", "-colorize", f"{round(dim * 100)}%", "-quality", "92"],
                    SHARED / "login.jpg")
    else:
        print("login_screen: duvar kâğıdı bulunamadı; giriş ekranı düz renk kalır", file=sys.stderr)

    avatar = SHARED / f"avatar-{getpass.getuser()}.png"
    face = Path.home() / ".face"
    if face.is_file():
        write_image(tool, [str(face) + "[0]", "-auto-orient", "-resize", "256x256^", "-gravity", "center",
                           "-extent", "256x256"], avatar)
    else:
        avatar.unlink(missing_ok=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
