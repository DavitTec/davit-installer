#!/usr/bin/env bash
# Version: 0.0.3
# Description: Generic script to create or update manifest.json for DavitTec projects. Extracts metadata from script comments.
# Alias: Generic

set -euo pipefail
trap 'log "ERROR" "Trap caught error $?"' ERR

# Load .env safely
ROOT_DIR="$(pwd)"
ENV_FILE="${ROOT_DIR}/.env"
if [[ ! -f "${ENV_FILE}" ]]; then
    echo "${RED}Error: .env missing. Run create-env.sh first.${RESET}"
    exit 1
fi
while IFS='=' read -r key value; do
    if [[ -n "${key}" && ! "${key}" =~ ^# ]]; then
        value="${value#\"}"; value="${value%\"}"
        export "${key}=${value}"
    fi
done < <(grep -v '^#' "${ENV_FILE}" | grep -v '^$')

# Check requirements (e.g., jq)
if ! command -v jq >/dev/null; then
    echo "${RED}Error: jq required but not installed.${RESET}"
    exit 1
fi
# Validate .env booleans/strings (example)
req_val="${REQUIREMENTS,,}"; if [[ "$req_val" != "true" && "$req_val" != "false" ]]; then echo "${RED}Error: Invalid REQUIREMENTS.${RESET}"; exit 1; fi
if [[ -z "${PROJECT_NAME}" || ${#PROJECT_NAME} -lt 3 ]]; then echo "${RED}Error: Invalid PROJECT_NAME.${RESET}"; exit 1; fi

# ... (keep paths, colors, log as before)

# Validate script headers with type checks
validate_script_headers() {
    local file="$1"
    local version_found=false description_found=false alias_found=false
    local version_regex='^[[:space:]]*#[[:space:]]*Version:[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+[[:space:]]*$'
    local description_regex='^[[:space:]]*#[[:space:]]*Description:[[:space:]]*.+[[:space:]]*$'
    local alias_regex='^[[:space:]]*#[[:space:]]*Alias:[[:space:]]*.+[[:space:]]*$'

    while IFS= read -r line; do
        if [[ "${line}" =~ $version_regex ]]; then version_found=true; fi
        if [[ "${line}" =~ $description_regex ]]; then description_found=true; fi
        if [[ "${line}" =~ $alias_regex ]]; then alias_found=true; fi
    done < "${file}"

    if ! $version_found; then echo "${RED}Error: Invalid Version in $file${RESET}"; echo "#TODO: Fix Version" >> "$file"; fi
    if ! $description_found; then echo "${RED}Error: Invalid Description in $file${RESET}"; echo "#TODO: Fix Description" >> "$file"; fi
    if ! $alias_found; then echo "${RED}Error: Invalid Alias in $file${RESET}"; echo "#TODO: Fix Alias" >> "$file"; fi
    [[ $version_found == true && $description_found == true && $alias_found == true ]] && return 0 || return 1
}

# Extract metadata with trimming
extract_metadata() {
    local file="$1"
    local version="0.0.1" description="No description available" alias=""
    while IFS= read -r line; do
        if [[ "${line}" =~ ^[[:space:]]*#[[:space:]]*Version:[[:space:]]*(.*)[[:space:]]*$ ]]; then
            version=$(echo "${BASH_REMATCH[1]}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            if ! [[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then echo "${RED}Error: Invalid semver $version in $file${RESET}"; exit 1; fi
        fi
        if [[ "${line}" =~ ^[[:space:]]*#[[:space:]]*Description:[[:space:]]*(.*)[[:space:]]*$ ]]; then
            description=$(echo "${BASH_REMATCH[1]}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            if [[ ${#description} -lt 10 ]]; then echo "${RED}Error: Description too short in $file${RESET}"; exit 1; fi
        fi
        if [[ "${line}" =~ ^[[:space:]]*#[[:space:]]*Alias:[[:space:]]*(.*)[[:space:]]*$ ]]; then
            alias=$(echo "${BASH_REMATCH[1]}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            if [[ -z $alias ]]; then echo "${RED}Error: Empty Alias in $file${RESET}"; exit 1; fi
        fi
    done < "$file"
    echo "$alias" "$description" "$version"
}

# ... (keep create_or_update_manifest, but add pre-check: find scripts | while read f; do validate_script_headers "$f" || exit 1; done)

# In main, before calling create_or_update_manifest: echo "Running pre-checks..."; # Add req checks here

# ... (rest as before)