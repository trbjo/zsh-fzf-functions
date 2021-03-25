export FZF_DEFAULT_COMMAND="/usr/bin/fd --color always --exclude Pictures --exclude Music --exclude node_modules --exclude bin --exclude obj --exclude \*.out --exclude lib --exclude \*.srt --exclude \*.exe"

export FZF_DEFAULT_OPTS="--ansi --bind \"alt-t:page-down,alt-c:page-up,ctrl-e:replace-query,ctrl-b:toggle-all,change:top,alt-w:execute-silent(wl-copy -- {+})+abort,ctrl-_:execute-silent(rm -rf {+})+abort,ctrl-r:toggle-sort,ctrl-q:beginning-of-line+kill-line\" --multi --inline-info --reverse --color=bg+:-1,info:-1,prompt:-1,pointer:4:regular,hl:4,hl+:6,fg+:12,border:19,marker:2:regular --prompt='  '   --marker=❯ --pointer=❯ --margin 0,0 --multi --preview-window=right:50%:sharp:wrap --preview 'if [[ {} =~ \"\.(jpeg|JPEG|jpg|JPG|png|webp|WEBP|PNG|gif|GIF|bmp|BMP|tif|TIF|tiff|TIFF)$\" ]]; then identify -ping -format \"%f\\n%m\\n%w x %h pixels\\n%b\\n\\n%l\\n%c\\n\" {} ; elif [[ {} =~ \"\.(svg|SVG)$\" ]]; then tiv -h \$FZF_PREVIEW_LINES -w \$FZF_PREVIEW_COLUMNS {}; elif [[ {} =~ \"\.(pdf|PDF)$\" ]]; then pdfinfo {}; elif [[ {} =~ \"\.(zip|ZIP)$\" ]]; then zip -sf {};  else bat --style=header,numbers --terminal-width=\$FZF_PREVIEW_COLUMNS --force-colorization --italic-text=always --line-range :70 {} 2>/dev/null || exa -T -L 2 --color=always --long {}; fi'"

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
  local precmd
  for precmd in $precmd_functions; do
    $precmd
done
zle reset-prompt
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
        for file in "${(q)out[@]:1}"
        do
            LBUFFER+="$(readlink -f $file) "
        done
        ;;
        (ctrl-o)
        cd "$(dirname "$(readlink -e "${out[@]:1}")")"
        ;;
        (*)
        u "${out[@]}"
        ;;
    esac
    zle fzf-redraw-prompt
    zle redisplay
    local ret=$?
    return $ret
    # return 0
}
zle     -N    fzf-widget
bindkey '^P' fzf-widget

fzf-downloads-widget() {
    # if [[ $#RBUFFER -ne 0 ]]; then
        # zle delete-char-or-list
    # else
        # this ensures that file paths with spaces are not interpreted as different files
        local IFS=$'\n'
        setopt localoptions pipefail no_aliases 2> /dev/null
        current_dir=$PWD
        cd ~/Downloads
        # local out=($(exa --color=always --sort oldest | fzf --tiebreak=index --no-sort --ansi --expect=ctrl-o,ctrl-p))
        local out=($(ls --color=always -ct -1 | fzf --tiebreak=index --no-sort --ansi --expect=ctrl-o,ctrl-p))
        if [[ -z "$out" ]]; then
            cd "$current_dir"
            # cd -
            zle redisplay
            return 0
        fi
        local key="$(head -1 <<< "${out[@]}")"
        case "$key" in
            (ctrl-p)
                cd "$current_dir"
                for file in "${(q)out[@]:1}"
                do
                    LBUFFER+="/home/tb/Downloads/$file "
                done
                ;;
            (ctrl-o)
                cd "$(dirname "$(readlink -e "${out[@]:1}")")"
                ;;
            (*)
                [[ -f "${out[1]}" ]] && ISFILE=1
                touch "${out[@]}" && u "${out[@]}"
                [[ $ISFILE ]] && cd $current_dir
                ;;
        esac
        unset ISFILE
        zle fzf-redraw-prompt
        local ret=$?
        return $ret
# fi
}
zle -N fzf-downloads-widget
bindkey '^O' fzf-downloads-widget



# Paste the selected command from history into the command line
fzf-history-widget() {
    local selected num
    setopt localoptions noglobsubst noposixbuiltins pipefail no_aliases 2> /dev/null
    selected=( $(fc -rl 1 |
                 FZF_DEFAULT_OPTS=" $FZF_DEFAULT_OPTS -n2..,.. --preview-window=bottom:4 --preview 'echo {2..}' --tiebreak=index --bind \"alt-w:execute-silent(wl-copy -- {2..})+abort\" --query=${(qqq)LBUFFER} +m" fzf) )
    local ret=$?
    if [ -n "$selected" ]; then
        num=$selected[1]
        if [ -n "$num" ]; then
            zle vi-fetch-history -n $num
        fi
    fi
    zle reset-prompt
    return $ret
}
zle -N fzf-history-widget
bindkey '^R' fzf-history-widget



deleter() {
    local pw="$(wl-paste -n)"
    sleep 15
    clipman clear --tool=CUSTOM --print0 --tool-args="printf \"$pw\""
}

fzf-password() {
    /usr/bin/fd . --extension gpg --base-directory /home/tb/.password-store | sed -e 's/.gpg$//' | sort | fzf --no-multi --preview-window=hidden --bind 'alt-w:abort+execute-silent@wl-copy -n -- $(pass {})@,enter:execute-silent@[ $PopUp ] && swaymsg "focus tiling; [app_id=^(subl|sublime_text|firefox)$ app_id=__focused__ workspace=^(3|2λ)$] fullscreen enable; [app_id=^PopUp$] scratchpad show"; wl-copy -n -- $(pass {})@+abort'
    zle redisplay
    (deleter &) > /dev/null 2>&1
}
zle -N fzf-password
bindkey -e '^K' fzf-password

fzf-clipman() {
    clipman pick --max-items=2000 --print0 --tool=CUSTOM --tool-args="fzf --read0 --preview 'echo {+}' --bind 'ctrl-_:execute-silent(echo -E {} > /tmp/pw; clipman clear --tool=CUSTOM --print0 --tool-args=\"cat /tmp/pw\")+abort,enter:execute-silent(wl-copy -- {+}; [ $PopUp ] && swaymsg \"focus tiling; [app_id=^(subl|sublime_text|firefox)$ app_id=__focused__ workspace=^(3|2λ)$] fullscreen enable; [app_id=^PopUp$] scratchpad show\"; [ $subl ] && subl --command paste_and_indent)+abort,alt-w:execute-silent(wl-copy -- {+})+abort,esc:execute-silent([ $subl ] && swaymsg scratchpad show)+cancel'"
    rm -f /tmp/pw
    zle redisplay
}
zle -N fzf-clipman
bindkey -e '^B' fzf-clipman
