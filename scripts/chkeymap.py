# -*- coding: utf-8 -*-

import subprocess

class Py3status:

    def __init__(self):
        process = subprocess.Popen(['setxkbmap', '-print'], shell=False, stdout=subprocess.PIPE,
                stderr=subprocess.PIPE)
        out, err = process.communicate()
        out = out.decode('utf-8')
        for line in out.split("\n"):
            if "xkb_symbol" in line:
                self.full_text = "\u2691 %s" %(line.split("+")[1])

    def click_info(self):
        return {
                'full_text': self.full_text,
                'cached_until': self.py3.CACHE_FOREVER
        }

    def on_click(self, event):
        button = event['button']
        keymap = 'de'
        if "de" in self.full_text:
            keymap = 'us'
        elif "us" in self.full_text:
            keymap = 'de'
        process = subprocess.Popen(['setxkbmap', keymap], shell=False, stdout=subprocess.PIPE,
                stderr=subprocess.PIPE)
        out, err = process.communicate()
        # out = out.decode('utf-8')
        # out = out.strip("\n")
        data = {'lang': keymap}

        format_string = "\u2691 {lang}" 
        self.full_text = self.py3.safe_format(format_string, data)
        
if __name__ == "__main__":
    """
    Run module in test mode.
    """
    from py3status.module_test import module_test
    module_test(Py3status)
