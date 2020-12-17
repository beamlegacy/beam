#!/bin/sh

set -exu

IDENTITY=${EXPANDED_CODE_SIGN_IDENTITY_NAME}
if [[ ! -d "builds" ]]
then
  mkdir "builds"
fi
echo "Will sign Sparkle with ${IDENTITY}" > builds/debug_beam.txt

alias dosign="${PROJECT_DIR}/Extern/Sparkle/bin/codesign_embedded_executable"
SPARKLE_PATH=${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}/Sparkle.framework

dosign "$IDENTITY" "${BUILT_PRODUCTS_DIR}/${XPCSERVICES_FOLDER_PATH}"/org.sparkle-project.*.xpc
dosign "$IDENTITY" "${SPARKLE_PATH}/Versions/A/Resources/Autoupdate"
dosign "$IDENTITY" "${SPARKLE_PATH}/Versions/A/Resources/Updater.app/"
dosign "$IDENTITY" "${SPARKLE_PATH}"
