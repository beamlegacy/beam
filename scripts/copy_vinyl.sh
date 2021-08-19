#!/bin/sh

if [ "$(ls -A ${SRCROOT}/BeamTests/Vinyl.tar.bz2)" ]; then
    echo "Extracting ${SRCROOT}/BeamTests/Vinyl.tar.bz2 to ${HOME}/Library/Containers/co.beamapp.macos/Data/Library/Logs/Beam/Vinyl/${CI_JOB_ID}/"
    mkdir -p ${HOME}/Library/Containers/co.beamapp.macos/Data/Library/Logs/Beam/Vinyl/${CI_JOB_ID}/
    tar -xf BeamTests/Vinyl.tar.bz2 -C ${HOME}/Library/Containers/co.beamapp.macos/Data/Library/Logs/Beam/Vinyl/${CI_JOB_ID}/
fi
