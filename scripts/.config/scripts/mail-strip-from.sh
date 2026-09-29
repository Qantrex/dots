#!/usr/bin/env bash
# Remove the mbox "From <sender> <date>" line from the top of local wbauer mails.
#
# The wbauer server stores mail with that line, which aerc cannot parse (see
# ~/.config/isyncrc). Run after every mbsync; aerc's check-mail-cmd does that.
# Only files changed since the last run are read, so repeat runs are cheap.

dir=~/Mail/wbauer
stamp=$dir/.strip-stamp
[[ -d $dir ]] || exit 0

# -cnewer, not -newer: mbsync sets a mail's mtime to its arrival date
# (CopyArrivalDate), so fresh downloads look older than the stamp. The ctime is
# when the file appeared here and cannot be backdated.
newer=()
[[ -e $stamp ]] && newer=(-cnewer "$stamp")
# Take the timestamp before scanning, so a mail arriving mid-run is caught next time.
touch "$stamp.new"

find "$dir" -type f \( -path '*/cur/*' -o -path '*/new/*' \) "${newer[@]}" -print0 |
while IFS= read -r -d '' f; do
    IFS= read -r first < "$f" || continue
    # The line has no colon before the first space, unlike a real "From:" header.
    if [[ $first == "From "* ]]; then
        sed -i '1d' "$f"
    fi
done

mv "$stamp.new" "$stamp"
