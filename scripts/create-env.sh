#!/usr/bin/env bash
# create-env.sh
# Version: 0.0.1
# Description: Generic script to create or update .env from .env-example for DavitTec projects

# Set strict mode
set -euo pipefail

# Determine project root and environment files
ROOT_DIR="$(pwd)"
ENV_EXAMPLE_FILE="${ROOT_DIR}/.env-example"
ENV_FILE="${ROOT_DIR}/.env"
ENV_LOCAL_FILE="${ROOT_DIR}/.env-local"

# Define colors for output (foreground only)
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RESET="\033[0m"

# Check for .env-example
if [[ ! -f "$ENV_EXAMPLE_FILE" ]]; then
    echo -e "${RED}Error:${RESET} .env-example not found in ${ROOT_DIR}"
    exit 1
fi

# Logging function (basic, writes to stdout or file if LOG_FILE is set)
log() {
    local level="$1"
    shift
    local log_message="$(date '+%Y-%m-%d %H:%M:%S') [$level] $*"
    echo "$log_message"
    if [[ -n "${LOG_FILE:-}" && -d "${LOG_DIR:-}" ]]; then
        mkdir -p "$LOG_DIR"
        echo "$log_message" >> "$LOG_FILE"
    fi
}

# Read defaults from .env-example and prompt for custom values
create_env() {
    local output_file="$1"
    local domain host project_name git_user github_user script_name alias git_type requirements git_enabled

    echo -e "${GREEN}Creating ${output_file} from .env-example...${RESET}"
    log "INFO" "Starting .env creation for ${output_file}"

    # Read defaults from .env-example
    while IFS='=' read -r key value; do
        if [[ -n "$key" && ! "$key" =~ ^# ]]; then
            value=$(echo "$value" | sed 's/^"\|"$//g')
            eval "${key}=${value}"
        fi
    done < <(grep -v '^#' "$ENV_EXAMPLE_FILE" | grep -v '^$')

    # Prompt for key values (with defaults)
    read -p "Enter DOMAIN [${DOMAIN}]: " domain
    domain=${domain:-${DOMAIN}}
    read -p "Enter HOST [${HOST}]: " host
    host=${host:-${HOST}}
    read -p "Enter PROJECT_NAME [${PROJECT_NAME}]: " project_name
    project_name=${project_name:-${PROJECT_NAME}}
    read -p "Enter GIT_USER [${GIT_USER}]: " git_user
    git_user=${git_user:-${GIT_USER}}
    read -p "Enter GITHUB_USER [${GITHUB_USER}]: " github_user
    github_user=${github_user:-${GITHUB_USER}}
    read -p "Enter SCRIPT_NAME [${SCRIPT_NAME}]: " script_name
    script_name=${script_name:-${SCRIPT_NAME}}
    read -p "Enter ALIAS [${ALIAS}]: " alias
    alias=${alias:-${ALIAS}}
    read -p "Enter GIT_TYPE [${GIT_TYPE}]: " git_type
    git_type=${git_type:-${GIT_TYPE}}
    read -p "Enter REQUIREMENTS (true/false) [${REQUIREMENTS}]: " requirements
    requirements=${requirements:-${REQUIREMENTS}}
    read -p "Enter GIT_ENABLED (true/false) [${GIT_ENABLED}]: " git_enabled
    git_enabled=${git_enabled:-${GIT_ENABLED}}
    read -p "Enter GITHUB_TOKEN (leave empty for none): " github_token

    # Generate .env with updated values
    cp "$ENV_EXAMPLE_FILE" "$output_file"
    sed -i "s|^DOMAIN=.*|DOMAIN=\"${domain}\"|" "$output_file"
    sed -i "s|^HOST=.*|HOST=\"${host}\"|" "$output_file"
    sed -i "s|^AUTHOR=.*|AUTHOR=\"${USER:-$(whoami)}\"|" "$output_file"
    sed -i "s|^PROJECT_NAME=.*|PROJECT_NAME=\"${project_name}\"|" "$output_file"
    sed -i "s|^VERSION=.*|VERSION=\"0.0.1\"|" "$output_file"
    sed -i "s|^CREATED=.*|CREATED=\"$(date '+%Y%m%d-%H:%M')\"|" "$output_file"
    sed -i "s|^LAST_VISITED=.*|LAST_VISITED=\"$(date '+%Y-%m-%d %H:%M:%S')\"|" "$output_file"
    sed -i "s|^DirectoryName=.*|DirectoryName=\"$(basename "${PWD}")\"|" "$output_file"
    sed -i "s|^OPT_DIR=.*|OPT_DIR=\"/opt/${domain}\"|" "$output_file"
    sed -i "s|^BIN_DIR=.*|BIN_DIR=\"/opt/${domain}/bin\"|" "$output_file"
    sed -i "s|^DEV_DIR=.*|DEV_DIR=\"/opt/${domain}/development\"|" "$output_file"
    sed -i "s|^ROOT_DIR=.*|ROOT_DIR=\"/opt/${domain}/development/${project_name}\"|" "$output_file"
    sed -i "s|^ARCHIVES_DIR=.*|ARCHIVES_DIR=\"/opt/${domain}/development/${project_name}/archives\"|" "$output_file"
    sed -i "s|^TEMP_DIR=.*|TEMP_DIR=\"/opt/${domain}/development/${project_name}/tmp/${project_name}\"|" "$output_file"
    sed -i "s|^TEST_DIR=.*|TEST_DIR=\"/opt/${domain}/development/${project_name}/tests/${project_name}.log\"|" "$output_file"
    sed -i "s|^DB_FILE=.*|DB_FILE=\"/opt/${domain}/development/${project_name}/data/files.json\"|" "$output_file"
    sed -i "s|^LOG_DIR=.*|LOG_DIR=\"/opt/${domain}/development/${project_name}/logs\"|" "$output_file"
    sed -i "s|^LOG_FILE=.*|LOG_FILE=\"/opt/${domain}/development/${project_name}/logs/${project_name}.log\"|" "$output_file"
    sed -i "s|^SCRIPT_NAME=.*|SCRIPT_NAME=\"${script_name}\"|" "$output_file"
    sed -i "s|^ALIAS=.*|ALIAS=\"${alias}\"|" "$output_file"
    sed -i "s|^REQUIREMENTS=.*|REQUIREMENTS=${requirements}|" "$output_file"
    sed -i "s|^SERVER=.*|SERVER=\"${host}\"|" "$output_file"
    sed -i "s|^GIT_ENABLED=.*|GIT_ENABLED=${git_enabled}|" "$output_file"
    sed -i "s|^GIT_TYPE=.*|GIT_TYPE=\"${git_type}\"|" "$output_file"
    sed -i "s|^GIT_USER=.*|GIT_USER=\"${git_user}\"|" "$output_file"
    sed -i "s|^GITHUB_USER=.*|GITHUB_USER=\"${github_user}\"|" "$output_file"
    sed -i "s|^GIT_IGNORE_TEMPLATE=.*|GIT_IGNORE_TEMPLATE=\"${GIT_IGNORE_TEMPLATE:-node+shell+davit}\"|" "$output_file"
    sed -i "s|^GIT_IGNORE_FILE=.*|GIT_IGNORE_FILE=\"${GIT_IGNORE_FILE:-.gitignore}\"|" "$output_file"
    sed -i "s|^GITHUB_URL=.*|GITHUB_URL=\"https://github.com/${github_user}/${project_name}\"|" "$output_file"
    sed -i "s|^GITHUB_TOKEN=.*|GITHUB_TOKEN=\"${github_token}\"|" "$output_file"

    echo -e "${GREEN}Created ${output_file}${RESET}"
    log "INFO" "Created ${output_file} with updated values"
}

# Main logic
main() {
    if [[ -f "$ENV_FILE" || -f "$ENV_LOCAL_FILE" ]]; then
        echo -e "${YELLOW}Warning:${RESET} .env or .env-local already exists."
        read -p "Overwrite .env? (y/n) [n]: " overwrite
        if [[ "${overwrite:-n}" != "y" ]]; then
            echo "Aborted."
            exit 0
        fi
    fi
    create_env "$ENV_FILE"
}

main "$@"