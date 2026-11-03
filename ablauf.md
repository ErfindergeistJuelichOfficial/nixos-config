
---

# Teil 10: Ollama-Modelle auch auf die neue SSD

## 36. Wo liegen die Modelle, wie groß sind sie?

```bash
ssh root@werkstatt-workstation 'ls -ld /var/lib/ollama'                  # -> private/ollama (nur ein Link!)
ssh root@werkstatt-workstation 'du -sh /var/lib/private/ollama'          # 26 GB
ssh root@werkstatt-workstation 'df -h /var/lib/comfyui'                  # 76 GB frei auf der Intenso
```

- Ollama läuft mit `DynamicUser`: systemd erfindet beim Start einen Benutzer und legt
  dessen Daten unter `/var/lib/private/ollama` ab. `/var/lib/ollama` ist nur ein Link
  darauf. Deshalb zeigte `du /var/lib/ollama` vorher 0.

## 37. Aufbau: eine Datenplatte, zwei Bind-Mounts

**Problem:** Die Intenso war direkt unter `/var/lib/comfyui` eingehängt. Eine Platte
kann man nicht einfach an zwei Stellen gleichzeitig einhängen.

**Lösung:** Die Platte kommt nach `/data`, mit den Unterordnern `comfyui/` und
`ollama/`. Diese Ordner werden per **Bind-Mount** dort eingeblendet, wo die Dienste
sie erwarten. Ein Bind-Mount ist wie eine Verknüpfung, nur dass Programme den
Unterschied nicht merken.

```
Intenso-SSD  ──►  /data
                   ├── comfyui/  ──bind──►  /var/lib/comfyui
                   └── ollama/   ──bind──►  /var/lib/private/ollama
```

Neue Datei `hosts/werkstatt-workstation/storage.nix`:

```nix
fileSystems."/data" = {
  device = "/dev/disk/by-uuid/2561817c-4e7d-4140-9693-92acda04f173";
  fsType = "ext4";
  options = [ "nofail" ];
};
fileSystems."/var/lib/comfyui" = {
  device = "/data/comfyui"; fsType = "none";
  options = [ "bind" "nofail" ]; depends = [ "/data" ];
};
fileSystems."/var/lib/private/ollama" = {
  device = "/data/ollama"; fsType = "none";
  options = [ "bind" "nofail" ]; depends = [ "/data" ];
};
systemd.services.ollama.unitConfig.RequiresMountsFor = "/var/lib/private/ollama";
```

- `depends = [ "/data" ]`: Die Bind-Mounts warten, bis `/data` eingehängt ist.
- In `comfyui.nix` fällt der alte `fileSystems`-Eintrag weg. `RequiresMountsFor` bleibt.
- In `default.nix` bei `imports` die Zeile `./storage.nix` ergänzen.

## 38. Neue Datei auf der Workstation bekannt machen

```bash
scp hosts/werkstatt-workstation/{default,comfyui,storage}.nix root@werkstatt-workstation:/root/nixos-config/hosts/werkstatt-workstation/
ssh root@werkstatt-workstation 'cd /root/nixos-config && git add -N hosts/werkstatt-workstation/storage.nix'
```

**Warum `git add -N`:** Eine Flake in einem Git-Repo sieht **nur Dateien, die Git kennt**.
Eine neu kopierte Datei ist „untracked“, und der Build würde mit „does not exist“
abbrechen. `git add -N` („intent to add“) meldet die Datei bei Git an, ohne ihren
Inhalt zu speichern oder etwas zu committen.

Dann zur Probe bauen (wie in Schritt 35) und prüfen:

```bash
ssh root@werkstatt-workstation 'grep -E "data|comfyui|ollama" /root/nixos-config/result/etc/fstab'
```

## 39. Daten umziehen

Prüfen, ob gerade jemand Ollama oder ComfyUI benutzt:

```bash
ssh root@werkstatt-workstation 'curl -s localhost:11434/api/ps; curl -s localhost:8188/queue'   # leer = niemand
```

Dienste stoppen, auf der SSD umräumen, Ollama kopieren:

```bash
ssh root@werkstatt-workstation '
systemctl stop podman-comfyui ollama-model-loader ollama
cd /var/lib/comfyui                                  # hier hing noch die ganze SSD
mkdir .comfyui-tmp
find . -mindepth 1 -maxdepth 1 ! -name lost+found ! -name .comfyui-tmp -exec mv -t .comfyui-tmp {} +
mv .comfyui-tmp comfyui && chmod 0750 comfyui        # ComfyUI-Daten jetzt im Unterordner
mkdir ollama
rsync -aHAX --numeric-ids /var/lib/private/ollama/ /var/lib/comfyui/ollama/
'
```

- `mv` innerhalb derselben Platte kopiert nichts, es ändert nur Namen. Das geht in
  Sekundenbruchteilen, auch bei 29 GB.
- `find … -exec mv -t ziel {} +` verschiebt alles im Ordner, auch versteckte Dateien
  (`.cache`, `.config`), außer `lost+found` und dem Zielordner selbst.
- `--numeric-ids`: Den Ollama-Benutzer gibt es nur, solange der Dienst läuft. rsync soll
  die Besitzer-**Nummern** übernehmen, nicht versuchen, Namen zuzuordnen.

Vergleich (keine Ausgabe = identisch), dann umhängen:

```bash
ssh root@werkstatt-workstation 'rsync -aHAXn --numeric-ids --delete --itemize-changes /var/lib/private/ollama/ /var/lib/comfyui/ollama/'
ssh root@werkstatt-workstation '
U=/dev/disk/by-uuid/2561817c-4e7d-4140-9693-92acda04f173
umount /var/lib/comfyui
e2label $U daten                                     # Platte umbenennen, UUID bleibt gleich
mkdir -p /data && mount $U /data
mount --bind /data/comfyui /var/lib/comfyui
mv /var/lib/private/ollama /var/lib/private/ollama.alt
mkdir /var/lib/private/ollama
mount --bind /data/ollama /var/lib/private/ollama
'
```

## 40. Umschalten, testen, aufräumen

```bash
ssh root@werkstatt-workstation '/root/nixos-config/result/bin/switch-to-configuration dry-activate'
ssh root@werkstatt-workstation 'cd /root/nixos-config && nixos-rebuild switch --flake .#werkstatt-workstation --option experimental-features "nix-command flakes"'
ssh root@werkstatt-workstation 'systemctl start ollama podman-comfyui ollama-model-loader'
ssh root@werkstatt-workstation 'systemctl is-active data.mount var-lib-comfyui.mount var-lib-private-ollama.mount ollama podman-comfyui'
```

- `switch` startet gestoppte Dienste nicht von selbst neu, deshalb `systemctl start`.

Test: Ein Modell wirklich laden lassen (nicht nur auflisten), damit sicher ist, dass
Ollama die Dateien auf der SSD lesen darf:

```bash
ssh root@werkstatt-workstation 'curl -s localhost:11434/api/generate -d "{\"model\":\"qwen3.5:4b\",\"prompt\":\"Antworte nur mit: ok\",\"stream\":false,\"think\":false,\"keep_alive\":0}"'
```

- `keep_alive: 0` entlädt das Modell danach sofort wieder aus der GPU.

Ergebnis: `"response":"ok"`, ComfyUI HTTP 200, Generation **67** aktiv. Erst dann:

```bash
ssh root@werkstatt-workstation 'rm -rf /var/lib/private/ollama.alt && df -h / /data'
```

| Platte | belegt | frei |
|---|---|---|
| Samsung (System) | 112 GB | **79 GB** (vorher 53 GB) |
| Intenso (`/data`) | 54 GB | 51 GB |

---

# Teil 11: OpenSCAD installieren

## 41. Welche Version?

**Was:** Nachsehen, welche OpenSCAD-Pakete nixpkgs anbietet.

**Warum:** Manche Programme gibt es in nixpkgs in mehreren Varianten. `nix eval` liest
die Version direkt aus, ohne etwas zu bauen.

```bash
ssh root@werkstatt-workstation 'cd /root/nixos-config && nix --extra-experimental-features "nix-command flakes" eval --raw .#nixosConfigurations.werkstatt-workstation.pkgs.openscad.version'
ssh root@werkstatt-workstation 'cd /root/nixos-config && nix --extra-experimental-features "nix-command flakes" eval --raw .#nixosConfigurations.werkstatt-workstation.pkgs.openscad-unstable.version'
```

Ergebnis:
- `openscad`: **2021.01**. Das ist die letzte offizielle Veröffentlichung, über 5 Jahre alt.
- `openscad-unstable`: **2026-07-20**, ein aktueller Entwicklungsstand. Er bringt den neuen
  **Manifold**-Rechenkern mit, der Modelle um ein Vielfaches schneller rendert.

Gewählt: `openscad-unstable`. Das Programm heißt trotzdem einfach `openscad`.

## 42. Eintragen, bauen, umschalten

In `hosts/werkstatt-workstation/default.nix` bei `environment.systemPackages`:

```nix
openscad-unstable
```

```bash
scp hosts/werkstatt-workstation/default.nix root@werkstatt-workstation:/root/nixos-config/hosts/werkstatt-workstation/
ssh root@werkstatt-workstation 'cd /root/nixos-config && nixos-rebuild switch --flake .#werkstatt-workstation --option experimental-features "nix-command flakes"'
ssh root@werkstatt-workstation 'openscad --version'
```

Ergebnis: Generation **68**, `OpenSCAD version 2026.07.20-unstable`.

## 43. Test: Hexenturm ohne Fenster nach STL rendern

```bash
ssh root@werkstatt-workstation '
T=$(su erfindergeist -s /bin/sh -c "mktemp -d")       # Testordner, der erfindergeist gehört
su erfindergeist -s /bin/sh -c "cd $T && openscad --backend=manifold -o $T/test.stl /home/erfindergeist/hexenturm_v4.scad"
ls -la $T/test.stl; rm -rf $T
'
```

- `openscad -o datei.stl quelle.scad` rendert ohne Oberfläche und speichert das Ergebnis.
- `--backend=manifold` nimmt ausdrücklich den neuen, schnellen Rechenkern.
- Erster Versuch mit einem Ordner von `mktemp` als root: `cannot set current path:
  Keine Berechtigung`. Der Ordner gehörte root, `erfindergeist` durfte nicht hinein.
  Daher wird der Ordner jetzt als `erfindergeist` angelegt.

Ergebnis: `Status: NoError`, ein geschlossenes 3D-Objekt mit 1650 Flächen, STL geschrieben.

---

# Teil 12: FreeCAD installieren

## 44. Prüfen, ob FreeCAD schon da ist

```bash
grep -rni freecad hosts modules                                         # in der Config?
ssh root@werkstatt-workstation 'ls /run/current-system/sw/bin | grep -i freecad'   # systemweit installiert?
ssh root@werkstatt-workstation 'su - erfindergeist -c "flatpak list | grep -i freecad; ls ~/Applications ~/.local/bin | grep -i freecad"'
```

- Unter Linux kann ein Programm auf mehreren Wegen installiert sein: über die
  NixOS-Config, als Flatpak oder als AppImage. Deshalb an allen Stellen nachsehen.

Ergebnis: nirgends gefunden.

## 45. Version prüfen, eintragen, umschalten

```bash
ssh root@werkstatt-workstation 'cd /root/nixos-config && nix --extra-experimental-features "nix-command flakes" eval --raw .#nixosConfigurations.werkstatt-workstation.pkgs.freecad.version'
```

Ergebnis: `1.1.3`, die aktuelle Version. In `default.nix` bei `environment.systemPackages`:

```nix
freecad
```

```bash
scp hosts/werkstatt-workstation/default.nix root@werkstatt-workstation:/root/nixos-config/hosts/werkstatt-workstation/
ssh root@werkstatt-workstation 'cd /root/nixos-config && nixos-rebuild switch --flake .#werkstatt-workstation --option experimental-features "nix-command flakes"'
```

Ergebnis: 829 MB Download (3,3 GB entpackt), Generation **69**.

## 46. Test ohne Fenster

FreeCAD hat neben der Oberfläche auch `freecadcmd`, eine Version ohne Fenster, die
Python-Befehle ausführt. Damit kann man per SSH testen, ob FreeCAD funktioniert:

```bash
ssh root@werkstatt-workstation 'T=$(su erfindergeist -s /bin/sh -c "mktemp -d"); su erfindergeist -s /bin/sh -c "cd $T && freecadcmd -c \"import FreeCAD, Part; b = Part.makeBox(10, 20, 30); print(\\\"TEST Volumen\\\", b.Volume)\""; rm -rf $T'
```

- `-c "…"` führt den Python-Code direkt aus. Der erste Versuch mit einer `.py`-Datei als
  Argument hat nur die Startmeldung gezeigt. `freecadcmd datei.py` öffnet die Datei
  offenbar, statt sie auszuführen.
- `Part.makeBox(10, 20, 30)` erzeugt einen Quader, dessen Volumen 10 × 20 × 30 = 6000 sein muss.

Ergebnis: `TEST Volumen 6000.0`. Der CAD-Kern funktioniert.

---

# Teil 13: Werkstatt-Programme und `dialout`

## 47. Prüfen, ob es die Pakete gibt

```bash
ssh root@werkstatt-workstation 'cd /root/nixos-config && for p in kicad arduino-ide thonny fritzing meshlab rpi-imager nvtopPackages.nvidia ncdu smartmontools; do echo "$p: $(nix --extra-experimental-features "nix-command flakes" eval --raw .#nixosConfigurations.werkstatt-workstation.pkgs.$p.version)"; done'
```

- Eine Schleife (`for … do … done`) fragt jedes Paket nacheinander ab. Gibt es eines
  nicht, kommt eine Fehlermeldung statt einer Versionsnummer.
- `nvtopPackages.nvidia` hat einen Punkt im Namen: Das Paket `nvtop` gibt es in mehreren
  Varianten (Nvidia, AMD, Intel), und wir nehmen die für Nvidia.

## 48. Eintragen

In `hosts/werkstatt-workstation/default.nix` bei `environment.systemPackages` (alphabetisch):

```nix
arduino-ide  fritzing  kicad  meshlab  ncdu  nvtopPackages.nvidia  rpi-imager  smartmontools  thonny
```

Und beim Benutzer:

```nix
users.users.erfindergeist = {
  …
  # dialout: access to USB serial devices (Arduino, ESP32, Pico)
  extraGroups = [ "networkmanager" "wheel" "podman" "dialout" ];
};
```

**Warum `dialout`:** Ein Arduino oder ESP32 erscheint per USB als serielles Gerät
(`/dev/ttyUSB0` oder `/dev/ttyACM0`). Diese Geräte gehören der Gruppe `dialout`. Ohne die
Gruppe kann die Arduino IDE nichts auf das Board hochladen („Permission denied“).
Der Name stammt aus der Zeit der Modems, daher „dial out“ = hinauswählen.

## 49. Bauen (im Hintergrund), umschalten, prüfen

```bash
scp hosts/werkstatt-workstation/default.nix root@werkstatt-workstation:/root/nixos-config/hosts/werkstatt-workstation/
ssh root@werkstatt-workstation 'systemctl reset-failed nixos-build; systemd-run --unit=nixos-build --working-directory=/root/nixos-config --property=Environment=PATH=/run/current-system/sw/bin nixos-rebuild build --flake .#werkstatt-workstation --option experimental-features "nix-command flakes"'
ssh root@werkstatt-workstation 'systemctl show nixos-build -p Result'      # success?
ssh root@werkstatt-workstation 'cd /root/nixos-config && nixos-rebuild switch --flake .#werkstatt-workstation --option experimental-features "nix-command flakes"'
ssh root@werkstatt-workstation 'id erfindergeist'                          # dialout dabei?
ssh root@werkstatt-workstation 'ls /run/current-system/sw/share/applications'   # Einträge fürs GNOME-Menü
```

- `systemctl reset-failed nixos-build` räumt den alten Lauf mit demselben Namen weg,
  sonst verweigert `systemd-run` den Start.
- `journalctl -u nixos-build` zeigt **alle** Läufe mit diesem Namen, also auch alte.
  Mit `--since "-30min"` sieht man nur den aktuellen.
- Programmnamen sind nicht immer gleich Paketnamen: Fritzing heißt `Fritzing`
  (großes F), nvtop kommt aus `nvtopPackages.nvidia`, smartmontools liefert `smartctl`.

Ergebnis: 1,1 GB Download, Generation **70**. Alle Programme da, `erfindergeist` ist in
`dialout`. Gleich mit getestet: `smartctl -H` meldet für beide SSDs `PASSED`.

**Am Rechner:** `erfindergeist` einmal **ab- und wieder anmelden**. Gruppen werden nur
beim Anmelden gelesen. Vorher funktioniert das Hochladen auf Boards noch nicht, und die
neuen Programme erscheinen eventuell erst danach im Menü.
