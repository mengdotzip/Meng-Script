#!/bin/bash
set -euo pipefail

# ============================================================================
# MENG - Server Management Script
# ============================================================================

readonly CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/meng"
readonly ALIASES_FILE="$CONFIG_DIR/aliases"
readonly SCRIPTS_FILE="$CONFIG_DIR/scripts"

readonly RED=$'\033[0;31m'
readonly GREEN=$'\033[0;32m'
readonly YELLOW=$'\033[1;33m'
readonly BLUE=$'\033[0;34m'
readonly NC=$'\033[0m'

readonly DEFAULT_FILE=""
readonly VERSION="0.3.0"

log_info()    { echo -e "${BLUE}i${NC} $1"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
log_error()   { echo -e "${RED}✗${NC} $1" >&2; }

# ################# #
# UTILITY FUNCTIONS #
# ################# #

ensure_config_dir() {
    [[ -d "$CONFIG_DIR" ]] && return 0
    mkdir -p "$CONFIG_DIR"
    touch "$ALIASES_FILE" "$SCRIPTS_FILE"
    log_info "Created config directory: $CONFIG_DIR"
}

load_config() {
    declare -gA aliases=()
    declare -gA scripts=()
    local key value line

    if [[ -f "$ALIASES_FILE" ]]; then
        while IFS= read -r line; do
            [[ -z "$line" || "$line" == \#* ]] && continue
            key="${line%%=*}"; value="${line#*=}"
            aliases["$key"]="$value"
        done < "$ALIASES_FILE"
    fi

    if [[ -f "$SCRIPTS_FILE" ]]; then
        while IFS= read -r line; do
            [[ -z "$line" || "$line" == \#* ]] && continue
            key="${line%%=*}"; value="${line#*=}"
            scripts["$key"]="$value"
        done < "$SCRIPTS_FILE"
    fi
}

usage() {
    cat <<EOF
${BLUE}MENG${NC} v${VERSION} — Server Management Script

${YELLOW}SERVER:${NC}
  ${GREEN}ssh${NC}    <alias>                      Connect via SSH
  ${GREEN}scp${NC}    <alias> <file> [-r] [-p]     Copy file/folder to server
  ${GREEN}deploy${NC} <alias> <file>               Build (go build) and deploy
  ${GREEN}info${NC}   <alias>                      Show alias details

${YELLOW}SCRIPTS:${NC}
  ${GREEN}run${NC}           <name>                Run a script alias
  ${GREEN}script add${NC}    <name> <path>         Add a script alias
  ${GREEN}script remove${NC} <name>                Remove a script alias

${YELLOW}ALIAS MANAGEMENT:${NC}
  ${GREEN}add${NC}    <name> <user@host:/path>     Add a server alias
  ${GREEN}remove${NC} <name>                       Remove a server alias
  ${GREEN}ingest${NC} <name> [ssh] <user@host>     Parse SSH string into alias
  ${GREEN}list${NC}                                List all aliases and scripts

${YELLOW}SCP FLAGS:${NC}
  -r           Recursive (directories)
  -p <path>    Overwrite or append remote path

${YELLOW}EXAMPLES:${NC}
  meng add prod admin@10.0.0.1:/opt/app/
  meng ingest prod !!                    # after: ssh admin@10.0.0.1
  meng ssh prod
  meng scp prod build/myapp
  meng scp prod -r dist/
  meng scp prod myapp -p /tmp/
  meng deploy prod myapp
  meng run backup
  meng script add backup ~/scripts/backup.sh
  meng list
EOF
}

show_version() {
    echo "MENG v${VERSION}"
    echo "Config: $CONFIG_DIR"
}

# ########## #
# CONFIG I/O #
# ########## #

write_entry() {
    local file="$1" name="$2" value="$3"
    local tmpfile; tmpfile=$(mktemp)
    grep -v "^${name}=" "$file" > "$tmpfile" 2>/dev/null || true
    echo "${name}=${value}" >> "$tmpfile"
    mv "$tmpfile" "$file"
}

remove_entry() {
    local file="$1" name="$2"
    if ! grep -q "^${name}=" "$file" 2>/dev/null; then
        log_error "Entry '$name' not found"
        exit 1
    fi
    local tmpfile; tmpfile=$(mktemp)
    grep -v "^${name}=" "$file" > "$tmpfile" 2>/dev/null || true
    mv "$tmpfile" "$file"
}

# ############ #
# ALIAS LOOKUP #
# ############ #

resolve_alias() {
    local name="$1"
    if [[ -z "${aliases[$name]+_}" ]]; then
        log_error "Unknown alias '$name'"
        log_info "Run 'meng list' to see available aliases"
        exit 1
    fi
    local full="${aliases[$name]}"
    ALIAS="$name"
    USER_HOST="${full%%:*}"
    REMOTE_PATH="${full#*:}"
    USER="${USER_HOST%@*}"
    HOST="${USER_HOST#*@}"
}

resolve_script() {
    local name="$1"
    if [[ -z "${scripts[$name]+_}" ]]; then
        log_error "Unknown script '$name'"
        log_info "Run 'meng list' to see available scripts"
        exit 1
    fi
    SCRIPT_PATH="${scripts[$name]}"
}

list_all() {
    echo -e "${YELLOW}Server aliases:${NC}"
    if [[ ${#aliases[@]} -eq 0 ]]; then
        echo -e "  ${BLUE}(none)${NC} — add with: meng add <name> <user@host:/path>"
    else
        for name in "${!aliases[@]}"; do
            echo -e "  ${GREEN}${name}${NC} -> ${aliases[$name]}"
        done
    fi
    echo
    echo -e "${YELLOW}Script aliases:${NC}"
    if [[ ${#scripts[@]} -eq 0 ]]; then
        echo -e "  ${BLUE}(none)${NC} — add with: meng script add <name> <path>"
    else
        for name in "${!scripts[@]}"; do
            echo -e "  ${GREEN}${name}${NC} -> ${scripts[$name]}"
        done
    fi
}

# ########### #
# SERVER CMDS #
# ########### #

cmd_ssh() {
    local alias_name="${1:?Usage: meng ssh <alias>}"
    resolve_alias "$alias_name"
    log_info "Connecting to $USER@$HOST..."
    ssh "$USER@$HOST"
}

cmd_scp() {
    local alias_name="${1:?Usage: meng scp <alias> <file>}"
    local file="${2:?Usage: meng scp <alias> <file>}"
    resolve_alias "$alias_name"
    shift 2

    local recursion=false custom_path=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -r)        recursion=true; shift ;;
            -p|--path) custom_path="$2"; shift 2 ;;
            *)         log_error "Unknown option: $1"; exit 1 ;;
        esac
    done

    if [[ -n "$custom_path" ]]; then
        if [[ "${custom_path:0:1}" == "/" ]]; then
            REMOTE_PATH="$custom_path"
        else
            REMOTE_PATH="${REMOTE_PATH}${custom_path}"
        fi
        log_info "Remote path: $REMOTE_PATH"
    fi

    if [[ "$recursion" == true ]]; then
        [[ ! -d "$file" ]] && { log_error "Folder '$file' not found"; exit 1; }
    else
        [[ ! -f "$file" ]] && { log_error "File '$file' not found"; exit 1; }
    fi

    log_info "Copying '$file' -> $USER@$HOST:$REMOTE_PATH"
    local scp_opts=()
    [[ "$recursion" == true ]] && scp_opts+=(-r)
    if scp "${scp_opts[@]}" "$file" "$USER@$HOST:$REMOTE_PATH"; then
        log_success "Copied successfully"
    else
        log_error "SCP failed"; exit 1
    fi
}

cmd_deploy() {
    local alias_name="${1:?Usage: meng deploy <alias> <file>}"
    local file="${2:-$DEFAULT_FILE}"
    resolve_alias "$alias_name"

    if [[ -z "$file" ]]; then
        log_error "No file specified and DEFAULT_FILE is not set"
        exit 1
    fi

    log_info "Building '$file'..."
    if ! go build -o "$file"; then
        log_error "Build failed"; exit 1
    fi
    log_success "Build completed"

    log_info "Deploying '$file' -> $alias_name ($USER@$HOST:$REMOTE_PATH)"
    if scp "$file" "$USER@$HOST:$REMOTE_PATH"; then
        log_success "Deployed!"
    else
        log_error "Deployment failed"; exit 1
    fi
}

cmd_info() {
    local alias_name="${1:?Usage: meng info <alias>}"
    resolve_alias "$alias_name"
    echo -e "${YELLOW}Alias:${NC} $alias_name"
    echo "  User:   $USER"
    echo "  Host:   $HOST"
    echo "  Path:   $REMOTE_PATH"
}

# ########### #
# SCRIPT CMDS #
# ########### #

cmd_run() {
    local name="${1:?Usage: meng run <script>}"
    resolve_script "$name"
    log_info "Running '$name'..."
    sh "$SCRIPT_PATH"
    log_success "Script completed"
}

cmd_script() {
    local subcmd="${1:?Usage: meng script <add|remove> ...}"
    shift
    case "$subcmd" in
        add)
            local name="${1:?Usage: meng script add <name> <path>}"
            local path="${2:?Usage: meng script add <name> <path>}"
            [[ ! -f "$path" ]] && log_warning "Script '$path' does not exist yet (adding anyway)"
            write_entry "$SCRIPTS_FILE" "$name" "$path"
            log_success "Script '$name' -> $path"
            ;;
        remove)
            local name="${1:?Usage: meng script remove <name>}"
            remove_entry "$SCRIPTS_FILE" "$name"
            log_success "Removed script '$name'"
            ;;
        *)
            log_error "Unknown: meng script $subcmd"
            log_info "Usage: meng script <add|remove>"
            exit 1
            ;;
    esac
}

# ################ #
# ALIAS MANAGEMENT #
# ################ #

cmd_add() {
    local name="${1:?Usage: meng add <name> <user@host:/path>}"
    local target="${2:?Usage: meng add <name> <user@host:/path>}"
    if [[ ! "$target" =~ .+@.+: ]]; then
        log_error "Invalid format. Expected: user@host:/path (e.g. admin@10.0.0.1:/opt/app/)"
        exit 1
    fi
    write_entry "$ALIASES_FILE" "$name" "$target"
    log_success "Added '$name' -> $target"
}

cmd_remove() {
    local name="${1:?Usage: meng remove <name>}"
    remove_entry "$ALIASES_FILE" "$name"
    log_success "Removed alias '$name'"
}

cmd_ingest() {
    # Primary use: bash !! expansion
    #   ssh admin@10.0.0.1
    #   meng ingest prod !!   →   meng ingest prod ssh admin@10.0.0.1
    local alias_name="${1:?Usage: meng ingest <name> [ssh] <user@host[:/path]>}"
    shift

    [[ "${1:-}" == "ssh" ]] && shift

    # Strip SSH flags (-p 22, -i keyfile, etc.)
    local connection=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -p|-i|-l|-o|-J|-b|-c|-D|-E|-F|-I|-L|-m|-Q|-R|-S|-w|-W) shift 2 ;;
            -*) shift ;;
            *) connection="$1"; break ;;
        esac
    done

    [[ -z "$connection" ]] && { log_error "No host found in command"; exit 1; }

    local user_host path
    if [[ "$connection" == *:* ]]; then
        user_host="${connection%%:*}"; path="${connection#*:}"
    else
        user_host="$connection"; path="~/"
    fi

    if [[ "$user_host" != *@* ]]; then
        log_info "No user specified, defaulting to: $USER"
        user_host="${USER}@${user_host}"
    fi

    write_entry "$ALIASES_FILE" "$alias_name" "${user_host}:${path}"
    log_success "Ingested '$alias_name' -> ${user_host}:${path}"
    log_info "Connect with: meng ssh $alias_name"
}

# ############## #
# MAIN EXECUTION #
# ############## #

main() {
    ensure_config_dir
    load_config

    local cmd="${1:-}"
    [[ $# -gt 0 ]] && shift

    case "$cmd" in
        ssh)               cmd_ssh    "$@" ;;
        scp)               cmd_scp    "$@" ;;
        deploy)            cmd_deploy "$@" ;;
        info)              cmd_info   "$@" ;;
        run)               cmd_run    "$@" ;;
        script)            cmd_script "$@" ;;
        add)               cmd_add    "$@" ;;
        remove)            cmd_remove "$@" ;;
        ingest)            cmd_ingest "$@" ;;
        list)              list_all ;;
        help|-h|--help)    usage ;;
        version|--version) show_version ;;
        "")
            log_error "No command provided"
            echo
            usage
            exit 1
            ;;
        *)
            log_error "Unknown command: '$cmd'"
            log_info "Run 'meng help' for usage"
            exit 1
            ;;
    esac
}

main "$@"