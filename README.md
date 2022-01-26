# New Dev Checklist

### Setting up Beam
* Clone this repo then install git-lfs: `git lfs install`
* `cd` inside the project and run: `make setup`
* Setup Apple Developer Account with Beam AppleID.
* If the tests fail, cd to the beam directory and run: `direnv allow`

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

* In the `Makefile`, remove the dependency to `variable_injector`, and install `variable_injector` manually into `/usr/local/bin`:
	- download and unzip `https://github.com/LucianoPAlmeida/variable-injector/releases/download/0.3.3/x86_64-apple-macosx.zip`
	- copy `release/variable-injector` to `/usr/local/bin`.

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
- Make Components/<name>/Web folder
- add .eslintrc.js
- add package.json
- add jest.config.js
- add tsconfig.json
- add webpack.config.js
- add <name>.js
- add <name>.ts
- add <name>UI.ts
- add <name>UI_native.ts
- add "Test" folder
- add build_js_<name>.sh
- add build_xcfilelist_<name>.sh
- add build step in xcode
- add xcfilelist step in xcode