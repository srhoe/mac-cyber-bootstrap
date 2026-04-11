#!/usr/bin/env bash
set -Eeuo pipefail

############################################
# mac-cyber-bootstrap.sh
# Full macOS bootstrap for cybersecurity / CTF / bug bounty
# For authorized testing, labs, and CTFs only.
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

  path_line='export PATH="$HOME/.local/bin:$HOME/go/bin:$PATH"'

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

    # recon / web / bb
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
    wpscan
    masscan
    nmap
    recon-ng

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

    # dev / scanning / secrets
    semgrep
    gitleaks
    gemini-cli

    # useful extras
    whois
    inetutils
    iperf3
    telnet
    dnsx
    nuclei
    subfinder
    httpx
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
  ok "Rust ready."
}

setup_go_tools() {
  log "Installing Go-based tooling..."
  export PATH="$HOME/go/bin:$PATH"

  local go_tools=(
    github.com/hakluke/hakrawler@latest
    github.com/tomnomnom/waybackurls@latest
    github.com/tomnomnom/assetfinder@latest
    github.com/lc/gau/v2/cmd/gau@latest
    github.com/projectdiscovery/katana/cmd/katana@latest
    github.com/tomnomnom/httprobe@latest
    github.com/projectdiscovery/shuffledns/cmd/shuffledns@latest
    github.com/projectdiscovery/cdncheck/cmd/cdncheck@latest
    github.com/projectdiscovery/interactsh/cmd/interactsh-client@latest
    github.com/OJ/gobuster/v3@latest
  )

  for tool in "${go_tools[@]}"; do
    printf "  - go install %s\n" "$tool"
    go install "$tool" || warn "Go install failed: $tool"
  done
}

setup_gem_tools() {
  log "Installing Ruby-based tooling..."
  gem install wpscan || warn "Ruby gem install failed: wpscan"
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

  clone_repo_if_missing "https://github.com/danielmiessler/SecLists.git" "$HOME/wordlists/SecLists"
  clone_repo_if_missing "https://github.com/swisskyrepo/PayloadsAllTheThings.git" "$HOME/tools/PayloadsAllTheThings"
  clone_repo_if_missing "https://github.com/PowerShellMafia/PowerSploit.git" "$HOME/tools/PowerSploit"
  clone_repo_if_missing "https://github.com/lgandx/Responder.git" "$HOME/tools/Responder"
  clone_repo_if_missing "https://github.com/laramies/theHarvester.git" "$HOME/tools/theHarvester-src"
  clone_repo_if_missing "https://github.com/EnableSecurity/wafw00f.git" "$HOME/tools/wafw00f-src"
  clone_repo_if_missing "https://github.com/s0md3v/XSStrike.git" "$HOME/tools/XSStrike"
  clone_repo_if_missing "https://github.com/danielmiessler/RobotsDisallowed.git" "$HOME/tools/RobotsDisallowed"
  clone_repo_if_missing "https://github.com/1ndianl33t/Gf-Patterns.git" "$HOME/tools/Gf-Patterns"
  clone_repo_if_missing "https://github.com/projectdiscovery/fuzzing-templates.git" "$HOME/tools/fuzzing-templates"
  clone_repo_if_missing "https://github.com/projectdiscovery/nuclei-templates.git" "$HOME/tools/nuclei-templates"
  clone_repo_if_missing "https://github.com/itm4n/PrivescCheck.git" "$HOME/tools/PrivescCheck"
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
  append_once '# cyber / ctf aliases' "$rc_file"
  append_once 'alias ll="ls -lah"' "$rc_file"
  append_once 'alias ctf="cd $HOME/labs"' "$rc_file"
  append_once 'alias tools="cd $HOME/tools"' "$rc_file"
  append_once 'alias wordlists="cd $HOME/wordlists"' "$rc_file"
  append_once 'alias ports="lsof -i -P -n | grep LISTEN || true"' "$rc_file"
  append_once 'alias myip="curl -4 ifconfig.me && echo"' "$rc_file"
  append_once 'alias grepip="grep -Eo '\''([0-9]{1,3}\.){3}[0-9]{1,3}'\''"' "$rc_file"
  append_once 'alias pyserver="python3 -m http.server 8000"' "$rc_file"
  append_once 'alias reload="source ~/.zshrc 2>/dev/null || source ~/.bashrc"' "$rc_file"
  append_once 'export PATH="$HOME/.local/bin:$HOME/go/bin:$PATH"' "$rc_file"
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

  ok "Post-install tasks finished."
}

### ---------- manual notes ----------
manual_notes() {
  cat <<'EOF'

==========================================================
DONE
==========================================================

Installed:
- Core terminal/dev tools
- Recon/web/bug bounty tools
- Password/cracking tools
- AD/Windows support tools
- GUI apps
- Wordlists and common repos
- Handy shell aliases

Manual / special-case notes:
1. Nessus / Autonessus:
   Install Nessus directly from Tenable. It is better handled manually on macOS.

2. Mimikatz:
   Native use is Windows-focused. Keep it in a Windows VM/lab instead of your host Mac.

3. Flameshot:
   Linux-oriented. On macOS use:
   - built-in screenshot tools
   - Shottr
   - CleanShot X
   - Flameshot via unofficial workarounds only if you really want it

4. netstat-nat:
   Linux-oriented. On macOS use:
   - lsof -i -P -n
   - nettop
   - tcpdump

5. BloodHound:
   The Brew cask currently installs, but it is marked deprecated. Keep that in mind.

Recommended next steps:
- Restart Terminal
- Run: brew doctor
- Run: source ~/.zshrc   (or ~/.bashrc)
- Check tools:
    which nmap
    which ffuf
    which nuclei
    which subfinder
    which httpx
    which sqlmap
    which impacket-GetUserSPNs
    which evil-winrm
    which crackmapexec
- Open Burp, Caido, Wireshark, Obsidian once
- In Wireshark, confirm permissions and packet capture access
- In Docker, finish first-run setup
- Login to Bitwarden CLI:
    bw login
- Verify Mullvad / VPN setup before running recon from public networks

Useful folders:
- ~/labs
- ~/tools
- ~/wordlists
- ~/reports
- ~/screenshots

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
  setup_gem_tools
  clone_repos
  write_shell_config
  finalize_tools
  manual_notes
}

main "$@"
