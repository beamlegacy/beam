xcparse screenshots --activity-type attachmentContainer userCreated testAssertionFailure --test --os --model fastlane/test_output/Beam.xcresult screenshots
xcparse screenshots --test-status Failure --test --os --model fastlane/test_output/Beam.xcresult screenshots
find screenshots -type d -empty -delete
rm "${HOME}/Library/Containers/co.beamapp.macos/Data/Library/Application Support/Beam/Beam-test-${CI_JOB_ID}"*
rm "${HOME}/Library/Containers/co.beamapp.macos/Data/Library/Application Support/GRDB-test-${CI_JOB_ID}"*
mkdir -p logs
mv ${HOME}/Library/logs/scan/*.log logs
mv ${HOME}/Library/Containers/co.beamapp.macos/Data/Library/Logs/Beam/*.log logs
rm -r "${HOME}/Library/Containers/co.beamapp.macos/Data/Library/Application Support/Beam/BeamData-test-${CI_JOB_ID}"
rm -r ${HOME}/Downloads/*
