
build_virtualbox_image:
	gem install iesd
	# iesd -i "$(OSX_IMAGE)" -o OSX.dmg -t BaseSystem
	# Convert a DMG into ISO
	hdiutil convert OSX.dmg -format UDTO -o converted_iso

install_gitlab_runner:
	sudo curl --output /usr/local/bin/gitlab-runner https://gitlab-runner-downloads.s3.amazonaws.com/latest/binaries/gitlab-runner-darwin-amd64
	sudo chmod +x /usr/local/bin/gitlab-runner
	echo "Please register the runner at https://docs.gitlab.com/runner/register/index.html and https://gitlab.com/beamgroup/beam/-/settings/ci_cd"
	cd $(HOME)
	gitlab-runner install
	sudo gitlab-runner start
	sudo gitlab-runner register
	echo "Please check $(HOME)/Library/LaunchAgents/gitlab-runner.plist. Go read https://docs.gitlab.com/runner/install/osx.html as well."
	echo "Edit $(HOME)/.gitlab-runner/config.toml with settings"

# Xcode part
	xcode-select --install
	sudo gem install fastlane -N
	# Alternatively using Homebrew
	# brew cask install fastlane
	cd Beam
	fastlane init swift # use 4.
	echo "Edit Beam/fastlane/Appfile"
	@read "Tap enter when done"

install_swiftlint:
	brew install swiftlint
	sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

gym:
	fastlane gym

swiftlint:
	swiftlint autocorrect

swiftlint_rules:
	swiftlint rules

lint:
	cd Beam
	fastlane lint

variable_injector:
	curl -ssl https://raw.githubusercontent.com/penso/variable-injector/master/scripts/install-binary.sh | sh

install_direnv:
	brew install direnv

setup: install_direnv install_swiftlint variable_injector
