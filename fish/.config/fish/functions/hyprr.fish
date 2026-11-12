function hyprr
    # Reload Hyprland and restart the shell (Quickshell). Same as SUPER+SHIFT+R.
    echo "Reloading Hyprland..."
    hyprctl reload

    # Quickshell reloads itself on file changes; this is for when it got stuck.
    echo "Restarting the shell..."
    pkill -x qs
    sleep 0.3
    hyprctl dispatch exec qs >/dev/null

    echo "Successful!"
end
