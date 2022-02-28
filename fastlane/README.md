fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## Mac

### mac lint

```sh
[bundle exec] fastlane mac lint
```

Run linting

### mac register_local_device

```sh
[bundle exec] fastlane mac register_local_device
```

Register Device

### mac build_for_testing

```sh
[bundle exec] fastlane mac build_for_testing
```

Build for UI Testing

### mac tests

```sh
[bundle exec] fastlane mac tests
```

Run Unit Tests

### mac uitestsThread1

```sh
[bundle exec] fastlane mac uitestsThread1
```

Run UI tests Thread1

### mac uitestsThread2

```sh
[bundle exec] fastlane mac uitestsThread2
```

Run UI tests Thread2

### mac uitestsThread3

```sh
[bundle exec] fastlane mac uitestsThread3
```

Run UI tests Thread3

### mac uitestsThread4

```sh
[bundle exec] fastlane mac uitestsThread4
```

Run UI tests Thread4

### mac delete_s3_derived_data

```sh
[bundle exec] fastlane mac delete_s3_derived_data
```



### mac build

```sh
[bundle exec] fastlane mac build
```



### mac notarize_build

```sh
[bundle exec] fastlane mac notarize_build
```



### mac deploy

```sh
[bundle exec] fastlane mac deploy
```



### mac publish

```sh
[bundle exec] fastlane mac publish
```



### mac tag_build

```sh
[bundle exec] fastlane mac tag_build
```



### mac ping_sentry

```sh
[bundle exec] fastlane mac ping_sentry
```



### mac upload_s3

```sh
[bundle exec] fastlane mac upload_s3
```



### mac delete_s3

```sh
[bundle exec] fastlane mac delete_s3
```



----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
