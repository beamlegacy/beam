module Fastlane
  module Actions
    class GetVersionNumberFromPlistAction < Action
      def self.run(params)
        version_number = get_version_number_from_plist!(params[:info_plist])
        Actions.lane_context[SharedValues::VERSION_NUMBER] = version_number
        return version_number
      end

      def self.get_version_number_from_plist!(plist_file)
        plist = Xcodeproj::Plist.read_from_path(plist_file)
        UI.user_error!("Unable to read plist: #{plist_file}") unless plist

        plist["CFBundleShortVersionString"]
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :info_plist,
                                       env_name: "FL_VERSION_NUMBER_PLIST",
                                       description: "Path to the Info.plist",
                                       optional: false,
                                       verify_block: proc do |value|
                                         UI.user_error!("Could not find file at path '#{File.expand_path(value)}'") if !File.exist?(value) && !Helper.test?
                                       end)
        ]
      end

      def self.is_supported?(platform)
        [:ios, :mac].include?(platform)
      end
    end

    class GetBuildNumberFromPlistAction < Action
      def self.run(params)
        build_number = get_version_number_from_plist!(params[:info_plist])
        Actions.lane_context[SharedValues::BUILD_NUMBER] = build_number
        return build_number
      end

      def self.get_version_number_from_plist!(plist_file)
        plist = Xcodeproj::Plist.read_from_path(plist_file)
        UI.user_error!("Unable to read plist: #{plist_file}") unless plist

        plist["CFBundleVersion"]
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :info_plist,
                                       env_name: "FL_BUILD_NUMBER_PLIST",
                                       description: "Path to the Info.plist",
                                       optional: false,
                                       verify_block: proc do |value|
                                         UI.user_error!("Could not find file at path '#{File.expand_path(value)}'") if !File.exist?(value) && !Helper.test?
                                       end)
        ]
      end

      def self.is_supported?(platform)
        [:ios, :mac].include?(platform)
      end
    end
  end
end
