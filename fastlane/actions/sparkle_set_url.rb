# https://raw.githubusercontent.com/buildasaurs/Buildasaur/master/fastlane/actions/sparkle_add_update.rb
module Fastlane
  module Actions
    class SparkleSetUrlAction < Action
      module SharedValues
        SPARKLE_APPCAST_URL||= :SPARKLE_APPCAST_URL
      end

      def self.run(params)
        command = [
          '/usr/libexec/PlistBuddy',
          "-c \"Set SUFeedURL #{params[:appcast_url]}\"",
          params[:info_plist]
        ].join(' ')
        output = Actions.sh(command)
        return Actions.lane_context[SharedValues::SPARKLE_APPCAST_URL] = params[:appcast_url]
      end

      def self.details
        ""
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :info_plist,
                                       env_name: "FL_SPARKLE_SET_URL_PLIST",
                                       description: "Path to the Info.plist",
                                       optional: false,
                                       verify_block: proc do |value|
                                          raise "Couldn't find file at path '#{value}'".red unless File.exist?(value)
                                       end),
          FastlaneCore::ConfigItem.new(key: :appcast_url,
                                       env_name: "FL_SPARKLE_SET_URL_LINK",
                                       description: "URL for the AppFeed.json",
                                       verify_block: proc do |value|
                                          raise "Invalid URL '#{value}'".red unless (value and !value.empty?)
                                       end)
        ]
      end

      def self.is_supported?(platform)
        [:ios, :mac].include?(platform)
      end
    end
  end
end
