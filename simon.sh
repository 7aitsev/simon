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
WGET_OPTS='-q --show-progress --progress=bar:force:noscroll'
CURL_OPTS='-f --progress-bar'
RST=$(tput sgr0)
R=$(tput setaf 1)
G=$(tput setaf 2)
B=$(tput setaf 4)
Y=$(tput setaf 3)
BLD=$(tput bold)

###############################################################################
# Helper function for pretty-printing
###############################################################################
set_status() {
    printf -- '[%b    ] %s...' "$(tput sc)" "$1"
}

upd_status() {
    tput rc
    printf -- '%b%b\n' "$1" "$RST"
}

indent() {
    if [ -z "$1" ]; then
        printf '       '
    else
        printf '%*s' $((7+"$1")) ''
    fi
}

ok_status() {
    upd_status " $BLD${G}OK"
    printf '%b' "$1"
}

err_status() {
    upd_status "$BLD${R}ERR!"
    indent ""
}

print_diff() {
    printf '\n%b-----BEGIN DIFF BLOCK-----%b\n' "$Y" "$RST"
    printf -- '%b\n' "$(printf -- '%s\n' "$SNAPSHOT_NEW" \
        | diff -u --color=always "$SNAPSHOT_OLD" -)"
    printf '%b-----END DIFF BLOCK-----%b\n' "$Y" "$RST"
}

###############################################################################
# Check dependencies (use absolute paths for each of them)
###############################################################################
check_deps() {
    set_status 'Checking dependencies'
    SED="$(command -v sed)"
    if [ 0 -ne $? ] ; then
        err_status
        printf '%bThe script requires %bsed%b\n' "$R" "$BLD" "$RST" 1>&2
        exit 1
    fi
    local dlder
    for dlder in "wwget" "curl" ; do
        DOWNLOADER="$(command -v "$dlder")"
        if [ 0 -eq $? ] ; then
            ok_status
            return 0
        fi
    done
    err_status
    printf '%bThe script requires %bwget%b or %bcurl%b\n' \
        "$R" "$BLD" "$RST$R" "$BLD" "$RST" 1>&2
    exit 1
}

###############################################################################
# Download the index.html page from the site
###############################################################################
download_page()
{
    local site_filter snapshot rc
    site_filter='s/.$//;/^$/d;s/^[[:space:]]*//;s/[[:space:]]*$//'
    set_status 'Getting a new snapshot'
#SNAPSHOT_NEW=$("$SED" -e "$site_filter" <"simon.new")
#ok_status
#return 0
    printf '\n%s' "$B"
    case "$DOWNLOADER" in
        *wget )
            snapshot=$(eval "$DOWNLOADER $WGET_OPTS -O - -- $SITE")
            rc=$?
            ;;
        *curl )
            mkfifo curl_err 2>/dev/null
            head -1 <curl_err 1>&2 &
            snapshot=$(eval "$DOWNLOADER $CURL_OPTS -- $SITE" 2>curl_err)
            rc=$?
            rm curl_err
            ;;
        * )
            err_status
            printf -- '%bUnknown downloader: "%s"\n%b' \
               "$R" "$DOWNLOADER" "$RST" 1>&2
            exit 1
    esac

    if [ 0 -ne "$rc" ]; then
        err_status
        printf '%bUnexpected error: %b%s%b returns code %b%s%b\n' \
            "$R" "$BLD" "$DOWNLOADER" "$RST$R" "$BLD" "$rc" "$RST" 1>&2
        exit 1
    fi

    SNAPSHOT_NEW=$(printf -- '%s' "$snapshot" | sed -e "$site_filter")
    ok_status '\n'
}

###############################################################################
# Save a file
#
# $1 - an URL of the file
# $2 - a path to store the file
###############################################################################
file_downloader()
{
    if [ 2 -ne $# ] ; then
        err_status
        printf '%b@file_downloader: missing arguments%b\n' "$R" "$RST" 1>&2
        exit 1
    fi
    local rc
    case "$DOWNLOADER" in
        *wget )
            eval "$DOWNLOADER $WGET_OPTS -O $2 -- $1"
            rc=$?
            ;;
        *curl )
            mkfifo curl_err 2>/dev/null
            head -1 <curl_err 1>&2 &
            eval "$DOWNLOADER $CURL_OPTS -o $2 -- $1" 2>curl_err
            rc=$?
            rm curl_err
            ;;
        * )
            err_status
            printf -- '%bUnknown downloader: %b"%s"%b\n' \
               "$R" "$BLD" "$DOWNLOADER" "$RST" 1>&2
            exit 1
    esac
    # clean up in case of downloading failure
    if [ 0 -eq $rc ] ; then
        ok_status '\n'
    else
        err_status
        printf '%bUnexpected error: %b%s%b returns code %b%s%b\n' \
            "$R" "$BLD" "$DOWNLOADER" "$RST$R" "$BLD" "$rc" "$RST" 1>&2
        rm -f "$2"
    fi
}

###############################################################################
# Ask if a user wishes to overwrite the old snapshot with a new one
###############################################################################
ask_overwrite() {
    while true ; do
        read -rp '[ :: ] Overwrite the old snapshot? [y/n/diff] ' yn
        case "$yn" in
            [Yy]* )
                printf -- '%s' "$SNAPSHOT_NEW" >"$SNAPSHOT_OLD"
                indent
                printf '%bSnapshot overwritten%b\n' "$Y" "$Y"
                break;;
            [Nn]* )
                indent
                printf '%bSnapshot untouched%b\n' "$G" "$G";
                break;;
            [Dd]* )
                print_diff
                ;;
            * )
                indent
                printf 'Please answer yes or no\n';;
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
    set_status "Preparing a list of images"
    if [ -n "$links" ] ; then
        local fname
        local link
        ok_status
        # show a list of fetched link(s)
        for link in $links; do
            indent
            printf -- '%b%s%b\n' "$Y" "$(basename "$link")" "$RST"
        done
        # loop through the links again to download them
        for link in $links; do
            fname=$(basename "$link")
            # ask if a user wishes to save the file from the fetched link
            while true; do
                printf -- '[%b :: ] Save %b%s%b? [y/n] ' \
                    "$(tput sc)" "$Y" "$fname" "$RST"
                read -r yn
                case "$yn" in
                    [Yy]* )
                        file_downloader "${SITE}${link}" "./$fname"
                        break;;
                    [Nn]* )
                        upd_status " -- " && indent
                        printf 'Skipping...\n'
                        break;;
                    * )
                        indent
                        printf 'Please answer yes or no\n';;
                esac
            done
        done
    else
        upd_status "${Y}WARN" && indent
        printf 'No links fetched\n'
    fi
    ask_overwrite
}

###############################################################################
# Is there something new?
###############################################################################
find_diffs() {
    local diffs
    set_status "Comparing the snapshots"
    diffs=$(printf -- '%s\n' "$SNAPSHOT_NEW" | diff "$SNAPSHOT_OLD" -)
    if [ -n "$diffs" ]
        then
            upd_status "${Y}WARN" && indent
            printf 'Snapshots are different\n'
            fetch_and_download "$diffs"
        else
            ok_status "$(indent)"
            printf 'Snapshots are the same\n'
    fi
}

###############################################################################
# Entry point
###############################################################################

# a hack to resolve the issue with an inconsistent work of `tput sc/rc`
tput clear

check_deps

download_page

# Is there simon.old file?
set_status 'Looking for an old snapshot'
if [ -f "$SNAPSHOT_OLD" ] ; then
    ok_status "$(indent)"
    printf -- 'Snapshot found: %s\n' "$SNAPSHOT_OLD"
    find_diffs
else
    upd_status "${BLD}INFO"
    indent
    printf -- 'Snapshot "%s" not found\n' "$SNAPSHOT_OLD"
    printf -- '%s' "$SNAPSHOT_NEW" >"$SNAPSHOT_OLD"
    indent
    printf -- 'Snapshot of the site saved as "%s"\n' "$SNAPSHOT_OLD"
fi
