#!/usr/bin/env python3

import json
import sys
import uuid

def convert(issue):
    codeClimateItem = {
        'description': issue["reason"],
        'fingerprint': str(uuid.uuid4()),
        'severity': 'blocker',
        'location': {
            'path': issue["file"],
            'lines': {
                'begin': issue["line"]
                }
            }
        }

    return codeClimateItem

def main(argv):
    print("[CodeClimate Converter] Running the script")
    with open("fastlane/swiftlint.json", "r") as swiftLintData:
        issues = json.load(swiftLintData)

        print("[CodeClimate Converter] Loaded fastlane/swiftlint.json file, converting....")
        convertedIssues = list(map(convert, issues))

        print("[CodeClimate Converter] Converted, writing to file fastlane/codequality_report.json")
        with open("fastlane/codequality_report.json", "w") as codeClimateData:
            json.dump(convertedIssues, codeClimateData, indent=4, sort_keys=True)

if __name__ == "__main__":
   main(sys.argv[1:])
