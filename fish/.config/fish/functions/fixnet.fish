function fixnet --description "Restarts the system's network service"
    echo "Attempting to restart the NetworkManager service..."
    echo "You will be disconnected temporarily."

    # The 'command' keyword ensures we run the actual systemctl command,
    # not a function or alias that might also be named systemctl.
    # 'sudo' is used because this action requires administrator privileges.
    command sudo systemctl restart NetworkManager.service

    # Check the exit status of the last command ($status).
    # A status of 0 means it was successful.
    if test $status -eq 0
        echo "✅ NetworkManager restarted successfully."
        echo "It may take a moment to reconnect."
    else
        echo "❌ There was an error restarting NetworkManager."
        echo "You could try running 'sudo systemctl status NetworkManager.service' for details."
    end
end
