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

yadm_check()
{
    if ! (( $+commands[yadm] )); then
        git clone https://github.com/TheLocehiliosan/yadm.git $YADM_HOME
        ln -s $YADM_HOME/yadm /usr/local/bin/yadm
    else
        cd $YADM_HOME
        git pull
    fi 
}

bkp_zshrc()
{
    echo "Looking for original zsh config..."
    if [ -f $HOME/.zshrc ] || [ -h $HOME/.zshrc ]; then
        echo "Found ~/.zshrc -- backing up to ~/.zshrc.pre-iraquitan";
        mv $HOME/.zshrc $HOME/.zshrc.pre-iraquitan;
        echo "Your original zsh config was backed to ~/.zshrc.pre-iraquitan."
    fi
}

change_default_shell()
{
    if [ ! $0 = "-zsh" ]; then
        echo 'Changing default shell to zsh'
        chsh -s /bin/zsh
    else
        echo 'Already using zsh'
    fi
}

execute \
    --title \
    "Checking if your zsh version is newer than 4.1.9" \
    --cursor \
    0
    "sleep 1" \
    "is-at-least 4.1.9"

execute \
    --title \
    "Installing/Updating yadm" \
    --error \
    "Is git installed?" \
    --error \
    "Does '$YADM_HOME' already exist?" \
    --cursor \
    0
    yadm_check

execute \
    --title \
    "Backing up .zshrc config file" \
    --cursor \
    0
    bkp_zshrc

execute \
    --title \
    "Configuring dotfiles" \
    --error \
    "Is YADM installed?" \
    --error \
    "Does '$YADM_DIR' already exist?" \
    --cursor \
    0
    "yadm -Y $YADM_DIR clone https://github.com/iraquitan/dotfiles.git --bootstrap"

execute \
    --title \
    "Installing vim plugins with Vim Plug" \
    --error \
    "Is Vim Plug installed?" \
    --cursor \
    0
    "vim +PlugInstall +qall"

execute \
    --title \
    "Setting zsh as default shell" \
    --cursor \
    1
    change_default_shell

printf " All processes are successfully completed \U1F389\n"
printf " For more information, see ${(%):-%U}https://github.com/iraquitan/dotfiles${(%):-%u} \U1F33A\n"
printf " Enjoy the new dotfiles by @iraquitan!\n"

