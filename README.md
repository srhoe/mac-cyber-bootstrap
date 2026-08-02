# 🛡️ mac-cyber-bootstrap

A one-shot macOS setup script for cybersecurity professionals, CTF players, and bug bounty hunters.

> For authorized testing, labs, and CTFs only. Run this only on machines you own or have explicit written permission to test.

---

## What It Does

Bootstraps a fresh Mac into a fully-equipped security workstation in a single command. Handles everything — package managers, CLI tools, GUI apps, Go/Python/Rust toolchains, wordlists, OSINT tools, and shell config — so you can focus on hacking, not setup.

**v2.0.0** reorganizes everything under `~/pentester/` for a clean workspace, adds a full OSINT suite, Blue Team/DFIR tooling, cloud security tools, reverse engineering tools, wireless tools, and fixes a pre-download bug reported by the community.

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

## Workspace Layout

Everything lives under `~/pentester/` — no more scattered folders across your home directory.

```
~/pentester/
├── tools/              # Cloned repos and custom tools
├── labs/               # CTF and lab workspaces
├── wordlists/          # SecLists, assetnote, and others
├── reports/            # Pentest / bug bounty reports
├── screenshots/        # Evidence and findings
├── pcaps/              # Packet captures
├── memory-dumps/       # Volatility3 analysis targets
├── malware-samples/    # Malware analysis (isolate in VM)
└── osint/              # OSINT workspace
    ├── targets/        # Target notes and scope
    ├── reports/        # OSINT investigation reports
    ├── dumps/          # Data dumps
    ├── sherlock/       # Username enumeration
    ├── holehe/         # Email recon
    ├── maigret/        # Deep username OSINT
    ├── spiderfoot/     # Automated OSINT
    ├── phoneinfoga/    # Phone number OSINT
    ├── h8mail/         # Email breach hunting
    ├── theHarvester/   # Domain/email/subdomain recon
    ├── recon-ng/       # Modular recon framework
    ├── osintgram/      # Instagram OSINT
    └── ghunt/          # Google account OSINT
```

---

## What Gets Installed

### 🖥️ Core / Terminal
`git` · `wget` · `curl` · `jq` · `tmux` · `fzf` · `ripgrep` · `bat` · `neovim` · `htop` · `btop` · `asciinema` · `glow`

### 🔍 Recon / OSINT
`nmap` · `masscan` · `amass` · `subfinder` · `httpx` · `nuclei` · `ffuf` · `gobuster` · `feroxbuster` · `theharvester` · `recon-ng` · `dnsrecon` · `fierce` · `shodan` · `exiftool` · `spiderfoot`

### 🕵️ OSINT Specific
`sherlock` · `holehe` · `maigret` · `phoneinfoga` · `h8mail` · `ghunt` · `osintgram` · `maltego`

### 🌐 Web / Bug Bounty
`sqlmap` · `nikto` · `wafw00f` · `dalfox` · `jwt_tool` · `tplmap` · `arjun` · `smuggler` · `corscanner` · `zaproxy` · `XSStrike` · `LinkFinder` · `SecretFinder` · `crlfuzz` · `bxss`

### 🔑 Credentials / Cracking
`hashcat` · `john-jumbo` · `hydra` · `hcxtools` · `hcxdumptool` · `bitwarden-cli`

### 🏢 Active Directory / Windows / SMB
`impacket` · `evil-winrm` · `kerbrute` · `BloodHound` · `CrackMapExec` · `NetExec` · `certipy-ad` · `pypykatz` · `Responder` · `mitm6` · `ldapdomaindump` · `coercer` · `enum4linux-ng` · `smbmap` · `windapsearch`

### 🔴 Red Team / C2
`Sliver C2` · `Metasploit` · `chisel` · `ligolo-ng` · `pwntools` · `LinPEAS/WinPEAS` · `SharpCollection`

### 🔬 Reverse Engineering
`Ghidra` · `radare2` · `Cutter` · `binwalk` · `pwndbg` · `ROPgadget` · `YARA` · `capstone` · `unicorn` · `floss` · `capa`

### 🔵 Blue Team / DFIR
`volatility3` · `Zeek` · `Suricata` · `chainsaw` · `hayabusa` · `sigma` · `YARA-Rules` · `oletools` · `pdfid`

### ☁️ Cloud Security
`awscli` · `azure-cli` · `Pacu` · `ScoutSuite` · `CloudFox` · `ROADtools` · `TeamFiltration` · `s3scanner` · `enumerate-iam`

### 📡 Wireless
`aircrack-ng` · `hcxdumptool` · `bettercap`

### 🖱️ GUI Apps
`Burp Suite` · `Caido` · `Wireshark` · `Ghidra` · `Cutter` · `BloodHound` · `Maltego` · `Proxyman` · `Docker` · `Obsidian` · `Firefox` · `Tor Browser` · `Mullvad VPN` · `iTerm2` · `VS Code` · `Bitwarden`

### 🐍 Python (via pipx)
`impacket` · `bloodhound-python` · `certipy-ad` · `netexec` · `pypykatz` · `volatility3` · `oletools` · `pacu` · `scoutsuite` · `sherlock` · `holehe` · `maigret` · `pwntools` · `mitmproxy` · `dirsearch` · `arjun` · `jwt_tool`

### 🐹 Go Tools
Full `tomnomnom` suite · Full `projectdiscovery` suite · `dalfox` · `puredns` · `ligolo-ng` · `cloudfox` · `hayabusa` · `ffuf` and more

### 📚 Wordlists & Repos
- `SecLists` → `~/pentester/wordlists/SecLists`
- `assetnote wordlists` → `~/pentester/wordlists/assetnote`
- `PayloadsAllTheThings` → `~/pentester/tools/PayloadsAllTheThings`
- `nuclei-templates` · `PEASS-ng` · `SharpCollection` · `sigma` · `YARA-Rules` · `Responder` · `PowerSploit` and more

---

## Shell Aliases Added

| Alias | Description |
|---|---|
| `pentester` | `cd ~/pentester` |
| `ctf` | `cd ~/pentester/labs` |
| `tools` | `cd ~/pentester/tools` |
| `wordlists` | `cd ~/pentester/wordlists` |
| `osint` | `cd ~/pentester/osint` |
| `reports` | `cd ~/pentester/reports` |
| `dumps` | `cd ~/pentester/memory-dumps` |
| `pcaps` | `cd ~/pentester/pcaps` |
| `nmapfull` | `nmap -sC -sV -p- --open` |
| `nmapquick` | `nmap -sC -sV --top-ports 1000` |
| `rustscan` | `rustscan --ulimit 5000` |
| `pyserver` | `python3 -m http.server 8000` |
| `myip` | Show your public IP |
| `ports` | List all listening ports |
| `vol3` | Run volatility3 from its venv |
| `sherlock` | Run sherlock username OSINT |
| `reload` | Reload your shell config |

---

## After Running the Script

```bash
# 1. Reload shell
source ~/.zshrc

# 2. Sanity check
brew doctor

# 3. Verify key tools
which nmap ffuf nuclei subfinder httpx sqlmap rustscan dalfox
which impacket-secretsdump pypykatz netexec certipy

# 4. Authenticate tools
bw login
shodan init <YOUR_API_KEY>

# 5. Test C2
sudo sliver-server

# 6. Test DFIR
vol3 --help
```

---

## Manual / Special Cases

| Tool | Reason | Alternative |
|---|---|---|
| Mimikatz | Windows-only binary | Use `pypykatz` on macOS for offline analysis |
| Havoc C2 | Requires manual Linux build | Use Sliver C2 (auto-installed) |
| Nessus | Must install via Tenable directly | [tenable.com/downloads/nessus](https://www.tenable.com/downloads/nessus) |
| Flameshot | Linux-oriented | Shottr, CleanShot X, or built-in macOS screenshots |

---

## Errors & Partial Failures

The script uses `set -Eeuo pipefail` with per-tool error handling. If a single tool fails, it warns and continues. Check for `[!]` warnings when done.

---

## License

MIT — use freely, contribute back.

---

## Disclaimer

This script is intended for legal, authorized use only — your own machines, home labs, and CTF environments. The authors are not responsible for misuse.
