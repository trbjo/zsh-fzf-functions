# Paste the selected command(s) from history into the command line
fzf-history-widget() {
    local IFS=$'\n'
    local out myQuery line REPLACE separator_var=";"
    setopt localoptions noglobsubst noposixbuiltins pipefail no_aliases 2> /dev/null

    if [[ ${LBUFFER: -3} != "&& " ]] && [[ ${LBUFFER: -2} != "; " ]] && [[ ${LBUFFER: -2} != "&&" ]] && [[ ${LBUFFER: -1} != ";" ]]; then
        REPLACE=true
        myQuery="\'${(qqq)LBUFFER}"
    fi

    local out=( $(fc -rnli 1 | sed -r "s/^(................)/`printf '\033[4m'`\1`printf '\033[0m'`/" |
                 FZF_DEFAULT_OPTS=" $FZF_DEFAULT_OPTS --no-sort --prompt=\"$(print -Pn ${PROMPT:0:84}) \" --expect=ctrl-/,ctrl-p,enter --delimiter='  ' --nth=2.. --preview-window=bottom:4 --preview 'echo {2..}' --no-hscroll --tiebreak=index --bind \"alt-w:execute-silent(wl-copy -- {2..})+abort\" --query=${myQuery}" fzf) )
    if [ -n "$out" ]; then


        if [[ ${LBUFFER: -2} == "&&" ]] || [[ ${LBUFFER: -1} == ";" ]]; then
            LBUFFER+=' '
        fi

        key="${out[@]:0:1}"
        if [[ "$key" == "ctrl-p" ]]; then
            separator_var=" &&"
        fi
        [[ $REPLACE ]] && LBUFFER="${${out[@]:1:1}#*:[0-9][0-9]  }" || LBUFFER+="${${out[@]:1:1}#*:[0-9][0-9]  }"
        for hist in "${out[@]:2}"; do
            LBUFFER+="$separator_var ${hist#*:[0-9][0-9]  }"
        done
    fi
    zle reset-prompt
}
zle -N fzf-history-widget
bindkey '^R' fzf-history-widget

export FZF_DEFAULT_OPTS="--ansi --bind \"alt-t:page-down,alt-c:page-up,ctrl-e:replace-query,ctrl-b:toggle-all,change:top,alt-w:execute-silent(wl-copy -- {+})+abort,ctrl-/:execute-silent(rm -rf {+})+abort,ctrl-r:toggle-sort,ctrl-q:unix-line-discard\" --multi --inline-info --reverse --color=bg+:-1,info:-1,prompt:regular,pointer:5:regular,hl:4:underline,hl+:regular:4:underline,fg+:12:regular,border:19,marker:2:regular --prompt='  ' --marker=❯ --pointer=❯ --margin 0,0 --multi --preview-window=right:50%:sharp:wrap --preview 'if [[ -d {} ]]; then exa -T -L 2 --color=always --long {}; elif [[ {} =~ \"\.(jpeg|JPEG|jpg|JPG|png|webp|WEBP|PNG|gif|GIF|bmp|BMP|tif|TIF|tiff|TIFF)$\" ]]; then identify -ping -format \"%f\\n%m\\n%w x %h pixels\\n%b\\n\\n%l\\n%c\\n\" {} ; elif [[ {} =~ \"\.(svg|SVG)$\" ]]; then tiv -h \$FZF_PREVIEW_LINES -w \$FZF_PREVIEW_COLUMNS {}; elif [[ {} =~ \"\.(pdf|PDF)$\" ]]; then pdfinfo {}; elif [[ {} =~ \"\.(zip|ZIP|sublime-package)$\" ]]; then zip -sf {}; else bat --style=header,numbers --terminal-width=\$((\$FZF_PREVIEW_COLUMNS - 6)) --force-colorization --italic-text=always --line-range :70 {} 2>/dev/null; fi'"

# Do not load the rest if fd is not found

if type fd > /dev/null 2>&1; then
        export FZF_DEFAULT_COMMAND="/usr/bin/fd --color always --exclude gi --exclude \*.dll --exclude node_modules --exclude bin --exclude obj --exclude \*.out --exclude lib --exclude \*.srt --exclude \*.exe"
fi


if type rg > /dev/null 2>&1; then
alias fif='noglob _fif'
_fif() {
    [[ "$#" -eq 0 ]] && print "Need a string to search for!" && return 1
    local IFS=$'\n'
    setopt localoptions pipefail no_aliases 2> /dev/null
    local myQuery="$@"
    local out=($(rg --files-with-matches --no-messages "$myQuery" | fzf --expect=ctrl-p --prompt="$(print -Pn "${PROMPT:0:84} \e[3m$myQuery\e[0m") " --preview "rg $RIPGREP_OPTS --pretty --context 10 '$myQuery' {}"))
    if [[ -z "$out" ]]; then
        return 0
    fi

   local key="$(head -1 <<< "${out[@]}")"
   case "$key" in
       (ctrl-p)
       swaymsg -q -- "exec /opt/sublime_text/sublime_text --command close_all"
       swaymsg -q -- "[app_id=^PopUp$] move scratchpad; [app_id=^sublime_text$ title=.] focus; exec /opt/sublime_text/sublime_text ${out[@]:1:A}"
       ;;
       (*)
       swaymsg -q -- "[app_id=^PopUp$] move scratchpad; [app_id=^sublime_text$ title=.] focus; exec /opt/sublime_text/sublime_text ${out[@]}"
       ;;
   esac
   return 0
}
fi


# Ensure precmds are run after cd
fzf-redraw-prompt() {
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
    local out=($(eval "${FZF_DEFAULT_COMMAND:-fd} --type f" | fzf --delimiter=/ --with-nth=2.. --bind "alt-.:reload($FZF_DEFAULT_COMMAND --type d)" --tiebreak=index --expect=ctrl-o,ctrl-p --prompt="$(print -Pn ${PROMPT:0:84}) "))
    if [[ -z "$out" ]]; then
        return 0
    fi
    local key="$(head -1 <<< "${out[@]}")"
    # we save it as an array instead of one string to be able to parse it as separate arguments
    case "$key" in
        (ctrl-p)
        for file in "${out[@]:1:a:q}"
        do
            LBUFFER+="${file} "
        done
        zle reset-prompt
        ;;
        (ctrl-o)
        cd ${${out[@]:1:a}%/*}
        print
        zle fzf-redraw-prompt
        ;;
        (*)
        file_opener "${out[@]}"
        ;;
    esac
    zle reset-prompt
}
zle     -N    fzf-widget
bindkey '^P' fzf-widget

() {
    # we locale the download directory
    case $OSTYPE in
         (darwin*)
            DL_DIR="$HOME/Downloads"
            ;;
        (linux-gnu)
            while read line
            do
                if [[ $line == XDG_DOWNLOAD_DIR* ]]; then
                    DL_DIR=${(P)line##*=}
                    break
                fi
            done < "${XDG_CONFIG_HOME:-$HOME/.config}/user-dirs.dirs"
            ;;
         (*)
            print "Your platform is not supported. Please open an issue"
            return 1
            ;;
    esac
    [[ -z $DL_DIR ]] && return
    fzf-downloads-widget() {
            # this ensures that file paths with spaces are not interpreted as different files
            local IFS=$'\n'
            setopt localoptions pipefail no_aliases 2> /dev/null
            local out=($(ls --color=always -ctd1 ${(q)DL_DIR}/* | fzf --preview-window=right:68% --tiebreak=index --delimiter=/ --with-nth=5.. --no-sort --ansi --expect=ctrl-o,ctrl-p --prompt="$(cd $DL_DIR; print -Pn ${PROMPT:0:84}) "))
            if [[ -z "$out" ]]; then
                return 0
            fi
            local key="$(head -1 <<< "${out[@]}")"
            case "$key" in
                (ctrl-p)
                    for file in "${out[@]:1:q}"
                    do
                        LBUFFER+="${file} "
                    done
                    ;;
                (ctrl-o)
                    cd "${${out[@]:1}%/*}"
                    ;;
                (*)
                    local oldpwd="$PWD"
                    cd "${DL_DIR}"
                    touch "${out[@]}" && file_opener "${out[@]}"
                    if [[ "${#out[@]}" -eq 1 ]] && [[ -f "${out[1]}" ]] && [[ "${out[1]:e}" =~ "${_ZSH_FILE_OPENER_ARCHIVE_FORMATS//,/|}" ]]; then
                        :
                    elif [[ "${#out[@]}" -eq 1 ]] && [[ -d "${out[1]}" ]]; then
                        :
                    else
                        cd "$oldpwd"
                    fi
                    ;;
            esac
            zle fzf-redraw-prompt
            zle reset-prompt
    }
    zle -N fzf-downloads-widget
    bindkey '^O' fzf-downloads-widget
}


if type pass > /dev/null 2>&1; then
fzf-password() {
    /usr/bin/fd . --extension gpg --base-directory $HOME/.password-store |\
     sed -e 's/.gpg$//' |\
     sort |\
     fzf --no-multi --preview-window=hidden --bind 'alt-w:abort+execute-silent@touch /tmp/clipman_ignore ; wl-copy -n -- $(pass {})@,enter:execute-silent@ if [[ $PopUp ]]; then swaymsg "[app_id=^PopUp$] scratchpad show"; fi; touch /tmp/clipman_ignore; wl-copy -n -- $(pass {})@+abort'
}
zle -N fzf-password
# bindkey -e '^K' fzf-password
fi

if type clipman > /dev/null 2>&1; then
fzf-clipman() {
    clipman pick --max-items=2000 --print0 --tool=CUSTOM --tool-args="fzf --exact --read0 --preview 'echo {+}' --bind 'ctrl-_:execute-silent(echo -E {} > /tmp/pw; clipman clear --tool=CUSTOM --print0 --tool-args=\"cat /tmp/pw\")+abort,enter:execute-silent(wl-copy -- {+}; [ $PopUp ] && swaymsg \"[title=^PopUp$] scratchpad show\"; [ $subl ] && /opt/sublime_text/sublime_text --command smart_paste)+abort,alt-w:execute-silent(wl-copy -- {+}; swaymsg scratchpad show)+abort,esc:execute-silent([ $subl ] && swaymsg scratchpad show)+cancel'"
    rm -f /tmp/pw
}
zle -N fzf-clipman
# bindkey -e '^B' fzf-clipman
fi
