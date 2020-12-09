
build_virtualbox_image:
	gem install iesd
	# iesd -i "$(OSX_IMAGE)" -o OSX.dmg -t BaseSystem
	# Convert a DMG into ISO
	hdiutil convert OSX.dmg -format UDTO -o converted_iso

unlock_keychain:
	sudo security lock-keychain ~/Library/Keychains/login.keychain-db
	sudo security unlock-keychain ~/Library/Keychains/login.keychain-db

install_dev_keys:
	security unlock-keychain -p ${MACOSX_PASSWORD} ~/Library/Keychains/login.keychain
	# security import ~/private_key.p12 -k ~/Library/Keychains/login.keychain -P "${PRIVATE_KEY_PASSWORD}"
	# security import ~/public_key.pem -k ~/Library/Keychains/login.keychain
	security import ~/certs.p12 -k ~/Library/Keychains/login.keychain -P "${PRIVATE_KEY_PASSWORD}"

install_gitlab_runner:
	# TODO: install sudo file

	# Install Brew
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	# CI=1 /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

	brew install direnv
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
	gitlab-runner register --non-interactive --name=`hostname | sed -e s/\.local//` --url=https://gitlab.com/ --executor="shell" --shell="bash" --registration-token=${GITLAB_TOKEN}

	# Xcode
	curl -sL -O https://github.com/neonichu/ruby-domain_name/releases/download/v0.5.99999999/domain_name-0.5.99999999.gem
	sudo gem install domain_name-0.5.99999999.gem
	sudo gem install --conservative xcode-install
	rm -f domain_name-0.5.99999999.gem
	xcversion install ${XCODE_VERSION}

	# Fastlane
	sudo gem install fastlane -N

	# Swiftlint
	brew install swiftlint

	# injector
	curl -ssl https://raw.githubusercontent.com/penso/variable-injector/master/scripts/install-binary.sh | sh

	# Register new device
	bundle exec fastlane register_local_device

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
	fastlane lint

variable_injector:
	curl -ssl https://raw.githubusercontent.com/penso/variable-injector/master/scripts/install-binary.sh | sh

install_direnv:
	brew install direnv

setup: install_direnv install_swiftlint variable_injector
