#!/bin/sh
# shellcheck disable=SC2039

###############################################################################
# Usage:
#
# 1. Place the script in a dedicated directory, e.g., "./simon/simon.sh".
# 2. cd to the folder.
# 3. Run the script and follow the prompts. If it's the first run, then
#    you'll be informed that a snapshot named "simon.old" has been created.
###############################################################################

###############################################################################
# Global vals and vars
###############################################################################
SITE='http://simonstalenhag.se/'
SNAPSHOT_NEW=''
IMAGES_DIR=''
SNAPSHOT_OLD='simon.old'
SED=''
DOWNLOADER=''
WGET_OPTS='-q'
CURL_OPTS='-q -sf'
RST="$(tput sgr0)"
R="$(tput setaf 1)"
G="$(tput setaf 2)"
Y="$(tput setaf 3)"
B="$(tput setaf 4)";
BLD="$(tput bold)"
STATUS_LAST_MSG=''
FWERR=''; FAUTO=''; FVERB=''; FNERR=''; FDIFF=''; FCOLR='always'
TMP=''
VBUF=''

###############################################################################
# Helper functions for pretty-printing
###############################################################################
redraw() {
    local slc lc
    slc="$(tput lines)"
    lc="$(printf -- '%s' "$VBUF" | wc -l)"

    tput -S << "END"
cup 0 0
ed
END
    if [ "$slc" -gt "$lc" ]; then
        printf -- '%s\n' "$VBUF"
    else
        printf -- '%s\n' "$(printf -- '%s' "$VBUF" | tail -"$lc")"
    fi
}

cleanup() {
    printf 'Enter any key to continue...'
    read -r TMP
    tput -S <<END
cup 0 0
ed
rmcup
END
}

vbuf_append() {
    VBUF="$VBUF$(printf -- '%s' "$1")"
    redraw
}

vbuf_replace_last() {
    VBUF="$(printf -- '%s' "$VBUF" | "$SED" -e '$ s|^.*|'"$1"'|g')"
    redraw
}

##
# Formats a line with a status and a given message and appends
# the line to VBUF.
#
# $1 - a message
# $2 - defines the status: usually it's an empty placeholder, so if the
#      parameter is empty, then the placeholder is filled with four spaces
set_status() {
    if [ 1 = "$FAUTO" ]; then
        [ 1 = "$FVERB" ] && printf -- ':: %s ' "$1"
        return
    fi
    local status msg
    [ -z "$2" ] && status='    ' || status="$2"
    msg="$(printf -- '[%s] %s' "$status" "$1")"
    # if this isn't the first status line - prepend '\n'
    [ -n "$STATUS_LAST_MSG" ] && msg="$(printf '\n%s' "$msg")"
    STATUS_LAST_MSG="$(printf -- '%s' "$1")"

    vbuf_append "$msg"
}

##
# Updates the status in a line which is obtained from a VBUF
#
# $1 (required) - a type: one of OK, ERR!, WARN, INFO, or a custom type.
# $2 (optional) - a string which can be appened to a message (can be empty).
#                 the sring is needed for saving user input after a prompt.
upd_status() {
    if [ -z "$1" ]; then
        put_descr "${R}@upd_status: ${BLD}type$RST$R wasn't provided$RST"
        exit 1
    fi
    [ -n "$2" ] && STATUS_LAST_MSG="$STATUS_LAST_MSG$2"
    local msg st
    FWERR=0
    case "$1" in
        OK )    st=" $BLD${G}OK$RST ";;
        ERR\! ) st="$BLD${R}ERR!$RST"; FWERR=1;;
        WARN )  st="$BLD${Y}WARN$RST";;
        INFO )  st="${BLD}INFO$RST";;
        * )     st="$1"
    esac
    if [ 1 = "$FAUTO" ]; then
        [ 1 = "$FVERB" ] && printf '%s\n' "$st"
        return
    fi
    msg="$(printf -- '[%s] %s' "$st" "$STATUS_LAST_MSG")"

    vbuf_replace_last "$msg"
}

##
# Prints $1 with indentation after a status line
put_descr() {
    if [ 1 = "$FAUTO" ]; then
        if [ 1 = "$FWERR" ]; then
            [ 0 = "$FNERR" ] && printf '%s\n' "$1" >&2
        else
            [ 1 = "$FVERB" ] && printf '%s\n' "$1"
        fi
        return
    fi
    vbuf_append "$(printf -- '\n       %s' "$1")"
}

##
# Get length of the latest string in VBUF. Count only printable characters,
# i.e. without special symbols for text manipulation.
# The length is needed to put the cursor right after a prompt for user input.
put_cursor_after_prompt() {
    local xoffset
    xoffset="$(printf -- '%s' "$VBUF" | tail -1 \
        | tr -d "$R$G$Y$RST$BLD" | wc -m)"
    # move the cursor up on the line with a prompt
    tput cuu1
    # place the cursor after the prompt
    tput cuf "$((xoffset+2))"
}

##
# Set a prompt for user input. Can be updated simply with upd_status
set_prompt() {
  set_status "$1" ' :: '
  put_cursor_after_prompt
}

print_diff() {
    printf -- '%s\n' "$SNAPSHOT_NEW" \
       | diff -u --color="$FCOLR" "$SNAPSHOT_OLD" -
}

##
# Resets global variables related to text manipulation and removes those
# special characters from VBUF if it's not empty.
disable_colors() {
    FCOLR='never'
    if [ -n "$VBUF" ]; then
        VBUF="$(printf '%b\n' "$VBUF" | tr -d "$RST$R$G$B$BLD")"
    fi
    RST=''; R=''; G=''; B=''; BLD=''
}

###############################################################################
# Functions for parsing options and arguments
###############################################################################
print_help() {
    printf '%s\n' \
"USAGE:
  simon [OPTIONS]

OPTIONS:
  -a      - enter non-interactive mode
  -i dir  - define a directory to store images
  -s path - set a path to store and use an old snapshot
  -c      - disable colors
  -h      - show the help and exit (interactive mode only)
  -v      - verbose output (non-interactive mode only)
  -q      - disable errors (non-interactive mode only)
  -d      - print diff (only with -v in non-interactive mode)
"
    # a regular error code is 1, but that case should be distinguished
    # from both a normal execution and a faulty one
    exit 3
}

##
# Append $1 to VBUF (hide output). Call args_unstash to print out all
# stashed messages.
args_stash() {
    VBUF="$VBUF$(printf -- '%b' "$1")"
}

##
# Output content of VBUF and zero it out. The function assumes that
# every line was prepended with leading \n. So it removes the first empty
# line prior to printing.
args_unstash() {
    [ 0 = "$FVERB" ] && return
    local lc
    lc=$(printf -- '%s' "$VBUF" | wc -l)
    printf -- '%s' "$VBUF" | tail -n "$lc" | uniq
    VBUF=''
}

args_out() {
    [ 0 = "$FVERB" ] && return
    printf -- '%b\n' "$1"
}

args_err() {
    [ 1 = "$FNERR" ] && return
    printf -- '%b\n' "$1" >&2
}

##
# The function parses arguments in such way that a user will be notified
# about all wrong options. Also the behavior should be consistent. If there
# is one or more -h switches - print help once, even if there are more options
# like in "./simon -xxyzhh". Note that in the example command illegal option
# "-x" appeared twice, but the warning should be outputted only once. If
# user do not want to see any regular messages in non-interactive mode
# (no "-v"), no messages should be printed, even errors if "-q" was specified.
args() {
    local a c h v q d opts
    while getopts ':ai:s:chvqd' opts; do
        case "$opts" in
            a ) a=1;;
            i ) IMAGES_DIR="$OPTARG";;
            s ) SNAPSHOT_OLD="$OPTARG";;
            c ) c=1;;
            h ) h=1;;
            v ) v=1;;
            q ) q=1;;
            d ) d=1;;
            \? ) args_stash "\\n${B}Unknown option: -$OPTARG$RST";;
            : ) printf 'Option -%s requires an argument\n' "$OPTARG" >&2
                exit 1
                # TODO: this doesn't honor any options above: delay processing
        esac
    done

    [ -n "$c" ] && disable_colors

    if [ -z "$a" ]; then
        FAUTO=0; FVERB=1; FNERR=0; FDIFF=0
        [ -n "$h" ] && print_help
        [ -n "$v" ] && args_stash "\\n${B}WARN: -v has no impact$RST"
        [ -n "$q" ] && args_stash "\\n${B}WARN: -q has no impact$RST"
        [ -n "$d" ] && args_stash "\\n${B}WARN: -d has no impact$RST"
    else
        FAUTO=1
        [ -n "$v" ] && FVERB=1 || FVERB=0
        [ -n "$q" ] && FNERR=1 || FNERR=0
        [ -n "$d" ] && FDIFF=1 || FDIFF=0
        if [ 1 = "$FVERB" ] && [ 1 = "$FNERR" ]; then
            TMP="$R${BLD}ERR!$RST$R: the combination of -v and -q makes"
            TMP="$TMP no sense.\n      Proceeding with the defaults "
            TMP="$TMP (no -v and -q)...$RST"
            printf '%b\n' "$TMP" >&2
            FVERB=0; FNERR=0
        fi
        if [ 1 = "$FDIFF" ] && [ 0 = "$FVERB" ] && [ 0 = "$FNERR" ]; then
            TMP="$R${BLD}ERR!$RST$R: -d option has no sense without -v."
            TMP="$TMP\n      Ignoring -d and proceeding...$RST"
            printf '%b\n' "$TMP" >&2
            FVERB=0; FNERR=0
        fi
        args_unstash
        [ -n "$h" ] && \
            args_out "${B}WARN: -h has no effect in non-interactive mode$RST"
    fi

    # check if a directory for images exists
    if ! [ -d "${IMAGES_DIR:=./}" ]; then
        args_err "${R}No such directory: $IMAGES_DIR$RST"
        exit 1
    fi
    # the path must be valid
    case "${SNAPSHOT_OLD:=./simon.old}" in
        # a given path has to contain a file name part
        */ | . | \.\. | */\. | */\.\.)
            TMP="${R}Specify a path to a ${BLD}file$RST$R"
            TMP="$TMP for an old snapshot$RST"
            args_err "$TMP"
            exit 1
            ;;
        * )
            # check if a path for a snapshot contains an existing directory
            if ! [ -d "$(dirname "$SNAPSHOT_OLD")" ]; then
                TMP="${R}No such directory: $(dirname "$SNAPSHOT_OLD")$RST"
                args_err "$TMP"
                exit 1
            fi
            # check if a path is not a directory
            if [ -d "$SNAPSHOT_OLD"are ]; then
                TMP="${R}You provided a path to an existing directory;"
                TMP="$TMP not to a snapshot$RST"
                args_err "$TMP"
                exit 1
            fi
    esac

    # notify about warnings if VBUF not empty
    if [ 0 = "$FAUTO" ] && [ -n "$VBUF" ]; then
        args_unstash
        printf '\nEnter "q" to leave or any other key to continue... '
        read -r q
        [ q = "$q" ] && exit 0
    fi

    if [ 0 = "$FAUTO" ]; then
        tput smcup
        trap redraw WINCH
        trap cleanup EXIT
    fi
}

###############################################################################
# Check dependencies (use absolute paths for each of them)
###############################################################################
check_deps() {
    set_status 'Checking dependencies...'
    SED="$(command -v sed)"
    # shellcheck disable=SC2181
    if [ 0 -ne $? ] ; then
        upd_status 'ERR!'
        put_descr "${R}The script requires ${BLD}sed$RST"
        exit 1
    fi
    local dlder
    for dlder in 'wget' 'curl' ; do
        DOWNLOADER="$(command -v "$dlder")"
        # shellcheck disable=SC2181
        if [ 0 -eq $? ] ; then
            upd_status 'OK'
            return 0
        fi
    done
    upd_status 'ERR!'
    put_descr "${R}The script requires ${BLD}wget$RST$R or ${BLD}curl$RST"
    exit 1
}

###############################################################################
# Download the index.html page from the site
###############################################################################
download_page()
{
    local site_filter snapshot rc
    site_filter='s/.$//;/^$/d;s/^[[:space:]]*//;s/[[:space:]]*$//'
    set_status 'Getting a new snapshot...'
    case "$DOWNLOADER" in
        *wget )
            snapshot=$(eval "$DOWNLOADER $WGET_OPTS -O - -- $SITE")
            rc=$?
            ;;
        *curl )
            snapshot=$(eval "$DOWNLOADER $CURL_OPTS -- $SITE")
            rc=$?
            ;;
        * )
            upd_status 'ERR!'
            put_descr "${R}Unknown downloader: \"$DOWNLOADER\"$RST"
            exit 1
    esac

    if [ 0 -ne "$rc" ]; then
        upd_status 'ERR!'
        TMP="${R}Unexpected error: ${BLD}$(basename "$DOWNLOADER")$RST$R"
        TMP="$TMP returned code $BLD$rc$RST"
        put_descr "$TMP"
        exit 1
    fi

    SNAPSHOT_NEW=$(printf -- '%s' "$snapshot" | "$SED" -e "$site_filter")
    upd_status 'OK'
}

###############################################################################
# Save a file. To restore a user input the function updates the status
# by placing "yes" after the prompt. With the approach there's no need for
# passing an actual user input but it's obvious that the answer was '[Y/y]*'
#
# $1 (required) - an URL of the file
# $2 (required) - a path to store the file
###############################################################################
file_downloader() {
    if [ 2 -ne $# ] ; then
        upd_status 'ERR!' 'yes'
        put_descr "${R}@file_downloader: missing arguments$RST"
        exit 1
    fi
    local rc
    case "$DOWNLOADER" in
        *wget )
            eval "$DOWNLOADER $WGET_OPTS -O $2 -- $1"
            rc=$?
            ;;
        *curl )
            eval "$DOWNLOADER $CURL_OPTS -o $2 -- $1"
            rc=$?
            ;;
        * )
            upd_status 'ERR!' 'yes'
            put_descr "${R}Unknown downloader: \"$DOWNLOADER\"$RST"
            exit 1
    esac
    # clean up in case of downloading failure
    if [ 0 -eq $rc ] ; then
        upd_status 'OK' 'yes'
    else
        upd_status 'ERR!' 'yes'
        TMP="${R}Unexpected error: ${BLD}$(basename "$DOWNLOADER")$RST$R"
        TMP="$TMP returns code $BLD$rc$RST"
        put_descr "$TMP"
        rm -f "$2"
    fi
}

###############################################################################
# Ask if a user wishes to overwrite the old snapshot with a new one
###############################################################################
ask_overwrite() {
    local yn
    while true ; do
        if [ 0 = "$FAUTO" ]; then
            set_prompt 'Overwrite the old snapshot? [y/n/diff] '
            read -r yn
        else
            if [ 1 = "$FDIFF" ] && [ 1 = "$FVERB" ]; then
                printf '%s-----BEGIN DIFF BLOCK-----%s\n' "$B" "$RST"
                print_diff
                printf '%s-----END DIFF BLOCK-----%s\n' "$B" "$RST"
            fi
            set_status 'Overriding the old snapshot...'
            yn='y'
        fi
        case "$yn" in
            [Yy]* )
                printf -- '%s' "$SNAPSHOT_NEW" >"$SNAPSHOT_OLD"
                upd_status 'WARN' "$yn"
                put_descr "${Y}Snapshot overwritten$RST"
                break;;
            [Nn]* )
                upd_status 'INFO' "$yn"
                put_descr "${BLD}Snapshot untouched$RST"
                break;;
            [Dd]* )
                upd_status ' <> ' "$yn"
                print_diff | less -R
                ;;
            * )
                upd_status ' :: ' "$yn"
                put_descr 'Please answer yes or no'
        esac
    done
}

###############################################################################
# Fetch link(s) from diff and download pic(s)
#
# $1 - the diff between an old and a new snapshot
###############################################################################
fetch_and_download() {
    local links
    links=$(printf -- '%s' "$1" \
        | "$SED" -n '/^>/p' | cut -d '"' -f 2 \
        | "$SED" -n '/\.[jJ][pP][eE]\?[gG]/p' | sort -u)
    set_status 'Preparing a list of images...'
    if [ -n "$links" ] ; then
        local fname link yn xoffset
        upd_status 'OK'
        # show a list of fetched link(s)
        for link in $links; do
            put_descr "$Y$(basename "$link")$RST"
        done
        # loop through the links again to download them
        for link in $links; do
            fname=$(basename "$link")
            # ask if a user wishes to save the file from the fetched link
            while true; do
                if [ 1 = "$FAUTO" ]; then
                    set_status "Downloading $B$fname$RST..."
                    yn='y'
                else
                    set_prompt "Save $Y$fname$RST? [y/n] "
                    read -r yn
                fi
                case "$yn" in
                    [Yy]* )
                        file_downloader "${SITE}${link}" "$IMAGES_DIR$fname"
                        break;;
                    [Nn]* )
                        upd_status ' -- ' "$yn"
                        put_descr 'Skipping...'
                        break;;
                    * )
                        upd_status ' :: ' "$yn"
                        put_descr 'Please answer yes or no'
                esac
            done
        done
    else
        upd_status 'INFO'
        put_descr 'No links are fetched'
    fi
    ask_overwrite
}

###############################################################################
# Is there something new?
###############################################################################
find_diffs() {
    local diffs
    set_status 'Comparing the snapshots...'
    diffs=$(printf -- '%s' "$SNAPSHOT_NEW" | diff "$SNAPSHOT_OLD" -)
    if [ -n "$diffs" ]
        then
            upd_status 'WARN'
            put_descr 'Snapshots are different'
            fetch_and_download "$diffs"
        else
            upd_status 'OK'
            put_descr 'Snapshots are the same'
    fi
}

###############################################################################
# Entry point
###############################################################################
main() {
    args "$@"
    check_deps
    download_page
    # Is there simon.old file?
    set_status 'Looking for an old snapshot...'
    if [ -f "$SNAPSHOT_OLD" ] ; then
        upd_status 'OK'
        put_descr "${G}Snapshot is found:$RST $Y$SNAPSHOT_OLD$RST"
        find_diffs
    else
        upd_status 'INFO'
        put_descr "Snapshot \"$SNAPSHOT_OLD\" is not found"
        printf -- '%s' "$SNAPSHOT_NEW" >"$SNAPSHOT_OLD"
        put_descr 'Snapshot of the site is created'
    fi
}

main "$@"
