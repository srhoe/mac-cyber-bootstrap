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

    # useful extras
    whois
    inetutils
    iperf3
    telnet
    proxychains-ng
  )

  for pkg in "${formulae[@]}"; do
    if brew list --formula "$pkg" >/dev/null 2>&1; then
      ok "$pkg already installed"
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
    if brew list --formula "$pkg" >/dev/null 2>&1; then
      ok "$pkg already installed"
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
  )

  for cask in "${casks[@]}"; do
    if brew list --cask "$cask" >/dev/null 2>&1; then
      ok "$cask already installed"
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

    # other
    github.com/hakluke/hakrawler@latest
    github.com/lc/gau/v2/cmd/gau@latest
    github.com/OJ/gobuster/v3@latest
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
  append_once 'export PATH="$HOME/.local/bin:$HOME/go/bin:$HOME/.cargo/bin:$PATH"' "$rc_file"
  append_once 'export EDITOR="nvim"' "$rc_file"
  append_once 'export WORDLISTS="$HOME/wordlists/SecLists"' "$rc_file"

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
- Recon / web / bug bounty tools
- Password / cracking tools
- AD / Windows support tools
- Exploitation tools (Metasploit, exploitdb/searchsploit)
- GUI apps
- Wordlists and common repos
- tomnomnom suite (anew, gf, unfurl, qsreplace, waybackurls, etc.)
- projectdiscovery suite (nuclei, subfinder, httpx, notify, etc.)
- pwntools (for CTF pwn challenges)
- Handy shell aliases

Manual / special-case notes:
1. Nessus:
   Install directly from Tenable — better handled manually on macOS.
   https://www.tenable.com/downloads/nessus

2. Mimikatz:
   Windows-focused. Keep it in a Windows VM / lab.

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

6. Burp Suite CA Certificate:
   After opening Burp for the first time:
   - Go to http://burpsuite (with proxy active)
   - Download the CA cert and install it in macOS Keychain
   - Trust it for SSL — required to intercept HTTPS

7. Mullvad VPN Kill Switch:
   Enable the kill switch in Mullvad settings before doing
   any recon from public networks.

8. proxychains-ng config:
   Edit /usr/local/etc/proxychains.conf (Intel) or
   /opt/homebrew/etc/proxychains.conf (Apple Silicon)
   to point at your proxy (e.g., Burp or SOCKS5).

Recommended next steps:
- Restart Terminal
- Run: brew doctor
- Run: source ~/.zshrc   (or ~/.bashrc)
- Verify key tools:
    which nmap ffuf nuclei subfinder httpx sqlmap
    which evil-winrm crackmapexec msfconsole searchsploit
    which anew gf unfurl qsreplace notify
- Open Burp, Caido, Wireshark, Docker once and finish first-run setup
- Log in to Bitwarden CLI:
    bw login
- Confirm Mullvad / VPN is working before recon on public networks

Useful folders:
- ~/labs        → CTF and lab workspaces
- ~/tools       → Cloned repos and custom tools
- ~/wordlists   → SecLists and other wordlists
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
