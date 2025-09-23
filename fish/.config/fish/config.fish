fish_config theme choose "Rosé Pine"

function fish_greeting
    set_color brred
    echo -n "🌹 $USER"
    
    set_color magenta
    echo -n "@bauarch "
    
    set_color normal
    echo -n "on "
    
    set_color cyan
    echo -n (grep '^PRETTY_NAME=' /etc/os-release | cut -d= -f2- | tr -d '"')
    
    set_color normal
    echo -n " - uptime: "
    
    set_color green
    echo (uptime -p | sed 's/up //')
    
    set_color normal
end




if status is-interactive
    # Commands to run in interactive sessions can go here
end

fish_add_path /home/kbauer/.spicetify


abbr -a hyprr 'hyprr'
