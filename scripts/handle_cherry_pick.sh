#!/usr/bin/env bash

set -eo pipefail

# Get GitLab API URL from project URL
GITLAB_API_URL="https://gitlab.com/api/v4"

LAST_DEVELOP_COMMIT=$(curl -sS -H "PRIVATE-TOKEN: $GITLAB_API_ACCESS_TOKEN" "${GITLAB_API_URL}/projects/$CI_PROJECT_ID/repository/branches/develop" | \
    jq '.commit.short_id' | tr -d '"' ) 

RELEASE_COMMIT=$(curl -sS -H "PRIVATE-TOKEN: $GITLAB_API_ACCESS_TOKEN" "${GITLAB_API_URL}/projects/$CI_PROJECT_ID/repository/branches/$CI_COMMIT_BRANCH" | \
    jq '.commit.short_id' | tr -d '"' )

# Do not create cherry pick for the first build of release branch from develop
if [ "$LAST_DEVELOP_COMMIT" != "$RELEASE_COMMIT" ]; then
    # create branch for the cherry pick
    curl -sS -X POST -H "PRIVATE-TOKEN: $GITLAB_API_ACCESS_TOKEN" "${GITLAB_API_URL}/projects/$CI_PROJECT_ID/repository/branches?ref=$CI_COMMIT_SHA&branch=cherry-pick/$CI_COMMIT_SHORT_SHA"

    # Get title and id of cherry picked MR
    MR_TITLE=$(curl -sS -H "PRIVATE-TOKEN: $GITLAB_API_ACCESS_TOKEN" "${GITLAB_API_URL}/projects/$CI_PROJECT_ID/repository/commits/$CI_COMMIT_SHA/merge_requests" | \
        jq '.[] | .title' | jq -sRr @uri)

    ORIGINAL_MR_IID=$(curl -sS -H "PRIVATE-TOKEN: $GITLAB_API_ACCESS_TOKEN" "${GITLAB_API_URL}/projects/$CI_PROJECT_ID/repository/commits/$CI_COMMIT_SHA/merge_requests" | \
        jq '.[] | .iid')

    # create MR and get the iid
    MR_IID=$(curl -sS -X POST -H "PRIVATE-TOKEN: $GITLAB_API_ACCESS_TOKEN" "${GITLAB_API_URL}/projects/$CI_PROJECT_ID/merge_requests?squash=true&source_branch=cherry-pick/$CI_COMMIT_SHORT_SHA&target_branch=develop&remove_source_branch=true&title=Cherry%20Pick%20$MR_TITLE%20into%20develop&approvals_before_merge=0" | \
    	jq '.iid')

    # Add note to original MR
    curl -sS -X POST -H "PRIVATE-TOKEN: $GITLAB_API_ACCESS_TOKEN" "${GITLAB_API_URL}/projects/$CI_PROJECT_ID/merge_requests/$ORIGINAL_MR_IID/notes?body=MR%20cherry%20picked%20%21$MR_IID"

    # Auto Merge MR when it is possible to set up the flag
    until $(curl -sS --fail --output /dev/null --silent -X PUT -H "PRIVATE-TOKEN: $GITLAB_API_ACCESS_TOKEN" "${GITLAB_API_URL}/projects/$CI_PROJECT_ID/merge_requests/${MR_IID}/merge?merge_when_pipeline_succeeds=true"); do
        printf '.'
        sleep 2
    done
fi