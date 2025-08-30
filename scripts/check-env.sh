#!/usr/bin/env bash
# check-env.sh
# Version: 0.0.8
# Description: Modular .env validator comparing target to standard, with per-key tests and logging.
# Alias: chkenv, checkenv

set -euo pipefail

# Globals
STANDARD_ENV="/opt/davit/development/.env-standard"
REQUIREMENTS_YAML="requirements.yaml"
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RESET="\033[0m"
LOG_FILE="logs/check-env.log"
MIN_KEYS_THRESHOLD=5
USE_COLORS=true
ENV_VERSION="0001"

# Check if colors should be used
if [[ ! -t 1 || $(tput colors 2>/dev/null || echo 0) -eq 0 ]]; then
    USE_COLORS=false
    RED=""
    GREEN=""
    YELLOW=""
    RESET=""
fi

# Print with colors to terminal, plain to log
print_message() {
    local message="$1"
    local color="$2"
    mkdir -p "$(dirname "$LOG_FILE")"
    if $USE_COLORS; then
        printf "%b%s%b\n" "$color" "$message" "$RESET"
    else
        printf "%s\n" "$message"
    fi
    echo "$message" >> "$LOG_FILE"
}

# Check for yq
check_yq() {
    if [[ -f "$REQUIREMENTS_YAML" ]] && ! command -v yq >/dev/null; then
        print_message "Error: yq required for $REQUIREMENTS_YAML. Install: sudo VERSION=v4.47.1 BINARY=yq_linux_amd64; wget https://github.com/mikefarah/yq/releases/download/\${VERSION}/\${BINARY}.tar.gz -O - | tar xz && mv \${BINARY} /usr/local/bin/yq" "$RED"
        return 1
    fi
    if [[ -f "$REQUIREMENTS_YAML" ]]; then
        yq e . "$REQUIREMENTS_YAML" >/dev/null 2>&1 || {
            print_message "Warning: $REQUIREMENTS_YAML is malformed. Falling back to dummy rules." "$YELLOW"
            return 1
        }
    fi
    return 0
}

# Load env file into arrays
load_env_file() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        print_message "Error: File $file not found." "$RED"
        return 1
    fi

    declare -g -a loaded_keys=()
    declare -g -A loaded_values=()
    declare -g -A loaded_comments=()
    local line_num=0
    while IFS= read -r line || [[ -n "$line" ]]; do
        ((line_num++))
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        if [[ -z "$line" || "$line" =~ ^# ]]; then continue; fi

        # Handle quoted values with command substitutions
        #TODO: Improve handling of complex cases if line contains dynamic content
        if [[ "$line" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)\s*=\s*(\"[^\"]*\"|\'[^\']*\'|[^[:space:]#]*)([[:space:]]*#.*)?$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            local comment="${BASH_REMATCH[3]}"

            # Validate key format (uppercase underscore only)
            if [[ ! "$key" =~ ^[A-Z_][A-Z0-9_]*$ ]]; then
                print_message "Warning: Invalid key format at line $line_num in $file: '$key'. Must be uppercase with underscores (e.g., PROJECT_NAME)." "$YELLOW"
                continue
            fi

            value="${value#\"}"; value="${value%\"}"
            value="${value#\'}"; value="${value%\'}"
            comment="${comment#"#"}"
            comment="${comment#"${comment%%[![:space:]]*}"}"

            loaded_keys+=("$key")
            loaded_values["$key"]="$value"
            loaded_comments["$key"]="$comment"
        else
            print_message "Warning: Invalid line $line_num in $file: '$line'. Skipping." "$YELLOW"
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
    print_message "FAIL: No target .env found (checked: ${possible_targets[*]})." "$RED"
    exit 1
}

# Get validation rules
get_validation_rules() {
    local key="$1"
    if [[ -f "$REQUIREMENTS_YAML" ]] && check_yq; then
        local required type min_length error_code help_comment values regex default
        required=$(yq e ".validation_rules.\"$key\".required // false" "$REQUIREMENTS_YAML" 2>/dev/null || echo "false")
        type=$(yq e ".validation_rules.\"$key\".type // 'string'" "$REQUIREMENTS_YAML" 2>/dev/null || echo "string")
        min_length=$(yq e ".validation_rules.\"$key\".min_length // 0" "$REQUIREMENTS_YAML" 2>/dev/null || echo "0")
        error_code=$(yq e ".validation_rules.\"$key\".error_code // 'E999'" "$REQUIREMENTS_YAML" 2>/dev/null || echo "E999")
        help_comment=$(yq e ".validation_rules.\"$key\".help_comment // 'Unknown key'" "$REQUIREMENTS_YAML" 2>/dev/null || echo "Unknown key")
        regex=$(yq e ".validation_rules.\"$key\".regex // ''" "$REQUIREMENTS_YAML" 2>/dev/null || echo "")
        default=$(yq e ".validation_rules.\"$key\".default // ''" "$REQUIREMENTS_YAML" 2>/dev/null || echo "")
        if [[ "$type" == "enum" ]]; then
            values=$(yq e ".validation_rules.\"$key\".values | join(' ')" "$REQUIREMENTS_YAML" 2>/dev/null || echo "none")
        else
            values="none"
        fi
        if [[ "$required" == "null" || "$type" == "null" || "$error_code" == "null" ]]; then
            print_message "Warning: Failed to parse $REQUIREMENTS_YAML for $key. Using dummy rules." "$YELLOW"
            case "$key" in
                ENV_VERSION) echo "true string none 0 E000 Environment version code (e.g., '0001') ^[0-9]{4}$ ''";;
                DOMAIN) echo "true string none 3 E001 Project domain (e.g., davit) '' ''";;
                HOST) echo "true string none 4 E002 Server hostname (e.g., node) '' ''";;
                PROJECT_NAME) echo "true string none 5 E003 Project name (must match folder) '' ''";;
                VERSION) echo "true semver none 0 E004 Semantic version (X.Y.Z) '' ''";;
                REQUIREMENTS) echo "false boolean none 0 E012 Check requirements (true/false, optional default true) '' true";;
                GIT_ENABLED) echo "false boolean none 0 E013 Enable Git (true/false, optional default false) '' false";;
                SYNC_LEVEL) echo "true enum patch minor major 0 E007 Sync level '' ''";;
                OPT_DIR) echo "false path none 0 E014 Base opt directory (e.g., /opt/davit) '' ''";;
                BIN_DIR) echo "false path none 0 E015 Bin directory '' ''";;
                GITHUB_TOKEN) echo "false string none 0 E010 GitHub access token (or empty) ^ghp_[a-zA-Z0-9]{36}$|^$ ''";;
                *) echo "false string none 0 E999 Unknown key - consider if needed '' ''";;
            esac
        else
            echo "$required $type $values $min_length $error_code $help_comment $regex $default"
        fi
    else
        case "$key" in
            ENV_VERSION) echo "true string none 0 E000 Environment version code (e.g., '0001') ^[0-9]{4}$ ''";;
            DOMAIN) echo "true string none 3 E001 Project domain (e.g., davit) '' ''";;
            HOST) echo "true string none 4 E002 Server hostname (e.g., node) '' ''";;
            PROJECT_NAME) echo "true string none 5 E003 Project name (must match folder) '' ''";;
            VERSION) echo "true semver none 0 E004 Semantic version (X.Y.Z) '' ''";;
            REQUIREMENTS) echo "false boolean none 0 E012 Check requirements (true/false, optional default true) '' true";;
            GIT_ENABLED) echo "false boolean none 0 E013 Enable Git (true/false, optional default false) '' false";;
            SYNC_LEVEL) echo "true enum patch minor major 0 E007 Sync level '' ''";;
            OPT_DIR) echo "false path none 0 E014 Base opt directory (e.g., /opt/davit) '' ''";;
            BIN_DIR) echo "false path none 0 E015 Bin directory '' ''";;
            GITHUB_TOKEN) echo "false string none 0 E010 GitHub access token (or empty) ^ghp_[a-zA-Z0-9]{36}$|^$ ''";;
            *) echo "false string none 0 E999 Unknown key - consider if needed '' ''";;
        esac
    fi
}

# Test single key
test_key() {
    local key="$1"
    local std_value="${loaded_values[$key]-}"
    local std_comment="${loaded_comments[$key]-}"
    local tgt_value="${target_values[$key]-}"
    local tgt_comment="${target_comments[$key]-}"

    read -r required type values min_length error_code help_comment regex default <<< "$(get_validation_rules "$key")"

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
            message+="Optional - defaults to '$default' ($help_comment)."
        fi
    else
        # Value/type validation
        case "$type" in
            string)
                if [[ ${#tgt_value} -lt $min_length ]]; then
                    result="FAIL"
                    message+="Value too short (min $min_length). "
                fi
                if [[ -n "$regex" ]]; then
                    if ! echo "$tgt_value" | grep -qE -- "$regex"; then
                        result="FAIL"
                        message+="Invalid format (must match '$regex'). "
                    fi
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
            path)
                if [[ -n "$tgt_value" && ! -e "$tgt_value" ]]; then
                    result="FAIL"
                    message+="Invalid path (does not exist). "
                fi
                ;;
        esac

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
    print_message "$result - $message (Code: $error_code)" "$color"
}

# Usage/help
usage() {
    print_message "Usage: $0 [-h]" "$GREEN"
    print_message "  -h: Show help and sample" "$GREEN"
    print_message "Sample from standard:" "$YELLOW"
    if ! load_env_file "$STANDARD_ENV"; then
        print_message "No standard loaded ($STANDARD_ENV missing)." "$RED"
        exit 1
    fi
    for key in "${loaded_keys[@]}"; do
        local value="${loaded_values[$key]}"
        local comment="${loaded_comments[$key]}"
        print_message "$key=\"$value\" # $comment" ""
    done
    exit 0
}

# Main
main() {
    mkdir -p "$(dirname "$LOG_FILE")"
    while getopts ":h" opt; do
        case "$opt" in
            h) usage ;;
            *) print_message "Invalid option: -$opt" "$RED"; usage ;;
        esac
    done

    check_yq

    # Load standard
    if ! load_env_file "$STANDARD_ENV"; then
        print_message "FAIL: Standard $STANDARD_ENV missing." "$RED"
        exit 1
    fi

    # Find and load target
    local target_file
    target_file=$(find_target_env)
    if ! load_env_file "$target_file"; then
        print_message "FAIL: Target $target_file invalid." "$RED"
        exit 1
    fi
    declare -A target_values
    for key in "${!loaded_values[@]}"; do target_values["$key"]="${loaded_values[$key]}"; done
    declare -A target_comments
    for key in "${!loaded_comments[@]}"; do target_comments["$key"]="${loaded_comments[$key]}"; done

    # Check env_version
    if [[ "${target_values[ENV_VERSION]-}" != "${loaded_values[ENV_VERSION]-}" ]]; then
        log_result "WARN" "ENV_VERSION mismatch (target: ${target_values[ENV_VERSION]-}, standard: ${loaded_values[ENV_VERSION]-}). Update to match standard." "E000"
    fi

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
        print_message "PASS" "$GREEN"
    else
        print_message "FAIL" "$RED"
    fi
}

main "$@"

# End of check-env.sh