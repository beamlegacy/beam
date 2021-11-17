// This file handles any configuration parameters
// Build configuration variables are defined in xcconfig files, feed Info.plist then accessed from here
// File is parsed by https://github.com/penso/variable-injector

/*
 *
 * * * * * * * * *
  IMPORTANT: Save this file and commit when you change it before building or you will lose your changes.

  Building will overwrite this file to inject the ENV variables.
 * * * * * * * * *
 */

// swiftlint:disable nesting
public struct EnvironmentVariables {
    public struct Oauth {
        public struct Google {
            static public private(set) var consumerKey = "$(GOOGLE_CONSUMER_KEY)"
            static public private(set) var consumerSecret = "$(GOOGLE_CONSUMER_SECRET)"
            static public private(set) var callbackURL = "$(GOOGLE_REDIRECT_URL)"
         }

        public struct Github {
            static public private(set) var consumerKey = "$(GITHUB_CONSUMER_KEY)"
            static public private(set) var consumerSecret = "$(GITHUB_CONSUMER_SECRET)"
            static public private(set) var callbackURL = "$(GITHUB_REDIRECT_URL)"
        }
    }

    public struct BrowsingTree {
        static public private(set) var accessToken = "$(BROWSING_TREE_ACCESS_TOKEN)"
        static public private(set) var url = "$(BROWSING_TREE_URL)"
    }

    public struct PublicAPI {
        static public private(set) var embed = "$(PUBLIC_API_EMBED_URL)"
        static public private(set) var publishServer = "$(PUBLIC_API_PUBLISH_URL)"
    }

    public struct Sentry {
        static public private(set) var key = "$(SENTRY_KEY)"
    }

    public struct Account {
        static public private(set) var testPassword = "$(TEST_ACCOUNT_PASSWORD)"
        static public private(set) var testEmail = "$(TEST_ACCOUNT_EMAIL)"
    }

    static public private(set) var beamObjectAPIEnabled = NSString("$(BEAM_OBJECT_API_ENABLED)").boolValue
    static public private(set) var env = "$(ENV)"
    static public private(set) var autoUpdate = NSString("$(AUTOMATIC_UPDATE)").boolValue
    static public private(set) var networkStubs = NSString("$(NETWORK_STUBS)").boolValue
    static public private(set) var sentryEnabled = NSString("$(SENTRY_ENABLED)").boolValue
    static public private(set) var networkEnabled = NSString("$(NETWORK_ENABLED)").boolValue
    static public private(set) var encryptionEnabled = NSString("$(ENCRYPTION_ENABLED)").boolValue
    static public private(set) var hideCategories = "$(HIDE_CATEGORIES)".split(separator: " ").compactMap {
        LogCategory(rawValue: String($0))
    }
}
