#!/bin/sh

MOCK_HTTP_SERVER_PATH="${BUILT_PRODUCTS_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/MockHttpServer_MockHttpServer.bundle"

if [[ "${BEAM_ENABLE_MOCK_HTTP_SERVER}" -eq 1 ]]
then
  exit 0
fi

if [[ -d "${MOCK_HTTP_SERVER_PATH}" ]]
then
  /bin/rm -r "${MOCK_HTTP_SERVER_PATH}"
fi

exit 0
