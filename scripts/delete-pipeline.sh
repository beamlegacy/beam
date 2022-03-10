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

	# Need to handle Merge and Head refs
	CI_MERGE_REQUEST_REF_PATH_MERGE=${CI_MERGE_REQUEST_REF_PATH/head/merge}
	echo "CI_MERGE_REQUEST_REF_PATH_MERGE = ${CI_MERGE_REQUEST_REF_PATH_MERGE}"
	curl -sS -H "PRIVATE-TOKEN: $GITLAB_API_ACCESS_TOKEN" "${GITLAB_API_URL}/projects/$CI_PROJECT_ID/pipelines?ref=${CI_MERGE_REQUEST_REF_PATH_MERGE}&status=running" | \
	jq '.[] | .id' | \
	tail -n +2 | \
	xargs -n 1 -I {} \
	curl -sS -H "PRIVATE-TOKEN: $GITLAB_API_ACCESS_TOKEN" -X POST "${GITLAB_API_URL}/projects/$CI_PROJECT_ID/pipelines/{}/cancel"

	echo "CI_MERGE_REQUEST_REF_PATH = ${CI_MERGE_REQUEST_REF_PATH}"
	curl -sS -H "PRIVATE-TOKEN: $GITLAB_API_ACCESS_TOKEN" "${GITLAB_API_URL}/projects/$CI_PROJECT_ID/pipelines?ref=${CI_MERGE_REQUEST_REF_PATH}&status=running" | \
	jq '.[] | .id' | \
	tail -n +2 | \
	xargs -n 1 -I {} \
	curl -sS -H "PRIVATE-TOKEN: $GITLAB_API_ACCESS_TOKEN" -X POST "${GITLAB_API_URL}/projects/$CI_PROJECT_ID/pipelines/{}/cancel"

fi
