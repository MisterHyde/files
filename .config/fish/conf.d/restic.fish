set -gx RESTIC_REPOSITORY           sftp:storagebox:restic-repo
#set -gx RESTIC_PASSWORD_COMMAND     "secret-tool lookup restic storagebox"
set -gx RESTIC_PASSWORD_COMMAND     "pass show restic/storagebox"
