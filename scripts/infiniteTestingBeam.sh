#!/bin/sh
testsCounter=0
testsCounterSuccess=0
testCounterFail=0
uiTestsCounter=0
uiTestsCounterSuccess=0
uiTestsCounterFail=0

echo "Infinite Beam Testing"
if [ $# = 0 ] ; then
    echo "Missing arguments: add -test for UnitTests or/and -uitest for UITests"
    exit 1
else
    while true; do
        if [[($1 = "-test" || $2 = "-test")]] ; then
            echo "========================"
            echo "* FASTLANE TESTS START *"
            echo "========================"
            bundle exec fastlane tests
            if [ $? = 0 ] ; then
                let testsCounterSuccess++
            else
                let testCounterFail++
            fi
            let testsCounter++
            echo "======================"
            echo "Tests Counter: $testsCounter times reached!"
            echo "Success: $testsCounterSuccess"
            echo "Fail: $testCounterFail"
            echo "* FASTLANE TESTS END *"
            echo "======================"
            sleep 15
        fi
        if [[($1 = "-uitest" || $2 = "-uitest")]] ; then
            echo "==========================="
            echo "* FASTLANE UI TESTS START *"
            echo "==========================="
            bundle exec fastlane uitests
            if [ $? = 0 ] ; then
                let uiTestsCounterSuccess++
            else
                let uiTestsCounterFail++
            fi
            let uiTestsCounter++
            echo "========================="
            echo "UI Tests Counter: $uiTestsCounter times reached!"
            echo "Success: $uiTestsCounterSuccess"
            echo "Fail: $uiTestsCounterFail"
            echo "* FASTLANE UI TESTS END *"
            echo "========================="
            sleep 15
        fi
    done
fi
