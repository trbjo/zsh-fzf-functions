fif() {
    if [ ! "$#" -gt 0 ]; then
        echo "Need a string to search for!"
        return 1
    fi
    rg --files-with-matches --no-messages "$1" | fzf --preview "rg --pretty --context 10 '$1' {}" | xargs subl
    [ $PopUp ] && swaymsg "focus tiling; [app_id=^(subl|sublime_text|firefox)$ app_id=__focused__ workspace=^(3|2λ)$] fullscreen enable; [app_id=^PopUp$] scratchpad show"
    # [ $PopUp ] && swaymsg "focus tiling; [app_id=^PopUp$] scratchpad show"
    return 0
}


# Ensure precmds are run after cd
fzf-redraw-prompt() {
    print
    local precmd
    for precmd in $precmd_functions; do
        $precmd
    done
}
zle -N fzf-redraw-prompt

fzf-widget() {
    # this ensures that file paths with spaces are not interpreted as different files
    local IFS=$'\n'
    setopt localoptions pipefail no_aliases 2> /dev/null
    local out=($(eval "${FZF_DEFAULT_COMMAND:-} --type f" | fzf --bind "alt-.:reload($FZF_DEFAULT_COMMAND --type d)" --tiebreak=index --expect=ctrl-o,ctrl-p))
    if [[ -z "$out" ]]; then
        zle redisplay
        return 0
    fi
    local key="$(head -1 <<< "${out[@]}")"
    # we save it as an array instead of one string to be able to parse it as separate arguments
    case "$key" in
        (ctrl-p)
        for file in "${(q)out[@]:1:a}"
        do
            LBUFFER+="${file} "
        done
        zle reset-prompt
        ;;
        (ctrl-o)
        cd ${${out[@]:1:a}%/*}
        zle fzf-redraw-prompt
        ;;
        (*)
        _file_opener "${out[@]}"
        ;;
    esac
    return
}
zle     -N    fzf-widget
bindkey '^P' fzf-widget

fzf-downloads-widget() {
        # this ensures that file paths with spaces are not interpreted as different files
        local IFS=$'\n'
        setopt localoptions pipefail no_aliases 2> /dev/null
        local out=($(ls --color=always -ctd1 ${XDG_DOWNLOAD_DIR}/* | fzf --tiebreak=index --delimiter=/ --with-nth=4.. --no-sort --ansi --expect=ctrl-o,ctrl-p))
        if [[ -z "$out" ]]; then
            zle redisplay
            return 0
        fi
        local key="$(head -1 <<< "${out[@]}")"
        case "$key" in
            (ctrl-p)
                for file in "${(q)out[@]:1}"
                do
                    LBUFFER+="${file} "
                done
                ;;
            (ctrl-o)
                cd "${${out[@]:1}%/*}"
                ;;
            (*)
                touch "${out[@]}" && _file_opener "${out[@]}"
                ;;
        esac
        unset ISFILE
        zle fzf-redraw-prompt
        zle reset-prompt
}
zle -N fzf-downloads-widget
bindkey '^O' fzf-downloads-widget

# Paste the selected command(s) from history into the command line
fzf-history-widget() {
    local IFS=$'\n'
    local out myQuery line REPLACE separator_var=";"
    setopt localoptions noglobsubst noposixbuiltins pipefail no_aliases 2> /dev/null

    if [[ ${LBUFFER: -3} != "&& " ]] && [[ ${LBUFFER: -2} != "; " ]] && [[ ${LBUFFER: -2} != "&&" ]] && [[ ${LBUFFER: -1} != ";" ]]; then
        REPLACE=true
        myQuery="${(qqq)LBUFFER}"
    fi

    out=( $(fc -rnli 1 |
                 FZF_DEFAULT_OPTS=" $FZF_DEFAULT_OPTS --expect=ctrl-/,ctrl-p,enter --delimiter='  ' --nth=2.. --preview-window=bottom:4 --preview 'echo {2..}' --no-hscroll --tiebreak=index --bind \"alt-w:execute-silent(wl-copy -- {2..})+abort\" --query=${myQuery}" fzf) )
    if [ -n "$out" ]; then


        if [[ ${LBUFFER: -2} == "&&" ]] || [[ ${LBUFFER: -1} == ";" ]]; then
            LBUFFER+=' '
        fi

        key="${out[@]:0:1}"
        if [[ "$key" == "ctrl-p" ]]; then
            separator_var=" &&"
        fi
        # if [[ "$key" == "ctrl-/" ]]; then
        #     for hist in "${out[@]:1}"
        #     do
        #         line=$(rg --no-config --line-number --fixed-strings "${hist#*  }" $HISTFILE | cut -f1 -d:)
        #         echo $line
        #         awk -v n=$line 'NR == n {next}' $HISTFILE
        #     done
        #     fc -R
        #     # LBUFFER+="${${out[@]:1:1}#*  }"
        # else
            [[ $REPLACE ]] && LBUFFER="${${out[@]:1:1}#*:[0-9][0-9]  }" || LBUFFER+="${${out[@]:1:1}#*:[0-9][0-9]  }"
            for hist in "${out[@]:2}"
            do
                LBUFFER+="$separator_var ${hist#*:[0-9][0-9]  }"
            done
        # fi
    fi
    zle reset-prompt
}
zle -N fzf-history-widget
bindkey '^R' fzf-history-widget






# deleter() {
    # local pw="$(wl-paste -n)"
    # sleep 15
    # clipman clear --tool=CUSTOM --print0 --tool-args="printf \"$pw\""
# }

fzf-password() {
    /usr/bin/fd . --extension gpg --base-directory $HOME/.password-store | sed -e 's/.gpg$//' | sort | fzf --no-multi --preview-window=hidden --bind 'alt-w:abort+execute-silent@touch /tmp/clipman_ignore ; wl-copy -n -- $(pass {})@,enter:execute-silent@[ $PopUp ] && swaymsg "focus tiling; [app_id=^(subl|sublime_text|firefox)$ app_id=__focused__ workspace=^(3|2λ)$] fullscreen enable; [app_id=^PopUp$] scratchpad show"; touch /tmp/clipman_ignore; wl-copy -n -- $(pass {})@+abort'
    rm /tmp/clipman_ignore
    zle redisplay
    # (deleter &) > /dev/null 2>&1
}
zle -N fzf-password
bindkey -e '^K' fzf-password

fzf-clipman() {
    clipman pick --max-items=2000 --print0 --tool=CUSTOM --tool-args="fzf --read0 --preview 'echo {+}' --bind 'ctrl-_:execute-silent(echo -E {} > /tmp/pw; clipman clear --tool=CUSTOM --print0 --tool-args=\"cat /tmp/pw\")+abort,enter:execute-silent(wl-copy -- {+}; [ $PopUp ] && swaymsg \"focus tiling; [app_id=^(subl|sublime_text|firefox)$ app_id=__focused__ workspace=^(3|2λ)$] fullscreen enable; [app_id=^PopUp$] scratchpad show\"; [ $subl ] && subl --command paste_and_indent)+abort,alt-w:execute-silent(wl-copy -- {+}; swaymsg scratchpad show)+abort,esc:execute-silent([ $subl ] && swaymsg scratchpad show)+cancel'"
    rm -f /tmp/pw
    # zle redisplay
}
zle -N fzf-clipman
bindkey -e '^B' fzf-clipman
