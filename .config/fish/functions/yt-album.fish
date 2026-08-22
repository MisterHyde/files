function yt-album --wraps='yt-dlp -o "%(playlist_index)s %(title)s" -x' --description 'alias yt-album yt-dlp -o "%(playlist_index)s %(title)s" -x'
    yt-dlp -o "%(playlist_index)s %(title)s" -x $argv
end
