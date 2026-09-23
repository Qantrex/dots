#!/usr/bin/env bash
# Check that every stow package is present in the repo and correctly symlinked
# into ~/.config.
#
#   ./verify-dotfiles.sh                 structure checks only
#   BACKUP=~/.config.bak-... ./verify-dotfiles.sh   also diff against a backup
#
# The backup diff is opt-in. It used to run automatically against the newest
# ~/.config.bak-*, which meant the script reported failure for every config
# that had legitimately changed since that backup was taken -- i.e. always,
# once the backup was more than a day or two old.

set -u

REPO="${REPO:-$HOME/dotfiles}"
BK="${BACKUP:-}"

if [[ -n $BK && ! -d $BK ]]; then
  echo "ERROR: BACKUP=$BK is not a directory."
  exit 2
fi

echo "Using REPO:   $REPO"
if [[ -n $BK ]]; then
  echo "Using BACKUP: $BK"
else
  echo "Using BACKUP: (none -- structure checks only; set BACKUP= to diff)"
fi
echo

# config name under ~/.config  ->  stow package name
declare -A MAP=(
  [micro]=micro
  [fish]=fish
  [fnott]=fnott
  [foot]=foot
  [qt5ct]=qt5ct
  [waybar]=waybar
  [gtk-3.0]=gtk
  [gtk-4.0]=gtk
  [wofi]=wofi
  [scripts]=scripts
  [hypr]=hypr
)

names=(micro fish fnott foot qt5ct waybar gtk-3.0 gtk-4.0 wofi scripts hypr)

fail=0
pad() { printf "%-12s" "$1"; }

for name in "${names[@]}"; do
  pkg="${MAP[$name]}"
  repo_path="$REPO/$pkg/.config/$name"
  live_path="$HOME/.config/$name"

  echo "=== $(pad "$name") ==="

  # 1) repo copy exists
  if [[ ! -e $repo_path ]]; then
    echo "  ❌ Repo path missing: $repo_path"
    fail=1
  else
    echo "  ✅ Repo path exists:  $repo_path"
  fi

  # 2) live path is a symlink into the repo
  if [[ -L $live_path ]]; then
    target="$(readlink -f -- "$live_path" || true)"
    repo_real="$(readlink -f -- "$repo_path" || true)"
    if [[ -n $target && -n $repo_real && $target == "$repo_real" ]]; then
      echo "  ✅ Symlink OK: $live_path → $(readlink -- "$live_path")"
    else
      echo "  ❌ Symlink points elsewhere:"
      echo "     live: $live_path → $(readlink -- "$live_path" || echo '?')"
      echo "     repo: $repo_path"
      fail=1
    fi
  elif [[ -e $live_path ]]; then
    echo "  ❌ Live path is not a symlink: $live_path"
    fail=1
  else
    echo "  ❌ Live path missing: $live_path"
    fail=1
  fi

  # 3) optional diff against a backup -- informational, never fails the run
  if [[ -n $BK ]]; then
    backup_path="$BK/$name"
    if [[ -e $backup_path ]]; then
      if diff -qr --no-dereference -- "$backup_path" "$repo_path" >/dev/null 2>&1; then
        echo "  ✅ Backup matches repo."
      else
        echo "  ℹ️  Differs from backup (expected if the config changed since):"
        diff -qr --no-dereference -- "$backup_path" "$repo_path" 2>/dev/null | head -n 10 | sed 's/^/     /'
      fi
    else
      echo "  ⚠️  No backup for: $name"
    fi
  fi

  echo
done

# Hyprland's Lua config: catch syntax errors before they gate a login.
if command -v luac >/dev/null 2>&1; then
  echo "=== $(pad "hypr lua") ==="
  lua_fail=0
  while IFS= read -r f; do
    luac -p "$f" 2>/dev/null || { echo "  ❌ Lua syntax error: $f"; lua_fail=1; fail=1; }
  done < <(find "$REPO/hypr/.config/hypr" -name '*.lua' -not -path '*/_backup*' 2>/dev/null)
  (( lua_fail == 0 )) && echo "  ✅ All Lua files parse."
  echo
fi

if [[ $fail -eq 0 ]]; then
  echo "✅ All checks passed."
else
  echo "❌ Some checks failed. See details above."
fi

exit $fail
