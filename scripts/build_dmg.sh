#!/bin/sh

test -f builds/Beam.dmg && rm builds/Beam.dmg

create-dmg --volname "Beam" \
	--window-pos 200 120 \
	--window-size 800 400 \
	--icon-size 100 \
	--icon Beam.app 200 190 \
	--hide-extension Beam.app \
	--app-drop-link 600 185 \
	builds/Beam.dmg builds/Beam.app
