#!/bin/zsh
#
# Best Goddamn zshrc in the whole world (if you're obsessed with Vim).
# Author: Seth House <seth@eseth.com>
# Version: 1.1.0
# Modified: 2007-03-01
# thanks to Adam Spiers, Steve Talley
# and to Unix Power Tools by O'Reilly
#
# {{{ setting options

setopt                          \
        auto_cd                 \
        chase_links             \
        noclobber               \
        complete_aliases        \
        extended_glob           \
        hist_ignore_all_dups    \
        hist_ignore_space       \
        ignore_eof              \
        share_history           \
        no_flow_control         \
        list_types              \
        mark_dirs               \
        path_dirs               \
        rm_star_wait

# }}}
# {{{ environment settings

umask 027
PATH=$PATH:$HOME/bin:/sbin:/usr/X11/bin:/usr/local/bin:/usr/local/sbin:/usr/sbin
MANPATH=$MANPATH:/usr/X11/man:/usr/local/man:/usr/local/share/man:/usr/man:/usr/share/man
CDPATH=$CDPATH::$HOME:/usr/local
HISTFILE=$HOME/.zsh_history
HISTSIZE=200
SAVEHIST=200
REPORTTIME=60       # Report time statistics for progs that take more than a minute to run
WATCH=notme         # Report any login/logout of other users
WATCHFMT='%n %a %l from %m at %T.'
#export LANG=en_US.UTF-8  # great for displaying utf-8 in the terminal, it tends to break things
export EDITOR=vi
export VISUAL=vi
export PAGER='less -iJMW'
export BROWSER='firefox'

# SSH Keychain
# http://www.gentoo.org/proj/en/keychain/
if which keychain >& /dev/null && [[ $UID != 0 ]]; then
    eval $(keychain -q --eval id_rsa)
fi

# }}}
# {{{ completions

autoload -U compinit
compinit -C
zstyle ':completion:*' list-colors "$LS_COLORS"
zstyle ':completion:*:*:*:users' ignored-patterns adm apache bin daemon ftp games gdm halt ident junkbust lp mail mailnull mysql named news nfsnobody nobody nscd ntp operator pcap pop postgres radvd rpc rpcuser rpm shutdown smmsp squid sshd sshfs sync uucp vcsa xfs
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;31'
zstyle ':completion:*:*:kill:*' menu yes select
zstyle -e ':completion:*:(ssh|scp|sshfs|ping|telnet|ftp|rsync):*' hosts 'reply=(${=${${(f)"$(cat {/etc/ssh_,$HOME/.ssh/known_}hosts(|2)(N) /dev/null)"}%%[# ]*}//,/ })'

# }}}
# {{{ prompt and theme

autoload -U promptinit
promptinit
prompt_adam2_setup

# }}}
# {{{ vi mode, mode display and extra vim-style keybindings
# TODO: why is there a half-second delay when pressing ? to enter search?
#       Update: found out has something to do with $KEYTIMEOUT and that
#       command-mode needs to use the same keys as insert-mode
# TODO: bug when searching through hist with n and N, when you pass the EOF the
#       term decrements the indent of $VIMODE on the right, which will collide
#       with the command you're typing

bindkey -v
bindkey "^?" backward-delete-char
bindkey -M vicmd "^R" redo
bindkey -M vicmd "u" undo
bindkey -M vicmd "ga" what-cursor-position

autoload edit-command-line
zle -N edit-command-line
bindkey -M vicmd "v" edit-command-line

showmode() { # may need adjustment with non adam2 themes
    RIGHT=$[COLUMNS-11]
    echo -n "7[$RIGHT;G" # one line down, right side
    echo -n "--$VIMODE--" # will be overwritten during long commands
    echo -n "8" # returns cursor to last position (normal prompt position)
}
makemodal () {
    eval "$1() { zle .'$1'; ${2:+VIMODE='$2'}; showmode }"
    zle -N "$1"
}
makemodal vi-add-eol           INSERT
makemodal vi-add-next          INSERT
makemodal vi-change            INSERT
makemodal vi-change-eol        INSERT
makemodal vi-change-whole-line INSERT
makemodal vi-insert            INSERT
makemodal vi-insert-bol        INSERT
makemodal vi-open-line-above   INSERT
makemodal vi-substitute        INSERT
makemodal vi-open-line-below   INSERT
makemodal vi-replace           REPLACE
makemodal vi-cmd-mode          NORMAL
unfunction makemodal

# }}}
# {{{ aliases

alias ls='ls -F --color'
alias la='ls -A'
alias ll='ls -lh'

alias less='less -iJMW'
alias cls='clear' # note: ctrl-L under zsh does something similar
alias ssh='ssh -X -C'
alias locate='locate -i'
alias lynx='lynx -cfg=$HOME/.lynx.cfg -lss=$HOME/.lynx.lss'
alias ducks='du -cks * | sort -rn | head -15'
alias ps='ps -opid,uid,cpu,time,command'

alias sc="exec screen -e'^Aa' -RD"
alias rsc="exec screen -e'^Ss' -RD"

alias vi='vim'
alias view='view'

# OS X versions
if [[ $(uname) == "Darwin" ]]; then
    alias ls='ls -FG'
    unalias locate
    alias lynx='lynx -cfg=$HOME/.lynx.cfg'
    alias top='top -ocpu'
fi

# }}}
# Miscellaneous Functions:
# {{{ calc()
# Command-line calculator (has some limitations...not sure the extent)(based on zsh functionality)

alias calc="noglob _calc"
function _calc() {
    echo $(($*))
}

# }}}
# {{{ body() | like head and tail

# Provides an in-between to head and tail to print a range of lines
# Usage: `body firstline lastline filename`
function body() {   
    head -$2 $3 | tail -$(($2-($1-1)))
}

# }}}
# {{{ pkill()
# Because OS X doesn't have pgrep :-(

function pkill() {
    HOSTTYPE=$(uname -s)

    SIGNAL=$1
    STRING=$2

    if [ -z "$1" -o -z "$2" ]
    then
        echo Usage: $0 signal string
        exit 1
    fi

    case $HOSTTYPE in
        Darwin|BSD)
        ps -a -opid,command | grep $STRING | awk '{ print $1; }' | xargs kill $SIGNAL
        ;;
        Linux|Solaris|AIX|HP-UX)
        ps -e -opid,command | grep $STRING | awk '{ print $1; }' | xargs kill $SIGNAL
        ;;
    esac
}

# }}}
# {{{ bookletize()
# Converts a PDF to a fold-able booklet sized PDF
# Print it double-sided and fold in the middle

bookletize ()
{
    if which pdfinfo && which pdflatex; then
        pagecount=$(pdfinfo $1 | awk '/^Pages/{print $2+3 - ($2+3)%4;}')

        # create single fold booklet form in the working directory
        pdflatex -interaction=batchmode \
        '\documentclass{book}\
        \usepackage{pdfpages}\
        \begin{document}\
        \includepdf[pages=-,signature='$pagecount',landscape]{'$1'}\
        \end{document}' 2>&1 >/dev/null
    fi
}

# }}}
# {{{ joinpdf()
# Merges, or joins multiple PDF files into "merged.pdf"

joinpdf () {
    gs -q -dNOPAUSE -dBATCH -sDEVICE=pdfwrite -sOutputFile=merged.pdf "$@"
}

# }}}
# {{{ dotsync()
# Checks for the lastest versions of various config files

dotsync ()
{
    dotsyncURI=http://eseth.org/filez/prefs
    dotsyncFiles=(
        Xresources
        lynx.cfg
        lynx.lss
        lynxrc
        nethackrc
        screenrc
        toprc
        vimrc
        gvimrc
        zshrc
    )
    dotsyncVimPlugins=(
        ToggleComment.vim
        vimbuddy.vim
    )
    dotsyncMozFiles=(
        bookmarks.html
        user.js
    )
    dotsyncMozChrome=(
        userChrome.css
        userContent.css
    )

    # Firefox files
    if [[ $1 == 'moz' ]]; then
        if pgrep firefox >& /dev/null; then
            echo "Please close Firefox first since it will overwrite these files on exit"
            return 1;
        fi
        if [[ ! -L $HOME/.firefox_home ]]; then
            echo "Symlink your Firefox profile dir to ~/.firefox_home first"
            return 1;
        fi
        for file in $dotsyncMozFiles
        do
            curl -f $dotsyncURI/$file -o $HOME/.firefox_home/$file
        done
        for file in $dotsyncMozChrome
        do
            curl -f $dotsyncURI/$file -o $HOME/.firefox_home/chrome/$file
        done
        return 0;
    fi

    # Misc dot files
    for file in $dotsyncFiles
    do
        curl -f -z $HOME/.$file $dotsyncURI/$file -o $HOME/.$file
    done

    # Vim files
    mkdir -m 750 -p $HOME/.vim/{tmp,plugin}
    for file in $dotsyncVimPlugins
    do
        curl -f -z $HOME/.vim/plugin/$file $dotsyncURI/$file -o $HOME/.vim/plugin/$file
    done

}

# }}}
# {{{ Django functions djedit & djsetup

# run this in your base project dir
djsetup()
{
    cd ..
    export PYTHONPATH=$PWD
    export DJANGO_SETTINGS_MODULE=$(basename $OLDPWD).settings
    cd -
}
# This may seem a little heavy-handed, but it's nice to have a convention for
# certain files in certain tabs. Computers are pretty fast these days. :-P
djedit() {
    screen -t $(basename $1) vim "+cd $1" \
        $1/{urls.py,models.py,views.py,forms.py} \
        $1/**/*py~**/__init__.py(N)~**/urls.py(N)~**/models.py(N)~**/forms.py(N)~**/views.py(N) \
        $1/templates/**/*.html(N)
}

# }}}
#
# EOF
