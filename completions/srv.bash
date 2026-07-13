# bash/zsh tab completion for srv — predictive text at the shell prompt.
#
# bash:  source this file, or install to /etc/bash_completion.d/srv
# zsh:   autoload -U +X bashcompinit && bashcompinit && source srv.bash
#
# Completes subcommands, then saved host names for `srv connect <TAB>`
# (and bare `srv <TAB>` also offers your saved hosts).

_srv_hosts() {
    awk '!/^\s*(#|$)/{print $1}' "${XDG_CONFIG_HOME:-$HOME/.config}/srv/hosts" 2>/dev/null
}

_srv() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local cmds="status health update monitor widgets connect apps tailscale backup logs tools stage0 harden hosts help"
    if [[ $COMP_CWORD -eq 1 ]]; then
        COMPREPLY=( $(compgen -W "$cmds $(_srv_hosts)" -- "$cur") )
    else
        case "${COMP_WORDS[1]}" in
            connect|c|ssh|go) COMPREPLY=( $(compgen -W "$(_srv_hosts)" -- "$cur") ) ;;
            apps|a)           COMPREPLY=( $(compgen -W "install deploy health" -- "$cur") ) ;;
            *)                COMPREPLY=() ;;
        esac
    fi
}

complete -F _srv srv tower
