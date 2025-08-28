#!/usr/bin/env bash
# davit-installer.sh    
# Version: 0.0.4
# Alias: install+
# Description: Generic installation script for DavitTec projects, configurable via .env

# Set strict mode
set -euo pipefail

# Assume running from project root
ROOT_DIR="$(pwd)"
ENV_FILE="${ROOT_DIR}/.env"
ENV_LOCAL_FILE="${ROOT_DIR}/.env-local"

# Check for .env or .env-local
if [[ ! -f "$ENV_FILE" && ! -f "$ENV_LOCAL_FILE" ]]; then
    echo "Error: No .env or .env-local found in ${ROOT_DIR}."
    echo "Please create .env by copying .env-example and customizing it,"
    echo "or run install_env.sh (if available) to generate it."
    exit 1
fi

# Use .env-local if .env doesn't exist
if [[ ! -f "$ENV_FILE" ]]; then
    ENV_FILE="$ENV_LOCAL_FILE"
fi

# Load .env file
while IFS='=' read -r key value; do
    if [[ -n "$key" && ! "$key" =~ ^# ]]; then
        value=$(echo "$value" | sed 's/^"\|"$//g')
        export "$key=$value"
    fi
done < <(grep -v '^#' "$ENV_FILE" | grep -v '^$')

# Define directories and settings from .env or defaults
INSTALL_DIR="${BIN_DIR:-/opt/davit/bin}"
DEV_DIR="${DEV_DIR:-/opt/davit/development}"
LOG_DIR="${LOG_DIR:-${ROOT_DIR}/logs}"
LOG_FILE="${LOG_FILE:-${LOG_DIR}/${PROJECT_NAME:-project}.log}"
BASH_ALIASES="${HOME}/.bash_aliases"
GITHUB_URL="${GITHUB_URL:-}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
PROJECT_NAME="${PROJECT_NAME:-$(basename "${ROOT_DIR}")}"
#TODO: Improve script name handling here, assuming more than one script may exist
# Example Array of scripts to install should be defined manifest.json or similar
# scripts=(
#     "create-env.sh"
#     "create-project.sh"
#     "create-manifest.sh"
#     "check-env.sh"
#     "davit-installer.sh"
#     "initialize-project.sh"
#     "install-dependencies.sh"
#     "setup-git.sh"
#     "create-readme.sh"
#     "update-gitignore.sh"
#     "create-script.sh"
#     "cat2md.sh"
#     "deploy.sh"
#     "backup.sh"
#     "monitor.sh"
#     "cleanup.sh"
#     "uninstall.sh"
#     "helpme.sh"
#     "setup-vscode.sh"
#     "logger.sh"
#     "your-script.sh"
# )

# Define colors for output (foreground only)
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RESET="\033[0m"

# Basic logging function (local, until central logging is available)
log() {
    local level="$1"
    shift
    mkdir -p "$LOG_DIR"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $*" >> "$LOG_FILE"
}

# Check for required commands
check_dependencies() {
    local deps=("curl" "git" "dialog")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            echo -e "${YELLOW}Installing $dep...${RESET}"
            sudo apt update && sudo apt install -y "$dep"
            log "INFO" "Installed dependency: $dep"
        fi
    done
}

# Install git-cliff for changelog generation
# FIXME: should not be part of davit-installer, but a separate script
install_git_cliff() {
    if ! command -v git-cliff &> /dev/null; then
        echo -e "${YELLOW}Installing git-cliff...${RESET}"
        curl -sSL https://github.com/orhun/git-cliff/releases/latest/download/git-cliff-linux-amd64.tar.gz | sudo tar -xz -C /usr/local/bin --strip-components=1 git-cliff-*/git-cliff
        log "INFO" "Installed git-cliff"
    fi
}

# Install the main script
# FIXME: single script assumption here, should be more generic requires $1
install_script() {
    echo -e "${GREEN}Installing ${PROJECT_NAME} script...${RESET}"
    mkdir -p "$INSTALL_DIR"
    local source_script="${ROOT_DIR}/scripts/${SCRIPT_NAME}"
    if [[ -f "$source_script" ]]; then
        sudo cp "$source_script" "${INSTALL_DIR}/"
        sudo chmod +x "${INSTALL_DIR}/${SCRIPT_NAME}"
        log "INFO" "Installed ${SCRIPT_NAME} to ${INSTALL_DIR}"
    else
        echo -e "${RED}Error:${RESET} ${SCRIPT_NAME} not found in ${ROOT_DIR}/scripts"
        log "ERROR" "Failed to find ${SCRIPT_NAME}"
        exit 1
    fi
}

# Set up alias if ALIAS is defined in .env
setup_alias() {
    if [[ -z "${ALIAS}" ]]; then
        echo -e "${YELLOW}Warning:${RESET} No ALIAS defined in .env. Skipping alias setup."
        log "WARN" "No ALIAS defined; skipping alias setup"
        return
    fi
    local script_path="${INSTALL_DIR}/${SCRIPT_NAME}"
    if ! grep -q "alias ${ALIAS}=" "$BASH_ALIASES" 2>/dev/null; then
        echo "alias ${ALIAS}='${script_path}'" >> "$BASH_ALIASES"
        log "INFO" "Added alias ${ALIAS} for ${script_path}"
        echo -e "${GREEN}Alias added:${RESET} ${ALIAS} -> ${script_path}"
    else
        echo -e "${YELLOW}Warning:${RESET} Alias ${ALIAS} already exists."
        log "WARN" "Alias ${ALIAS} already exists"
    fi
}

# Clone repository if not already present (if GITHUB_URL is defined)
clone_repository() {
    if [[ -z "${GITHUB_URL}" ]]; then
        echo -e "${YELLOW}Warning:${RESET} No GIT_URL defined in .env. Skipping clone."
        log "WARN" "No GIT_URL defined; skipping clone"
        return
    fi
    if [[ ! -d "${ROOT_DIR}/.git" ]]; then
        echo -e "${GREEN}Cloning repository from ${GIT_URL}...${RESET}"
        local clone_url="${GIT_URL}"
        if [[ -n "${GITHUB_TOKEN}" && "${GIT_URL}" =~ ^https://github.com ]]; then
            clone_url="https://${GITHUB_TOKEN}@${GIT_URL#https://}"
        fi
        git clone "${clone_url}" "${ROOT_DIR}"
        log "INFO" "Cloned repository from ${GIT_URL} to ${ROOT_DIR}"
    else
        echo -e "${YELLOW}Repository already exists at ${ROOT_DIR}${RESET}"
        log "INFO" "Repository already exists at ${ROOT_DIR}"
    fi
}

# Generate CHANGELOG.md using git-cliff (if cliff.toml exists)
generate_changelog() {
    if [[ ! -f "${ROOT_DIR}/cliff.toml" || ! -d "${ROOT_DIR}/.git" ]]; then
        echo -e "${YELLOW}Skipping changelog generation: cliff.toml or .git not found${RESET}"
        log "WARN" "Changelog generation skipped: missing cliff.toml or .git"
        return
    fi
    echo -e "${GREEN}Generating CHANGELOG.md...${RESET}"
    cd "${ROOT_DIR}"
    if [[ -n "${GITHUB_TOKEN}" ]]; then
        GITHUB_TOKEN="${GITHUB_TOKEN}" git-cliff --config cliff.toml --output CHANGELOG.md
    else
        git-cliff --config cliff.toml --output CHANGELOG.md
    fi
    log "INFO" "Generated CHANGELOG.md"
    cd - >/dev/null
}

# Main installation logic
main() {
    echo -e "${GREEN}Starting installation of ${PROJECT_NAME}...${RESET}"
    log "INFO" "Starting installation"

    check_dependencies
  #  install_git_cliff  # Temporarily disabled, see FIXME above
  #  clone_repository   # Disabled to avoid overwriting existing repo
    install_script    #FIXME: should be more generic to handle multiple scripts according to manifest
    setup_alias       # Setup alias if defined in manifest/.env or in scritps header
   # generate_changelog  # Versioning and changelog generation is optional

    echo -e "${GREEN}Installation complete!${RESET}"
    if [[ -n "${ALIAS}" ]]; then
        echo "Run 'source ~/.bash_aliases' to use the '${ALIAS}' alias."
    fi
    log "INFO" "Installation completed successfully"
}

main "$@"