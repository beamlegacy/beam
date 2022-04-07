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
	# This adds 2 keys and fails
	# security import certificates/dev_keys.p12 -k ~/Library/Keychains/login.keychain -P "${PRIVATE_KEY_PASSWORD}"

install_gitlab_runner:
	make install_direnv
	make install_xcode

	# Rubygems
	bundle

	# Fastlane
	sudo gem install fastlane -N

	make install_swiftlint
	make install_variable_injector

	# DMG
	brew install create-dmg

	# AWS
	brew install awscli

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

	# Deno for installing blocklists
	brew install deno

	# Manual Gitlab runner (see https://docs.gitlab.com/runner/install/osx.html)
	# sudo curl --output /usr/local/bin/gitlab-runner https://gitlab-runner-downloads.s3.amazonaws.com/latest/binaries/gitlab-runner-darwin-amd64
	# sudo chmod +x /usr/local/bin/gitlab-runner
	# gitlab-runner install
	# gitlab-runner start

	# Automatic
	brew install gitlab-runner
	brew services start gitlab-runner

	# Shell
	gitlab-runner register --non-interactive --custom_build_dir-enabled=true --name=`hostname | sed -e s/\.local//` --url=https://gitlab.com/ --executor="shell" --shell="bash" --tag-list="macos" --registration-token=${GITLAB_TOKEN}
	# Mono
	gitlab-runner register --non-interactive --custom_build_dir-enabled=true --name=`hostname | sed -e s/\.local//`-mono --limit=1 --url=https://gitlab.com/ --executor="shell" --shell="bash" --tag-list="macos-mono" --registration-token=${GITLAB_TOKEN}

install_fastlane:
	 gem install fastlane
	 bundle exec fastlane update_plugins

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
	yarn --cwd ./Beam/Classes/Components/PointAndShoot/Web run lint
	yarn --cwd ./Beam/Classes/Models/Navigation/Web run lint

install_variable_injector:
	rm -rf variable-injector
	git clone --depth 1 https://github.com/penso/variable-injector.git
	(cd variable-injector && make install)
	rm -rf variable-injector

install_direnv:
	brew install direnv
	eval "$(direnv hook zsh)"
	direnv allow .

install_rbenv:
	# Ruby
	brew install rbenv ruby-build
	rbenv init -
	rbenv install ${RUBY_VERSION}
	rbenv global ${RUBY_VERSION}

install_xcode:
	# Xcode
	curl -sL -O https://github.com/neonichu/ruby-domain_name/releases/download/v0.5.99999999/domain_name-0.5.99999999.gem
	sudo gem install domain_name-0.5.99999999.gem
	rm -f domain_name-0.5.99999999.gem
	sudo gem install --conservative xcode-install
	xcversion install ${XCODE_VERSION}

install_cmake:
	brew install cmake

# Not needed but left as documentation
install_libsodium:
	brew install libsodium
	sudo mkdir -p /opt/local
	sudo ln -s /opt/homebrew/lib /opt/local

install_js:
	brew install node
	brew install yarn
	brew install jq

install_codeclimate:
	brew tap codeclimate/formulae
	brew install codeclimate

git_checkout:
	brew install git-lfs
	git lfs install
	git submodule sync && git submodule update --init --recursive

delete_db_files:
	rm -f ${HOME}/Library/Containers/co.beamapp.macos/Data/Library/Application\ Support/Beam/Beam-*.sqlite*
	rm -f ${HOME}/Library/Containers/co.beamapp.macos.dev/Data/Library/Application\ Support/Beam/Beam-*.sqlite*

copy_vinyl_files:
	tar -a -cf BeamTests/Vinyl.tar.bz2 -C ${HOME}/Library/Containers/co.beamapp.macos/Data/Library/Logs/Beam/Vinyl/ .

reset_vinyl_files:
	rm -rf ${HOME}/Library/Containers/co.beamapp.macos.dev/Data/Library/Logs/Beam/Vinyl/*.json
	rm -rf ${HOME}/Library/Containers/co.beamapp.macos/Data/Library/Logs/Beam/Vinyl/*.json
	rm -f BeamTests/Vinyl.tar.bz2

extract_vinyl_files:
	tar -xf BeamTests/Vinyl.tar.bz2 -C ${HOME}/Library/Containers/co.beamapp.macos/Data/Library/Logs/Beam/Vinyl/
	tar -xf BeamTests/Vinyl.tar.bz2 -C ${HOME}/Library/Containers/co.beamapp.macos.dev/Data/Library/Logs/Beam/Vinyl/

js_test:
	./scripts/build_js.sh
	yarn run alltests

clean_app_files:
	rm -rf "${HOME}/Library/Containers/co.beamapp.macos.dev/Data/Library/Application Support/"*
	rm -rf "${HOME}/Library/Containers/co.beamapp.macos/Data/Library/Application Support/"*

clean_ci_server:
	docker system prune --volumes
	rm -rf ${HOME}/Library/Containers/co.beamapp.macos/
	rm -rf ${HOME}/Library/Containers/co.beamapp.macos.dev
	rm -rf ${HOME}/Library/Developer/Xcode/Archives/*
	rm -rf ${HOME}/Library/Developer/Xcode/DerivedData/*

# IMPORTANT: Only run this from Intel based machines, our CI will run on Intel
update_curl_jq_image:
	@echo "Building image"
	docker build -t registry.gitlab.com/beamgroup/beam/curl-jq registry/curl-jq
	@echo "Pushing image"
	docker push registry.gitlab.com/beamgroup/beam/curl-jq

setup: git_checkout install_dependencies install_swiftlint install_cmake install_direnv install_variable_injector build_libgit2 install_js
