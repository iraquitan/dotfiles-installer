#!/bin/zsh

# Release some autoloads
autoload -Uz colors; colors
autoload -Uz is-at-least; is-at-least

typeset    TMPFILE="/tmp/.iraquitan-dotfiles-$$$RANDOM"
typeset    XDG_DATA_HOME="$HOME/.local/share"
typeset    XDG_CONFIG_HOME="$HOME/.config"
typeset    YADM_HOME="$XDG_DATA_HOME/yadm_project"

if [[ -z $ZSH_VERSION ]]; then
    printf "dotfiles requires zsh 4.1.9 or newer\n"
    exit 1
fi

if [[ -z $YADM_DIR ]]; then
    export YADM_DIR="$XDG_DATA_HOME/yadm"
fi

spin()
{
    local \
        before_msg="$1" \
        after_msg="$2" \
        cursor="$3"
    local    spinner
    local -a spinners
    spinners=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)

    # if [ "$3" != ""]; then
    #     local cursor=
    # fi

    # hide cursor
    if [[ $cursor -ne 0 ]]; then
        tput cnorm || true
    else
        tput civis
    fi

    while true
    do
        for spinner in "${spinners[@]}"
        do
            if [[ -f $TMPFILE ]]; then
                rm -f $TMPFILE
                tput cnorm
                return 1
            fi
            sleep 0.05
            printf " $fg[white]$spinner$reset_color  $before_msg\r" 2>/dev/null
        done

        echo "$jobstates" \
            | awk '
            /[0-9]+=/ {
                jobs[++job_count] = $0
            }
            END {
                for (i = 1; i <= job_count; i++) {
                    print(jobs[i])
                }
                exit job_count == 0
            }' \
                | xargs test -z && break
    done

    if [[ -n $after_msg ]]; then
        printf "\033[2K"
        printf " $fg_bold[blue]\U2714$reset_color  $after_msg\n"
    fi 2>/dev/null

    # show cursor
    tput cnorm || true
}

execute()
{
    local    arg title error
    local -a args errors

    while (( $# > 0 ))
    do
        case "$1" in
            --title)
                title="$2"
                shift
                ;;
            --error)
                errors+=( "$2" )
                shift
                ;;
            --cursor)
                cursor="$2"
                shift
                ;;
            -*|--*)
                return 1
                ;;
            *)
                args+=( "$1" )
                ;;
        esac
        shift
    done

    {
        for arg in "${args[@]}"
        do
            ${~${=arg}} &>/dev/null
            # When an error causes
            if [[ $status -ne 0 ]]; then
                # error mssages
                printf "\033[2K" 2>/dev/null
                printf \
                    " $fg[yellow]\U26A0$reset_color  $title [$fg[red]FAILED$reset_color]\n" \
                    2>/dev/null
                printf "$status\n" >"$TMPFILE"
                # additional error messages
                if (( $#errors > 0 )); then
                    for error in "${errors[@]}"
                    do
                        printf "    -> $error\n" 2>/dev/null
                    done
                fi
            fi
        done
    } &

    spin \
        "$title" \
        "$title [$fg[green]SUCCEEDED$reset_color]" \
        "$cursor"

    if [[ $status -ne 0 ]]; then
	printf "\033[2K" 2>/dev/null
	printf "Oops \U2620 ... Try again!\n" 2>/dev/null
	exit 1
    fi
}

restore_zsh_config()
{
    echo "Looking for original zsh config..."
    if [ -f ~/.zshrc.pre-iraquitan ] || [ -h ~/.zshrc.pre-iraquitan ]; then
        echo "Found ~/.zshrc.pre-iraquitan -- Restoring to ~/.zshrc";

        if [ -f ~/.zshrc ] || [ -h ~/.zshrc ]; then
            ZSHRC_SAVE=".zshrc.iraquitan-uninstalled-$(date +%Y%m%d%H%M%S)";
            echo "Found ~/.zshrc -- Renaming to ~/${ZSHRC_SAVE}";
            mv ~/.zshrc ~/"${ZSHRC_SAVE}";
        fi

        mv ~/.zshrc.pre-iraquitan ~/.zshrc;

        echo "Your original zsh config was restored. Please restart your session."
    else
        if hash chsh >/dev/null 2>&1; then
            echo "Switching back to bash"
            chsh -s /bin/bash
        else
            echo "You can edit /etc/passwd to switch your default shell back to bash"
        fi
    fi
}

rm_config()
{
    echo "Removing ~/.config dirs"
    for c_dir in brew git motd tmux vim zsh
    do
        rm -rf $XDG_CONFIG_HOME/$c_dir
    done
}

rm_share_data()
{
    echo "Removing ~/.local/share dirs"
    for local_s in yadm yadm_project
    do
        rm -rf $XDG_DATA_HOME/$local_s
    done
}

unlink_yadm()
{
    echo "Unlinking yadm form /usr/local/bin" 
    rm -f -- /usr/local/bin/yadm
}

rm_gitmodules()
{
    echo "Removing .gitmodules" 
    rm -f -- $HOME/.gitmodules
}

printf "Are you sure you want to remove iraquitan's dotfiles? [y/N] "
    if ! read -q; then
        echo "Uninstall cancelled"
        exit
    fi

execute \
    --title \
    "Checking if your zsh version is newer than 4.1.9" \
    --cursor \
    0 \
    "sleep 1" \
    "is-at-least 4.1.9"

execute \
    --title \
    "Restoring .zshrc config" \
    --cursor \
    1 \
    restore_zsh_config

execute \
    --title \
    "Removing application config from $XDG_CONFIG_HOME" \
    --cursor \
    0 \
    rm_config

execute \
    --title \
    "Removing application data from $XDG_DATA_HOME" \
    --cursor \
    0 \
    rm_share_data

execute \
    --title \
    "Unlinking yadm from /usr/local/bin" \
    --cursor \
    0 \
    unlink_yadm

execute \
    --title \
    "Removing git submodules (.gitmodules) from $HOME" \
    --cursor \
    0 \
    rm_gitmodules

printf " All processes are successfully completed \U1F389\n"
printf " For more information, see ${(%):-%U}https://github.com/iraquitan/dotfiles${(%):-%u} \U1F33A\n"
printf " Thanks for trying out dotfiles by @iraquitan. It's been uninstalled.\n"
