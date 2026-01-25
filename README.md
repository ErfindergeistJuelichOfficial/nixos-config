# Erfindergeist NixOS Configuration

NixOS configurations for Erfindergeist Jülich infrastructure.

## Infrastructure Overview

| Host | Type | Purpose | Key Services |
|------|------|---------|--------------|
| **headscale** | VPS | VPN coordinator & reverse proxy | Headscale, Caddy, Fail2ban |
| **werkstatt-prodesk** | On-prem server | Self-hosted services | Nextcloud, Kanidm, Vikunja, Outline, GoToSocial, Listmonk |
| **werkstatt-workstation** | Desktop | Workstation with AI tools | GNOME, Ollama, Open WebUI, Remote Desktop |

### Network Architecture

- **VPN**: Tailscale mesh coordinated by headscale
- **Public access**: Caddy reverse proxy on headscale VPS
- **Internal services**: Hosted on werkstatt-prodesk, proxied through headscale

```
Internet → headscale (VPS) → Tailscale → werkstatt-prodesk (services)
```

## Prerequisites

- NixOS 25.11 installed on target machines
- SSH access to target machines
- SOPS age keys configured (see [Secrets Management](#secrets-management))
- GitHub repository access

## Quick Start

### 1. Clone Repository

```bash
git clone https://github.com/ErfindergeistJuelichOfficial/nixos-config.git
cd nixos-config
```

### 2. Deploy to Host

```bash
# Check flake
nix flake check

# Build without deploying
nixos-rebuild build --flake .#HOSTNAME

# Build and deploy to a specific host
nixos-rebuild switch --flake .#headscale --target-host root@headscale

# Or build locally and activate
sudo nixos-rebuild switch --flake .#werkstatt-prodesk
```

### 3. Test with VM

```bash
# Build and run a VM for testing
nix build .#headscale
./result/bin/run-headscale-vm
ssh -p 2222 root@localhost
```

## Secrets Management

This repository uses [sops-nix](https://github.com/Mic92/sops-nix) with age encryption.

### Setup New Host
1. Get age public key from SSH key:
```bash
nix shell nixpkgs#ssh-to-age --command sh -c \
  'ssh-keyscan localhost | ssh-to-age'
```

2. Add public key to `.sops.yaml`:
```yaml
- path_regex: hosts/HOSTNAME/secrets.yaml
  key_groups:
    - age:
      - *admin
      - age1... # new host key
```

3. Create secrets file:
```bash
sops hosts/HOSTNAME/secrets.yaml
```

### Edit Secrets

```bash
# Edit secrets for a specific host
sops hosts/headscale/secrets.yaml
sops hosts/werkstatt-prodesk/secrets.yaml
```

## Maintenance

### Automatic Updates

Hosts are configured for automatic daily updates with reboot:

```nix
system.autoUpgrade = {
  enable = true;
  flake = "github:ErfindergeistJuelichOfficial/nixos-config#HOSTNAME";
  allowReboot = true;
  dates = "daily";
};
```

### Manual Updates

```bash
# Update flake inputs
nix flake update

# Test build
nix build .#nixosConfigurations.headscale.config.system.build.toplevel

# Deploy
nixos-rebuild switch --flake .#headscale
```

### Garbage Collection

Automatic weekly garbage collection keeps last 30 days:

```nix
nix.gc = {
  automatic = true;
  dates = "weekly";
  options = "--delete-older-than 30d";
};
```

## Backups

See internal IT documentation on https://wiki.erfindergeist.org

## Common Tasks

### Join Device to Tailscale

```bash
# On the device
sudo tailscale up --login-server https://headscale.erfindergeist.org

# On headscale host
headscale nodes register --user USERNAME --key KEY
```

## License

Internal use for Erfindergeist Jülich.
