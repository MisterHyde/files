function ytd --wraps='yt-dlp --no-playlist -x' --wraps='yt-dlp --no-playlist -x -P ~/Music/youtube' --description 'alias ytd yt-dlp --no-playlist -x -P ~/Music/youtube'
    yt-dlp --no-playlist -x -P ~/Music/youtube $argv
end
