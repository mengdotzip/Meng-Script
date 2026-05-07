_meng_completions() {
    local cur prev words cword
    _init_completion || return

    local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/meng"
    local -a aliases=() scripts=()
    local line

    if [[ -f "$config_dir/aliases" ]]; then
        while IFS= read -r line; do
            [[ -z "$line" || "$line" == \#* ]] && continue
            aliases+=("${line%%=*}")
        done < "$config_dir/aliases"
    fi

    if [[ -f "$config_dir/scripts" ]]; then
        while IFS= read -r line; do
            [[ -z "$line" || "$line" == \#* ]] && continue
            scripts+=("${line%%=*}")
        done < "$config_dir/scripts"
    fi

    local all_commands="ssh scp deploy info run script add remove ingest list help version"
    local cmd="${words[1]}"

    if [[ $cword -eq 1 ]]; then
        COMPREPLY=($(compgen -W "$all_commands" -- "$cur"))
        return
    fi

    case "$cmd" in
        ssh|info|remove)
            [[ $cword -eq 2 ]] && COMPREPLY=($(compgen -W "${aliases[*]}" -- "$cur"))
            ;;
        add)
            case $cword in
                3) COMPREPLY=($(compgen -W "-p" -- "$cur")) ;;
            esac
            ;;
        scp|deploy)
            case $cword in
                2) COMPREPLY=($(compgen -W "${aliases[*]}" -- "$cur")) ;;
                3) _filedir ;;
                *) COMPREPLY=($(compgen -W "-r -p" -- "$cur")) ;;
            esac
            ;;
        run)
            [[ $cword -eq 2 ]] && COMPREPLY=($(compgen -W "${scripts[*]}" -- "$cur"))
            ;;
        script)
            case $cword in
                2) COMPREPLY=($(compgen -W "add remove" -- "$cur")) ;;
                3) [[ "${words[2]}" == "remove" ]] && \
                       COMPREPLY=($(compgen -W "${scripts[*]}" -- "$cur")) ;;
                4) [[ "${words[2]}" == "add" ]] && _filedir ;;
            esac
            ;;
    esac
}

complete -F _meng_completions meng