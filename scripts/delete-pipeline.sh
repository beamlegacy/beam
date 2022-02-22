#!/usr/bin/env bash

set -eo pipefail

# Get GitLab API URL from project URL
GITLAB_API_URL="https://gitlab.com/api/v4"

# Find correct refs for pipelines url
# If it is a merge request pipeline, branch ref is the CI_MERGE_REQUEST_REF_PATH
# else it is the branch name
if [[ -z "${CI_MERGE_REQUEST_REF_PATH}" ]]
then
	BRANCH_REF=${CI_BUILD_REF_NAME}
else
    BRANCH_REF=${CI_MERGE_REQUEST_REF_PATH}
fi
echo "CI_MERGE_REQUEST_REF_PATH = ${CI_MERGE_REQUEST_REF_PATH}"
echo "CI_BUILD_REF_NAME = ${CI_BUILD_REF_NAME}"
echo "BRANCH_REF used: ${BRANCH_REF}"

# Query running pipelines for the same branch, 
# process + filter them,
# and finally cancel them with another API call
curl -sS -H "PRIVATE-TOKEN: $GITLAB_API_ACCESS_TOKEN" "${GITLAB_API_URL}/projects/$CI_PROJECT_ID/pipelines?ref=${BRANCH_REF}&status=running" | \
jq '.[] | .id' | \
tail -n +2 | \
xargs -n 1 -I {} \
curl -sS -H "PRIVATE-TOKEN: $GITLAB_API_ACCESS_TOKEN" -X POST "${GITLAB_API_URL}/projects/$CI_PROJECT_ID/pipelines/{}/cancel"
