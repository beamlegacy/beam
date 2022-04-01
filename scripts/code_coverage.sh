#!/bin/bash

# TODO: deal with no previous pipeline / null coverage value

# get coverage for latest current pipeline
#tmp=`curl -s https://gitlab.com/api/v4/projects/${CI_PROJECT_ID}/pipelines/ | jq '.[0] | .id'`

echo "Will fetch https://gitlab.com/api/v4/projects/${CI_PROJECT_ID}/pipelines/${CI_PIPELINE_ID}"

latest=`curl -s --header "Authorization: Bearer ${GITLAB_ACCESS_TOKEN}" https://gitlab.com/api/v4/projects/${CI_PROJECT_ID}/pipelines/${CI_PIPELINE_ID} | jq '.coverage'`

latest="${latest%\"}"
latest="${latest#\"}"
latest="${latest/.*}"
echo "pipeline " ${CI_PIPELINE_ID} " coverage value = " $latest

# get coverage for develop
echo "Will fetch https://gitlab.com/api/v4/projects/${CI_PROJECT_ID}/pipelines?ref=develop&status=success"

tmp=`curl -s --header "Authorization: Bearer ${GITLAB_ACCESS_TOKEN}" https://gitlab.com/api/v4/projects/${CI_PROJECT_ID}/pipelines\?ref\=develop\&status\=success | jq '.[0] | .id'`

# pass that into the curl below
echo "Will fetch https://gitlab.com/api/v4/projects/${CI_PROJECT_ID}/pipelines/${tmp}"
develop=`curl -s --header "Authorization: Bearer ${GITLAB_ACCESS_TOKEN}" https://gitlab.com/api/v4/projects/${CI_PROJECT_ID}/pipelines/${tmp} | jq '.coverage'`
echo "develop coverage = " $develop
develop="${develop%\"}"
develop="${develop#\"}"
develop="${develop/.*}"
# Bash will cast the number 0 to null. 
# If the coverage is 0, use 1 for the comparison instead
if [[ "$develop" == null ]] ; then 
  echo "develop cover is null, using 1 for comparison"
  develop=1
fi
echo "develop coverage value =" $develop

# if latest >= develop exit 0
if [ "$latest" -ge "$develop" ]
then
  echo "Latest pipeline coverage >= develop"
  exit 0
# else exit 1
else
  echo "Latest pipeline coverage < develop"
  exit 1
fi
