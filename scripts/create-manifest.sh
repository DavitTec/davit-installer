#!/usr/bin/env bash
# scripts/create-manifest.sh
# Version: 0.0.2
# Description: Generic script to create or update manifest.json for DavitTec projects. Extracts metadata from script comments.
# Alias: Generic

# Set strict mode
set -euo pipefail
trap 'log "ERROR" "Trap caught error $?"' ERR

# Load .env safely
ROOT_DIR="$(pwd)"
ENV_FILE="${ROOT_DIR}/.env"
if [[ -f "${ENV_FILE}" ]]; then
    while IFS='=' read -r key value; do
        if [[ -n "${key}" && ! "${key}" =~ ^# ]]; then
            value="${value#\"}"    # Strip quotes
            value="${value%\"}"
            export "${key}=${value}"
        fi
    done < <(grep -v '^#' "${ENV_FILE}" | grep -v '^$')
else
    # If no .env, create it
    "${ROOT_DIR}/scripts/create-env.sh"
    . "${ENV_FILE}"  # Source after creation
fi

# Paths
MANIFEST_FILE="${ROOT_DIR:-.}/manifest.json"
SCRIPTS_DIR="${ROOT_DIR:-.}/scripts"
LOG_DIR="${LOG_DIR:-${ROOT_DIR}/logs}"
LOG_FILE="${LOG_FILE:-${LOG_DIR}/${PROJECT_NAME:-project}.log}"
MASTER_MANIFEST="/opt/davit/development/manifest.json"

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

# Validate script headers
validate_script_headers() {
    local file="$1"
    local version_found=false description_found=false alias_found=false
    local version_regex='^#[ ]*Version:[ ]*[0-9]+\.[0-9]+\.[0-9]+$'
    local description_regex='^#[ ]*Description:[ ]*.+$'
    local alias_regex='^#[ ]*Alias:[ ]*.+$'

    while IFS= read -r line; do
        line="${line#"${line%%[![:space:]]*}"}"  # Trim leading spaces
        line="${line%"${line##*[![:space:]]}"}"  # Trim trailing spaces
        if [[ "${line}" =~ ^# ]]; then
            if [[ "${line}" =~ ${version_regex} ]]; then version_found=true; fi
            if [[ "${line}" =~ ${description_regex} ]]; then description_found=true; fi
            if [[ "${line}" =~ ${alias_regex} ]]; then alias_found=true; fi
        fi
    done < "${file}"

    if ! "${version_found}"; then
        printf "%bError: Missing/invalid Version header in %s%b\n" "${RED}" "${file}" "${RESET}"
        echo "#TODO: Add Version header" >> "${file}"
    fi
    if ! "${description_found}"; then
        printf "%bError: Missing/invalid Description header in %s%b\n" "${RED}" "${file}" "${RESET}"
        echo "#TODO: Add Description header" >> "${file}"
    fi
    if ! "${alias_found}"; then
        printf "%bError: Missing/invalid Alias header in %s%b\n" "${RED}" "${file}" "${RESET}"
        echo "#TODO: Add Alias header" >> "${file}"
    fi
    [[ "${version_found}" == true && "${description_found}" == true && "${alias_found}" == true ]] && return 0 || return 1
}

# Extract metadata
extract_metadata() {
    local file="$1"
    local version="0.0.1" description="No description available" alias=""
    while IFS= read -r line; do
        line="${line#"${line%%[![:space:]]*}"}"  # Trim
        line="${line%"${line##*[![:space:]]}"}"
        if [[ "${line}" =~ ^#[ ]*Version:[ ]*(.*)$ ]]; then version="${BASH_REMATCH[1]}"; fi
        if [[ "${line}" =~ ^#[ ]*Description:[ ]*(.*)$ ]]; then description="${BASH_REMATCH[1]}"; fi
        if [[ "${line}" =~ ^#[ ]*Alias:[ ]*(.*)$ ]]; then alias="${BASH_REMATCH[1]}"; fi
    done < "${file}"
    printf "%s %s %s\n" "${alias:-$(basename "${file%.*}")}" "${description}" "${version}"
}

# Create/update local manifest
create_or_update_manifest() {
    local update="${1:-false}"
    local manifest=()
    if [[ "${update}" == "true" && -f "${MANIFEST_FILE}" ]]; then
        mapfile -t manifest < <(jq -c '.[]' "${MANIFEST_FILE}")
    fi

    local new_manifest=()
    while IFS= read -r file; do
        if [[ -f "${file}" && "${file}" =~ \.sh$ ]]; then
            validate_script_headers "${file}" || log "WARN" "Header validation failed for ${file}"
            read -r alias desc version < <(extract_metadata "${file}")
            local srcName
            srcName="$(basename "${file}")"
            local entry
            entry="{\"project\":\"${PROJECT_NAME}\",\"alias\":\"${alias}\",\"description\":\"${desc}\",\"srcName\":\"${srcName}\",\"version\":\"${version}\",\"installed\":\"installed\",\"remote_version\":\"${version}\",\"repo_path\":\"${PROJECT_NAME}/scripts/${srcName}\"}"
            local found=false
            for i in "${!manifest[@]}"; do
                if [[ "${manifest[i]}" =~ \"srcName\":\"${srcName}\" ]]; then
                    manifest[i]="${entry}"
                    found=true
                    break
                fi
            done
            if ! "${found}"; then
                new_manifest+=("${entry}")
            fi
        fi
    done < <(find "${SCRIPTS_DIR}" -type f -name "*.sh")

    # Write JSON
    { printf '%s\n' "${manifest[@]}"; printf '%s\n' "${new_manifest[@]}"; } | jq -s . > "${MANIFEST_FILE}"
    printf "%bManifest %screated at %s%b\n" "${GREEN}" "${update:+updated }" "${MANIFEST_FILE}" "${RESET}"
    log "INFO" "Manifest ${update:+updated }created"
}

# Sync to master manifest
sync_master() {
    if [[ -f "${MASTER_MANIFEST}" ]]; then
        # Remove old entries for this project
        jq --arg proj "${PROJECT_NAME}" 'map(select(.repo_path | startswith($proj + "/") | not))' "${MASTER_MANIFEST}" > tmp.json
        # Add new
        jq -s 'add' tmp.json "${MANIFEST_FILE}" > "${MASTER_MANIFEST}"
        rm -f tmp.json
        log "INFO" "Synced to master manifest ${MASTER_MANIFEST}"
        printf "%bSynced to master manifest.%b\n" "${GREEN}" "${RESET}"
    else
        log "WARN" "Master manifest not found at ${MASTER_MANIFEST}. Skipping sync."
    fi
}

# Integrate with cat2md (placeholder)
integrate_cat2md() {
    local cat2md_script="${ROOT_DIR}/scripts/cat2.md"  # Assume path; update if different
    if [[ -x "${cat2md_script}" ]]; then
        printf "%bRunning cat2.md for snapshot...%b\n" "${YELLOW}" "${RESET}"
        "${cat2md_script}"
        log "INFO" "Ran cat2.md for project snapshot"
    else
        printf "%bcat2.md not found or not executable. Skipping.%b\n" "${YELLOW}" "${RESET}"
        log "WARN" "cat2.md integration skipped"
    fi
}

# Bump version and optional sync
bump_version() {
    local bump_type="$1"
    local current_version
    current_version=$(jq -r '.[0].version // "0.0.0"' "${MANIFEST_FILE}")
    local major minor patch
    IFS='.' read -r major minor patch <<< "${current_version}"
    case "${bump_type}" in
        major) ((major++)); minor=0; patch=0 ;;
        minor) ((minor++)); patch=0 ;;
        patch) ((patch++)) ;;
        *) printf "%bInvalid bump type.%b\n" "${RED}" "${RESET}"; exit 1 ;;
    esac
    local new_version="${major}.${minor}.${patch}"
    # Update all versions
    jq --arg ver "${new_version}" 'map(.version = $ver | .remote_version = $ver)' "${MANIFEST_FILE}" > tmp.json && mv tmp.json "${MANIFEST_FILE}"
    git add "${MANIFEST_FILE}"
    git commit -m "chore(release): bump version to ${new_version}"
    git tag "v${new_version}"
    git push origin --tags
    printf "%bVersion bumped to %s and tagged.%b\n" "${GREEN}" "${new_version}" "${RESET}"
    log "INFO" "Version bumped to ${new_version}"

    # Sync if level meets threshold
    local levels=(patch minor major)
    local bump_idx=0 sync_idx=0
    for i in "${!levels[@]}"; do
        [[ "${levels[i]}" == "${bump_type}" ]] && bump_idx="${i}"
        [[ "${levels[i]}" == "${SYNC_LEVEL}" ]] && sync_idx="${i}"
    done
    if (( bump_idx >= sync_idx )); then
        sync_master
    else
        log "INFO" "Bump level ${bump_type} below SYNC_LEVEL ${SYNC_LEVEL}. Skipping master sync."
    fi
}

# Usage
usage() {
    printf "%bUsage:%b %s [options]\n" "${GREEN}" "${RESET}" "$0"
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
            --create) create=true ;;
            --update) update=true ;;
            --integrate) integrate=true ;;
            --bump) shift; bump="$1" ;;
            -h|--help) usage ;;
            *) printf "Invalid option: %s\n" "$1"; usage ;;
        esac
        shift
    done

    [[ "${integrate}" == true ]] && integrate_cat2md
    if [[ "${create}" == true || "${update}" == true ]]; then
        create_or_update_manifest "${update}"
    fi
    [[ -n "${bump}" ]] && bump_version "${bump}"
}

main "$@"

# End of create-manifest.sh