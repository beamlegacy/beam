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
### mac register_local_device
```
fastlane mac register_local_device
```
Register Device
### mac tests
```
fastlane mac tests
```
Run tests
### mac uitests
```
fastlane mac uitests
```
Run UI tests
### mac dev
```
fastlane mac dev
```

### mac beta
```
fastlane mac beta
```

### mac notarize_build
```
fastlane mac notarize_build
```

### mac deploy
```
fastlane mac deploy
```

### mac ping_sentry
```
fastlane mac ping_sentry
```

### mac upload_s3
```
fastlane mac upload_s3
```

### mac publish_release
```
fastlane mac publish_release
```

### mac delete_s3
```
fastlane mac delete_s3
```

### mac release
```
fastlane mac release
```


----

This README.md is auto-generated and will be re-generated every time [fastlane](https://fastlane.tools) is run.
More information about fastlane can be found on [fastlane.tools](https://fastlane.tools).
The documentation of fastlane can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
