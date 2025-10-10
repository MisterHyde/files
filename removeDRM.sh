#!/usr/bin/bash

IFS='.' read -a array <<< "$1"

acsmdownloader -o "${array[0]}.epub" -f $1
adept_remove "${array[0]}.epub"
