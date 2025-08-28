#!/usr/bin/env bash
# scripts/create-env.sh
# Version: 0.0.2
# Description: Create or update .env from .env-example for DavitTec projects.
# Alias: Generic

# Set strict mode
set -euo pipefail
trap 'log "ERROR" "Trap caught error $?"' ERR

# Load .env if exists (for LOG_FILE, etc.)
ROOT_DIR="$(pwd)"
ENV_FILE="${ROOT_DIR}/.env"
ENV_LOCAL_FILE="${ROOT_DIR}/.env-local"
ENV_EXAMPLE_FILE="${ROOT_DIR}/.env-example"
if [[ ! -f "${ENV_FILE}" && -f "${ENV_LOCAL_FILE}" ]]; then
    ENV_FILE="${ENV_LOCAL_FILE}"
fi

# Defaults if no .env
LOG_DIR="${LOG_DIR:-${ROOT_DIR}/logs}"
LOG_FILE="${LOG_FILE:-${LOG_DIR}/davit-installer.log}"

# Colors
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RESET="\033[0m"

# Logging
log() {
    local level="$1"
    shift
    mkdir -p "${LOG_DIR}"
    printf "%s [%s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "${level}" "$*" >> "${LOG_FILE}"
}

# Read defaults from .env-example safely (no eval)
declare -A defaults
while IFS='=' read -r key value; do
    if [[ -n "${key}" && ! "${key}" =~ ^# ]]; then
        value="${value%% #*}"  # Strip comments
        value="${value#\"}"    # Strip leading quote
        value="${value%\"}"    # Strip trailing quote
        defaults["${key}"]="${value}"
    fi
done < <(grep -v '^#' "${ENV_EXAMPLE_FILE}" | grep -v '^$')

# Create .env interactively
create_env() {
    local output_file="$1"
    local domain host project_name git_user github_user script_name alias git_type requirements git_enabled github_token

    printf "%bCreating %s from .env-example...%b\n" "${GREEN}" "${output_file}" "${RESET}"
    log "INFO" "Starting .env creation for ${output_file}"

    # Prompts with defaults
    read -r -p "Enter DOMAIN [${defaults[DOMAIN]}]: " domain
    domain="${domain:-${defaults[DOMAIN]}}"
    read -r -p "Enter HOST [${defaults[HOST]}]: " host
    host="${host:-${defaults[HOST]}}"
    read -r -p "Enter PROJECT_NAME [${defaults[PROJECT_NAME]}]: " project_name
    project_name="${project_name:-${defaults[PROJECT_NAME]}}"
    read -r -p "Enter GIT_USER [${defaults[GIT_USER]}]: " git_user
    git_user="${git_user:-${defaults[GIT_USER]}}"
    read -r -p "Enter GITHUB_USER [${defaults[GITHUB_USER]}]: " github_user
    github_user="${github_user:-${defaults[GITHUB_USER]}}"
    read -r -p "Enter SCRIPT_NAME [${defaults[SCRIPT_NAME]-}]: " script_name
    script_name="${script_name:-${defaults[SCRIPT_NAME]-}}"
    read -r -p "Enter ALIAS [${defaults[ALIAS]-}]: " alias
    alias="${alias:-${defaults[ALIAS]-}}"
    read -r -p "Enter GIT_TYPE [${defaults[GIT_TYPE]}]: " git_type
    git_type="${git_type:-${defaults[GIT_TYPE]}}"
    read -r -p "Enter REQUIREMENTS (true/false) [${defaults[REQUIREMENTS]}]: " requirements
    requirements="${requirements:-${defaults[REQUIREMENTS]}}"
    read -r -p "Enter GIT_ENABLED (true/false) [${defaults[GIT_ENABLED]}]: " git_enabled
    git_enabled="${git_enabled:-${defaults[GIT_ENABLED]}}"
    read -r -p "Enter GITHUB_TOKEN (leave empty for none): " github_token
    read -r -p "Enter SYNC_LEVEL (patch/minor/major) [${defaults[SYNC_LEVEL]}]: " sync_level
    sync_level="${sync_level:-${defaults[SYNC_LEVEL]}}"

    # Copy and update (use @ as sed delimiter to avoid / issues)
    cp "${ENV_EXAMPLE_FILE}" "${output_file}"
    sed -i "s@^DOMAIN=.*@DOMAIN=\"${domain}\"@" "${output_file}"
    sed -i "s@^HOST=.*@HOST=\"${host}\"@" "${output_file}"
    sed -i "s@^AUTHOR=.*@AUTHOR=\"${USER:-$(whoami)}\"@" "${output_file}"
    sed -i "s@^PROJECT_NAME=.*@PROJECT_NAME=\"${project_name}\"@" "${output_file}"
    sed -i "s@^VERSION=.*@VERSION=\"0.0.1\"@" "${output_file}"
    sed -i "s@^CREATED=.*@CREATED=\"$(date '+%Y%m%d-%H:%M')\"@" "${output_file}"
    sed -i "s@^LAST_VISITED=.*@LAST_VISITED=\"$(date '+%Y-%m-%d %H:%M:%S')\"@" "${output_file}"
    sed -i "s@^DirectoryName=.*@DirectoryName=\"$(basename "${PWD}")\"@" "${output_file}"
    sed -i "s@^OPT_DIR=.*@OPT_DIR=\"/opt/${domain}\"@" "${output_file}"
    sed -i "s@^BIN_DIR=.*@BIN_DIR=\"/opt/${domain}/bin\"@" "${output_file}"
    sed -i "s@^DEV_DIR=.*@DEV_DIR=\"/opt/${domain}/development\"@" "${output_file}"
    sed -i "s@^ROOT_DIR=.*@ROOT_DIR=\"/opt/${domain}/development/${project_name}\"@" "${output_file}"
    sed -i "s@^ARCHIVES_DIR=.*@ARCHIVES_DIR=\"/opt/${domain}/development/${project_name}/archives\"@" "${output_file}"
    sed -i "s@^TEMP_DIR=.*@TEMP_DIR=\"/opt/${domain}/development/${project_name}/tmp/${project_name}\"@" "${output_file}"
    sed -i "s@^TEST_DIR=.*@TEST_DIR=\"/opt/${domain}/development/${project_name}/tests/${project_name}.log\"@" "${output_file}"
    sed -i "s@^DB_FILE=.*@DB_FILE=\"/opt/${domain}/development/${project_name}/data/files.json\"@" "${output_file}"
    sed -i "s@^LOG_DIR=.*@LOG_DIR=\"/opt/${domain}/development/${project_name}/logs\"@" "${output_file}"
    sed -i "s@^LOG_FILE=.*@LOG_FILE=\"/opt/${domain}/development/${project_name}/logs/${project_name}.log\"@" "${output_file}"
    sed -i "s@^SCRIPT_NAME=.*@SCRIPT_NAME=\"${script_name}\"@" "${output_file}"
    sed -i "s@^ALIAS=.*@ALIAS=\"${alias}\"@" "${output_file}"
    sed -i "s@^REQUIREMENTS=.*@REQUIREMENTS=${requirements}@" "${output_file}"
    sed -i "s@^SERVER=.*@SERVER=\"${host}\"@" "${output_file}"
    sed -i "s@^GIT_ENABLED=.*@GIT_ENABLED=${git_enabled}@" "${output_file}"
    sed -i "s@^GIT_TYPE=.*@GIT_TYPE=\"${git_type}\"@" "${output_file}"
    sed -i "s@^GIT_USER=.*@GIT_USER=\"${git_user}\"@" "${output_file}"
    sed -i "s@^GITHUB_USER=.*@GITHUB_USER=\"${github_user}\"@" "${output_file}"
    sed -i "s@^GIT_IGNORE_TEMPLATE=.*@GIT_IGNORE_TEMPLATE=\"${defaults[GIT_IGNORE_TEMPLATE]:-node+shell+davit}\"@" "${output_file}"
    sed -i "s@^GIT_IGNORE_FILE=.*@GIT_IGNORE_FILE=\"${defaults[GIT_IGNORE_FILE]:-.gitignore}\"@" "${output_file}"
    sed -i "s@^GITHUB_URL=.*@GITHUB_URL=\"https://github.com/${github_user}/${project_name}\"@" "${output_file}"
    sed -i "s@^GITHUB_TOKEN=.*@GITHUB_TOKEN=\"${github_token}\"@" "${output_file}"
    sed -i "s@^SYNC_LEVEL=.*@SYNC_LEVEL=\"${sync_level}\"@" "${output_file}"

    # Validate required keys
    required_keys=(DOMAIN PROJECT_NAME VERSION SYNC_LEVEL)
    for key in "${required_keys[@]}"; do
        if ! grep -q "^${key}=" "${output_file}"; then
            log "ERROR" "Missing required key ${key} in ${output_file}"
            printf "%bError: Missing %s in %s%b\n" "${RED}" "${key}" "${output_file}" "${RESET}"
            exit 1
        fi
    done

    printf "%bCreated %s%b\n" "${GREEN}" "${output_file}" "${RESET}"
    log "INFO" "Created ${output_file} with updated values"
}

# Main
main() {
    if [[ -f "${ENV_FILE}" || -f "${ENV_LOCAL_FILE}" ]]; then
        printf "%bWarning: .env or .env-local already exists.%b\n" "${YELLOW}" "${RESET}"
        read -r -p "Overwrite .env? (y/n) [n]: " overwrite
        if [[ "${overwrite:-n}" != "y" ]]; then
            printf "Aborted.\n"
            exit 0
        fi
    fi
    create_env "${ENV_FILE}"
}

main "$@"

# End of create-env.sh