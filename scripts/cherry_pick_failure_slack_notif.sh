#!/bin/bash

set -euo pipefail

CHANNEL="devs"
WEBHOOK="https://hooks.slack.com/services/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"
GITLAB_API_URL="https://gitlab.com/api/v4"

# Get title and id of cherry picked MR
MR_TITLE=$(curl -sS -H "PRIVATE-TOKEN: $GITLAB_API_ACCESS_TOKEN" "${GITLAB_API_URL}/projects/$CI_PROJECT_ID/repository/commits/$CI_COMMIT_SHA/merge_requests" | \
    jq '.[] | .title' | jq -sRr @uri)
ORIGINAL_MR_IID=$(curl -sS -H "PRIVATE-TOKEN: $GITLAB_API_ACCESS_TOKEN" "${GITLAB_API_URL}/projects/$CI_PROJECT_ID/repository/commits/$CI_COMMIT_SHA/merge_requests" | \
    jq '.[] | .iid')

function print_slack_summary() {

    local slack_msg_header
    local slack_msg_body
    local slack_channel

    # Populate header and define slack channels

    slack_msg_header=":x: Auto Cherry Pick failed - Proceed manually"

    #define slack channel in case we want to dispatch later on different channels
    slack_channel="$CHANNEL"

    # Create slack message body
    slack_msg_body="MR ID: ${ORIGINAL_MR_IID}\nMR Title: ${MR_TITLE}\n"
    
    cat <<-SLACK
            {
                "channel": "${slack_channel}",
                "blocks": [
                  {
                          "type": "section",
                          "text": {
                                  "type": "mrkdwn",
                                  "text": "${slack_msg_header}"
                          }
                  },
                  {
                          "type": "divider"
                  },
                  {
                          "type": "section",
		                  "text": {
                                  "type": "mrkdwn",
                                  "text": "${slack_msg_body}"
                          }
                  }
                ]
}
SLACK
}

function share_slack_update() {

	local slack_webhook
    
    slack_webhook="$WEBHOOK"

    curl -X POST                                           \
        --data-urlencode "payload=$(print_slack_summary)"  \
        "${slack_webhook}"
}