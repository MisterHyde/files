# Firefox privacy settings
- Change settings in about:config:
    ```sh
        privacy.trackingprotection.enabled true
        privacy.resistFingerprinting true
        # WebRTC exposes LAN IP address
        media.peerconnection.ice.default_address_only true
        media.peerconnection.enabled false
        # This can cause trouble:
        network.http.sendRefererHeader 1 or 0
        # This is a new string and need to set to **Win32** or else the brower will be unique:
        general.platform.override Win32
        # Some sites use this for functional purpose
        network.http.sendRefererHeader 0 or 1
        # Disable conneciton tests
        network.captive-portal-service.enabled false
        # Disable telemetry
        toolkit.telemetry.enabled false
        # Disable 'Safe Browsing' service
        browser.safebrowsing.malware.enabled false
        browser.safebrowsing.phishing.enabled false
    ```
- Change browser time zone to UTC because it is used in fingerprinting:
    ```sh
    $ TZ=UTC firefox
    ```
- Firefox installs hidden extensions by default to _/usr/lib/firefox/browser/features_.
  These can be remove by rm _extension_name.xpi_ to prevent them from beeing installed again
  add the directories to **NoExtract** in _/etc/pacman.conf_.
- Telemetry tools can be deleted and added to **NoExtract** in _/etc/pacman.conf_ these are:
    ```sh
        /usr/lib/firefox/crashreporter
        /usr/lib/firefox/minidump-analyzer
        /usr/lib/firefox/pingsender
    ```
- A hardened configuration can be enfoced by a user.js [arkenfox/user.js](https://github.com/arkenfox/user.js) ([arkenfox-user.js](https://aur.archlinux.org/packages/arkenfox-user.js/)AUR)

## Resources
- https://wiki.archlinux.org/title/Firefox/Privacy called on 20. of November 2024
- https://brainfucksec.github.io/firefox-hardening-guide on 20. of November 2024
