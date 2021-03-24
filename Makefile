build_virtualbox_image:
	gem install iesd
	# iesd -i "$(OSX_IMAGE)" -o OSX.dmg -t BaseSystem
	# Convert a DMG into ISO
	hdiutil convert OSX.dmg -format UDTO -o converted_iso

unlock_keychain:
	sudo security lock-keychain ~/Library/Keychains/login.keychain-db
	sudo security unlock-keychain ~/Library/Keychains/login.keychain-db

install_dependencies:
	git submodule update --init --recursive

install_certificates:
	security unlock-keychain -p ${MACOSX_PASSWORD} ~/Library/Keychains/login.keychain
	security import certificates/keys.p12 -k ~/Library/Keychains/login.keychain -P "${PRIVATE_KEY_PASSWORD}"
	security import certificates/dev_keys.p12 -k ~/Library/Keychains/login.keychain -P "${PRIVATE_KEY_PASSWORD}"

install_gitlab_runner:
	# TODO: install sudo file

	# Install Brew
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	echo 'eval $(/opt/homebrew/bin/brew shellenv)' >> ~/.zprofile
	eval $(/opt/homebrew/bin/brew shellenv)
	# CI=1 /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

	# Install direnv for environment variables
	brew install direnv
	eval "$(direnv hook zsh)"
	
	direnv allow .

	# Ruby
	brew install rbenv ruby-build
	rbenv init -
	echo 'eval "$(rbenv init -)"' >> ~/.zshrc
	rbenv install ${RUBY_VERSION}
	rbenv global ${RUBY_VERSION}

	# Gitlab runner
	sudo curl --output /usr/local/bin/gitlab-runner https://gitlab-runner-downloads.s3.amazonaws.com/latest/binaries/gitlab-runner-darwin-amd64
	sudo chmod +x /usr/local/bin/gitlab-runner
	cd ${HOME}
	gitlab-runner install
	gitlab-runner start
	gitlab-runner register --non-interactive --custom_build_dir-enabled=true --name=`hostname | sed -e s/\.local//` --url=https://gitlab.com/ --executor="shell" --shell="bash" --registration-token=${GITLAB_TOKEN}

	# Xcode
	curl -sL -O https://github.com/neonichu/ruby-domain_name/releases/download/v0.5.99999999/domain_name-0.5.99999999.gem
	sudo gem install domain_name-0.5.99999999.gem
	sudo gem install --conservative xcode-install
	rm -f domain_name-0.5.99999999.gem
	xcversion install ${XCODE_VERSION}

	# Rubygems
	bundle

	# Fastlane
	sudo gem install fastlane -N

	# Swiftlint
	brew install swiftlint

	# injector
	curl -ssl https://raw.githubusercontent.com/penso/variable-injector/master/scripts/install-binary.sh | sudo sh

	# DMG
	brew install create-dmg

	# AWS
	brew install awscli

	# Docker, M1 must install manually and beta version
	brew install --cask docker

	# jq for scripts
	brew install jq

	# Register new device
	bundle exec fastlane register_local_device

	# For badge
	brew install imagemagick graphicsmagick

	# Sentry
	brew install getsentry/tools/sentry-cli

  # Screenshots
	brew install chargepoint/xcparse/xcparse

install_swiftlint:
	brew install swiftlint
	sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

build_libgit2:
	cd Extern/libgit2
	mkdir -p build && cd build
	cmake -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" -DBUILD_SHARED_LIBS="OFF" -DCMAKE_OSX_DEPLOYMENT_TARGET="10.15" -S Extern/libgit2/ -B Extern/libgit2/build
	cmake --build Extern/libgit2/build

gym:
	fastlane gym

swiftlint:
	swiftlint autocorrect

swiftlint_rules:
	swiftlint rules

lint:
	fastlane lint

variable_injector:
	curl -ssl https://raw.githubusercontent.com/penso/variable-injector/master/scripts/install-binary.sh | sh

install_direnv:
	brew install direnv

install_cmake:
	brew install cmake

# Not needed but left as documentation
install_libsodium:
	brew install libsodium
	sudo mkdir -p /opt/local
	sudo ln -s /opt/homebrew/lib /opt/local

git_checkout:
	git submodule sync && git submodule update --init --recursive

copy_vinyl_files:
	cp ${HOME}/Library/Containers/co.beamapp.macos/Data/Library/Logs/Beam/Vinyl/*.json BeamTests/Vinyl/

setup: git_checkout install_dependencies install_direnv install_swiftlint install_cmake variable_injector build_libgit2
