# Beam
## ⚠️ Open Sourcing in progress ⚠️ 

The official development of **beam** macOS app [has stopped in November 2022](https://twitter.com/getonbeam/status/1592134355371331585)

Because the app is still used by some of us, and we still believe in a webkit-based ML-powered browser + note editor. We decided to open source it.

This is still far from done, please reach out if you want to contribute [TBD]


## Running the project

For now we're focusing on making the project run in debug, locally from Xcode.

### How to run
* Clone this repo
* `cd` inside the project and run: `make setup`







#### Legacy 
#### Allow the debug app to transmit browsing trees to http endpoint
* Create a `.envrc.private` at root of repo
* Declare following env vars inside (values should be found in 1Password)

```bash
export BROWSING_TREE_ACCESS_TOKEN="abc"
export BROWSING_TREE_URL="https://url"
```

* Run `direnv allow`


### If not running from an admin account:

* Homebrew will complain it can't write to its directories in `/opt/homebrew`. Apply `chown` and `chmod` as requested.

* Install cmake:
	- `brew install cmake`
	- `sudo ln -s /opt/homebrew/bin/cmake /usr/local/bin`

* In the `Makefile`, remove the `sudo xcode-select` command under `install_swiftlint`, and perform `xcode-select` manually.

### Update Vinyl files and minimize MR size

* Make sure you have the Vinyl files from `develop`: `git checkout develop BeamTests/Vinyl/`

* Run the tests, if some network calls have changed you'll have errors,
	copy/paste the Xcode console logs to a file, then `grep rm <log file>  | grep
	Vinyl` will give you a list of files to delete. Copy paste it to a terminal.

* Run the tests, then `make copy_vinyl_files`

* Commit just the Vinyl files with `Update Vinyl` as a commit message

### Run the tests

* Create a test account on https://app.beamapp.co, add its credentials in
	`.envrc.private` with `TEST_ACCOUNT_EMAIL` and `TEST_ACCOUNT_PASSWORD`.

### Creating a new Web component with build step
Run `yarn generate` to use the CLI wizard to generate a TS component.
