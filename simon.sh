#!/bin/bash

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
SNAPSHOT_OLD='simon.old'
SITE='http://simonstalenhag.se/'
SNAPSHOT_NEW=''
SED=''
DOWNLOADER=''
WGET_OPTS='-q'
CURL_OPTS='-s -f'
RST=$(tput sgr0)
R=$(tput setaf 1)
G=$(tput setaf 2)
Y=$(tput setaf 3)
BLD=$(tput bold)
VBUF=''
STATUS_LAST_MSG=''
TMP=''

###############################################################################
# Helper function for pretty-printing
###############################################################################
redraw() {
    local slc lc
    slc="$(tput lines)"
    lc="$(printf -- '%s' "$VBUF" | wc -l)"

    clear
    tput -S << "END"
clear
cup 0 0
END
    if [ "$slc" -gt "$lc" ]; then
        printf -- '%s\n' "$VBUF"
    else
        printf -- '%s\n' "$(printf -- '%s' "$VBUF" | tail -"$lc")"
    fi
}

trap redraw WINCH

cleanup() {
    tput rmcup
}

trap cleanup EXIT

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
    case "$1" in
        OK )    st=" $BLD${G}OK$RST ";;
        ERR\! ) st="$BLD${R}ERR!$RST";;
        WARN )  st="$BLD${Y}WARN$RST";;
        INFO )  st="${BLD}INFO$RST";;
        * )     st="$1"
    esac
    msg="$(printf -- '[%s] %s' "$st" "$STATUS_LAST_MSG")"

    vbuf_replace_last "$msg"
}

##
# Prints $1 with indentation after a status line
put_descr() {
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
       | diff -u --color=always "$SNAPSHOT_OLD" - | less -R
}

###############################################################################
# Check dependencies (use absolute paths for each of them)
###############################################################################
check_deps() {
    set_status 'Checking dependencies...'
    SED="$(command -v sed)"
    if [ 0 -ne $? ] ; then
        upd_status 'ERR!'
        put_descr "${R}The script requires ${BLD}sed$RST"
        exit 1
    fi
    local dlder
    for dlder in "wget" "curl" ; do
        DOWNLOADER="$(command -v "$dlder")"
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
file_downloader()
{
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
        set_prompt 'Overwrite the old snapshot? [y/n/diff] '
        read -r yn
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
                print_diff
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
    set_status "Preparing a list of images..."
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
                yn='n'
                set_prompt "Save $Y$fname$RST? [y/n] "
                read -r yn
                case "$yn" in
                    [Yy]* )
                        file_downloader "${SITE}${link}" "./$fname"
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
        upd_status 'WARN'
        put_descr '{Y}No links fetched{Y}'
    fi
    ask_overwrite
}

###############################################################################
# Is there something new?
###############################################################################
find_diffs() {
    local diffs
    set_status "Comparing the snapshots..."
    diffs=$(printf -- '%s\n' "$SNAPSHOT_NEW" | diff "$SNAPSHOT_OLD" -)
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
    tput smcup
    check_deps
    download_page
    # Is there simon.old file?
    set_status 'Looking for an old snapshot...'
    if [ -f "$SNAPSHOT_OLD" ] ; then
        upd_status 'OK'
        put_descr "${G}Snapshot found:$RST $Y$SNAPSHOT_OLD$Y"
        find_diffs
    else
        upd_status 'INFO'
        put_descr "Snapshot \"$SNAPSHOT_OLD\" not found"
        printf -- '%s' "$SNAPSHOT_NEW" >"$SNAPSHOT_OLD"
        put_descr "Snapshot of the site saved as \"$SNAPSHOT_OLD\""
    fi
}

main
