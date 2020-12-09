# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.

GITLAB_URL=ENV['GITLAB_URL'] || "https://gitlab.com/"
GITLAB_REGISTRATION_TOKEN=ENV['GITLAB_REGISTRATION_TOKEN']
GITLAB_RUNNER_NAME=ENV['GITLAB_RUNNER_NAME']
GITLAB_RUNNER_TAGS=ENV['GITLAB_RUNNER_TAGS']

Vagrant.configure("2") do |config|
  # Get box
  config.vm.box = "ramsey/macos-catalina"

  # Configuration
  config.vm.provider 'virtualbox' do |vb|
    vb.customize ["modifyvm", :id, "--ostype", "MacOS_64"]
    vb.customize ["modifyvm", :id, "--ioapic", "on"]
    vb.customize ["modifyvm", :id, "--nestedpaging", "off"]
    vb.gui = true
    vb.name = "catalina-xcode"
    vb.cpus = (ENV["VAGRANT_CPU"] || "4")
    vb.memory = (ENV["VAGRANT_RAM"] || "4096")
    config.vm.synced_folder ".", "/vagrant", disabled: true
  end

  # Set boot timeout to 600 seconds
  config.vm.boot_timeout = 600

  # Copy Xcode install package
  config.vm.provision "file", source: ENV["XCODE_XIP_FILE"], destination: "/tmp/Xcode.xip"

  # Copy scripts
  # config.vm.provision "file", source: "./scripts", destination: "/tmp/scripts"

  # Environment variables
  config.vm.provision "shell", privileged: true, name: 'environment variables', inline: <<-SHELL
    echo export BINARIES_DIRECTORY='/opt/local/bin' >> /etc/profile
    echo export BUILD_TOOLS_REPOSITORY=build-ios-simple-shell >> /etc/profile
    echo export USERNAME='vagrant' >> /etc/profile
    echo export LANG='en_US.UTF-8' >> /etc/profile
    echo export LANGUAGE='en_US.UTF-8' >> /etc/profile
    echo export LC_ALL='en_US.UTF-8' >> /etc/profile
    echo export 'PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin' >> /etc/profile
  SHELL

  # Disable sleep mode
  config.vm.provision "shell", privileged: false, name: 'disable sleep mode', inline: <<-SHELL
    sudo systemsetup -setcomputersleep Never
  SHELL

  # Developer mode activation
  config.vm.provision "shell", privileged: false, name: 'developer mode activation', inline: <<-SHELL
    sudo /usr/sbin/DevToolsSecurity -enable
    sudo /usr/sbin/dseditgroup -o edit -t group -a staff _developer
  SHELL

  # Install scripts
  config.vm.provision "shell", privileged: true, name: 'scripts', inline: <<-SHELL
    mkdir -p /usr/local/opt
    mv /tmp/scripts/ /usr/local/opt
    chmod +x /usr/local/opt/scripts/*.sh
    echo export PATH=/usr/local/opt/scripts:\$PATH >> /etc/profile
  SHELL

  # Install brew
  config.vm.provision "shell", privileged: false, name: 'homebrew with command line tools', inline: <<-SHELL
    /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
  SHELL

  # Install command line tools with brew
  config.vm.provision "shell", privileged: false, name: 'brew tools', inline: <<-SHELL
    /usr/local/bin/brew tap oclint/formulae
    /usr/local/bin/brew install xz ruby wget gcovr doxygen graphviz sonar-scanner carthage python@2 imagemagick ghostscript oclint
  SHELL

  # Install brew tools path
  config.vm.provision "shell", privileged: true, name: 'brew tools path', inline: <<-SHELL
    echo export PATH=/usr/local/opt/python@2/libexec/bin:\$PATH >> /etc/profile
  SHELL

  # Install Lizard
  config.vm.provision "shell", privileged: true, name: 'pip tools', inline: <<-SHELL
    pip install lizard
  SHELL

  # Install gem tools
  config.vm.provision "shell", privileged: false, name: 'gem tools', inline: <<-SHELL
    /usr/local/opt/ruby/bin/gem install xcpretty slather cocoapods jazzy
    /usr/local/opt/ruby/bin/gem install bundler --force
    /usr/local/opt/ruby/bin/gem install xcodeproj
    /usr/local/opt/ruby/bin/gem install fileutils
    sudo /usr/local/opt/ruby/bin/gem install fastlane -N
  SHELL

  # Install gem tools path
  config.vm.provision "shell", privileged: true, name: 'gem tools path', inline: <<-SHELL
    GEM_TOOL_BIN_PATH=`/usr/local/opt/ruby/bin/gem environment | awk -F ' *: *' '$1 ~ /EXECUTABLE DIRECTORY/{print $2}'`
    echo export PATH=\$GEM_TOOL_BIN_PATH:\$PATH >> /etc/profile
  SHELL

  # sonar-swift script
    config.vm.provision "shell", privileged: true, name: 'sonar-swift script', env: {"SONAR_PUBLIC_REPOSITORY" => "sonar-swift"}, inline: <<-SHELL
    git clone -b master https://github.com/insideapp-oss/$SONAR_PUBLIC_REPOSITORY.git ~/$SONAR_PUBLIC_REPOSITORY
    cd ~/$SONAR_PUBLIC_REPOSITORY
    git checkout develop
    mv ~/$SONAR_PUBLIC_REPOSITORY/sonar-swift-plugin/src/main/shell/ /usr/local/opt/$SONAR_PUBLIC_REPOSITORY
    rm -rf ~/$SONAR_PUBLIC_REPOSITORY
    chmod +x /usr/local/opt/$SONAR_PUBLIC_REPOSITORY/run-sonar-swift.sh
    echo export PATH=/usr/local/opt/$SONAR_PUBLIC_REPOSITORY:\$PATH >> /etc/profile
  SHELL

  # Install java
    config.vm.provision "shell", privileged: false, name: 'java', inline: <<-SHELL
    /usr/local/bin/brew tap caskroom/versions
    /usr/local/bin/brew cask install java
  SHELL

  # Enable auto login
    config.vm.provision "shell", privileged: false, name: 'enable auto login', inline: <<-SHELL
    /usr/local/bin/brew tap xfreebird/utils
    /usr/local/bin/brew install kcpassword
    enable_autologin "${USERNAME}" "${USERNAME}"
  SHELL

  # Reboot (to enable auto login)
  #config.vm.provision :reload

  # Xcode
  config.vm.provision "shell", privileged: false, name: 'xcode installation', inline: <<-SHELL
      open -FWga "Archive Utility" --args /tmp/Xcode.xip
      # Move Xcode to Applications directory
      sudo mv ~/Downloads/Xcode.app /Applications/
      # Clean Xcode installation file
      rm /tmp/Xcode.xip
      # Accept Xcode licence
      sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
      sudo xcodebuild -license accept
      # Install XCode additional required components
      for pkg in /Applications/Xcode.app/Contents/Resources/Packages/*.pkg; do sudo installer -pkg "$pkg" -target /; done
  SHELL


  # Simulator tools (require Xcode to be installed)
  config.vm.provision "shell", privileged: false, name: 'ios simulator tools', inline: <<-SHELL
    /usr/local/bin/brew tap wix/brew
    /usr/local/bin/brew install applesimutils
    /usr/local/bin/brew tap facebook/fb
  SHELL

  # swiftlint (require Xcode to be installed)
  config.vm.provision "shell", privileged: false, name: 'swiftlint installation', inline: <<-SHELL
    /usr/local/bin/brew install swiftlint
  SHELL

  # flutter (require Xcode to be installed)
  config.vm.provision "shell", privileged: false, name: 'flutter installation', inline: <<-SHELL
    /usr/local/bin/brew tap MiderWong/flutter
    /usr/local/bin/brew install flutter 
  SHELL

  # Cocoapods repository setup
  config.vm.provision "shell", privileged: false, name: 'pod repository setup', inline: <<-SHELL
    pod setup
  SHELL

  # GitLab runner install
  config.vm.provision "shell", privileged: false, name: 'gitlab-runner installation', inline: <<-SHELL
    /usr/local/bin/brew install gitlab-runner
    /usr/local/bin/brew services start gitlab-runner
    # Registration
    gitlab-runner register --non-interactive --url "#{GITLAB_URL}" --registration-token "#{GITLAB_REGISTRATION_TOKEN}" --executor "shell" --name "#{GITLAB_RUNNER_NAME}" --tag-list "#{GITLAB_RUNNER_TAGS}"
  SHELL

  # Reboot
  config.vm.provision :reload

end
