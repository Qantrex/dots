#!/usr/bin/env bash
set -u

REPO="${REPO:-$HOME/dotfiles}"

# Determine BACKUP: prefer env var, else newest ~/.config.bak-*
if [[ -n "${BACKUP:-}" ]]; then
  BK="$BACKUP"
else
  BK="$(ls -1dt "$HOME"/.config.bak-* 2>/dev/null | head -n1 || true)"
fi

if [[ -z "${BK:-}" || ! -d "$BK" ]]; then
  echo "ERROR: Could not locate backup folder. Set BACKUP=/path/to/.config.bak-<timestamp> and re-run."
  exit 2
fi

echo "Using BACKUP: $BK"
echo "Using REPO:   $REPO"
echo

# Map config name -> stow package name
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
  backup_path="$BK/$name"

  echo "=== $(pad "$name") ==="
  # 1) Check repo copy exists
  if [[ ! -e "$repo_path" ]]; then
    echo "  ❌ Repo path missing: $repo_path"
    fail=1
  else
    echo "  ✅ Repo path exists:  $repo_path"
  fi

  # 2) Check live path is a symlink pointing into repo
  if [[ -L "$live_path" ]]; then
    target="$(readlink -f -- "$live_path" || true)"
    repo_real="$(readlink -f -- "$repo_path" || true)"
    if [[ -n "$target" && -n "$repo_real" && "$target" == "$repo_real" ]]; then
      echo "  ✅ Symlink OK: $live_path → $(readlink -- "$live_path")"
    else
      echo "  ❌ Symlink points elsewhere:"
      echo "     live: $live_path → $(readlink -- "$live_path" || echo '?')"
      echo "     repo: $repo_path"
      fail=1
    fi
  else
    if [[ -e "$live_path" ]]; then
      echo "  ❌ Live path is not a symlink: $live_path"
      fail=1
    else
      echo "  ❌ Live path missing: $live_path"
      fail=1
    fi
  fi

  # 3) Compare backup vs repo contents (if a backup exists for this name)
  if [[ -e "$backup_path" ]]; then
    # diff dirs or files uniformly
    if diff -qr --no-dereference -- "$backup_path" "$repo_path" > /dev/null 2>&1; then
      echo "  ✅ Backup matches repo."
    else
      echo "  ❌ Backup differs from repo. Showing brief diff:"
      # Show only a few lines to avoid flooding
      diff -qr --no-dereference -- "$backup_path" "$repo_path" | head -n 20
      fail=1
    fi
  else
    echo "  ⚠️  No backup for: $name (skipping diff)"
  fi

  echo
done

if [[ $fail -eq 0 ]]; then
  echo "✅ All checks passed."
else
  echo "❌ Some checks failed. See details above."
fi

exit $fail
EOF
