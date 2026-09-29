# shellcheck shell=bash
# Shared steps for install.sh and install-hyprland.sh. Sourced, not run.
#
# Every step is safe to re-run: packages use --needed, links that already point
# into the repo are left alone, and anything that would be overwritten is moved
# to $BACKUP_DIR first. Steps that fail are collected and reported at the end
# instead of aborting the whole run.

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
LOG="$HOME/.dotfiles-install.log"

# shellcheck source=packages.sh
source "$DOTFILES/install/packages.sh"
# shellcheck source=links.sh
source "$DOTFILES/install/links.sh"

ASSUME_YES=0
DRY_RUN=0
FAILED=()      # things that went wrong, reported by summary()
TODO=()        # things the user still has to do, reported by summary()
HW_PKGS=()
HW_ASUS=0
HW_LAPTOP=0

# ----------------------------------------------------------------- output

if [[ -t 1 ]]; then
  BOLD=$'\e[1m' DIM=$'\e[2m' RED=$'\e[31m' YEL=$'\e[33m' GRN=$'\e[32m' RST=$'\e[0m'
else
  BOLD='' DIM='' RED='' YEL='' GRN='' RST=''
fi

step() { printf '\n%s==> %s%s\n' "$BOLD" "$*" "$RST"; }
info() { printf '    %s\n' "$*"; }
ok()   { printf '    %s✓%s %s\n' "$GRN" "$RST" "$*"; }
warn() { printf '    %s! %s%s\n' "$YEL" "$*" "$RST"; }
die()  { printf '\n%s✗ %s%s\n' "$RED" "$*" "$RST" >&2; exit 1; }

# run CMD... -- execute, or only print it with --dry-run.
run() {
  if ((DRY_RUN)); then
    printf '    %s$ %s%s\n' "$DIM" "$*" "$RST"
  else
    "$@"
  fi
}

# root_write FILE CONTENT [append] -- write a root-owned file.
root_write() {
  local file=$1 content=$2 mode=${3:-}
  if ((DRY_RUN)); then
    info "${DIM}would ${mode:-write} $file:${RST}"
    sed "s/^/      ${DIM}|${RST} /" <<<"$content"
    return
  fi
  if [[ $mode == append ]]; then
    sudo tee -a "$file" <<<"$content" >/dev/null
  else
    sudo tee "$file" <<<"$content" >/dev/null
  fi
}

# json_set FILE JQ-FILTER -- edit (or create) a JSON settings file.
json_set() {
  local file=$1 filter=$2 tmp
  if ((DRY_RUN)); then
    info "${DIM}would set  $filter  in ${file/#$HOME/\~}${RST}"
    return
  fi
  mkdir -p "$(dirname "$file")"
  tmp=$(mktemp)
  if [[ -s $file ]]; then jq "$filter" "$file" >"$tmp"; else jq -n "$filter" >"$tmp"; fi \
    && mv "$tmp" "$file" || { rm -f "$tmp"; FAILED+=("editing $file"); }
}

have_tty() { { : </dev/tty; } 2>/dev/null; }

# ask QUESTION [y|n] -- yes/no prompt; --yes (or no terminal) takes the default.
ask() {
  local question=$1 default=${2:-n} hint answer
  [[ $default == y ]] && hint='[Y/n]' || hint='[y/N]'
  if ((ASSUME_YES)) || ! have_tty; then
    info "$question $hint ${DIM}-> $default${RST}"
    [[ $default == y ]]
    return
  fi
  read -rp "    ? $question $hint " answer </dev/tty || answer=
  answer=${answer:-$default}
  [[ ${answer,,} == y* ]]
}

# ----------------------------------------------------------------- setup

usage() {
  cat <<EOF
Usage: ${0##*/} [options]

  -y, --yes       don't ask; take the default answer to every question
  -n, --dry-run   print what would be done, change nothing
  -h, --help      show this help

The run is logged to $LOG and can be repeated safely.
EOF
}

parse_args() {
  while (($#)); do
    case $1 in
      -y|--yes)     ASSUME_YES=1 ;;
      -n|--dry-run) DRY_RUN=1 ;;
      -h|--help)    usage; exit 0 ;;
      *)            usage; die "unknown option: $1" ;;
    esac
    shift
  done
  # Log everything (a dry run only prints).
  ((DRY_RUN)) || exec > >(tee -a "$LOG") 2>&1
}

preflight() {
  step "Checking the system"
  [[ -f /etc/arch-release ]] || die "This is for Arch Linux."
  ((EUID != 0)) || die "Run this as your normal user, not root -- it uses sudo where needed."
  command -v sudo >/dev/null || die "sudo is missing. As root: pacman -S sudo, then add your user to the wheel group (EDITOR=nano visudo)."
  if ((DRY_RUN)); then
    info "dry run -- nothing will be changed"
  else
    sudo -v || die "sudo failed. Is $USER in the wheel group, and is wheel enabled in visudo?"
    # Keep the sudo timestamp fresh; package builds can outlast its timeout.
    ( while kill -0 $$ 2>/dev/null; do sudo -n true; sleep 50; done ) 2>/dev/null &
  fi
  curl -fsS --max-time 10 -o /dev/null https://archlinux.org \
    || die "No internet connection. On a fresh archinstall: nmtui (NetworkManager) or iwctl (iwd)."
  ok "Arch, user $USER, sudo, internet"
  [[ $DOTFILES == "$HOME/dotfiles" ]] \
    || warn "Repo is at $DOTFILES, not ~/dotfiles -- that works, but the README assumes ~/dotfiles."
}

system_upgrade() {
  step "Updating the system"
  # Arch doesn't support partial upgrades: installing new packages against an
  # outdated system can break it, so always sync everything first.
  run sudo pacman -Syu --noconfirm || die "System upgrade failed -- fix that first."
}

install_bootstrap() {
  step "Bootstrap tools"
  run sudo pacman -S --needed --noconfirm "${PKG_BOOTSTRAP[@]}" || die "Could not install ${PKG_BOOTSTRAP[*]}."
}

setup_chaotic_aur() {
  step "chaotic-aur repository"
  if grep -q '^\[chaotic-aur\]' /etc/pacman.conf; then
    ok "already configured"
    return
  fi
  info "Prebuilt AUR packages (spotify, vesktop, spicetify-cli, envycontrol, ...)."
  info "Without it they are compiled from the AUR, which works but takes much longer."
  ask "Add chaotic-aur?" y || return 0
  run sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com \
    && run sudo pacman-key --lsign-key 3056513887B78AEB \
    && run sudo pacman -U --noconfirm \
         'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' \
         'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' \
    || { warn "chaotic-aur setup failed; falling back to building from the AUR"; FAILED+=("chaotic-aur"); return; }
  root_write /etc/pacman.conf $'\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist' append
  run sudo pacman -Syu --noconfirm
}

bootstrap_yay() {
  step "yay (AUR helper)"
  if command -v yay >/dev/null; then
    ok "already installed"
    return
  fi
  if pacman -Si yay &>/dev/null; then   # chaotic-aur ships it prebuilt
    run sudo pacman -S --needed --noconfirm yay || die "Could not install yay."
    return
  fi
  local tmp
  tmp=$(mktemp -d)
  run git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin" || die "Could not fetch yay."
  if ((DRY_RUN)); then
    run makepkg -si --noconfirm
  else
    (cd "$tmp/yay-bin" && makepkg -si --noconfirm) || die "Could not build yay."
  fi
  rm -rf "$tmp"
}

YAY_FLAGS=(--needed --noconfirm --answerdiff None --answerclean None --answeredit None --removemake)

# install_pkgs LABEL PKG... -- install a group; on failure retry one by one so a
# single missing/broken package doesn't take the whole group down with it.
install_pkgs() {
  local label=$1
  shift
  (($#)) || return 0
  step "Packages: $label"
  info "$*"
  if ((DRY_RUN)); then
    run yay -S "${YAY_FLAGS[@]}" "$@"
    return
  fi
  yay -S "${YAY_FLAGS[@]}" "$@" && return
  warn "group failed, retrying one package at a time"
  local p
  for p; do
    yay -S "${YAY_FLAGS[@]}" "$p" || FAILED+=("package $p")
  done
}

# detect_hardware [--no-gpu] -- fill HW_PKGS for this machine.
detect_hardware() {
  step "Detecting hardware"
  local gpus amd=0 intel=0 nvidia=0
  # PCI class 0300 = VGA, 0302 = 3D (e.g. a laptop's NVIDIA dGPU), 0380 = display
  gpus=$(lspci -nn 2>/dev/null | grep -E '\[03(00|02|80)\]' || true)
  grep -q '\[1002:' <<<"$gpus" && amd=1
  grep -q '\[8086:' <<<"$gpus" && intel=1
  grep -q '\[10de:' <<<"$gpus" && nvidia=1
  compgen -G '/sys/class/power_supply/BAT*' >/dev/null && HW_LAPTOP=1
  grep -qi asus /sys/class/dmi/id/sys_vendor 2>/dev/null && HW_ASUS=1

  info "GPU: $( ((amd)) && printf 'AMD ')$( ((intel)) && printf 'Intel ')$( ((nvidia)) && printf 'NVIDIA ')"
  info "laptop: $( ((HW_LAPTOP)) && echo yes || echo no), ASUS: $( ((HW_ASUS)) && echo yes || echo no)"

  if [[ ${1:-} != --no-gpu ]]; then
    ((amd)) && HW_PKGS+=("${PKG_GPU_AMD[@]}")
    ((intel)) && HW_PKGS+=("${PKG_GPU_INTEL[@]}")
    if ((nvidia)) && ask "Install the NVIDIA driver (open kernel modules: GTX 16xx / RTX 20xx or newer)?" y; then
      HW_PKGS+=("${PKG_GPU_NVIDIA[@]}")
      # The prebuilt module only matches the stock `linux` kernel; anything else
      # (lts, zen, ...) needs the DKMS build plus that kernel's headers.
      local kernels
      mapfile -t kernels < <(pacman -Qq linux linux-lts linux-zen linux-hardened 2>/dev/null)
      if [[ ${kernels[*]} == linux ]]; then
        HW_PKGS+=(nvidia-open)
      else
        HW_PKGS+=(nvidia-open-dkms "${kernels[@]/%/-headers}")
      fi
      ((amd || intel)) && HW_PKGS+=("${PKG_GPU_HYBRID[@]}")
    fi
  fi
  ((HW_LAPTOP)) && HW_PKGS+=("${PKG_LAPTOP[@]}")
  ((HW_ASUS)) && HW_PKGS+=("${PKG_ASUS[@]}")
  return 0
}

# ----------------------------------------------------------------- dotfiles

link_dotfiles() {
  step "Linking dotfiles into $HOME"
  local entry path pkg live src moved=0
  for entry in "${LINKS[@]}"; do
    path=${entry%%|*} pkg=${entry##*|}
    live=$HOME/$path src=$DOTFILES/$pkg/$path
    [[ -e $src ]] || { warn "missing in repo: $pkg/$path"; continue; }
    # The parent has to exist as a real directory, or stow would link it
    # instead (e.g. all of ~/.config/vesktop, session data included).
    [[ -d $(dirname "$live") ]] || run mkdir -p "$(dirname "$live")"
    if [[ -L $live && $(readlink -f "$live") == "$(readlink -f "$src")" ]]; then
      continue
    fi
    if [[ -e $live || -L $live ]]; then
      run mkdir -p "$BACKUP_DIR/$(dirname "$path")"
      run mv "$live" "$BACKUP_DIR/$path"
      info "backed up ~/$path"
      moved=1
    fi
  done
  local pkgs
  mapfile -t pkgs < <(printf '%s\n' "${LINKS[@]}" | cut -d'|' -f2 | sort -u)
  run stow --dir="$DOTFILES" --target="$HOME" --restow "${pkgs[@]}" \
    || { FAILED+=("stow"); warn "stow failed -- see above"; return; }
  ((moved)) && TODO+=("Your previous configs are in $BACKUP_DIR")
  ok "${#LINKS[@]} links in place"
}

setup_shell() {
  step "zsh + oh-my-zsh"
  local omz=$HOME/.oh-my-zsh repo
  [[ -d $omz ]] || run git clone --depth 1 https://github.com/ohmyzsh/ohmyzsh.git "$omz"
  # Plugins .zshrc loads that don't ship with oh-my-zsh.
  for repo in hlissner/zsh-autopair zsh-users/zsh-autosuggestions zsh-users/zsh-completions \
              zsh-users/zsh-syntax-highlighting MichaelAquilina/zsh-you-should-use; do
    [[ -d $omz/custom/plugins/${repo#*/} ]] \
      || run git clone --depth 1 "https://github.com/$repo.git" "$omz/custom/plugins/${repo#*/}" \
      || FAILED+=("zsh plugin $repo")
  done
  if [[ $(getent passwd "$USER" | cut -d: -f7) != */zsh ]]; then
    if ask "Make zsh your login shell?" y; then
      run sudo chsh -s /usr/bin/zsh "$USER" || FAILED+=("chsh")
    fi
  fi
  ok "zsh ready"
}

setup_micro() {
  step "micro plugins"
  # Installed from micro's plugin channel rather than kept in the repo;
  # bindings.json and init.lua use all three.
  local plugin
  for plugin in filemanager fzf lsp; do
    [[ -d $HOME/.config/micro/plug/$plugin ]] \
      || run micro -plugin install "$plugin" \
      || FAILED+=("micro plugin $plugin")
  done
  ok "micro plugins ready"
}

enable_services() {  # enable_services [--now] UNIT...
  run sudo systemctl enable "$@" || FAILED+=("systemctl enable $*")
}

setup_greetd() {
  step "Login screen (greetd + tuigreet)"
  local session=Hyprland
  [[ -x /usr/bin/start-hyprland ]] && session=start-hyprland
  root_write /etc/greetd/config.toml "[terminal]
vt = 1

[default_session]
command = \"tuigreet --time --remember --asterisks --cmd $session\"
user = \"greeter\""
  enable_services greetd.service
}

setup_vesktop() {
  step "Discord (Vesktop) theme"
  local dir=$HOME/.config/vesktop
  if pgrep -x vesktop >/dev/null; then
    # Vesktop writes its settings back on exit, which would undo this.
    if ask "Vesktop is running and would overwrite its settings on exit. Close it now?" y; then
      run pkill -x vesktop
      ((DRY_RUN)) || sleep 2
    else
      TODO+=("Vesktop: Settings > Themes > enable monochrome.theme.css")
      return
    fi
  fi
  json_set "$dir/settings/settings.json" '.enabledThemes = ["monochrome.theme.css"]'
  json_set "$dir/settings.json" '.splashBackground = "rgb(0, 0, 0)" | .splashColor = "rgb(255, 255, 255)"'
  ok "monochrome theme enabled"
}

setup_spicetify() {
  step "Spotify theme (spicetify)"
  local sp prefs=$HOME/.config/spotify/prefs
  sp=$(command -v spicetify || echo "$HOME/.spicetify/spicetify")
  if [[ ! -x $sp ]] && ! ((DRY_RUN)); then
    warn "spicetify is not installed"
    FAILED+=("spicetify")
    return
  fi
  # Spotify creates its prefs file on first launch, and spicetify refuses to
  # work without it -- so on a fresh machine this has to wait.
  if [[ ! -f $prefs ]]; then
    info "skipped: Spotify hasn't been started yet"
    TODO+=("Spotify theme: start Spotify once, log in, quit it, then re-run this script")
    return
  fi
  # spicetify patches Spotify's own files.
  [[ -w /opt/spotify/Apps ]] \
    || run sudo setfacl -R -m "u:$USER:rwX" -m "d:u:$USER:rwX" /opt/spotify
  run "$sp" config prefs_path "$prefs" spotify_path /opt/spotify/ \
    current_theme Ziro color_scheme monochrome inject_css 1 replace_colors 1

  # Backup state lives in config-xpui.ini: none yet -> make one; one for an
  # older Spotify -> refresh it; current -> just apply. -n: don't let spicetify
  # restart Spotify itself, because it would start it without the adblocker.
  local backed installed
  backed=$(sed -n 's/^version *= *//p' "$HOME/.config/spicetify/config-xpui.ini" 2>/dev/null)
  installed=$(pacman -Q spotify 2>/dev/null | awk '{print $2}' | sed 's/^[0-9]*://; s/-[0-9]*$//')
  if [[ -z $backed ]]; then
    run "$sp" backup apply -n
  elif [[ -n $installed && $backed != "$installed"* ]]; then
    run "$sp" restore backup apply -n
  else
    run "$sp" apply -n
  fi || { FAILED+=("spicetify apply"); return; }
  pgrep -x spotify >/dev/null && TODO+=("Restart Spotify to see its new theme")
  ok "applied"
}

setup_firefox_theme() {
  step "Firefox theme"
  local id='{9b84b6b4-07c4-4b4b-ba21-394d86f6e9ee}' url='https://addons.mozilla.org/firefox/addon/black21/'
  local policies=/etc/firefox/policies/policies.json
  if [[ -f $policies ]] && grep -q "$id" "$policies"; then
    ok "black21 already installed by policy"
    return
  fi
  info "black21: pure black/white Firefox theme. It can be installed automatically"
  info "through a Firefox policy, but Firefox then shows 'managed by your organization'."
  if ask "Install it through a policy?" n; then
    local filter=".policies.ExtensionSettings[\"$id\"] = {installation_mode: \"normal_installed\", install_url: \"https://addons.mozilla.org/firefox/downloads/latest/black21/latest.xpi\"}"
    run sudo mkdir -p "$(dirname "$policies")"
    if ((DRY_RUN)); then
      info "${DIM}would set  $filter  in $policies${RST}"
    else
      local current='{}'
      [[ -s $policies ]] && current=$(sudo cat "$policies")
      jq "$filter" <<<"$current" | sudo tee "$policies" >/dev/null || FAILED+=("Firefox policy")
    fi
    TODO+=("Firefox: about:addons > Themes > enable black21")
  else
    TODO+=("Firefox: install the black21 theme -- $url")
  fi
}

run_root_scripts() {
  step "One-time system setup scripts"
  local s=$DOTFILES/scripts/.config/scripts
  if ask "Firewall: drop incoming traffic this machine didn't ask for (setup-firewall.sh)?" y; then
    run sudo "$s/setup-firewall.sh" || FAILED+=("setup-firewall.sh")
  fi
  if ((HW_ASUS)) && ask "ASUS: Quiet/Performance profiles via asusctl + TLP (setup-power-profiles.sh)?" y; then
    run sudo "$s/setup-power-profiles.sh" || FAILED+=("setup-power-profiles.sh")
  fi
  if ask "Maintenance: prune the pacman cache, enable paccache/fstrim timers (maintain.sh)?" y; then
    run sudo "$s/maintain.sh" || FAILED+=("maintain.sh")
  fi
  # Written for the Vivobook's systemd-boot entries and kernel command line.
  info "optimize-boot.sh edits boot entries and was written for one specific laptop;"
  info "preview it with: $s/optimize-boot.sh --dry-run"
  if ask "Run optimize-boot.sh now?" n; then
    run sudo "$s/optimize-boot.sh" || FAILED+=("optimize-boot.sh")
  fi
}

check_home_paths() {
  [[ $HOME == /home/kbauer ]] && return
  local files
  mapfile -t files < <(grep -rl --exclude-dir=.git --exclude-dir=install /home/kbauer "$DOTFILES" 2>/dev/null)
  ((${#files[@]})) || return 0
  warn "These configs contain /home/kbauer paths; edit them for $HOME:"
  printf '      %s\n' "${files[@]#"$DOTFILES"/}"
  TODO+=("Replace /home/kbauer in the configs listed above")
}

check_hyprland_version() {
  local v
  v=$(Hyprland --version 2>/dev/null | grep -oE 'Hyprland [0-9]+\.[0-9]+' | head -1 | cut -d' ' -f2)
  [[ -n $v ]] || return 0
  # The config is Lua, which Hyprland reads from 0.55 on.
  if (( ${v%%.*} == 0 && ${v#*.} < 55 )); then
    warn "Hyprland $v is too old for the Lua config (needs 0.55+)"
    FAILED+=("Hyprland >= 0.55")
  fi
}

verify() {
  step "Verifying links"
  if ((DRY_RUN)); then
    info "skipped in a dry run"
    return
  fi
  REPO=$DOTFILES "$DOTFILES/verify-dotfiles.sh" | grep -E '❌|All checks' || true
}

summary() {
  local done_msg=$1
  step "Done"
  if ((${#FAILED[@]})); then
    printf '    %sThese failed -- check %s:%s\n' "$RED" "$LOG" "$RST"
    printf '      - %s\n' "${FAILED[@]}"
  fi
  if ((${#TODO[@]})); then
    info "Still to do:"
    printf '      - %s\n' "${TODO[@]}"
  fi
  info "$done_msg"
}
