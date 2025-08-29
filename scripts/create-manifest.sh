#!/usr/bin/env bash
# Version: 0.0.4
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

while IFS= read -r line || [[ -n "$line" ]]; do  # Handle last line without \n
    # Strip mid-line comments
    line="${line%%#*}"
    # Trim all whitespace
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    if [[ -z "$line" ]]; then continue; fi

    # Regex: KEY = VALUE with optional spaces around =
    if ! [[ "$line" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)\s*=\s*(.*)$ ]]; then
        echo "${RED}Error: Invalid line in .env: $line (strict format required)${RESET}"
        exit 1
    fi
    key="${BASH_REMATCH[1]}"
    value="${BASH_REMATCH[2]}"

    # Strip outer quotes (single or double)
    if [[ "$value" =~ ^\"(.*)\"$ ]] || [[ "$value" =~ ^\'(.*)\'$ ]]; then
        value="${BASH_REMATCH[1]}"
    else
        # Strict: Warn if value has spaces but wasn't quoted (potential issue)
        if [[ "$value" =~ [[:space:]] ]]; then
            echo "${YELLOW}Warning: Unquoted value with spaces in $key: '$value' (may be invalid; quote in .env)${RESET}"
            # Optionally: exit 1 for strictness
        fi
    fi

    # Export
    export "$key=$value"
done < "$ENV_FILE"

# Post-parsing strict validation (data types, lengths)
# Required keys
required_keys=("DOMAIN" "PROJECT_NAME" "VERSION" "SYNC_LEVEL")
for req in "${required_keys[@]}"; do
    if [[ -z "${!req}" ]]; then
        echo "${RED}Error: Missing required key $req in .env${RESET}"
        exit 1
    fi
done

# String length (example: PROJECT_NAME >=5)
if [[ ${#PROJECT_NAME} -lt 5 ]]; then
    echo "${RED}Error: PROJECT_NAME too short (min 5 chars)${RESET}"
    exit 1
fi

# Semver for VERSION
if ! [[ "${VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "${RED}Error: Invalid semver for VERSION: ${VERSION}${RESET}"
    exit 1
fi

# Boolean for REQUIREMENTS/GIT_ENABLED (case-insensitive)
req_val="${REQUIREMENTS,,}"
if [[ "$req_val" != "true" && "$req_val" != "false" ]]; then
    echo "${RED}Error: Invalid boolean for REQUIREMENTS: ${REQUIREMENTS}${RESET}"
    exit 1
fi
git_val="${GIT_ENABLED,,}"
if [[ "$git_val" != "true" && "$git_val" != "false" ]]; then
    echo "${RED}Error: Invalid boolean for GIT_ENABLED: ${GIT_ENABLED}${RESET}"
    exit 1
fi

# Add more: e.g., SYNC_LEVEL one of patch/minor/major
if ! [[ "${SYNC_LEVEL,,}" =~ ^(patch|minor|major)$ ]]; then
    echo "${RED}Error: Invalid SYNC_LEVEL: ${SYNC_LEVEL} (must be patch/minor/major)${RESET}"
    exit 1
fi

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