#!/bin/sh
export PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"
yarn run buildpackages
yarn workspaces foreach run build