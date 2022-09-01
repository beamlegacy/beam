#!/bin/sh

CLUSTERING_BUNDLE_PATH="${BUILT_PRODUCTS_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/Clustering_Clustering.bundle"

if [[ -d "${CLUSTERING_BUNDLE_PATH}" ]] && [[ "${STRIP_CLUSTERING_V2_MODEL}" -eq 1 ]]
then
    echo "This is a Beta, delete model at ${CLUSTERING_BUNDLE_PATH}"
  /bin/rm -r "${CLUSTERING_BUNDLE_PATH}"
else
    echo "Not Beta, skip deletion"
fi

exit 0
