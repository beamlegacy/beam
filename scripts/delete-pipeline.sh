#!/usr/bin/env bash

set -eo pipefail

# Get GitLab API URL from project URL
GITLAB_API_URL="https://gitlab.com/api/v4"

# Find correct refs for pipelines url
# If we are in a MR pipeline, delete old pipelines to keep only the last one
if [[ ${CI_PIPELINE_SOURCE} == "merge_request_event" ]]
then
	# Query running pipelines for the same branch, 
	# process + filter them,
	# and finally cancel them with another API call
	echo "CI_MERGE_REQUEST_REF_PATH = ${CI_MERGE_REQUEST_REF_PATH}"
	curl -sS -H "PRIVATE-TOKEN: $GITLAB_API_ACCESS_TOKEN" "${GITLAB_API_URL}/projects/$CI_PROJECT_ID/pipelines?ref=${BRANCH_REF}&status=running" | \
	jq '.[] | .id' | \
	tail -n +2 | \
	xargs -n 1 -I {} \
	curl -sS -H "PRIVATE-TOKEN: $GITLAB_API_ACCESS_TOKEN" -X POST "${GITLAB_API_URL}/projects/$CI_PROJECT_ID/pipelines/{}/cancel"
fi
