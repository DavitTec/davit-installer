#!/usr/bin/env bash
# create-manifest.sh
# Version: 0.0.1
# Description: Generic script to create or update manifest.json for DavitTec projects
# Extracts metadata from script comments (# Version:, # Description:, # Alias:)

# Set strict mode
set -euo pipefail

# Load .env or .env-local
ROOT_DIR="$(pwd)"
ENV_FILE="${ROOT_DIR}/.env"
ENV_LOCAL_FILE="${ROOT_DIR}/.env-local"
if [[ ! -f "$ENV_FILE" && -f "$ENV_LOCAL_FILE" ]]; then
    ENV_FILE="$ENV_LOCAL_FILE"
fi
#TODO: Check that ENV_FILE exists and its Version is set above 0.1.1
#TODO: Consider using 'set -a' to export all variables after sourcing .env
#TODO: Validate required variables are set after sourcing .env
#Fixme: Not formating the manifest.json corectly. 

if [[ -f "$ENV_FILE" ]]; then
    while IFS='=' read -r key value; do
        if [[ -n "$key" && ! "$key" =~ ^# ]]; then
            value=$(echo "$value" | sed 's/^"\|"$//g')
            export "$key=$value"
        fi
    done < <(grep -v '^#' "$ENV_FILE" | grep -v '^$')
fi

# Define paths from .env or defaults
MANIFEST_FILE="${ROOT_DIR:-.}/manifest.json"
SCRIPTS_DIR="${ROOT_DIR:-.}/scripts"
LOG_DIR="${LOG_DIR:-${ROOT_DIR}/logs}"
LOG_FILE="${LOG_FILE:-${LOG_DIR}/${PROJECT_NAME:-project}.log}"

# Define colors
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RESET="\033[0m"

# Basic logging
log() {
    local level="$1"
    shift
    mkdir -p "$LOG_DIR"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $*" >> "$LOG_FILE"
}

# Function to validate script file headers meet standards
validate_script_headers() {
    local file="$1"
    local valid=true
    local version_regex='^#[\ ]*Version:[\ ]*[0-9]+\.[0-9]+\.[0-9]+$'
    local description_regex='^#[\ ]*Description:[\ ]*.+$'
    local alias_regex='^#[\ ]*Alias:[\ ]*.+$'

    while IFS= read -r line; do
        line=$(echo "$line" | sed 's/^\s*//;s/\s*$//')
        if [[ "$line" =~ ^# ]]; then
            if [[ "$line" =~ $version_regex ]]; then
                version_found=true
            elif [[ "$line" =~ $description_regex ]]; then
                description_found=true
            elif [[ "$line" =~ $alias_regex ]]; then
                alias_found=true
            fi
        fi
    done < "$file"
    if [[ "$version_found" != true ]]; then
        echo -e "${RED}Error:${RESET} Missing or invalid Version header in $file"
        # add "#TODO:[script_name] Add version in header" to log and to script footer.
        valid=false
    fi
    if [[ "$description_found" != true ]]; then
        echo -e "${RED}Error:${RESET} Missing or invalid Description header in $file"
        # add "#TODO:[script_name] Add description in header" to log and to script footer.
        valid=false
    fi
    if [[ "$alias_found" != true ]]; then
        echo -e "${RED}Error:${RESET} Missing or invalid Alias header in $file"
        # add "#TODO:[script_name] Add alias in header" to log and to script footer.
        valid=false
    fi
    $valid && return 0 || return 1
}

# Extract metadata from script file
extract_metadata() {
    local file="$1"
    local version="0.0.1"
    local description="No description available"
    local alias=""
    while IFS= read -r line; do
        line=$(echo "$line" | sed 's/^\s*//;s/\s*$//')
        if [[ "$line" =~ ^#[\ ]*Version:[\ ]*(.*)$ ]]; then
            version="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^#[\ ]*Description:[\ ]*(.*)$ ]]; then
            description="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^#[\ ]*Alias:[\ ]*(.*)$ ]]; then
            alias="${BASH_REMATCH[1]}"
        fi
    done < "$file"
    echo "$alias" "$description" "$version"
}

# Create or update manifest
create_or_update_manifest() {
    local update="${1:-false}"
    local manifest=()
    if [[ "$update" == "true" && -f "$MANIFEST_FILE" ]]; then
        manifest=$(jq -c '.[]' "$MANIFEST_FILE" | while read -r entry; do echo "$entry"; done)
    fi

    local new_manifest=()
    while IFS= read -r file; do
        if [[ -f "$file" && "$file" =~ \.sh$ ]]; then
            read -r alias desc version <<< "$(extract_metadata "$file")"
            alias="${alias:-$(basename "${file%.*}")}"
            srcName="$(basename "$file")"
            entry="{\"alias\":\"$alias\",\"description\":\"$desc\",\"srcName\":\"$srcName\",\"version\":\"$version\",\"installed\":\"installed\",\"remote_version\":\"$version\",\"repo_path\":\"scripts/$srcName\"}"
            # Update if exists, else add
            found=false
            for i in "${!manifest[@]}"; do
                if [[ "${manifest[$i]}" =~ \"srcName\":\"$srcName\" ]]; then
                    manifest[$i]="$entry"
                    found=true
                    break
                fi
            done
            if [[ "$found" == "false" ]]; then
                new_manifest+=("$entry")
            fi
        fi
    done < <(find "$SCRIPTS_DIR" -type f -name "*.sh")

    # Combine and write to JSON
    printf '%s\n' "${manifest[@]}" "${new_manifest[@]}" | jq -s > "$MANIFEST_FILE"
    echo -e "${GREEN}Manifest ${update:+updated}${update:+ }created at $MANIFEST_FILE${RESET}"
    log "INFO" "Manifest ${update:+updated}${update:+ }created"
}

# Integrate with cat2.md (placeholder: assume cat2.md generates combined.md)
integrate_cat2md() {
    local cat2md_script="${ROOT_DIR}/scripts/cat2.md"  # Assume path
    if [[ -x "$cat2md_script" ]]; then
        echo -e "${YELLOW}Running cat2.md for snapshot...${RESET}"
        "$cat2md_script"
        log "INFO" "Ran cat2.md for project snapshot"
        # Placeholder: Parse combined.md if needed for manifest updates
    else
        echo -e "${YELLOW}cat2.md not found or not executable. Skipping integration.${RESET}"
        log "WARN" "cat2.md integration skipped"
    fi
}

# Version bump and git tag (optional)
bump_version() {
    local bump_type="$1"  # major, minor, patch
    local current_version=$(jq -r '.[0].version // "0.0.0"' "$MANIFEST_FILE")
    IFS='.' read -r major minor patch <<< "$current_version"
    case "$bump_type" in
        major) ((major++)); minor=0; patch=0 ;;
        minor) ((minor++)); patch=0 ;;
        patch) ((patch++)) ;;
    esac
    new_version="$major.$minor.$patch"
    # Update manifest versions (simplified: update all to new_version)
    jq --arg ver "$new_version" 'map(.version = $ver | .remote_version = $ver)' "$MANIFEST_FILE" > tmp.json && mv tmp.json "$MANIFEST_FILE"
    git add "$MANIFEST_FILE"
    git commit -m "chore(release): bump version to $new_version"
    git tag "v$new_version"
    git push origin --tags
    echo -e "${GREEN}Version bumped to $new_version and tagged.${RESET}"
    log "INFO" "Version bumped to $new_version"
}

# Usage
usage() {
    echo -e "${GREEN}Usage:${RESET} $0 [options]"
    echo "Options:"
    echo "  --create       Create new manifest.json"
    echo "  --update       Update existing manifest.json"
    echo "  --integrate    Integrate with cat2.md snapshot"
    echo "  --bump <type>  Bump version (major/minor/patch) and git tag"
    echo "  -h, --help     Show this help"
    exit 0
}

# Main
main() {
    local create=false update=false integrate=false bump=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -c|--create) create=true ;;
            -u|--update) update=true ;;
            -i|--integrate) integrate=true ;;
            -b|--bump) shift; bump="$1" ;;
            -h|--help) usage ;;
            *) echo "Invalid option: $1"; usage ;;
        esac
        shift
    done

    if [[ "$integrate" == "true" ]]; then
        integrate_cat2md
    fi

    if [[ "$create" == "true" || "$update" == "true" ]]; then
        # validate_script_headers in "$SCRIPTS_DIR" loop all scripts
        # validate_script_registry for alias conflicts
        create_or_update_manifest "$update"
    fi

    if [[ -n "$bump" ]]; then
        bump_version "$bump"
    fi
}

main "$@"