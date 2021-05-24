#!/bin/sh
yarn --cwd "${PROJECT_DIR:-..}"/Beam/Classes/Components/PointAndShoot run build
yarn --cwd "${PROJECT_DIR:-..}"/Beam/Classes/Components/PointAndShoot run test
