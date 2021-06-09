#!/bin/sh
yarn --cwd "${PROJECT_DIR:-..}"/Beam/Classes/Components/PointAndShoot/Web run build
yarn --cwd "${PROJECT_DIR:-..}"/Beam/Classes/Components/PointAndShoot/Web run test
