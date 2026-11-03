
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
