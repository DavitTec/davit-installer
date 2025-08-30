#!/usr/bin/env bash
# check-env.sh
# Version: 0.0.3
# Description: Modular .env validator comparing target to standard, with per-key tests and logging.
# Alias: chkenv, checkenv

set -euo pipefail

# Globals
STANDARD_ENV="/opt/davit/development/.env-standard"
REQUIREMENTS_YAML="requirements.yaml"  # Renamed for clarity
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RESET="\033[0m"
LOG_FILE="check-env.log"  # Relative to cwd
MIN_KEYS_THRESHOLD=5  # Warn if fewer keys

# Check for yq (optional, only if requirements.yaml exists)
check_yq() {
    if [[ -f "$REQUIREMENTS_YAML" ]] && ! command -v yq >/dev/null; then
        echo "${RED}Error: yq required for parsing $REQUIREMENTS_YAML. Install via package manager (e.g., sudo apt install yq).${RESET}"
        exit 1
    fi
}

# Load env file into arrays (keys in order, assoc for values/comments)
load_env_file() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo "${RED}Error: File $file not found.${RESET}"
        return 1
    fi

    declare -g -a loaded_keys=()
    declare -g -A loaded_values=()
    declare -g -A loaded_comments=()
    local line_num=0
    while IFS= read -r line || [[ -n "$line" ]]; do
        ((line_num++))
        line="${line#"${line%%[![:space:]]*}"}"  # Trim leading
        line="${line%"${line##*[![:space:]]}"}"  # Trim trailing
        if [[ -z "$line" || "$line" =~ ^# ]]; then continue; fi  # Skip blank/comments

        # Parse KEY="value" # comment
        if [[ "$line" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)\s*=\s*(\"[^\"]*\"|\'[^\']*\'|[^#]*)(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            local comment="${BASH_REMATCH[3]}"

            # Strip outer quotes from value
            value="${value#\"}"; value="${value%\"}"
            value="${value#\'}"; value="${value%\'}"

            # Trim comment (if starts with #)
            comment="${comment#"#"}"
            comment="${comment#"${comment%%[![:space:]]*}"}"

            loaded_keys+=("$key")
            loaded_values["$key"]="$value"
            loaded_comments["$key"]="$comment"
        else
            echo "${YELLOW}Warning: Invalid line $line_num in $file: '$line'. Skipping.${RESET}"
        fi
    done < "$file"
    return 0
}

# Find first valid target .env
find_target_env() {
    local possible_targets=(".env" ".env-local" ".env-example")
    for target in "${possible_targets[@]}"; do
        if [[ -f "$target" ]]; then
            echo "$target"
            return 0
        fi
    done
    echo "${RED}FAIL: No target .env found (checked: ${possible_targets[*]}).${RESET}"
    exit 1
}

# Get validation rules per key (from requirements.yaml or dummy)
get_validation_rules() {
    local key="$1"
    if [[ -f "$REQUIREMENTS_YAML" ]]; then
        local required type min_length error_code help_comment
        required=$(yq e ".validation_rules.$key.required // false" "$REQUIREMENTS_YAML")
        type=$(yq e ".validation_rules.$key.type // 'string'" "$REQUIREMENTS_YAML")
        min_length=$(yq e ".validation_rules.$key.min_length // 0" "$REQUIREMENTS_YAML")
        error_code=$(yq e ".validation_rules.$key.error_code // 'E999'" "$REQUIREMENTS_YAML")
        help_comment=$(yq e ".validation_rules.$key.help_comment // 'Unknown key'" "$REQUIREMENTS_YAML")
        if [[ "$type" == "enum" ]]; then
            local values
            values=$(yq e ".validation_rules.$key.values | join(' ')" "$REQUIREMENTS_YAML")
            echo "$required $type $values $min_length $error_code $help_comment"
        else
            echo "$required $type none $min_length $error_code $help_comment"
        fi
    else
        # Dummy rules until requirements.yaml updated
        case "$key" in
            DOMAIN) echo "true string none 3 E001 Project domain (e.g., 'davit')";;
            HOST) echo "true string none 4 E002 Server hostname (e.g., 'node')";;
            PROJECT_NAME) echo "true string none 5 E003 Project name (must match folder)";;
            VERSION) echo "true semver none 0 E004 Semantic version (X.Y.Z)";;
            REQUIREMENTS) echo "false boolean none 0 E012 Check requirements (true/false, optional default true)";;
            GIT_ENABLED) echo "false boolean none 0 E013 Enable Git (true/false, optional default false)";;
            SYNC_LEVEL) echo "true enum patch minor major 0 E007 Sync level";;
            *) echo "false string none 0 E999 Unknown key - consider if needed";;
        esac
    fi
}

# Test single key (compare target vs standard)
test_key() {
    local key="$1"
    local std_value="${loaded_values[$key]-}"
    local std_comment="${loaded_comments[$key]-}"
    local tgt_value="${target_values[$key]-}"
    local tgt_comment="${target_comments[$key]-}"

    read -r required type values min_length error_code help_comment <<< "$(get_validation_rules "$key")"

    local result="PASS"
    local message="Key $key: "

    # Presence check
    if [[ -z "$tgt_value" ]]; then
        message+="Missing. "
        if [[ "$required" == "true" ]]; then
            result="FAIL"
            message+="Required - add with value like '$std_value' ($help_comment)."
        else
            result="WARN"
            message+="Optional - defaults possible ($help_comment)."
        fi
    else
        # Value/type validation
        case "$type" in
            string)
                if [[ ${#tgt_value} -lt $min_length ]]; then
                    result="FAIL"
                    message+="Value too short (min $min_length). "
                fi
                ;;
            semver)
                if [[ ! "$tgt_value" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                    result="FAIL"
                    message+="Invalid semver. "
                fi
                ;;
            boolean)
                local val="${tgt_value,,}"
                if [[ "$val" != "true" && "$val" != "false" ]]; then
                    result="FAIL"
                    message+="Invalid boolean. "
                fi
                ;;
            enum)
                local found=false
                IFS=' ' read -ra enum_vals <<< "$values"
                for val in "${enum_vals[@]}"; do
                    if [[ "$tgt_value" == "$val" ]]; then
                        found=true
                        break
                    fi
                done
                if ! $found; then
                    result="FAIL"
                    message+="Invalid enum (${values}). "
                fi
                ;;
        esac

        # Compare value/comment if present
        if [[ "$tgt_value" != "$std_value" ]]; then
            message+="Value differs (standard: '$std_value'). "
        fi
        if [[ "$tgt_comment" != "$std_comment" ]]; then
            message+="Comment differs (standard: '$std_comment'). "
        fi
    fi

    log_result "$result" "$message" "$error_code"
    [[ "$result" == "FAIL" ]] && return 1 || return 0
}

# Log pass/fail
log_result() {
    local result="$1" message="$2" error_code="$3"
    local color="${GREEN}"
    [[ "$result" == "FAIL" ]] && color="${RED}"
    [[ "$result" == "WARN" ]] && color="${YELLOW}"
    echo "${color}$result - $message (Code: $error_code)${RESET}" | tee -a "$LOG_FILE"
}

# Usage/help
usage() {
    echo "${GREEN}Usage:${RESET} $0 [-h]"
    echo "  -h: Show help and sample"
    echo "${YELLOW}Sample from standard:${RESET}"
    if [[ ${#loaded_keys[@]} -eq 0 ]]; then
        load_env_file "$STANDARD_ENV" || echo "No standard loaded."
    fi
    for key in "${loaded_keys[@]}"; do
        local value="${loaded_values[$key]}"
        local comment="${loaded_comments[$key]}"
        echo "$key=\"$value\" # $comment"
    done
    exit 0
}

# Main
main() {
    while getopts ":h" opt; do
        case "$opt" in
            h) usage ;;
            *) echo "${RED}Invalid option: -$opt${RESET}"; usage ;;
        esac
    done

    check_yq

    # Load standard
    if ! load_env_file "$STANDARD_ENV"; then
        echo "${RED}FAIL: Standard $STANDARD_ENV missing.${RESET}"
        exit 1
    fi

    # Find and load target
    local target_file
    target_file=$(find_target_env)
    if ! load_env_file "$target_file"; then
        echo "${RED}FAIL: Target $target_file invalid.${RESET}"
        exit 1
    fi
    declare -A target_values
    for key in "${!loaded_values[@]}"; do target_values["$key"]="${loaded_values[$key]}"; done
    declare -A target_comments
    for key in "${!loaded_comments[@]}"; do target_comments["$key"]="${loaded_comments[$key]}"; done

    # Condition: Warn if few keys
    if [[ ${#target_values[@]} -lt $MIN_KEYS_THRESHOLD ]]; then
        log_result "WARN" "Few keys (${#target_values[@]} / $MIN_KEYS_THRESHOLD min). May miss dependencies." "E000"
    fi

    # Loop and test each standard key
    local overall_pass=true
    for key in "${loaded_keys[@]}"; do
        if ! test_key "$key"; then
            overall_pass=false
        fi
    done

    if $overall_pass; then
        echo "${GREEN}PASS${RESET}"
    else
        echo "${RED}FAIL${RESET}"
    fi
}

main "$@"

# End of check-env.sh