#!/bin/bash
# Bad substituion?
# find . -name "*.zip" -exec sh -c 'bn=$(basename "$1"); dn=${bn::-4}; unzip "$bn" -d "$dn"' _ {} \;

ZIPS=*.zip
for z in $ZIPS
do
	bn=$(basename "$z")
	dn=${bn::-4}
	echo "=========================================================================================================="
	echo "\"unzip $bn -d $dn\""
	unzip "$bn" -d "$dn"

	if [[ -d "$dn" ]] then
        echo "Remove \"$z\"\n"
		rm "$z"
	else
		echo "Error with \"$z\"\n"
	fi
done
