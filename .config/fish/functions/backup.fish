# The following two variables must be present (set them in a private script with 'set -gx'):
#RESTIC_LOCAL_REPO

function backup
	if not test -d $RESTIC_LOCAL_REPO
		echo "backup: SSD not mounted" >&2
		return 1
	end

    read -s -P "restic password: " -l pw
    echo
    set -x RESTIC_PASSWORD $pw
    # Promt again here if the password differs for the remote repo
    set -x RESTIC_FROM_PASSWORD $pw

	set -gx RESTIC_KEEP --keep-last 5 --keep-monthly 12

    echo env RESTIC_PASSWORD_COMMAND= restic -r $RESTIC_LOCAL_REPO backup --tag backups ~/backups/
    env RESTIC_PASSWORD_COMMAND= restic -r $RESTIC_LOCAL_REPO backup --tag backups ~/backups/
    or begin; echo "$HOME/backups failed!" >&2; return 1; end
    env RESTIC_PASSWORD_COMMAND= restic -r $RESTIC_LOCAL_REPO backup --tag Documents ~/Documents/
    or begin; echo "$HOME/Documents failed!"; return 1; end
    env RESTIC_PASSWORD_COMMAND= restic -r $RESTIC_LOCAL_REPO backup --tag Fotos ~/Pictures/Fotos/
    or begin; echo "$HOME/Pictures/Fotos failed!"; return 1; end

    restic -r <local-ssd-repo> snapshots

	echo
    echo "=== forget policy (dry run) ==="
    env RESTIC_PASSWORD_COMMAND= restic -r $RESTIC_LOCAL_REPO forget $RESTIC_KEEP --dry-run
    or return 1

    read -l -P "Apply this policy? [y/N] " answer
    if string match -qri '^y(es)?$' -- $answer
        env RESTIC_PASSWORD_COMMAND= restic -r $RESTIC_LOCAL_REPO forget $RESTIC_KEEP --prune
    end

    env RESTIC_PASSWORD_COMMAND= restic -r sftp:storagebox:restic-repo copy \
        --from-repo $RESTIC_LOCAL_REPO #--from-password-command "echo \$RESTIC_PASSWORD"
end
