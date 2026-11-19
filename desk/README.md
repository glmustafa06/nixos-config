# desk

Hyprland 0.57 + Quickshell 0.3 üzerinde, macOS'un üst barından ilham alan kendi masaüstü shell'im.

## Kurulum ve çalıştırma

desk `~/nixos-config/desk`'te durur ve Nix modülleriyle kurulur (`nix/`):

- `nix/home.nix` (Home Manager; `home.nix`'te `imports` ve `desk.enable = true`): desk'in kullandığı programlar,
  `~/.config/quickshell/desk` → desk'in klasörü (`desk.source`), pano geçmişi (cliphist), `desk` ve `hypridle`
  servisleri, ilk kurulum (kitty.conf'a `include`, `scripts/apps_theme.py`, `scripts/dolphin_setup.py`; her
  updatenix'te eksik olanı tamamlar).
- `nix/nixos.nix` (`flake.nix` → modules, `configuration.nix`'te `desk.enable = true`): kilit ekranının şifre
  denetimi (PAM), giriş ekranı teması ve `/var/lib/desk`, pil (upower), güç modu, yazı tipleri (Inter, JetBrains Mono).

desk grafik oturumla başlayan bir servis; çökerse 2 sn sonra kendini açar. Kod Nix deposuna kopyalanmaz:
bir `.qml` dosyasını kaydettiğin an desk kendini yeniler.

```
journalctl --user -u desk -f          # hatalar, uyarılar
systemctl --user restart desk         # yeniden başlat
systemctl --user stop desk            # durdur; elle denemek için: qs -c desk
```

Uygulamalar (dock, arama, uygulama menüsü) `uwsm app` ile kendi birimlerinde açılır: desk yeniden başlarken
kapanmazlar; terminalde açılması gerekenler (btop, nvim) kitty'de açılır (`xdg-terminal-exec`).

Kilit ekranı ayrı bir örnektir (`lock.qml`); normalde hypridle açar. Ekranı kilitlemeden denemek için:

```
DESK_LOCK_TEST=1 qs -p ~/.config/quickshell/desk/lock.qml
```

Aynı görünüm sıradan bir pencerede açılır; doğru şifre ya da boşken Esc kapatır.

## Renkler

```
scripts/colors.sh ~/Pictures/duvar-kagidi.jpg
```

Duvar kâğıdından şunları üretir:

- vurgu rengi (matugen),
- barın görünümü: duvar kâğıdının üst şeridi açıksa bar koyu yazıya geçer (`scripts/bar_tone.py`, ImageMagick gerekir),
- kilit ekranında duvar kâğıdının ne kadar karartılacağı (`lockDim`),
- kitty ve Dolphin'in renkleri (`scripts/apps_theme.py`, aşağıda).

Pencerelerde kenarlık yok; odaktaki pencere, ötekiler hafifçe karardığı için belli olur
(`hypr/config/appearance.lua` → `dim_inactive`).

Yüzeyler sabit (Grafit). Duvar kâğıdı Super+W ile seçilince betik kendiliğinden çalışır; elle çalıştırmak
yalnızca başka yoldan değiştirince gerekir.

## Bar

- Solda logo, uygulamanın adı ve menüleri; ortada ada (çalışma alanı noktaları, düzen simgesi — adı üstüne gelince
  açılır —, çalarken kapak ve dalga); sağda macOS'taki sırayla, gruplar arasında biraz boşlukla:
  tepsi · klavye dili · Bluetooth, ses, pil, Wi-Fi · arama, kontrol merkezi · tarih ve saat.
- Bardaki simgeler tek renk ve aynı kalınlıkta (`Metrics.barIconSize`, `barIconStroke`). Tepsi simgeleri gri tonlu;
  üstüne gelince ya da menüsü açıkken kendi renkleri. Mikrofon kullanılıyorsa kontrol merkezi simgesinin yanında
  turuncu nokta.
- Cam yüzeylerin (menüler, kontrol merkezi, bildirim merkezi, arama, dock) üst kenarında ince bir ışık var
  (`components/GlassEdge.qml`); yazıların altına girmez.

## Dock

- Sabitlenenler `~/.local/state/desk/dock.json` dosyasında; dock'ta sağ tık → **Dock'ta tut** ile değişir.
- Açık bir uygulamaya tıklayınca penceresine gider; birden çok penceresi varsa her tıklamada sıradakine geçer.
  Orta tık her zaman yeni pencere açar. Sağ tıkta pencere listesi, uygulamanın eylemleri ve kapatma var.
- Bu alandaki bir pencere dock'un yerine girince gizlenir; fare ekranın alt kenarına gelince çıkar.
- Sağ tık menüsü ve ad etiketi dock'un kendi penceresinde çizilir (ayrı pencerede menüye tıklanamıyordu, plan: Sorun 62).
- Açık uygulamaların altında nokta; odaktaki uygulamanınki vurgu renginde kısa bir hap. Altında yumuşak bir gölge.
- Uygulama simgeleri Colloid temasından (`shell.qml` → `//@ pragma IconTheme Colloid-Dark`;
  NixOS'ta `home.nix` → `colloid-icon-theme`).

## Arama

Super+Boşluk, bardaki logo ya da büyüteç açar.

- Uygulamalar, ayarlar ("wifi", "ses", "pil" kontrol merkezinin sayfasını açar) ve hızlı işlemler ("gece ışığı",
  "kilitle", "uyku", "güç modu", "düzen"). Yeniden başlatma ve kapatma onay isteyen güç sayfasını açar.
- Hesap makinesi: işlem yazınca sonuç çıkar (`2+3*4`, `sqrt(2)`, `5!`, `80'in %15'i`); Enter sonucu kopyalar.
- Dosyalar: `/` ile başla (`/vize`); ev klasöründe `fd` ile aranır. Enter açar, Ctrl+Enter klasöründe gösterir.
- Harf atlayarak ve Türkçe harflere duyarsız eşleşir; sık açtıkların öne geçer (`~/.local/state/desk/search.json`).
- Esc önce yazıyı siler, sonra kapatır.

## Bildirimler

desk bir bildirim sunucusudur (`services/Notifications.qml`). Sistemde tek sunucu olabilir: dunst, mako
gibi başka bir bildirim programı çalışmamalı. Kontrol: `busctl --user status org.freedesktop.Notifications`.

- Bildirim adada ~5 sn görünür; fare üstündeyken bekler. Ardışık gelenler sırayla gösterilir (sırada en çok 3;
  fazlası yalnızca merkezde kalır), sonra ada müziğe döner.
- Tıklayınca uygulamanın kendi eylemi çalışır (yoksa penceresine gidilir). Destekleyen uygulamalarda **Yanıtla**
  ile yanıt adanın içinde yazılır; Enter gönderir, Esc ya da dışarı tıklamak bırakır. **Sustur** o uygulamayı
  1 saat adada göstermez (merkezde görünür; merkezde "Susturuldu · aç" ile geri açılır).
- Acil bildirimler kapatılana kadar kalır ve rahatsız etme modunu deler. Rahatsız etme açıkken ya da tam ekran bir
  pencere odaktayken bildirimler adaya çıkmaz, doğrudan merkeze gider; barda saatin önünde ay görünür.
- Bildirim merkezi: saate tıkla (ya da `qs ipc -c desk call notifications toggle`). Üstte ay takvimi,
  altında uygulamaya göre gruplu bildirimler. Gruba tıklayınca açılır; tek bildirime tıklayınca uygulamaya gidilir.
  Üstüne gelince çıkan × siler (kapalı grupta bütün grubu).
- Geçmiş `~/.local/state/desk/notifications.json` dosyasında saklanır (son 50); ses yok.
- Pil %20 ve %10'da uyarır (tıklayınca tasarruf modu), %5'te acil uyarır; şarja takınca uyarı adadan kalkar.
- Rahatsız etme: kontrol merkezinden ya da `… call notifications dnd`.

## Kilit ekranı

Super+Esc, kapak, uykudan önce ve boşta kalınca. Hepsi `loginctl lock-session` der; hypridle da
`lock.qml`'i açar (`~/nixos-config/hypr/hypridle.conf`). Kilit, bar ile dock'un çalıştığı örnekten ayrıdır:
desk düzenlenirken ya da çökerken etkilenmez, kilitliyken dosya değişikliğiyle yeniden yüklenmez.

- Üstte tarih ve saat, çalıyorsa müzik; altta şifre. Yanlış şifrede kutu sallanır; Caps Lock açıksa yazar.
- Sağ altta uyku, yeniden başlat ve kapat (son ikisi iki kez basınca).
- Şifre PAM ile doğrulanır: `/etc/pam.d/desk-lock` (`configuration.nix` → `security.pam.services.desk-lock`);
  yoksa ya da hata verirse sistemin giriş ayarı (`login`).
- Arka plan duvar kâğıdının bulanık hâli. Ne kadar karartılacağını `colors.sh` ölçer (beyaz yazılar okunsun
  diye; `lockDim`), ölçülmemişse bembeyaz duvar kâğıdında bile okunan değer kullanılır.
- Kişi resmi: `~/.face` (varsa).
- Boşta (hypridle + `hypr/scripts/idle.sh`): pilde 3 dk karartır, 5 dk kilitler ve ekranı kapatır, 15 dk uyutur;
  prizde 10 dk karartır, 15 dk kilitler ve ekranı kapatır. Video oynarken hiçbiri olmaz.
- Kilit çökerse Hyprland düz renkli bir ekran gösterir; kurtarma: plan → Sorun 26.

## Giriş ekranı (SDDM)

Kilit ekranıyla aynı: bulanık duvar kâğıdı, tarih ve saat, kişi ve şifre kutusu, sağ altta uyku/yeniden
başlat/kapat, sol altta oturum seçici (varsayılan Hyprland (UWSM)), sağ üstte klavye düzeni.

- Tema `sddm/` (Qt 6, kendi başına; desk'in parçalarını kullanamaz). `nix/nixos.nix` kurar
  (`desk.loginScreen`, varsayılan açık); temanın kendisinde değişiklik updatenix ister.
- SDDM ev klasörünü okuyamaz: duvar kâğıdının bulanık, karartılmış hâli ve kişi resmi (`~/.face`)
  `/var/lib/desk`'e konur (`scripts/login_screen.py`; duvar kâğıdı değişince colors.sh, ayrıca her updatenix).
- Çıkış yapmadan denemek: `sddm-greeter-qt6 --test-mode --theme /run/current-system/sw/share/sddm/themes/desk`

## Duvar kâğıdı

Super+W (ya da aramada "duvar"): ekranın ortasında bir ızgara. Tıklayınca yumuşak bir geçişle değişir; renkler ve
barın görünümü kendiliğinden güncellenir (`scripts/colors.sh`).

- Seçim `~/.local/state/desk/wallpaper.json` dosyasında. Klasör: oradaki `"directory"` yazılıysa o; yoksa şu anki
  duvar kâğıdının klasörü; o da yoksa Resimler'deki "Duvar Kağıtları" ya da "Wallpapers".
- Seçici açmadan: `qs ipc -c desk call wallpaper set /yol/resim.jpg`

## Pano

Super+V aramayı pano geçmişiyle açar (kontrol merkezindeki "Pano" da). Kopyalananları cliphist kaydeder
(`home.nix` → `services.cliphist`). Yazınca süzülür; Enter kopyalar, Delete siler (imleç yazının sonundayken).
En çok 8 satır görünür, gerisi oklarla ve tekerlekle kayar. Resimlerin küçük hâli `$XDG_RUNTIME_DIR` içinde
(bellekte; kapanınca silinir).

## Ekran görüntüsü

Print: alan seç; Shift+Print: bütün ekran (`scripts/screenshot.sh`). Resim panoya kopyalanır ve
Resimler/Ekran görüntüleri'ne kaydedilir; bildirimine tıklayınca açılır.

## Uygulamalar: kitty ve Dolphin

`scripts/apps_theme.py` (colors.sh sonunda çalışır) desk'in görünümünü uygulamalara yazar:

- kitty: `~/.config/kitty/desk-colors.conf` (`kitty.conf`'un sonunda `include desk-colors.conf`).
  - Yazı tipi, boşluklar, imleç, sekmeler: `theme/kitty/settings.conf` (JetBrains Mono 11.5, satır aralığı %110,
    ince imleç ve kısa iz, üstte sade sekmeler, seçilen yazı orta tıkla yapıştırılır).
  - Renkler: koyu buzlu cam zemin (%80 örtücü, Hyprland bulanıklaştırır), vurgu imleçte ve seçimde.
  - Açık pencereler renk değişince kendiliğinden yenilenir; saydamlık ve yazı tipi yeni pencerelerde.
  - İstem (prompt): Starship (`home.nix` → `programs.starship`): klasör, git, Python ortamı, süre, hata kodu.
- Dolphin'in görünüşü (renk değişince Dolphin yeniden açılınca güncellenir):
  - Kvantum teması `~/.config/Kvantum/Desk` (KvMojave'den uyarlandı; şablonlar `theme/kvantum/`); seçili Kvantum
    teması da Desk yapılır. Finder gibi: kenar çubuğu buzlu cam, dosya alanı opak, seçim vurgunun koyu tonunda
    (üstündeki yazı her vurguda okunur), köşeler yuvarlak, odak çizgisi yok, klasör okları ince.
  - Renk şeması `~/.local/share/color-schemes/Desk.colors` ve `~/.config/kdeglobals` (stil `kvantum`, şema Desk;
    dosyadaki başka ayarlar kalır). Plasma dışında KDE programları stili ve renk şemasını buradan okur, qt6ct'yi
    dinlemez; yazılı değilse Breeze'e döner.
- Dolphin'in kullanımı: `scripts/dolphin_setup.py` (updatenix'te kendiliğinden; Dolphin açıksa o sefer atlanır,
  elle de çalıştırılabilir, tekrar çalıştırmak zararsız).
  Kararlar betiğin başındaki sabitlerde:
  - ayrıntılı liste, klasörler önce, klasörler `›` ile yerinde açılır; her klasörde aynı görünüm
  - Colloid-Dark simgeleri, çift tıkla açma, araç çubuğunda yalnızca simgeler (büyütme: Ctrl + tekerlek)
  - kenar çubuğu: Ev, Belgeler, İndirilenler, Resimler, Projeler, Veri, Çöp, diskler; Masaüstü, Müzik, Videolar,
    Ağ, Son kullanılanlar, Arama, Etiketler gizli (sağ tık → "Gizli Yerleri Göster")
  - önizlemeler: resim, video, PDF, belge, e-kitap (`home.nix`: kdegraphics-thumbnailers, ffmpegthumbs, kimageformats)
  - Shift+F4: bulunduğun klasörde kitty; zip dosyalarının içine klasör gibi girilir; her açılışta ev klasörü
- 16 terminal rengi ve Dolphin'in yazıları (seçim dâhil) arkada beyaz sayfa varken de okunur; `scripts/contrast.py` denetler.

## Bluetooth eşleşme

Kontrol merkezi → Bluetooth → Yakındaki cihazlar: tıklayınca eşleşir, güvenilir işaretlenir ve bağlanır.
Cihaz bir şey isterse soru Bluetooth sayfasının üstünde çıkar (kontrol merkezi kapalıysa o sayfada açılır):

- kod onayı ("033 412 · Eşleştir"; telefonda da aynı kod görünmeli), PIN ya da 6 haneli kod yazma,
  klavyede yazılacak kodu gösterme, eşleşme ya da bağlantı izni (eşleşmiş cihazlara sorulmaz).
- Bunu `scripts/bt_agent.py` yapar: BlueZ'e eşleşme yardımcısı (agent) olarak kaydolur, soruları desk'e iletir
  (Python + dbus-next; `nix/home.nix` → `DESK_PYTHON`). Yardımcı olmadan onay isteyen cihazlar ya hiç eşleşmiyor
  ya da anahtar saklanmadan yarım eşleşiyordu (plan: Sorun 52, 79).
- bluetoothctl açıkken onun yardımcısı öne geçer; sorular oraya gider. Kapatınca desk'e döner.
- Eşleşirken çevredeki cihaz araması durur (arama sürerken bağlantı "meşgul" hatası veriyor), sonra sürer.

## Pilde

Fiş çekilince (3 sn bekledikten sonra) ekran 60 Hz'e iner, bulanıklık tek geçişe düşer, animasyonlar %20 kısalır;
takınca geri gelir. desk Hyprland'e söyler (`services/Theming.qml` → `hypr/config/desk.lua` → `desk.set_power`).
Hz değişirken ekran bir an kararabilir.

## Tasarım kuralları

**Okunabilirlik.** Cam yüzeylerin (menüler, kontrol merkezi, ses göstergesi, ileride dock ve arama) arkasında
en kötü durumda bembeyaz bir sayfa vardır. Yazılar o durumda da okunmalı:

| Ne | En az kontrast |
|---|---|
| yazı, gri yazı (`text`, `textMuted`) | 4.5 |
| soluk yazı, simgeler (`textFaint`: süre, ipucu, bölüm başlığı) | 3.0 |
| üstüne gelince değişen zeminlerde gri yazı | 3.0 |

Bunu sağlayan üç ayar birlikte çalışır:

- `theme/Colors.qml` → `glassOpacity` (camın örtücülüğü; `glassMinOpacity` tabanının altına inemez),
- `~/nixos-config/hypr/config/appearance.lua` → `blur.brightness` (camın arkasını karartır),
- yazı renkleri.

Birini değiştirince:

```
python3 scripts/contrast.py
```

Betik en kötü durumu hesaplar, kuralı bozan her şeyi listeler ve 1 ile çıkar. Ayrıca `modules/` ve
`components/` içinde elle yazılmış renk arar: **bütün renkler `theme/Colors.qml`'den gelmeli**, yoksa denetim onları göremez.

**Bar.** Bar camı değil, duvar kâğıdını görür. Açık duvar kâğıdında koyu yazıya geçer (macOS gibi);
üst şerit çok karışıksa (yarısı beyaz, yarısı siyah) zemini okunana kadar koyulaşır.
Barda `Colors.text` değil `Colors.barText`, `barTextMuted`, `barAccent` kullanılır.

**Akıcılık ve pil.**

- Değişen bir listeyi `Repeater`'a doğrudan JS dizisi olarak verme; `ScriptModel { values: … }` içine koy.
  Yoksa listedeki her küçük değişiklikte bütün satırlar silinip baştan kurulur. Wi-Fi menüsünün geç açılmasının
  nedeni buydu: tarama sırasında her sinyal güncellemesi listeyi baştan kuruyordu.
- Uzun ya da kaydırılan listeler `ListView` (yalnızca görünen satırları kurar).
- Tıklanabilir satırlar içerik değişince baştan kurulmaz. Kurulursa fare basılıyken satır değişir ve tıklama kaybolur
  (dock menüsünde böyle oldu). Menüler bu yüzden satır sayısını model alır, satırlar yerinde güncellenir.
- Sıralama sık değişen bir değere (sinyal gücü gibi) göre yapılmaz; kaba düzeylere göre yapılır ki satırlar zıplamasın.
- Sayfa açılınca yapılacak ağır işler (Wi-Fi taraması, Bluetooth araması, `nmcli`) panel ekrana geldikten sonra başlar.
- Barda sürekli çalışan animasyon olmaz. Gerekiyorsa düşük kare hızında bir `Timer` (müzik dalgası: saniyede 15 kare)
  ve yalnızca görünürken.
- Açılış/kapanış animasyonlarını Hyprland yapar (`rules.lua`); QML yalnızca panelin içindeki geçişleri yapar
  (kontrol merkezinde sayfa değişimi, sürgünün kayması).

## Yapı

| Klasör | İçerik |
|---|---|
| `shell.qml` | giriş noktası |
| `theme/` | renkler, ölçüler, yazı tipleri (tek yerden yönetilir) |
| `components/` | her yerde kullanılan parçalar (simgeler, logo, kapak resmi, dalga) |
| `services/` | sistemden bilgi okuyan tekil nesneler (pil, ağ, ses, Hyprland, müzik) |
| `modules/bar/` | üst bar, ada, uygulama / Pencere / Düzen menüleri, sistem tepsisi |
| `modules/menu/` | açılır menü bileşeni (bar, tepsi ve ileride dock kullanır) |
| `modules/controlcenter/` | kontrol merkezi: Wi-Fi, Bluetooth, güç modu, sürgüler, müzik, güç |
| `modules/osd/` | ses ve parlaklık göstergesi |
| `modules/dock/` | dock: uygulamalar, İndirilenler, çöp kutusu, akıllı gizleme |
| `modules/search/` | arama (Super+Boşluk): uygulamalar, ayarlar, hesap makinesi, dosyalar |
| `modules/notifications/` | bildirim merkezi: takvim, gruplu bildirimler (adadaki hâli `modules/bar/IslandNotice.qml`) |
| `modules/wallpaper/` | duvar kâğıdı katmanı ve seçici (Super+W) |
| `modules/lock/` | kilit ekranı (`lock.qml` ayrı örnek olarak açar) |
| `lock.qml` | kilit ekranının giriş noktası |
| `matugen/` | renk üretim ayarı ve şablonu |
| `theme/kvantum/` | Dolphin'in Kvantum teması için şablonlar (apps_theme.py doldurur) |
| `nix/` | Home Manager ve NixOS modülleri (programlar, servisler, ilk kurulum, PAM) |
| `sddm/` | giriş ekranı teması (SDDM, kilit ekranıyla aynı görünüm) |
| `scripts/` | yardımcı betikler |

Kod İngilizce, açıklamalar Türkçe.

## Hyprland tarafı

Bazı parçalar `~/nixos-config/hypr` içindeki ayara dayanıyor:

- `layouts.lua` → `desk.set_layout` ve `desk.cycle_layout` (Düzen menüsü bunları çağırır)
- `keybinds.lua` → desk'e IPC ile ulaşan kısayollar: Super+Boşluk (`search toggle`), Super+V (`search clipboard`),
  Super+S (`controlcenter toggle`), Super+W (`wallpaper toggle`), Super+Shift+Esc (`controlcenter open session`),
  ses/parlaklık tuşları (`osd …`). Print ve Shift+Print `scripts/screenshot.sh`'ı çağırır.
  Bildirim merkezi için kısayol yok (saate tıklanıyor); istersen `… call notifications toggle` bağlanabilir.
- `autostart.lua` → desk ve hypridle artık burada değil, servis (`nix/home.nix`)
- `desk.lua` → desk'in çalışırken çağırdığı: `desk.set_power` (pilde hafif görünüm);
  `monitors.lua` → `desk.set_refresh`, `appearance.lua` → `desk.apply_animations`. Elle: `hyprctl eval 'desk.set_power(true)'`
- `hypridle.conf` ve `scripts/idle.sh` → boşta kalınca karartma, kilit, uyku; `loginctl lock-session` gelince kilit
- `appearance.lua` → `blur.brightness` (okunabilirlik) ve katman animasyonlarının hızı (`layersIn`, `layersOut`)
- `rules.lua` → `desk-popin`: menüler, kontrol merkezi, bildirim merkezi, arama ve duvar kâğıdı seçici hafifçe
  büyüyerek açılır; `no-anim-panels`: bar, dock ve duvar kâğıdı animasyonsuz (dock kendisi kayıyor, duvar kâğıdı
  kendi geçişini yapıyor). Katman adları: `desk-wallpaper`, `desk-bar`, `desk-dock`, `desk-menu`,
  `desk-control-center`, `desk-notification-center`, `desk-search`, `desk-wallpaper-picker`, `desk-osd`
  (`hyprctl layers` ile görülebilir).

NixOS tarafı: `configuration.nix` → kilit için PAM (`security.pam.services.desk-lock`, yedek `hyprlock`);
`home.nix` → `services.cliphist` (pano), `imagemagick` (renk ölçümü), `colloid-icon-theme`.
