#!/bin/sh

test -f builds/FixDMG.dmg && rm builds/FixDMG.dmg

mkdir builds/fixDMG
touch builds/fixDMG/dummy

create-dmg --volname "FixDMG" \
	--window-pos 200 120 \
	--window-size 800 400 \
	--icon-size 100 \
	--app-drop-link 600 185 \
	builds/FixDMG.dmg builds/fixDMG
