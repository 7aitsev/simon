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
RST=$(tput sgr0)
R=$(tput setaf 1)
G=$(tput setaf 2)
B=$(tput setaf 3)
BLD=$(tput bold)
UP=$(tput cuu1)

###############################################################################
# Helper function for pretty-printing
###############################################################################
set_status() {
    printf -- '[%b    ] %s' "$(tput sc)" "$1"
}

upd_status() {
    tput rc
    printf -- '%b%b\n' "$1" "$RST"
}

indent() {
    if [ -z "$1" ]; then
        printf '       '
    else
        printf '%*s' $((7+"$1")) ""
    fi
}

ok_status() {
    upd_status "$1 $BLD${G}OK"
    printf "%b" "$2"
}

err_status() {
    upd_status "$1$BLD${R}ERR!"
    indent ""
}

###############################################################################
# Check dependencies (use absolute paths for each of them)
###############################################################################
check_deps() {
    set_status 'Checking dependencies...'
    SED="$(command -v sed)"
    if [ 0 -ne $? ] ; then
        err_status
        printf '%bThe script requires %bsed%b\n' "$R" "$BLD" "$RST" 1>&2
        exit 1
    fi
    local dlder
    for dlder in "wgett" "curl" ; do
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
    set_status 'Reaching the site...'
#SNAPSHOT_NEW=$("$SED" -e "$site_filter" <"simon.new")
#ok_status
#return 0
    printf '\n%s' "$B"
    case "$DOWNLOADER" in
        *wget )
            snapshot=$("$DOWNLOADER" -q --show-progress -O - -- "http://speedtest-sfo1.digitalocean.com/test_checksums.txt")
            rc=$?
#            SNAPSHOT_NEW=$("$DOWNLOADER" -nv --show-progress -O - -- "$SITE" \
#                | sed -e "$site_filter")
            ;;
        *curl )
            snapshot=$("$DOWNLOADER" -f --progress -- "http://speedtest-sfo1.digitalocean.com/test_checksums.txt" >/dev/null)
            rc=$?
#            SNAPSHOT_NEW=$("$DOWNLOADER" -f --progress -- "$SITE" \
#                | sed -e "$site_filter")
            ;;
        * )
            err_status
            printf -- '%bUnknown downloader: "%s"\n%b' \
               "$R" "$DOWNLOADER" "$RST" 1>&2
            exit 1
    esac

    if [ 0 -ne "$rc" ]; then
        err_status "$UP"
        printf '%bUnexpected error: %b%s%b returns code %b%s%b\n' \
            "$R" "$BLD" "$DOWNLOADER" "$RST$R" "$BLD" "$rc" "$RST" 1>&2
        exit 1
    fi

    ok_status "$UP$UP" '\n'
    exit 0
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
        printf '@file_downloader: missing arguments\n' 1>&2
        return 1
    fi
    local rc
    case "$DOWNLOADER" in
        *wget )
            "$DOWNLOADER" -O "$2" -nv --show-progress -- "$1"
            rc=$?
            ;;
        *curl )
            "$DOWNLOADER" -o "$2" -f --progress-bar -- "$1"
            rc=$?
            ;;
        * )
            printf -- 'Unknown downloader: "%s"\n' "$DOWNLOADER" 1>&2
            exit 1
    esac
    # clean up in case of downloading failure
    if [ 0 -ne $rc ] ; then
        rm "$2"
    fi
}

###############################################################################
# Ask if a user wishes to overwrite the old snapshot with a new one
###############################################################################
ask_overwrite() {
    printf '\n'
    while true ; do
        read -rp 'Overwrite the old snapshot (y/n)? ' yn
        case "$yn" in
            [Yy]* )
                printf -- '%s' "$SNAPSHOT_NEW" >"$SNAPSHOT_OLD"
                printf 'Snapshot overwritten\n'
                break;;
            [Nn]* )
                printf 'Snapshot untouched\n';
                break;;
            * )
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
    printf '\n'
    if [ -n "$links" ] ; then
        local fname
        local link
        # show a list of fetched link(s) and loop through them
        printf -- 'Fetched links:\n%s\n\n' "$links"
        for link in $links; do
            fname=$(printf -- '%s' "$link" | cut -d '/' -f 2)
            # ask if a user wishes to save the file from the fetched link
            while true; do
                read -rp "Save \"$fname\" (y/n)? " yn
                case "$yn" in
                    [Yy]* )
                        file_downloader "${SITE}${link}" "./$fname"
                        break;;
                    [Nn]* )
                        #printf 'Skipping...\n'
                        break;;
                    * )
                        printf 'Please answer yes or no\n';;
                esac
            done
        done
    else
        printf 'No links fetched...\n\n'
        printf -- '-----BEGIN DIFF BLOCK-----\n'
        printf -- '%s\n' "$1"
        printf -- '-----END DIFF BLOCK-----\n'
    fi
    ask_overwrite
}

###############################################################################
# Is there something new?
###############################################################################
find_diffs() {
    local diffs
    diffs=$(printf -- '%s\n' "$SNAPSHOT_NEW" | diff "$SNAPSHOT_OLD" -)
    printf '\n'
    if [ -n "$diffs" ]
        then
            printf 'Snapshots are different\n'
            fetch_and_download "$diffs"
        else
            printf 'Snapshots are the same\n'
    fi
}

###############################################################################
# Entry point
###############################################################################

check_deps

download_page

# Is there simon.old file?
if [ -f "$SNAPSHOT_OLD" ]
    then
        printf -- 'Snapshot "%s" found\n' "$SNAPSHOT_OLD"
        find_diffs
    else
        printf -- 'Snapshot "%s" not found\n' "$SNAPSHOT_OLD"
        printf -- '%s' "$SNAPSHOT_NEW" >"$SNAPSHOT_OLD"
        printf -- 'Snapshot of the site saved as "%s"\n' "$SNAPSHOT_OLD"
fi
