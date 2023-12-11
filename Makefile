git_checkout:
	git submodule sync && git submodule update --init --recursive

install_fastlane:
	 gem install fastlane
	 bundle exec fastlane update_plugins

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
	yarn --cwd ./Beam/Classes/Components/PointAndShoot/Web run lint
	yarn --cwd ./Beam/Classes/Models/Navigation/Web run lint

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

install_js:
	brew install node
	brew install yarn
	brew install jq

install_codeclimate:
	brew tap codeclimate/formulae
	brew install codeclimate

delete_db_files:
	rm -f ${HOME}/Library/Containers/co.beamapp.macos/Data/Library/Application\ Support/Beam/Beam-*.sqlite*
	rm -f ${HOME}/Library/Containers/co.beamapp.macos.dev/Data/Library/Application\ Support/Beam/Beam-*.sqlite*

copy_vinyl_files:
	tar -a -cf BeamTests/Vinyl.tar.bz2 -C ${HOME}/Library/Containers/co.beamapp.macos/Data/Library/Logs/Beam/Vinyl/ .

reset_vinyl_files:
	rm -rf ${HOME}/Library/Containers/co.beamapp.macos.dev/Data/Library/Logs/Beam/Vinyl/*.json
	rm -rf ${HOME}/Library/Containers/co.beamapp.macos.dev/Data/Library/Logs/Beam/Vinyl/json/
	rm -rf ${HOME}/Library/Containers/co.beamapp.macos/Data/Library/Logs/Beam/Vinyl/*.json
	rm -rf ${HOME}/Library/Containers/co.beamapp.macos/Data/Library/Logs/Beam/Vinyl/json/
	rm -f BeamTests/Vinyl.tar.bz2

extract_vinyl_files:
	tar -xf BeamTests/Vinyl.tar.bz2 -C ${HOME}/Library/Containers/co.beamapp.macos/Data/Library/Logs/Beam/Vinyl/
	tar -xf BeamTests/Vinyl.tar.bz2 -C ${HOME}/Library/Containers/co.beamapp.macos.dev/Data/Library/Logs/Beam/Vinyl/

js_test:
	./scripts/build_js.sh
	yarn run alltests

setup_js_xcfilelists:
	./scripts/build_xcfilelist_web.sh

clean_app_files:
	rm -rf "${HOME}/Library/Containers/co.beamapp.macos.dev/Data/Library/Application Support/"*
	rm -rf "${HOME}/Library/Containers/co.beamapp.macos/Data/Library/Application Support/"*

setup: git_checkout install_swiftlint install_js setup_js_xcfilelists
