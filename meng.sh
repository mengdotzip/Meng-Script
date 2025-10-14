#!/bin/bash
set -euo pipefail

# ============================================================================
# MENG - Server Management Script
# A unified interface for deployment, SSH, and server management
# ============================================================================

# ###### #
# CONFIG #
# ###### #

# DEFINE YOUR ALIASES HERE
declare -A aliases=(
[myserver]="user@192.168.1.100:/path/to/deploy/"
[staging]="deploy@staging.company.com:/var/www/"
[production]="admin@prod.company.com:/opt/apps/"
)
##########

# DEFINE SCRIPT ALIASES HERE
declare -A scripts=(
[backup]="/home/user/scripts/rclone_backup.sh"
)
##########

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

#vars
readonly DEFAULT_FILE="" #If you dont set -file it will default to this file, very handy for testing
readonly VERSION="0.1.3"

# ################# #
# UTILITY FUNCTIONS #
# ################# #

log_info() {
echo -e "${BLUE}i${NC} $1"
}
log_success() {
echo -e "${GREEN}✓${NC} $1"
}
log_warning() {
echo -e "${YELLOW}⚠${NC} $1"
}
log_error() {
echo -e "${RED}✗${NC} $1" >&2
}

usage() {
    printf "%b\n" \
    "${BLUE}MENG${NC} - Server Management Script v${VERSION}" \
    "${YELLOW}USAGE:${NC}" \
    "$0 --alias <alias> -action <action> [--file <filename>] [options]" \
    "$0 --script <alias> -action <action>" \
    "${YELLOW}ACTIONS:${NC}" \
    "${GREEN}scp${NC} Copy file to server" \
    "${GREEN}ssh${NC} Connect to server via SSH" \
    "${GREEN}deploy${NC} Build (if needed) and deploy file" \
    "${GREEN}run${NC} Run a script alias" \
    "${YELLOW}OPTIONS:${NC}" \
    "-al, --alias <name> Server alias (required for most actions)" \
    "-s,  --script <name> Script alias" \
    "-ac, --action <action> Action to perform (required for most actions)" \
    "-f,  --file <filename> File to copy/deploy (required for scp/deploy)" \
    "-p,  --path <path> Overwrite or append the path thats defined in the alias" \
    "-l,  --list List all scripts and aliases" \
    "-v,  --verbose Enable verbose output" \
    "-h,  --help Show this help message" \
    "--version Show version information" \
    "${YELLOW}EXAMPLES:${NC}" \
    "$0 --alias ubproxy --action ssh" \
    "$0 --alias ubproxy --action deploy --file mazarin" \
    "$0 --script backup --action run" \
    "$0 --list" 
}

show_version() {
    echo "MENG v${VERSION}"
    echo "Server Management Script"
}

build_go() {
    if go build -o "$FILE"; then
        log_success "Build completed successfully"
    else
        log_error "Build failed"
        exit 1
    fi
}

validate_alias() {
    if [[ -z "${aliases[$ALIAS]+_}" ]]; then
        log_error "Unknown alias '$ALIAS'"
        log_info "Available aliases:"
        list_aliases
        exit 1
    fi
}

validate_scripts() {
    if [[ -z "${scripts[$SCRIPT_AL]+_}" ]]; then
        log_error "Unknown script '$SCRIPT_AL'"
        log_info "Available aliases:"
        list_scripts
        exit 1
    fi
}

validate_file() {
    if [[ "$RECURSION" == true ]]; then
        if [[ ! -d "$FILE" ]]; then
            log_error "Folder '$FILE' not found"
            exit 1
        fi
    elif [[ ! -f "$FILE" ]]; then
        log_error "File '$FILE' not found"
        exit 1
    fi
}

list_scripts() {
    echo -e "${YELLOW}Available server scripts:${NC}"
    for script in "${!scripts[@]}"; do
        local alias_info="${scripts[$script]}"
        echo -e " ${GREEN}$script${NC} -> $alias_info"
    done
}

list_aliases() {
    echo -e "${YELLOW}Available server aliases:${NC}"
    for alias in "${!aliases[@]}"; do
        local alias_info="${aliases[$alias]}"
        local user_host="${alias_info%%:*}"
        local path="${alias_info#*:}"
        echo -e " ${GREEN}$alias${NC} -> $user_host:$path"
    done
}

# ########## #
# MAIN LOGIC #
# ########## #

parse_script() {
    validate_scripts

    SCRIPT_TORUN="${scripts[$SCRIPT_AL]}"

    if [[ "$VERBOSE" == true ]]; then
        log_info "Parsed script '$SCRIPT_TORUN':"
    fi
}

parse_alias() {
    validate_alias

    local alias_full="${aliases[$ALIAS]}"
    USER_HOST="${alias_full%%:*}"  # %%:* = "Remove the longest match of :* from the end"
    REMOTE_PATH="${alias_full#*:}" # #*: = "Remove the shortest match of *: from the beginning"
    USER="${USER_HOST%@*}"         # %@* = "Remove the shortest match of @* from the end"
    HOST="${USER_HOST#*@}"         # #*@ = "Remove the shortest match of *@ from the beginning"

    if [[ -n "${CUSTOM_PATH}" ]]; then
        if [[ "${CUSTOM_PATH:0:1}" == "/" ]]; then
            REMOTE_PATH="$CUSTOM_PATH"  
            log_info "Using absolute path: $REMOTE_PATH"
        else
            REMOTE_PATH="${REMOTE_PATH}$CUSTOM_PATH"
            log_info "Appending to alias path: $REMOTE_PATH"
        fi
    fi

    if [[ "$VERBOSE" == true ]]; then
        log_info "Parsed alias '$ALIAS':"
        echo " User: $USER"
        echo " Host: $HOST"
        echo " Remote Path: $REMOTE_PATH"
    fi
}

parse_arguments() {
    SCRIPT_AL=""
    ALIAS=""
    ACTION=""
    FILE=""
    CUSTOM_PATH=""
    VERBOSE=false
    RECURSION=false
    while [[ $# -gt 0 ]]; do
        case $1 in
            -al|--alias)
                ALIAS="$2"
                shift 2
                ;;
            -s|--script)
                SCRIPT_AL="$2"
                shift 2
                ;;
            -ac|--action)
                ACTION="$2"
                shift 2
                ;;
            -f|--file)
                FILE="$2"
                shift 2
                ;;
            -p|--path)
                CUSTOM_PATH="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -r)
                RECURSION=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            -l|--list)
                list_scripts
                list_aliases
                exit 0
                ;;
            --version)
                show_version
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

# ####### #
# ACTIONS #
# ####### #

action_scp() {
    if [ -z "${FILE}" ]; then
        FILE="$DEFAULT_FILE"
        log_warning "No file specified for scp, using DEFAULT_FILE fallback: $DEFAULT_FILE"
    fi
    validate_file
    log_info "Copying '$FILE' to $USER@$HOST:$REMOTE_PATH"
    if [[ "$RECURSION" == true ]]; then
        if scp -r "$FILE" "$USER@$HOST:$REMOTE_PATH"; then
            log_success "File copied successfully"
        else
            log_error "SCP failed"
            exit 1
        fi
    else
        if scp "$FILE" "$USER@$HOST:$REMOTE_PATH"; then
            log_success "File copied successfully"
        else
            log_error "SCP failed"
            exit 1
        fi
    fi
}

action_ssh() {
    log_info "Connecting to $USER@$HOST..."
    ssh "$USER@$HOST"
}

action_echo() {
    log_info "Parsed alias '$ALIAS':"
    echo " User: $USER"
    echo " Host: $HOST"
    echo " Remote Path: $REMOTE_PATH" 
}

action_deploy() {
    if [ -z "${FILE}" ]; then
        FILE="$DEFAULT_FILE"
        log_warning "No file specified for scp, using DEFAULT_FILE fallback: $DEFAULT_FILE"
    fi
    build_go
    log_info "Deploying '$FILE' to $ALIAS ($USER@$HOST)"
    if scp "$FILE" "$USER@$HOST:$REMOTE_PATH"; then
        log_success "Deployment completed successfully! "
    else
        log_error "Deployment failed"
        exit 1
    fi
}

action_run() {
    log_info "Running script alias $SCRIPT_AL"
    sh "$SCRIPT_TORUN"
    log_success "Script ran"
}


# ############## #
# MAIN EXECUTION #
# ############## #

main(){
    parse_arguments "$@"

    # Validate required arguments
    if [[ -z "$ACTION" ]]; then
        log_error "Action is required"
        usage
        exit 1
    fi

    if [[ -z "$ALIAS" && -z "$SCRIPT_AL" ]]; then
        log_error "Alias is required for action '$ACTION'"
        usage
        exit 1
    fi

    case $ACTION in
        ssh)
            parse_alias
            action_ssh
            ;;
        scp)
            parse_alias
            action_scp
            ;;
        deploy)
            parse_alias
            action_deploy
            ;;
        echo)
            parse_alias
            action_echo
            ;;
        run)
            parse_script
            action_run
            ;;
        *)
            log_error "Unknown action: $ACTION"
            usage
            exit 1
            ;;
    esac
}

main "$@"