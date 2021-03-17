# New Dev Checklist

### Setting up Beam
* Run:
  `$ [arch -x86_64] make setup`
* Setup Apple Developer Account with Beam AppleID.

### If not running from an admin account:

* Homebrew will complain it can't write to its directories in `/opt/homebrew`. Apply `chown` and `chmod` as requested.

* Install cmake:
	- `brew install cmake`
	- `sudo ln -s /opt/homebrew/bin/cmake /usr/local/bin`

* In the `Makefile`, remove the `sudo xcode-select` command under `install_swiftlint`, and perform `xcode-select` manually.

* In the `Makefile`, remove the dependency to `variable_injector`, and install `variable_injector` manually into `/usr/local/bin`:
	- download and unzip `https://github.com/LucianoPAlmeida/variable-injector/releases/download/0.3.3/x86_64-apple-macosx.zip`
	- copy `release/variable-injector` to `/usr/local/bin`.

