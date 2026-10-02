#!/usr/bin/env bash
# =============================================================================
# install.sh -- Cross-Platform Auto-Installer for R-TRCE Code Assistant (Linux & macOS)
# =============================================================================
# Copyright (c) 2026 Asterov Labs. All Rights Reserved.
# Licensed under the Asterov Labs Proprietary Software License.
# See LICENSE file in the project root for full license terms.
# =============================================================================
# USAGE:
#   curl -fsSL https://raw.githubusercontent.com/AsterovLabs/R-TRCE-Code-Assistant/main/install.sh | bash
#   OR locally:
#   ./install.sh
#   OR non-interactive (CI):
#   ./install.sh --no-interaction
# =============================================================================

set -e

REPO_URL="https://github.com/AsterovLabs/R-TRCE-Code-Assistant.git"
BIN_DIR="$HOME/.local/bin"
NO_INTERACTION=false

# Where to install. RTRCE_HOME wins; the previous R_TRCE_HOME variable and an
# existing ~/.r-trce checkout are still honoured so upgrading needs no cleanup.
DEFAULT_INSTALL_DIR="$HOME/.r-trce-code-assistant"
if [ -d "$HOME/.r-trce" ] && [ ! -d "$DEFAULT_INSTALL_DIR" ]; then
  DEFAULT_INSTALL_DIR="$HOME/.r-trce"
fi
INSTALL_DIR="${RTRCE_HOME:-${R_TRCE_HOME:-$DEFAULT_INSTALL_DIR}}"

# Parse arguments
for arg in "$@"; do
  case "$arg" in
    --no-interaction) NO_INTERACTION=true ;;
  esac
done

# Styling
BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}${BOLD}"
echo "  ____        _____ ____   ____ _____ "
echo " |  _ \      |_   _|  _ \ / ___| ____|"
echo " | |_) |____   | | | |_) | |   |  _|  "
echo " |  _ <|____|  | | |  _ <| |___|  ___ "
echo " |_| \_\       |_| |_| \_\\\____|_____|"
echo -e "${NC}"
echo -e "${BOLD}R-TRCE Code Assistant: Architectural Comprehension & Student Tutor Suite${NC}"
echo -e "Installing to: ${YELLOW}${INSTALL_DIR}${NC}\n"

# Helper: prompt the user even when script is piped via curl | bash.
# In piped mode, stdin is the script itself — we must read from /dev/tty.
prompt_yn() {
  local prompt_text="$1"
  local default="${2:-n}"
  if [ "$NO_INTERACTION" = true ]; then
    # Non-interactive mode: use default
    [ "$default" = "y" ] && return 0 || return 1
  fi
  if [ -t 0 ]; then
    # stdin is a terminal — read normally
    read -p "$prompt_text" -n 1 -r REPLY
    echo
  elif [ -e /dev/tty ]; then
    # stdin is piped — read from controlling terminal
    read -p "$prompt_text" -n 1 -r REPLY < /dev/tty
    echo
  else
    # No terminal available — use default
    [ "$default" = "y" ] && return 0 || return 1
  fi
  [[ "$REPLY" =~ ^[Yy]$ ]]
}

# 1. Detect Operating System
OS="$(uname -s)"
case "$OS" in
  Linux*)   PLATFORM="Linux" ;;
  Darwin*)  PLATFORM="macOS" ;;
  *)        PLATFORM="Unknown ($OS)" ;;
esac
echo -e "Detected OS: ${GREEN}${PLATFORM}${NC}"

# 2. Locate R / Rscript
echo -n "Checking for R / Rscript... "
RSCRIPT_BIN=""

if [ -n "$R_ENV" ] && [ -x "$R_ENV/bin/Rscript" ]; then
  RSCRIPT_BIN="$R_ENV/bin/Rscript"
elif [ -x "$HOME/.r-env/bin/Rscript" ]; then
  RSCRIPT_BIN="$HOME/.r-env/bin/Rscript"
elif command -v Rscript >/dev/null 2>&1; then
  RSCRIPT_BIN="$(command -v Rscript)"
fi

if [ -n "$RSCRIPT_BIN" ]; then
  R_VER="$("$RSCRIPT_BIN" --version 2>&1 | head -n 1)"
  echo -e "${GREEN}Found!${NC} ($R_VER at $RSCRIPT_BIN)"
else
  echo -e "${YELLOW}Not detected.${NC}"
  AUTO_INSTALLED=false
  if command -v sudo >/dev/null 2>&1; then
    if command -v apt-get >/dev/null 2>&1; then
      echo -e "\n${BOLD}Would you like this installer to automatically install R for you via apt?${NC}"
      if prompt_yn "Install R (r-base, r-base-dev) now? (Y/n) " "y"; then
        echo "Running: sudo apt update && sudo apt install -y r-base r-base-dev"
        sudo apt update && sudo apt install -y r-base r-base-dev || true
        AUTO_INSTALLED=true
      fi
    elif command -v dnf >/dev/null 2>&1; then
      echo -e "\n${BOLD}Would you like this installer to automatically install R for you via dnf?${NC}"
      if prompt_yn "Install R now? (Y/n) " "y"; then
        sudo dnf install -y R || true
        AUTO_INSTALLED=true
      fi
    elif command -v pacman >/dev/null 2>&1; then
      echo -e "\n${BOLD}Would you like this installer to automatically install R for you via pacman?${NC}"
      if prompt_yn "Install R now? (Y/n) " "y"; then
        sudo pacman -S --noconfirm r || true
        AUTO_INSTALLED=true
      fi
    fi
    if [ "$AUTO_INSTALLED" = true ] && command -v Rscript >/dev/null 2>&1; then
      RSCRIPT_BIN="$(command -v Rscript)"
      R_VER="$("$RSCRIPT_BIN" --version 2>&1 | head -n 1)"
      echo -e "${GREEN}R installed successfully!${NC} ($R_VER)"
    fi
  fi

  if [ -z "$RSCRIPT_BIN" ]; then
    echo -e "\n${YELLOW}[!] R is required for R-TRCE Code Assistant to execute.${NC}"
    echo "Please install R using your system package manager:"
    if [ "$PLATFORM" = "macOS" ]; then
      echo "  brew install r"
    elif command -v apt-get >/dev/null 2>&1; then
      echo "  sudo apt update && sudo apt install -y r-base"
    elif command -v dnf >/dev/null 2>&1; then
      echo "  sudo dnf install -y R"
    elif command -v pacman >/dev/null 2>&1; then
      echo "  sudo pacman -S r"
    elif command -v apk >/dev/null 2>&1; then
      echo "  sudo apk add R R-dev"
    else
      echo "  Visit https://cran.r-project.org to download R for your system."
    fi
    echo ""
    if ! prompt_yn "Continue installation anyway? (y/N) " "n"; then
      exit 1
    fi
    RSCRIPT_BIN="Rscript"
  fi
fi

# 3. Download or Copy Repository
mkdir -p "$INSTALL_DIR"
mkdir -p "$BIN_DIR"

# Detect if running from a local R-TRCE Code Assistant checkout.
# BASH_SOURCE may be empty when piped via curl | bash, so handle gracefully.
SCRIPT_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ "${BASH_SOURCE[0]}" != "bash" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
fi

if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/r_trce.R" ] && [ -d "$SCRIPT_DIR/R" ]; then
  echo "Installing from local directory: $SCRIPT_DIR"
  if [ "$SCRIPT_DIR" != "$INSTALL_DIR" ]; then
    cp -r "$SCRIPT_DIR"/* "$INSTALL_DIR/"
  fi
else
  echo "Fetching latest R-TRCE Code Assistant from GitHub..."
  DOWNLOAD_OK=false

  # Attempt 1: git clone (disable terminal prompts to prevent hanging)
  if command -v git >/dev/null 2>&1; then
    if [ -d "$INSTALL_DIR/.git" ]; then
      echo "Updating existing installation in $INSTALL_DIR..."
      if GIT_TERMINAL_PROMPT=0 git -C "$INSTALL_DIR" pull --quiet 2>/dev/null; then
        DOWNLOAD_OK=true
      else
        echo -e "${YELLOW}Git pull failed. Trying fresh download...${NC}"
        rm -rf "$INSTALL_DIR"
        mkdir -p "$INSTALL_DIR"
      fi
    fi

    if [ "$DOWNLOAD_OK" = false ]; then
      if GIT_TERMINAL_PROMPT=0 git clone --depth 1 "$REPO_URL" "$INSTALL_DIR" 2>/dev/null; then
        DOWNLOAD_OK=true
      else
        echo -e "${YELLOW}Git clone failed. Trying archive download...${NC}"
      fi
    fi
  fi

  # Attempt 2: curl + tar archive download
  if [ "$DOWNLOAD_OK" = false ]; then
    TAR_URL="https://github.com/AsterovLabs/R-TRCE-Code-Assistant/archive/refs/heads/main.tar.gz"
    if command -v curl >/dev/null 2>&1; then
      if curl -fsSL "$TAR_URL" | tar -xz --strip-components=1 -C "$INSTALL_DIR" 2>/dev/null; then
        DOWNLOAD_OK=true
      fi
    elif command -v wget >/dev/null 2>&1; then
      if wget -qO- "$TAR_URL" | tar -xz --strip-components=1 -C "$INSTALL_DIR" 2>/dev/null; then
        DOWNLOAD_OK=true
      fi
    fi
  fi

  if [ "$DOWNLOAD_OK" = false ]; then
    echo -e "${RED}[!] Error: Could not download R-TRCE Code Assistant.${NC}"
    echo "Please check your internet connection and try again."
    echo "Or download manually from: https://github.com/AsterovLabs/R-TRCE-Code-Assistant/releases"
    exit 1
  fi
fi

# Verify the download has the essential files
if [ ! -f "$INSTALL_DIR/r_trce.R" ]; then
  echo -e "${RED}[!] Error: Installation appears incomplete (r_trce.R not found).${NC}"
  echo "Please try again or download manually from: https://github.com/AsterovLabs/R-TRCE-Code-Assistant/releases"
  exit 1
fi

# 4. Check & Install Required R Packages (jsonlite, shiny)
if [ -x "$RSCRIPT_BIN" ] || command -v "$RSCRIPT_BIN" >/dev/null 2>&1; then
  echo -n "Checking required R packages (manifest: R/common.R)... "
  # The list itself lives in required_packages() in R/common.R, so this
  # installer, install.ps1 and `rtrce doctor` cannot disagree about what
  # "required" means. RTRCE_HOME already names the install directory, so it is
  # exported rather than interpolated (that also survives paths with spaces).
  export RTRCE_HOME="$INSTALL_DIR"
  MISSING_PKGS="$("$RSCRIPT_BIN" -e '
    source(file.path(Sys.getenv("RTRCE_HOME"), "R", "common.R"))
    cat(paste(missing_packages(), collapse = " "))
  ' 2>/dev/null || true)"

  if [ -z "$MISSING_PKGS" ]; then
    echo -e "${GREEN}All installed!${NC}"
  else
    echo -e "${YELLOW}Missing: $MISSING_PKGS${NC}"
    echo "Installing missing packages ($MISSING_PKGS) from CRAN into user library..."
    "$RSCRIPT_BIN" -e "
      pkgs <- strsplit('$MISSING_PKGS', ' ')[[1]]
      user_lib <- Sys.getenv('R_LIBS_USER')
      if (is.null(user_lib) || user_lib == '') user_lib <- file.path(Sys.getenv('HOME'), 'R', 'library')
      if (!dir.exists(user_lib)) dir.create(user_lib, recursive = TRUE, showWarnings = FALSE)
      .libPaths(unique(c(user_lib, .libPaths())))
      install.packages(pkgs, lib = user_lib, repos = 'https://cloud.r-project.org', quiet = FALSE)
    " || {
      echo -e "${YELLOW}[!] Note: If compiling from CRAN failed, you can install precompiled binaries on Debian/Ubuntu/Chromebook with:${NC}"
      echo -e "    ${BOLD}sudo apt update && sudo apt install -y r-cran-shiny r-cran-jsonlite${NC}"
    }

    # Verify if installed now (same manifest, so this cannot check a stale list)
    RECHECK="$("$RSCRIPT_BIN" -e '
      source(file.path(Sys.getenv("RTRCE_HOME"), "R", "common.R"))
      cat(paste(missing_packages(), collapse = " "))
    ' 2>/dev/null || true)"
    if [ -z "$RECHECK" ]; then
      echo -e "${GREEN}Successfully installed required R packages!${NC}"
    fi
  fi
fi

# 4b. Optional: Pre-install React Studio backend dependencies if Node.js & npm are present
if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
  if [ -d "$INSTALL_DIR/studio/server" ] && [ ! -d "$INSTALL_DIR/studio/server/node_modules" ]; then
    echo "Installing React Studio backend dependencies..."
    (cd "$INSTALL_DIR/studio/server" && npm install --silent --omit=dev) 2>/dev/null || true
  fi
fi

# 5. Create Executable Wrappers in ~/.local/bin
echo "Creating CLI and Studio executable wrappers..."

# rtrce wrapper (CLI router)
cat << 'WRAPPER_EOF' > "$BIN_DIR/rtrce"
#!/usr/bin/env bash
INSTALL_DIR="__INSTALL_DIR__"
R_BIN="__RSCRIPT_BIN__"

if [ ! -x "$R_BIN" ] && command -v Rscript >/dev/null 2>&1; then
  R_BIN="$(command -v Rscript)"
fi

if [ ! -x "$R_BIN" ]; then
  echo "Error: Rscript not found. Please install R or ensure it is on your PATH." >&2
  exit 1
fi

exec "$R_BIN" "$INSTALL_DIR/r_trce.R" "$@"
WRAPPER_EOF

# rtrce-studio wrapper (interactive Studio)
# rtrce-studio wrapper (interactive Studio - defaults to modern local desktop IDE)
cat << 'WRAPPER_EOF' > "$BIN_DIR/rtrce-studio"
#!/usr/bin/env bash
INSTALL_DIR="__INSTALL_DIR__"
R_BIN="__RSCRIPT_BIN__"

for arg in "$@"; do
  if [ "$arg" = "--shiny" ] || [ "$arg" = "-s" ]; then
    if [ ! -x "$R_BIN" ] && command -v Rscript >/dev/null 2>&1; then
      R_BIN="$(command -v Rscript)"
    fi
    exec "$R_BIN" "$INSTALL_DIR/app.R"
  fi
done

if [ -f "$INSTALL_DIR/start_react_studio.sh" ]; then
  exec bash "$INSTALL_DIR/start_react_studio.sh" "$@"
fi

if [ ! -x "$R_BIN" ] && command -v Rscript >/dev/null 2>&1; then
  R_BIN="$(command -v Rscript)"
fi
exec "$R_BIN" "$INSTALL_DIR/app.R" "$@"
WRAPPER_EOF

# rtrce-react-studio wrapper (React Local Studio)
cat << 'WRAPPER_EOF' > "$BIN_DIR/rtrce-react-studio"
#!/usr/bin/env bash
INSTALL_DIR="__INSTALL_DIR__"
exec bash "$INSTALL_DIR/start_react_studio.sh" "$@"
WRAPPER_EOF

# Substitute actual paths — handle GNU sed (Linux) vs BSD sed (macOS)
if [ "$PLATFORM" = "macOS" ]; then
  sed -i '' "s|__INSTALL_DIR__|$INSTALL_DIR|g" "$BIN_DIR/rtrce" "$BIN_DIR/rtrce-studio" "$BIN_DIR/rtrce-react-studio"
  sed -i '' "s|__RSCRIPT_BIN__|$RSCRIPT_BIN|g" "$BIN_DIR/rtrce" "$BIN_DIR/rtrce-studio"
else
  sed -i "s|__INSTALL_DIR__|$INSTALL_DIR|g" "$BIN_DIR/rtrce" "$BIN_DIR/rtrce-studio" "$BIN_DIR/rtrce-react-studio"
  sed -i "s|__RSCRIPT_BIN__|$RSCRIPT_BIN|g" "$BIN_DIR/rtrce" "$BIN_DIR/rtrce-studio"
fi

chmod +x "$BIN_DIR/rtrce" "$BIN_DIR/rtrce-studio" "$BIN_DIR/rtrce-react-studio"

# Legacy command names kept as aliases so existing habits and scripts keep working
ln -sf "rtrce"        "$BIN_DIR/r-trce"
ln -sf "rtrce-studio" "$BIN_DIR/r-trce-studio"

# 5b. Create Desktop Entry & Application Launcher (Linux)
if [ "$PLATFORM" = "Linux" ]; then
  APP_DIR="$HOME/.local/share/applications"
  ICON_PATH="$INSTALL_DIR/www/brand/asterov-icon-256.png"
  if [ ! -f "$ICON_PATH" ]; then
    ICON_PATH="$INSTALL_DIR/www/brand/asterov-icon.png"
  fi
  
  if mkdir -p "$APP_DIR" 2>/dev/null; then
    cat << DESKTOP_EOF > "$APP_DIR/rtrce-studio.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=R-TRCE Code Assistant
GenericName=R Code Analysis & Studio
Comment=Architectural Comprehension, TRCE Telemetry & Student Studio
Exec=$BIN_DIR/rtrce-studio
Icon=$ICON_PATH
Terminal=false
Categories=Development;IDE;Education;
StartupNotify=true
DESKTOP_EOF
    chmod +x "$APP_DIR/rtrce-studio.desktop"
    if command -v update-desktop-database >/dev/null 2>&1; then
      update-desktop-database "$APP_DIR" >/dev/null 2>&1 || true
    fi
    echo -e "${GREEN}Created application launcher:${NC} $APP_DIR/rtrce-studio.desktop"
  fi

  if [ -d "$HOME/Desktop" ]; then
    cp "$APP_DIR/rtrce-studio.desktop" "$HOME/Desktop/R-TRCE Studio.desktop" 2>/dev/null || true
    chmod +x "$HOME/Desktop/R-TRCE Studio.desktop" 2>/dev/null || true
    echo -e "${GREEN}Created desktop shortcut:${NC} ~/Desktop/R-TRCE Studio.desktop"
  fi
fi

# 6. Verify PATH integration
PATH_CONFIGURED=false
if echo ":$PATH:" | grep -q ":$BIN_DIR:"; then
  PATH_CONFIGURED=true
fi

if [ "$PATH_CONFIGURED" = false ]; then
  # Detect the user's shell profile
  SHELL_PROFILE=""
  CURRENT_SHELL="$(basename "${SHELL:-/bin/bash}")"
  case "$CURRENT_SHELL" in
    zsh)  [ -f "$HOME/.zshrc" ] && SHELL_PROFILE="$HOME/.zshrc" ;;
    bash) [ -f "$HOME/.bashrc" ] && SHELL_PROFILE="$HOME/.bashrc" ;;
    fish) [ -f "$HOME/.config/fish/config.fish" ] && SHELL_PROFILE="$HOME/.config/fish/config.fish" ;;
  esac
  # Fallback
  if [ -z "$SHELL_PROFILE" ] && [ -f "$HOME/.profile" ]; then
    SHELL_PROFILE="$HOME/.profile"
  fi

  if [ -n "$SHELL_PROFILE" ]; then
    if ! grep -q "$BIN_DIR" "$SHELL_PROFILE" 2>/dev/null; then
      if [ "$CURRENT_SHELL" = "fish" ]; then
        echo "set -gx PATH \$HOME/.local/bin \$PATH" >> "$SHELL_PROFILE"
      else
        printf '\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$SHELL_PROFILE"
      fi
      echo -e "${GREEN}Added ~/.local/bin to $SHELL_PROFILE${NC}"
    fi
  fi
fi

echo -e "\n${GREEN}=================================================================="
echo -e "  R-TRCE Code Assistant installed successfully!"
echo -e "==================================================================${NC}\n"
echo -e "Quick Start Commands:"
echo -e "  ${BOLD}rtrce tutor script.R${NC}        Student walkthrough & pitfall audit"
echo -e "  ${BOLD}rtrce pitfalls script.R${NC}     Quick beginner pitfall sentinel"
echo -e "  ${BOLD}rtrce quiz script.R${NC}         Generate student comprehension quiz"
echo -e "  ${BOLD}rtrce explain script.R${NC}      Full architectural explanation"
echo -e "  ${BOLD}rtrce help${NC}                  Every command and option"
echo -e "  ${BOLD}rtrce-studio${NC}                Launch interactive Studio (defaults to React Local IDE)"
echo -e "  ${BOLD}rtrce-studio --shiny${NC}        Launch interactive Shiny web studio explicitly"
echo ""
echo -e "${YELLOW}Note:${NC} the older names 'r-trce' and 'r-trce-studio' still work as aliases."
echo ""
if [ "$PATH_CONFIGURED" = false ]; then
  echo -e "${YELLOW}Note: To use commands immediately in this terminal, run:${NC}"
  echo -e "  ${BOLD}export PATH=\"\$HOME/.local/bin:\$PATH\"${NC}\n"
fi
