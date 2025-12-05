if status is-interactive
    # Commands to run in interactive sessions can go here

    # Save passwords for keyfiles during a fish session
    eval $(ssh-agent -c)
end
