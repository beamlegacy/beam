#!/bin/sh
export PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"
yarn --cwd "${PROJECT_DIR:-..}"/Beam/Classes/Components/BeamTextEdit/EmbedNode/Web run build