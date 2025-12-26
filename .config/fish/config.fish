if status is-interactive
    # Commands to run in interactive sessions can go here

    # Save passwords for keyfiles during a fish session
    set ssh_agent_pid (pgrep ssh-agent)
    if test -z "$ssh_agent_pid"
        eval $(ssh-agent -c)
    else
        echo "ssh-agent already running PID=$ssh_agent_pid"
    end
end

export POWERLINE_CONFIG_OVERRIDES="$HOME/.config/powerline"
