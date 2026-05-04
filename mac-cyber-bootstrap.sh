#!/usr/bin/env bash
set -Eeuo pipefail

############################################
# mac-cyber-bootstrap.sh
# Full macOS bootstrap for cybersecurity / CTF / bug bounty
# For authorized testing, labs, and CTFs only.
#
# Author : srhoe (https://github.com/srhoe)
# Repo   : https://github.com/srhoe/mac-cyber-bootstrap
############################################

### ---------- helpers ----------
log()   { printf "\n[+] %s\n" "$*"; }
warn()  { printf "\n[!] %s\n" "$*" >&2; }
ok()    { printf "[✓] %s\n" "$*"; }
fail()  { printf "\n[x] %s\n" "$*" >&2; exit 1; }

trap 'warn "An unexpected error happened on line $LINENO. Review the output above."' ERR

### ---------- preflight ----------
require_macos() {
  [[ "$(uname -s)" == "Darwin" ]] || fail "This script is for macOS only."
}

install_xcode_clt() {
  if xcode-select -p >/dev/null 2>&1; then
    ok "Xcode Command Line Tools already installed."
    return
  fi

  log "Installing Xcode Command Line Tools..."
  xcode-select --install || true

  warn "If a popup appeared, complete it. This script will wait."
  until xcode-select -p >/dev/null 2>&1; do
    sleep 10
    printf "."
  done
  echo
  ok "Xcode Command Line Tools installed."
}

install_homebrew() {
  if command -v brew >/dev/null 2>&1; then
    ok "Homebrew already installed."
  else
    log "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi

  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  else
    fail "brew installed but not found in expected locations."
  fi
}

ensure_shell_profile() {
  local profile_file
  local brew_line
  local path_line

  if [[ "${SHELL:-}" == */zsh ]]; then
    profile_file="$HOME/.zprofile"
  else
    profile_file="$HOME/.bash_profile"
  fi

  if [[ -x /opt/homebrew/bin/brew ]]; then
    brew_line='eval "$(/opt/homebrew/bin/brew shellenv)"'
  else
    brew_line='eval "$(/usr/local/bin/brew shellenv)"'
  fi

  path_line='export PATH="$HOME/.local/bin:$HOME/go/bin:$HOME/.cargo/bin:$PATH"'

  touch "$profile_file"

  grep -Fq "$brew_line" "$profile_file" || echo "$brew_line" >> "$profile_file"
  grep -Fq "$path_line" "$profile_file" || echo "$path_line" >> "$profile_file"

  ok "Shell profile updated: $profile_file"
}

### ---------- dirs ----------
create_dirs() {
  log "Creating workspace directories..."
  mkdir -p "$HOME/tools"
  mkdir -p "$HOME/labs"
  mkdir -p "$HOME/wordlists"
  mkdir -p "$HOME/screenshots"
  mkdir -p "$HOME/reports"
  mkdir -p "$HOME/.local/bin"
  mkdir -p "$HOME/go/bin"
  ok "Directories created."
}

### ---------- brew setup ----------
brew_taps() {
  log "Adding useful taps..."
  brew tap sidaf/homebrew-pentest || true
  ok "Taps ready."
}

brew_update_upgrade() {
  log "Updating Homebrew..."
  brew update
  brew upgrade || true
}

# FIX: Check if a formula is installed BEFORE brew ever touches the network.
# Previously, brew install would still fetch metadata even when the package
# was already installed. Now we guard with `brew list` first so no download
# is initiated for already-present packages. (Issue reported by HappyG)
is_formula_installed() {
  brew list --formula "$1" >/dev/null 2>&1
}

is_cask_installed() {
  brew list --cask "$1" >/dev/null 2>&1
}

install_formulae() {
  log "Installing CLI formulae..."

  local formulae=(
    # core / terminal
    git
    wget
    curl
    jq
    yq
    ripgrep
    fd
    bat
    tree
    tmux
    fzf
    coreutils
    moreutils
    gnu-sed
    grep
    gawk
    findutils
    watch
    htop
    btop
    ncdu
    rename
    unzip
    zip
    p7zip
    sqlite
    openssl@3
    gnupg
    direnv
    stow
    zsh-completions

    # runtimes
    python
    pipx
    go
    node
    ruby
    rustup

    # editors / database / misc
    neovim
    mysql
    netcat
    socat
    tcpdump
    libpcap

    # recon / web / bug bounty
    ffuf
    gobuster
    feroxbuster
    amass
    subfinder
    httpx
    nuclei
    naabu
    sqlmap
    nikto
    wafw00f
    wfuzz
    theharvester
    masscan
    nmap
    recon-ng
    dnsx

    # creds / cracking / auth
    hydra
    john-jumbo
    hashcat
    hcxtools
    bitwarden-cli

    # ad / windows / infra
    evil-winrm
    kerbrute
    impacket
    azurehound

    # exploitation
    metasploit
    exploitdb

    # dev / scanning / secrets
    semgrep
    gitleaks
    gemini-cli

    # NEW: cloud / infra recon
    awscli          # AWS CLI — useful for cloud pentesting and SSRF validation
    azure-cli       # Azure CLI — pairs with AzureHound for AAD enumeration
    terraform       # IaC analysis and lab spins
    trufflehog      # secret scanning across git history (faster than gitleaks for large repos)
    cloudsplaining  # AWS IAM policy auditing

    # NEW: network / protocol analysis
    mtr             # traceroute + ping combined, great for network debugging
    testssl         # TLS/SSL cipher and cert assessment without Burp
    sslscan         # quick SSL version and cipher scanner
    dnsrecon        # DNS enumeration (zone transfers, brute force, etc.)
    fierce          # DNS recon / subdomain brute

    # NEW: OSINT / recon extras
    shodan          # Shodan CLI — query internet-facing asset data
    metagoofil      # metadata extraction from public docs
    exiftool        # deep file metadata extraction (images, PDFs, Office)

    # NEW: utility / workflow
    gron            # make JSON greppable — great for parsing API responses
    httpie          # human-friendly curl alternative
    xh              # fast httpie-compatible HTTP client written in Rust
    dasel           # query/modify JSON, YAML, TOML, CSV from CLI

    # useful extras
    whois
    inetutils
    iperf3
    telnet
    proxychains-ng
  )

  for pkg in "${formulae[@]}"; do
    # FIX: guard check happens here — no brew invocation if already installed
    if is_formula_installed "$pkg"; then
      ok "$pkg already installed (skipping download)"
    else
      printf "  - installing %s\n" "$pkg"
      brew install "$pkg" || warn "Failed to install formula: $pkg"
    fi
  done

  # custom tap formulae / pentest extras
  local tapped_formulae=(
    sidaf/homebrew-pentest/crackmapexec
  )

  for pkg in "${tapped_formulae[@]}"; do
    if is_formula_installed "$pkg"; then
      ok "$pkg already installed (skipping download)"
    else
      printf "  - installing %s\n" "$pkg"
      brew install "$pkg" || warn "Failed to install tapped formula: $pkg"
    fi
  done
}

install_casks() {
  log "Installing GUI apps / casks..."

  local casks=(
    visual-studio-code
    iterm2
    firefox
    discord
    signal
    telegram
    obsidian
    wireshark-app
    burp-suite
    caido
    bitwarden
    mullvad-vpn
    tor-browser
    libreoffice
    bloodhound
    maltego
    docker

    # NEW: GUI additions
    proxyman        # native macOS HTTP/HTTPS proxy debugger (great Burp companion)
    cyberduck       # S3 / cloud storage browser — useful for misconfigured bucket hunting
    gas-mask        # /etc/hosts manager — handy for lab/CTF target switching
    secretive       # store SSH keys in Secure Enclave instead of on disk
    apparency       # inspect app code signatures and entitlements
  )

  for cask in "${casks[@]}"; do
    # FIX: guard check happens here — no brew invocation if already installed
    if is_cask_installed "$cask"; then
      ok "$cask already installed (skipping download)"
    else
      printf "  - installing %s\n" "$cask"
      brew install --cask "$cask" || warn "Failed to install cask: $cask"
    fi
  done
}

### ---------- language toolchains ----------
setup_pipx() {
  log "Setting up pipx..."
  pipx ensurepath || true

  local pipx_apps=(
    dirsearch
    paramspider
    mitmproxy
    bloodhound-python
    cython
    pwntools

    # NEW: pipx additions
    certipy-ad       # Active Directory certificate abuse (ESC1-ESC8)
    impacket         # Windows protocol suite — SMB, Kerberos, NTLM
    crackmapexec     # network pentesting multi-tool (fallback if brew tap fails)
    netexec          # actively maintained CrackMapExec fork
    pypykatz         # Mimikatz reimplemented in pure Python
    ldapdomaindump   # dump AD info over LDAP without needing domain admin
    pywhisker        # shadow credentials attack tool for AD CS abuse
    coercer          # coerce Windows hosts to authenticate (PetitPotam, PrinterBug, etc.)
  )

  for app in "${pipx_apps[@]}"; do
    if pipx list 2>/dev/null | grep -q "$app"; then
      ok "$app already installed with pipx"
    else
      printf "  - pipx installing %s\n" "$app"
      pipx install "$app" || warn "pipx install failed: $app"
    fi
  done
}

setup_rust() {
  log "Initializing rustup..."
  export PATH="$(brew --prefix rustup)/bin:$PATH"
  rustup default stable || true
  export PATH="$HOME/.cargo/bin:$PATH"

  log "Installing Rust-based security tools..."
  local cargo_tools=(
    rustscan    # fast port scanner — scans all 65k ports then hands off to nmap
    feroxbuster # already in brew but cargo version is latest
  )

  for tool in "${cargo_tools[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
      ok "$tool already installed"
    else
      printf "  - cargo installing %s\n" "$tool"
      cargo install "$tool" || warn "cargo install failed: $tool"
    fi
  done

  ok "Rust ready."
}

setup_go_tools() {
  log "Installing Go-based tooling..."
  export PATH="$HOME/go/bin:$PATH"

  local go_tools=(
    # tomnomnom suite
    github.com/tomnomnom/waybackurls@latest
    github.com/tomnomnom/assetfinder@latest
    github.com/tomnomnom/httprobe@latest
    github.com/tomnomnom/anew@latest
    github.com/tomnomnom/unfurl@latest
    github.com/tomnomnom/qsreplace@latest
    github.com/tomnomnom/gf@latest

    # projectdiscovery suite
    github.com/projectdiscovery/katana/cmd/katana@latest
    github.com/projectdiscovery/shuffledns/cmd/shuffledns@latest
    github.com/projectdiscovery/cdncheck/cmd/cdncheck@latest
    github.com/projectdiscovery/interactsh/cmd/interactsh-client@latest
    github.com/projectdiscovery/notify/cmd/notify@latest
    github.com/projectdiscovery/tlsx/cmd/tlsx@latest        # NEW: TLS data extraction and cert scanning
    github.com/projectdiscovery/asnmap/cmd/asnmap@latest    # NEW: ASN to CIDR mapping for org recon
    github.com/projectdiscovery/uncover/cmd/uncover@latest  # NEW: query Shodan/Fofa/Censys from CLI

    # other
    github.com/hakluke/hakrawler@latest
    github.com/lc/gau/v2/cmd/gau@latest
    github.com/OJ/gobuster/v3@latest

    # NEW: Go additions
    github.com/d3mondev/puredns/v2@latest           # fast subdomain brute-forcer with wildcard filtering
    github.com/sw33tLie/sns@latest                   # SNI sniffing — finds vhosts on an IP
    github.com/003random/getJS@latest                # extract JS file URLs from a page
    github.com/KathanP19/Jsmon@latest                # monitor JS files for changes (bug bounty recon)
    github.com/hahwul/dalfox/v2@latest               # fast XSS parameter analysis and scanning
    github.com/dwisiswant0/crlfuzz@latest            # CRLF injection fuzzer
    github.com/ethicalhackingplayground/bxss@latest  # blind XSS injector
    github.com/RedTeamPentesting/pretender@latest    # LLMNR/NBNS/mDNS spoofer (lab use)
  )

  for tool in "${go_tools[@]}"; do
    printf "  - go install %s\n" "$tool"
    go install "$tool" || warn "Go install failed: $tool"
  done
}

setup_gf_patterns() {
  log "Setting up gf patterns..."
  mkdir -p "$HOME/.gf"

  if [[ -d "$HOME/tools/Gf-Patterns" ]]; then
    cp "$HOME/tools/Gf-Patterns/"*.json "$HOME/.gf/" 2>/dev/null || true
    ok "gf patterns installed to ~/.gf"
  else
    warn "Gf-Patterns repo not found — run clone_repos first."
  fi
}

### ---------- repos / wordlists ----------
clone_repo_if_missing() {
  local repo_url="$1"
  local target_dir="$2"

  if [[ -d "$target_dir/.git" || -d "$target_dir" ]]; then
    ok "$(basename "$target_dir") already exists"
  else
    git clone --depth=1 "$repo_url" "$target_dir" || warn "Clone failed: $repo_url"
  fi
}

clone_repos() {
  log "Cloning security repos and wordlists..."

  clone_repo_if_missing "https://github.com/danielmiessler/SecLists.git"                    "$HOME/wordlists/SecLists"
  clone_repo_if_missing "https://github.com/swisskyrepo/PayloadsAllTheThings.git"            "$HOME/tools/PayloadsAllTheThings"
  clone_repo_if_missing "https://github.com/PowerShellMafia/PowerSploit.git"                 "$HOME/tools/PowerSploit"
  clone_repo_if_missing "https://github.com/lgandx/Responder.git"                            "$HOME/tools/Responder"
  clone_repo_if_missing "https://github.com/laramies/theHarvester.git"                       "$HOME/tools/theHarvester-src"
  clone_repo_if_missing "https://github.com/EnableSecurity/wafw00f.git"                      "$HOME/tools/wafw00f-src"
  clone_repo_if_missing "https://github.com/s0md3v/XSStrike.git"                             "$HOME/tools/XSStrike"
  clone_repo_if_missing "https://github.com/danielmiessler/RobotsDisallowed.git"             "$HOME/tools/RobotsDisallowed"
  clone_repo_if_missing "https://github.com/1ndianl33t/Gf-Patterns.git"                      "$HOME/tools/Gf-Patterns"
  clone_repo_if_missing "https://github.com/projectdiscovery/fuzzing-templates.git"          "$HOME/tools/fuzzing-templates"
  clone_repo_if_missing "https://github.com/projectdiscovery/nuclei-templates.git"           "$HOME/tools/nuclei-templates"
  clone_repo_if_missing "https://github.com/itm4n/PrivescCheck.git"                          "$HOME/tools/PrivescCheck"

  # NEW repos
  clone_repo_if_missing "https://github.com/dirkjanm/BloodHound.py.git"                      "$HOME/tools/BloodHound.py"
  clone_repo_if_missing "https://github.com/ly4k/Certipy.git"                                "$HOME/tools/Certipy"
  clone_repo_if_missing "https://github.com/p0dalirius/Coercer.git"                          "$HOME/tools/Coercer"
  clone_repo_if_missing "https://github.com/Tib3rius/AutoRecon.git"                          "$HOME/tools/AutoRecon"
  clone_repo_if_missing "https://github.com/assetnote/wordlists.git"                         "$HOME/wordlists/assetnote"
  clone_repo_if_missing "https://github.com/Bo0oM/fuzz.txt.git"                              "$HOME/wordlists/fuzz.txt"
  clone_repo_if_missing "https://github.com/xmendez/wfuzz.git"                               "$HOME/tools/wfuzz-src"
  clone_repo_if_missing "https://github.com/21y4d/nmapAutomator.git"                         "$HOME/tools/nmapAutomator"
}

### ---------- aliases / config ----------
append_once() {
  local line="$1"
  local file="$2"
  grep -Fq "$line" "$file" || echo "$line" >> "$file"
}

write_shell_config() {
  local rc_file

  if [[ "${SHELL:-}" == */zsh ]]; then
    rc_file="$HOME/.zshrc"
  else
    rc_file="$HOME/.bashrc"
  fi

  touch "$rc_file"

  log "Writing aliases to $rc_file..."

  append_once '' "$rc_file"
  append_once '# cyber / ctf aliases — srhoe/mac-cyber-bootstrap' "$rc_file"
  append_once 'alias ll="ls -lah"' "$rc_file"
  append_once 'alias ctf="cd $HOME/labs"' "$rc_file"
  append_once 'alias tools="cd $HOME/tools"' "$rc_file"
  append_once 'alias wordlists="cd $HOME/wordlists"' "$rc_file"
  append_once 'alias ports="lsof -i -P -n | grep LISTEN || true"' "$rc_file"
  append_once 'alias myip="curl -4 ifconfig.me && echo"' "$rc_file"
  append_once 'alias grepip="grep -Eo '\''([0-9]{1,3}\.){3}[0-9]{1,3}'\''"' "$rc_file"
  append_once 'alias pyserver="python3 -m http.server 8000"' "$rc_file"
  append_once 'alias reload="source ~/.zshrc 2>/dev/null || source ~/.bashrc"' "$rc_file"
  append_once 'alias searchsploit="searchsploit"' "$rc_file"
  # NEW aliases
  append_once 'alias rustscan="rustscan --ulimit 5000"' "$rc_file"
  append_once 'alias autorecon="python3 $HOME/tools/AutoRecon/autorecon.py"' "$rc_file"
  append_once 'alias nmapauto="$HOME/tools/nmapAutomator/nmapAutomator.sh"' "$rc_file"
  append_once 'alias http="http --verify=no"' "$rc_file"  # httpie ignore SSL in lab
  append_once 'export PATH="$HOME/.local/bin:$HOME/go/bin:$HOME/.cargo/bin:$PATH"' "$rc_file"
  append_once 'export EDITOR="nvim"' "$rc_file"
  append_once 'export WORDLISTS="$HOME/wordlists/SecLists"' "$rc_file"
  append_once 'export ASSETNOTE="$HOME/wordlists/assetnote"' "$rc_file"

  ok "Shell config updated."
}

### ---------- updates / templates ----------
finalize_tools() {
  log "Running post-install updates..."

  if command -v nuclei >/dev/null 2>&1; then
    nuclei -update-templates || warn "nuclei template update failed"
  fi

  if [[ -d "$HOME/tools/nuclei-templates/.git" ]]; then
    git -C "$HOME/tools/nuclei-templates" pull || true
  fi

  # update exploitdb
  if command -v searchsploit >/dev/null 2>&1; then
    searchsploit -u || warn "searchsploit update failed"
  fi

  ok "Post-install tasks finished."
}

### ---------- manual notes ----------
manual_notes() {
  cat <<'EOF'

==========================================================
  mac-cyber-bootstrap — by srhoe
  https://github.com/srhoe/mac-cyber-bootstrap
==========================================================

Installed:
- Core terminal / dev tools
- Recon / web / bug bounty tools (+ dalfox, puredns, uncover, asnmap, tlsx)
- Password / cracking tools
- AD / Windows support tools (+ certipy, netexec, coercer, pypykatz)
- Exploitation tools (Metasploit, exploitdb/searchsploit)
- Cloud tools (awscli, azure-cli, cloudsplaining)
- GUI apps (+ proxyman, cyberduck, gas-mask, secretive)
- Wordlists and common repos (+ assetnote wordlists)
- tomnomnom suite
- projectdiscovery suite (+ tlsx, asnmap, uncover)
- Rust tools (+ rustscan)
- pwntools (for CTF pwn challenges)
- Handy shell aliases

Manual / special-case notes:
1. Nessus:
   Install directly from Tenable — better handled manually on macOS.
   https://www.tenable.com/downloads/nessus

2. Mimikatz:
   Windows-focused. Keep it in a Windows VM / lab.
   Use pypykatz (installed via pipx) on macOS for offline analysis.

3. Flameshot:
   Linux-oriented. On macOS use:
   - Built-in screenshot tools (Cmd+Shift+4/5)
   - Shottr (free, great for pentest annotation)
   - CleanShot X

4. netstat-nat:
   Linux-only. On macOS use:
   - lsof -i -P -n
   - nettop
   - tcpdump

5. BloodHound:
   The Brew cask installs but is marked deprecated. Keep that in mind.
   bloodhound-python (pipx) is used for data collection from Linux/macOS.

6. Burp Suite CA Certificate:
   After opening Burp for the first time:
   - Go to http://burpsuite (with proxy active)
   - Download the CA cert and install it in macOS Keychain
   - Trust it for SSL — required to intercept HTTPS
   Proxyman can also be used as a lightweight alternative.

7. Mullvad VPN Kill Switch:
   Enable the kill switch in Mullvad settings before doing
   any recon from public networks.

8. proxychains-ng config:
   Edit /usr/local/etc/proxychains.conf (Intel) or
   /opt/homebrew/etc/proxychains.conf (Apple Silicon)
   to point at your proxy (e.g., Burp or SOCKS5).

9. RustScan:
   The alias sets --ulimit 5000 to avoid macOS file descriptor limits.
   Usage: rustscan -a <target> -- -sV -sC
   (passes remaining args to nmap)

10. Shodan CLI:
    After install, authenticate with:
      shodan init <YOUR_API_KEY>
    Then use: shodan host <IP>, shodan search "apache"

11. Gas Mask:
    Lets you switch /etc/hosts profiles quickly.
    Useful for lab environments where you need to route domain names
    to specific IPs without editing /etc/hosts manually each time.

12. Secretive:
    Stores SSH keys in the Secure Enclave (T2/M-series chips).
    Keys are hardware-bound and never leave the chip.
    Pair with your SSH config for GitHub and remote lab access.

Recommended next steps:
- Restart Terminal
- Run: brew doctor
- Run: source ~/.zshrc   (or ~/.bashrc)
- Verify key tools:
    which nmap ffuf nuclei subfinder httpx sqlmap
    which evil-winrm crackmapexec msfconsole searchsploit
    which anew gf unfurl qsreplace notify
    which rustscan dalfox puredns tlsx asnmap uncover
- Open Burp, Caido, Wireshark, Docker, Proxyman once and finish first-run setup
- Log in to Bitwarden CLI:
    bw login
- Initialize Shodan CLI:
    shodan init <API_KEY>
- Confirm Mullvad / VPN is working before recon on public networks

Useful folders:
- ~/labs        → CTF and lab workspaces
- ~/tools       → Cloned repos and custom tools
- ~/wordlists   → SecLists, assetnote, and other wordlists
- ~/reports     → Pentest / bug bounty reports
- ~/screenshots → Evidence and findings

EOF
}

main() {
  require_macos
  install_xcode_clt
  install_homebrew
  ensure_shell_profile
  create_dirs
  brew_taps
  brew_update_upgrade
  install_formulae
  install_casks
  setup_pipx
  setup_rust
  setup_go_tools
  clone_repos
  setup_gf_patterns
  write_shell_config
  finalize_tools
  manual_notes
}

main "$@"
