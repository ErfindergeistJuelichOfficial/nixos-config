# CLAUDE.md

NixOS-Konfiguration des Erfindergeist Jülich e.V. (Flake). Hosts unter `hosts/`:
`headscale` (Headscale, Kanidm, Caddy), `werkstatt-prodesk`, `werkstatt-workstation`.

## Bevor Claude auf die Workstation kann (macht der Mensch)

Der Rechner, auf dem Claude läuft, muss im Tailnet sein:

```bash
sudo tailscale up --login-server https://headscale.erfindergeist.org
```

Danach im Browser mit dem Erfindergeist-SSO anmelden. SSH auf die Werkstatt-Rechner
dürfen nur Mitglieder von `group:admins` (siehe `hosts/headscale/acl.jsonc`).
Prüfen: `tailscale status | grep werkstatt-workstation` muss eine `100.64.x.x`-IP zeigen.

## Zugang zur Workstation

```bash
ssh root@werkstatt-workstation            # = 100.64.0.19, MagicDNS: werkstatt-workstation.tailnet.erfindergeist.org
```

- Das ist **Tailscale SSH**, nicht OpenSSH: kein Schlüssel nötig, Freigabe über die ACL.
  Erlaubter Benutzer ist praktisch nur `root` (`egj` steht in der ACL, existiert aber nicht).
- Für Befehle von Claude immer `-o BatchMode=yes` setzen.
- Tailscale SSH lehnt **sporadisch** mit `Permission denied (publickey,keyboard-interactive)`
  ab. Einfach wiederholen, notfalls direkt `root@100.64.0.19`.
- Über das LAN (`werkstatt-workstation.local`) geht es nicht: OpenSSH hat
  `PasswordAuthentication = false` und es sind keine Keys hinterlegt.
- Desktop-Benutzer ist `erfindergeist` (GNOME). Vor Dingen, die die Sitzung stören
  könnten, mit `loginctl list-sessions` schauen, ob jemand angemeldet ist.

## Mit dem Menschen arbeiten

- Kommunikation auf **Deutsch**. Der Nutzer kommt aus der Windows-Welt: Linux/Nix-Begriffe
  kurz erklären.
- Jeden Schritt in **`ablauf.md`** (Repo-Root, nicht committet) dokumentieren, immer mit
  **Was**, **Warum** und **Befehl**, damit der Nutzer es nachvollziehen und lernen kann.
  Neue Teile hinten anhängen und die Nummerierung fortsetzen.
- **Keine Commits und keine Pushes.** Das macht der Nutzer selbst. (Claude hat in der
  Shell auch keine GitHub-Zugangsdaten.)
- Lokale Dateien wie `ablauf.md`, `blender_mcp.md` und `hexenturm_*` gehören nicht ins Repo.

## Config auf der Workstation bauen

Das Repo liegt auf der Workstation unter `/root/nixos-config` (Klon von GitHub).
**Flakes sind dort nicht standardmäßig aktiv**, daher immer mit Zusatz-Option:

```bash
F='--option experimental-features "nix-command flakes"'
ssh root@werkstatt-workstation "cd /root/nixos-config && git pull"
ssh root@werkstatt-workstation "cd /root/nixos-config && nixos-rebuild build  --flake .#werkstatt-workstation $F"
ssh root@werkstatt-workstation "/root/nixos-config/result/bin/switch-to-configuration dry-activate"   # was startet neu?
ssh root@werkstatt-workstation "cd /root/nixos-config && nixos-rebuild switch --flake .#werkstatt-workstation $F"
```

- Auf dem Laptop des Nutzers ist **kein Nix** installiert. Nicht committete Änderungen
  testet man so: per `scp` nach `/root/nixos-config/...` kopieren und dort bauen
  (Flakes nehmen geänderte, Git bekannte Dateien mit). Danach auf der Workstation
  `git checkout -- . && git pull`, sobald der Nutzer gepusht hat.
- Lange Builds (z. B. CUDA-Pakete) mit `systemd-run --unit=nixos-build --working-directory=/root/nixos-config --property=Environment=PATH=/run/current-system/sw/bin nixos-rebuild build ...`
  starten, damit sie einen SSH-Abbruch überleben. Status: `journalctl -u nixos-build`.
- Werkzeuge, die nicht installiert sind, vorübergehend holen:
  `nix --extra-experimental-features "nix-command flakes" shell /root/nixos-config#nixosConfigurations.werkstatt-workstation.pkgs.<paket> -c <befehl>`.
  `nix-shell -p` geht nicht (kein `<nixpkgs>`-Kanal). **Kein `python3`** auf der Workstation:
  JSON lieber lokal auswerten.
- Platz freigeben ohne Generationen zu löschen: `nix-store --gc`.
  `nix.gc` läuft zusätzlich wöchentlich mit `--delete-older-than 30d`.
- Rollback: `nixos-rebuild switch --rollback`.

## Hardware und Besonderheiten der Workstation

- Mainboard Gigabyte H610M K DDR4, 15 GB RAM, 34 GB Swap, GPU **RTX 5060 Ti 16 GB** (sm_120),
  BIOS-Boot mit GRUB.
- Platten (die `sdX`-Namen können sich vertauschen, **immer `/dev/disk/by-id/` verwenden**):
  - `ata-Samsung_SSD_840_PRO_Series_S1ATNSAD703635R`: System (`/`, Swap), 256 GB.
    `boot.loader.grub.device` zeigt per by-id hierauf.
  - `ata-Intenso_SSD_Sata_III_2026071600272`: 120 GB, ext4, Label `daten`, eingehängt
    unter `/data` (`storage.nix`). Von dort per Bind-Mount: `/data/comfyui` →
    `/var/lib/comfyui` und `/data/ollama` → `/var/lib/private/ollama` (Ollama nutzt
    `DynamicUser`, `/var/lib/ollama` ist nur ein Link). Alles `nofail`, die Dienste haben
    `RequiresMountsFor`. Beim Kopieren von Ollama-Daten `rsync --numeric-ids` verwenden.
- **Ollama** (`llama.nix`): Port 11434, `OLLAMA_CONTEXT_LENGTH = 32768` (Standard 4096 war
  zu klein für opencode). Modelle aus `loadModels`.
- **opencode** (`blender.nix`): Config fest unter `/etc/opencode/opencode.json`
  (`OPENCODE_CONFIG`). Provider = lokales Ollama, Modellliste kommt aus `loadModels`.
  `qwen2.5-coder:14b` gibt Werkzeug-Aufrufe nur als Text aus und taugt daher **nicht** für
  MCP. `qwen3.5:9b` und `gemma4:12b` funktionieren.
- **Blender-MCP**: Das Addon lauscht nur auf `127.0.0.1:9876`, ohne Anmeldung. Von außen
  per Tunnel: `ssh -f -N -L 19876:127.0.0.1:9876 root@100.64.0.19`, dann JSON wie
  `{"type": "execute_code", "params": {"code": "..."}}` an `localhost:19876` schicken.
  Vorsicht bei Remesh: `voxel_size` passend zur Objektgröße wählen (bei 0.1 auf
  260 Einheiten lief der RAM voll).
- **VS Code** als normales Paket in `systemPackages`, nicht `programs.vscode`. Das Modul
  setzt `--extensions-dir` auf den schreibgeschützten Nix-Store.
- **ComfyUI** läuft als Podman-Container (`podman-comfyui`), Port 8188 nur auf localhost.

## Offene Punkte (Stand 2026-11-03)

- Mit der `flake.lock` aus `main` (nixpkgs `02c087f`) scheitert der Build an
  **open-webui 0.12.3** (`makeWrapper doesn't understand the arg --set FRONTEND_BUILD_DIR`).
  Übergangsweise liegt auf der Workstation **lokal** die `flake.lock` aus Commit
  `df0378f` (nixpkgs `4975466`), nicht committet. Bei einem neuen Lock-Update prüfen, ob
  open-webui wieder baut, dann auf der Workstation `git checkout -- flake.lock`.
- Die SSD-Änderungen (`default.nix` GRUB by-id, `storage.nix`, `comfyui.nix`) sind noch
  nicht in `main`. Auf der Workstation liegen sie als lokale Änderungen im Repo
  (`storage.nix` per `git add -N`) und sind aktiv (Generation 67). **Wer `main` ohne sie
  baut, installiert GRUB auf `/dev/sda` = die Intenso-Platte!**
- Neue Dateien, die per `scp` auf die Workstation kommen, mit `git add -N <datei>`
  anmelden, sonst sieht die Flake sie nicht.
