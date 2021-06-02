#!/bin/sh

set -exu

IDENTITY=${EXPANDED_CODE_SIGN_IDENTITY_NAME}
if [[ ! -d "builds" ]]
then
  mkdir "builds"
fi

AUTOUPDATE_PATH=${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}/AutoUpdate.framework

echo "warning: Will sign AutoUpdate with ${IDENTITY}"

codesign -o runtime -fs "$IDENTITY" "${AUTOUPDATE_PATH}/XPCServices/UpdateInstaller.xpc"
codesign -o runtime -fs "$IDENTITY" "${AUTOUPDATE_PATH}/Versions/A/AutoUpdate"
codesign -o runtime -fs "$IDENTITY" "${AUTOUPDATE_PATH}"
