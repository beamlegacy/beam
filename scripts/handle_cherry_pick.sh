#!/usr/bin/env bash

set -eo pipefail

# Get GitLab API URL from project URL
GITLAB_API_URL="https://gitlab.com/api/v4"

# create branch for the cherry pick
curl -sS -X POST -H "PRIVATE-TOKEN: $GITLAB_API_ACCESS_TOKEN" "${GITLAB_API_URL}/projects/$CI_PROJECT_ID/repository/branches?ref=$CI_COMMIT_SHA&branch=cherry-pick/$CI_COMMIT_SHORT_SHA"

# create MR and get the iid
MR_IID=$(curl -sS -X POST -H "PRIVATE-TOKEN: $GITLAB_API_ACCESS_TOKEN" "${GITLAB_API_URL}/projects/$CI_PROJECT_ID/merge_requests?squash=true&source_branch=cherry-pick/$CI_COMMIT_SHORT_SHA&target_branch=develop&remove_source_branch=true&title=Cherry%20Pick%20$CI_COMMIT_SHORT_SHA%20into%20develop&approvals_before_merge=0" | \
	jq '.iid')

# Auto Merge MR when it is possible to set up the flag
until $(curl -sS --fail --output /dev/null --silent -X PUT -H "PRIVATE-TOKEN: $GITLAB_API_ACCESS_TOKEN" "${GITLAB_API_URL}/projects/$CI_PROJECT_ID/merge_requests/${MR_IID}/merge?merge_when_pipeline_succeeds=true"); do
    printf '.'
    sleep 2
done
