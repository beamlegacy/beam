#!/bin/sh

projectDir=${PROJECT_DIR:-..}
echo "projectDir=""${projectDir}"""
packageManager=$(which yarn)
echo "packageManager=""${packageManager}"""
${packageManager} --verbose --cwd "${projectDir}"/Beam/Classes/Helpers/Utils/Web run build
