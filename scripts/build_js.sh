#!/bin/sh
# Set the -e flag to stop running the script in case a command returns
# a nonzero exit code.
set -e

export PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"
yarn install
yarn run buildpackages
yarn workspaces foreach run build