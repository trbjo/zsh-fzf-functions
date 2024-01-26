# Paste the selected command(s) from history into the command line
fzf-history-widget() {
    format_start=$'\033[4m'
    format_end=$'\033[0m \033[37m│\033[0m'
    numbers=($(fc -rli 1 | \
    sed -r "s/^ ?([0-9]{1,5}).(.{16})./\1$format_start\2$format_end/" | \
    fzf \
     --delimiter=' ' \
     --with-nth=2.. \
     --no-sort \
     --prompt="$(print -Pn ${_PROMPT})" \
     --no-extended \
     --bind 'enter:execute(echo {+1})+abort' \
     --no-hscroll \
     --tiebreak=index \
     --query="${LBUFFER}" \
     --preview-window=bottom,30% \
     --preview "xargs -0 <<< {6..}"))
    LBUFFER+="${history[${numbers[1]}]}"
    for number in ${numbers[@]:1}; LBUFFER+=$'\n'${history[$number]}
    zle reset-prompt
}
zle -N fzf-history-widget
bindkey '^R' fzf-history-widget

export FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS} \
--bind \"alt-t:page-down,\
alt-c:page-up,\
ctrl-e:replace-query,\
ctrl-b:toggle-all,\
change:top,\
ctrl-/:execute-silent(rm -rf {+})+abort,\
ctrl-r:toggle-sort,\
ctrl-q:unix-line-discard\" \
--multi \
--preview-window=right:50%:sharp:wrap \
--preview 'if [[ -d {} ]]
    then
        fancyls {}
    elif [[ {} =~ \"\.(jpeg|JPEG|jpg|JPG|png|webp|WEBP|PNG|gif|GIF|bmp|BMP|tif|TIF|tiff|TIFF)$\" ]]
    then
        identify -ping -format \"%f\\n%m\\n%w x %h pixels\\n%b\\n\\n%l\\n%c\\n\" {}
    elif [[ {} =~ \"\.(svg|SVG)$\" ]]
    then tiv -h \$FZF_PREVIEW_LINES -w \$FZF_PREVIEW_COLUMNS {}
    elif [[ {} =~ \"\.(pdf|PDF)$\" ]]
    then pdfinfo {}
    elif [[ {} =~ \"\.(zip|ZIP|sublime-package)$\" ]]
    then zip -sf {}
    elif [[ {} =~ \"(json|JSON)$\" ]]
    then jq --indent 4 --color-output < {}
else bat \
    --style=header,numbers \
    --terminal-width=\$((\$FZF_PREVIEW_COLUMNS - 6)) \
    --force-colorization \
    --italic-text=always \
    --line-range :70 {} 2>/dev/null; fi'"

if type fd > /dev/null 2>&1; then
    export FZF_DEFAULT_COMMAND="/usr/bin/fd --color always --exclude node_modules"
fi


alias fif='noglob _fif'
_fif() {
    [[ -z "$@" ]] && print "Need a string to search for!" && return 1
    rg \
        --files-with-matches \
        --no-messages \
        "$@" | \
    fzf \
        --prompt="$(print -Pn "${PROMPT_PWD:-$PWD} \e[3m$myQuery\e[0m") " \
        --preview "rg $RIPGREP_OPTS --pretty --context 10 '$@' {}"
}


# Ensure precmds are run after cd
fzf-redraw-prompt() {
    local precmd
    for precmd in $precmd_functions; do
        $precmd
    done
}
zle -N fzf-redraw-prompt

alias myfzf="eval 'myp=\$(print -Pn \${PROMPT})'
    fd --color always --exclude node_modules | \
    fzf \
        --prompt=\"\$myp\" \
        --bind 'ctrl-h:change-preview-window(right,75%|hidden|right,50%)' \
        --preview-window=right,50%,border-left"



fzf-widget() {
    eval 'myp=$(print -Pn "${PROMPT}")'
    fd --color always --exclude node_modules | \
    fzf \
        --prompt="$myp" \
        --bind 'ctrl-h:change-preview-window(right,75%|hidden|right,50%)' \
        --preview-window='right,50%,border-left' | open
    zle fzf-redraw-prompt
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
    [[ ! -z $DL_DIR ]] || return
    fzf-downloads-widget() {
            ls --color=always -ctd1 ${(q)DL_DIR}/* | fzf --tiebreak=index --delimiter=/ --with-nth=5.. --no-sort | open
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
fi

alias glo="eval 'myp=\$(print -Pn \${_PROMPT})'
    git log \
        --date=format-local:'%Y-%m-%d %H:%M' \
        --pretty=format:'%C(red)%h %C(green)%cd%C(reset) %C(cyan)●%C(reset) %C(yellow)%an%C(reset) %C(cyan)●%C(reset) %s' \
        --abbrev-commit \
        --color=always | \
    fzf \
        --header=\"\$myp\" \
        --header-first \
        --delimiter=' ' \
        --no-sort \
        --no-extended \
        --with-nth=2.. \
        --bind 'enter:become(print -l -- {+1})' \
        --bind 'alt-w:execute-silent(wl-copy -n -- {+1})+abort' \
        --bind 'ctrl-h:change-preview-window(down,75%|down,99%|hidden|down,50%)' \
        --bind 'ctrl-b:put( ● )' \
        --preview='
        typeset -a args=(--hyperlinks --width=\$(( \$FZF_PREVIEW_COLUMNS - 2)));
        [[ \$FZF_PREVIEW_COLUMNS -lt 160 ]] || args+=--side-by-side
        git show --color=always {1} | delta \$args' \
        --preview-window=bottom,50%,border-top"

load='_gitstatus=$(git -c color.status=always status --short --untracked-files=all $PWD)
    {
       rg "^\x1b\[32m.\x1b\[m" <<< $_gitstatus
    rg -v "^\x1b\[32m.\x1b\[m" <<< $_gitstatus &!
    }'

resetterm=$'\033[2J\033[3J\033[H'
cyan=$'\e[1;36;m'
magenta=$'\e[0;35;m'
white=$'\e[0;37;m'
reset=$'\e[0;m'
quote='\\\"'

alias gs="\
    eval 'myp=\$(print -Pn \${_PROMPT})'
    $load | fzf \
        --header=\"\$myp\" \
        --header-first \
        --delimiter='' \
        --exit-0 \
        --nth='4..' \
        --no-sort \
        --no-extended \
        --bind 'enter:become(print -l {+4..} | sed -e 's/^${quote}//' -e 's/${quote}$//')' \
        --bind 'ctrl-p:execute-silent(open {+4..})+become(print -l {+4..} | sed -e 's/^${quote}//' -e 's/${quote}$//')' \
        --bind 'ctrl-a:execute-silent(git add {+4..})+reload($load)' \
        --bind 'ctrl-c:execute-silent(git checkout {+4..})+reload($load)' \
        --bind 'ctrl-r:execute-silent(git restore --staged {+4..})+reload($load)' \
        --bind 'ctrl-n:execute(git add -p {+4..}; printf \"$resetterm\")+reload($load)' \
        --bind 'ctrl-h:change-preview-window(down,75%|down,99%|hidden|down,50%)' \
        --preview '
        typeset -a args=(--hyperlinks --width=\$(( \$FZF_PREVIEW_COLUMNS - 2)));
        [[ \$FZF_PREVIEW_COLUMNS -lt 160 ]] || args+=--side-by-side
        if [[ {} == \"?*\" ]]; then
                          git diff --no-index /dev/null {4..} | delta \$args;
                      else
                          git diff HEAD -- {4..} | delta \$args;
                      fi;' \
        --preview-window=bottom,50%,border-top"
