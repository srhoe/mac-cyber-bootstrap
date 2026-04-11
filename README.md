# 🛡️ mac-cyber-bootstrap

A one-shot macOS setup script for cybersecurity professionals, CTF players, and bug bounty hunters.

> **For authorized testing, labs, and CTFs only.**
> Run this only on machines you own or have explicit written permission to test.

---

## What It Does

Bootstraps a fresh Mac into a fully-equipped security workstation in a single command. It handles everything — package managers, CLI tools, GUI apps, Go/Python/Rust toolchains, wordlists, and shell config — so you can focus on hacking, not setup.

---

## Requirements

| Requirement | Notes |
|---|---|
| macOS | Tested on macOS 13 Ventura and later |
| Apple Silicon or Intel | Script handles both Homebrew paths automatically |
| Admin access | Needed for Homebrew and Xcode CLT |
| Internet connection | Required throughout |

---

## Quick Start

```bash
curl -fsSL https://raw.githubusercontent.com/srhoe/mac-cyber-bootstrap/main/mac-cyber-bootstrap.sh -o mac-cyber-bootstrap.sh
chmod +x mac-cyber-bootstrap.sh
./mac-cyber-bootstrap.sh
```

Or clone the repo first:

```bash
git clone https://github.com/srhoe/mac-cyber-bootstrap.git
cd mac-cyber-bootstrap
chmod +x mac-cyber-bootstrap.sh
./mac-cyber-bootstrap.sh
```

---

## What Gets Installed

### 🖥️ Core / Terminal
`git` · `wget` · `curl` · `jq` · `tmux` · `fzf` · `ripgrep` · `bat` · `neovim` · `htop` · `btop` and more

### 🌐 Recon / Web / Bug Bounty
`ffuf` · `gobuster` · `feroxbuster` · `amass` · `subfinder` · `httpx` · `nuclei` · `naabu` · `sqlmap` · `nikto` · `wafw00f` · `wfuzz` · `masscan` · `nmap` · `recon-ng` · `theharvester` · `wpscan`

### 🔑 Credentials / Cracking
`hydra` · `john-jumbo` · `hashcat` · `hcxtools` · `bitwarden-cli`

### 🏢 Active Directory / Windows / Infra
`evil-winrm` · `kerbrute` · `impacket` · `azurehound` · `crackmapexec`

### 🔍 Dev / Scanning / Secrets
`semgrep` · `gitleaks`

### 🐍 Python (via pipx)
`dirsearch` · `paramspider` · `mitmproxy` · `bloodhound-python`

### 🐹 Go Tools
`hakrawler` · `waybackurls` · `assetfinder` · `gau` · `katana` · `httprobe` · `shuffledns` · `cdncheck` · `interactsh-client`

### 🖱️ GUI Apps
`Burp Suite` · `Caido` · `Wireshark` · `Obsidian` · `BloodHound` · `Maltego` · `Docker` · `Firefox` · `Tor Browser` · `Mullvad VPN` · `iTerm2` · `VS Code` · `Signal` · `Bitwarden`

### 📚 Wordlists & Repos
- [SecLists](https://github.com/danielmiessler/SecLists) → `~/wordlists/SecLists`
- [PayloadsAllTheThings](https://github.com/swisskyrepo/PayloadsAllTheThings) → `~/tools/PayloadsAllTheThings`
- [nuclei-templates](https://github.com/projectdiscovery/nuclei-templates) → `~/tools/nuclei-templates`
- [XSStrike](https://github.com/s0md3v/XSStrike) · `Gf-Patterns` · `fuzzing-templates` · `PrivescCheck` · `Responder` · `PowerSploit`

---

## Workspace Layout

```
~/
├── labs/          # CTF and lab workspaces
├── tools/         # Cloned repos and custom tools
├── wordlists/     # SecLists and other wordlists
├── reports/       # Pentest and bug bounty reports
└── screenshots/   # Evidence and findings
```

---

## Shell Aliases Added

| Alias | Command |
|---|---|
| `ll` | `ls -lah` |
| `ctf` | `cd ~/labs` |
| `tools` | `cd ~/tools` |
| `wordlists` | `cd ~/wordlists` |
| `ports` | List all listening ports |
| `myip` | Show your public IP |
| `grepip` | Extract IPs from output |
| `pyserver` | Start a Python HTTP server on port 8000 |
| `reload` | Reload your shell config |

---

## After Running the Script

```bash
# 1. Restart Terminal (or reload shell)
source ~/.zshrc

# 2. Sanity check
brew doctor

# 3. Verify key tools
which nmap ffuf nuclei subfinder httpx sqlmap evil-winrm crackmapexec

# 4. Open and finish first-run setup for:
#    Burp Suite, Caido, Wireshark, Docker

# 5. Log in to Bitwarden CLI
bw login

# 6. Confirm your VPN (Mullvad) before running recon from a public network
```

---

## Manual / Special Cases

These tools are intentionally **not included** in the script — see below for why:

| Tool | Reason | Alternative |
|---|---|---|
| **Nessus** | Must be installed via Tenable directly | [Download from Tenable](https://www.tenable.com/downloads/nessus) |
| **Mimikatz** | Windows-only in practice | Use inside a Windows VM |
| **Flameshot** | Linux-oriented | Use Shottr, CleanShot X, or built-in macOS screenshots |
| **netstat-nat** | Linux-only | `lsof -i -P -n`, `nettop`, `tcpdump` |
| **BloodHound** | Brew cask is deprecated | Monitor for updates or install manually |

---

## Errors & Partial Failures

The script uses `set -Eeuo pipefail` with per-tool error handling. If a single tool fails to install, the script warns you and continues rather than exiting. Check the output for any `[!]` warnings when done.

---

## License

MIT — use freely, contribute back.

---

## Disclaimer

This script is intended for **legal, authorized use only** — your own machines, home labs, and CTF environments. The authors are not responsible for misuse.
