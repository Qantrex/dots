# shellcheck shell=bash disable=SC2034
# Package lists for install.sh / install-hyprland.sh. Sourced, not run.
# Everything goes through yay, so AUR and chaotic-aur packages can sit in the
# same list as official ones.

# Needed before anything else (git + stow for the repo, pciutils for GPU
# detection, jq for editing app JSON settings, acl for spicetify's write access).
PKG_BOOTSTRAP=(git stow base-devel pciutils jq acl)

# The compositor and the pieces its config starts or calls.
PKG_DESKTOP=(
  hyprland hyprlock hyprpaper hyprpolkitagent
  xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
  qt5-wayland qt6-wayland xorg-xwayland
  waybar wofi wofimoji mako swayosd swayidle batsignal
  cliphist wl-clipboard grim slurp playerctl brightnessctl libnotify
  imagemagick libvips               # wallpaper picker thumbnails
  polkit udisks2 upower xdg-user-dirs
  blueman pavucontrol gnome-calendar  # waybar click actions
)

# Only on a bare system: an existing Hyprland setup already has a working
# audio stack / network manager / login, and swapping those under a running
# system (pulseaudio -> pipewire, iwd -> NetworkManager) is not something to do
# unasked.
PKG_AUDIO=(pipewire pipewire-pulse pipewire-alsa pipewire-jack wireplumber)
PKG_NETWORK=(networkmanager bluez bluez-utils)
PKG_LOGIN=(greetd greetd-tuigreet)

# Shell and terminal tools (.zshrc / .zsh_aliases / tmux / micro use these).
PKG_SHELL=(zsh fish starship tmux micro fzf zoxide eza bat ripgrep fd btop)

PKG_FONTS=(ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols noto-fonts noto-fonts-emoji noto-fonts-cjk)

# Themes referenced by name from gtk/qt/hypr configs.
PKG_THEME=(
  qt5ct qt6ct papirus-icon-theme breeze-icons
  rose-pine-gtk-theme-full rose-pine-hyprcursor rose-pine-cursor
)

PKG_APPS=(foot firefox dolphin vesktop spotify spotify-adblock spicetify-cli)

# The root setup scripts in scripts/.config/scripts need these.
PKG_SYSTEM=(nftables pacman-contrib)

# Hardware -- picked by detect_hardware().
PKG_GPU_AMD=(mesa vulkan-radeon)
PKG_GPU_INTEL=(mesa vulkan-intel intel-media-driver)
PKG_GPU_NVIDIA=(nvidia-utils nvidia-settings)   # + nvidia-open / -dkms, see lib.sh
PKG_GPU_HYBRID=(nvidia-prime envycontrol)       # iGPU + NVIDIA laptops (gpumode)
PKG_LAPTOP=(tlp acpi)
PKG_ASUS=(asusctl)                              # powerprofile.sh / waybar module
