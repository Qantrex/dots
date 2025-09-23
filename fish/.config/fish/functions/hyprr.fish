function hyprr
    echo "Reloading Hyprland..."
    hyprctl reload

    # Kill and restart Waybar to ensure it reloads its configuration
    echo "Restarting Waybar..."
    pkill waybar
    hyprctl dispatch exec waybar

    echo "Successful!"
end
