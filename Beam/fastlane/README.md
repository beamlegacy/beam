fastlane documentation
================
# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```
xcode-select --install
```

Install _fastlane_ using
```
[sudo] gem install fastlane -NV
```
or alternatively using `brew install fastlane`

# Available Actions
## Mac
### mac lint
```
fastlane mac lint
```
Run linting
### mac tests
```
fastlane mac tests
```
Run tests
### mac dev
```
fastlane mac dev
```

### mac beta
```
fastlane mac beta
```

### mac upload_s3
```
fastlane mac upload_s3
```

### mac build_dmg
```
fastlane mac build_dmg
```

### mac ping_slack
```
fastlane mac ping_slack
```

### mac release
```
fastlane mac release
```


----

This README.md is auto-generated and will be re-generated every time [fastlane](https://fastlane.tools) is run.
More information about fastlane can be found on [fastlane.tools](https://fastlane.tools).
The documentation of fastlane can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
