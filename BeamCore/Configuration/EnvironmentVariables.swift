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
        static public private(set) var apiSyncEnabled = NSString("$(BROWSING_TREE_API_SYNC_ENABLED)").boolValue
    }

    public struct Clustering {
        static public private(set) var tabColoring = NSString("$(TAB_COLORING)").boolValue
    }

    public struct PublicAPI {
        static public private(set) var embed = "$(PUBLIC_API_EMBED_URL)"
        static public private(set) var publishServer = "$(PUBLIC_API_PUBLISH_URL)"
    }

    public struct Sentry {
        static public private(set) var key = "$(SENTRY_KEY)"
    }

    public struct Firebase {
        static public private(set) var apiKey = "$(FIREBASE_API_KEY)"
        static public private(set) var clientID = "$(FIREBASE_CLIENT_ID)"
        static public private(set) var googleAppID = "$(FIREBASE_GOOGLE_APP_ID)"
        static public private(set) var projectID = "$(FIREBASE_PROJECT_ID)"
        static public private(set) var apiKeyDev = "$(FIREBASE_DEV_API_KEY)"
        static public private(set) var clientIDDev = "$(FIREBASE_DEV_CLIENT_ID)"
        static public private(set) var googleAppIDDev = "$(FIREBASE_DEV_GOOGLE_APP_ID)"
        static public private(set) var projectIDDev = "$(FIREBASE_DEV_PROJECT_ID)"
    }

    public struct Account {
        static public private(set) var testPassword = "$(TEST_ACCOUNT_PASSWORD)"
        static public private(set) var testEmail = "$(TEST_ACCOUNT_EMAIL)"
    }

    static public private(set) var env = "$(ENV)"
    static public private(set) var autoUpdate = NSString("$(AUTOMATIC_UPDATE)").boolValue
    static public private(set) var networkStubs = NSString("$(NETWORK_STUBS)").boolValue
    static public private(set) var sentryEnabled = NSString("$(SENTRY_ENABLED)").boolValue
    static public private(set) var networkEnabled = NSString("$(NETWORK_ENABLED)").boolValue
    static public private(set) var beamObjectSendPrivateKey = NSString("$(BEAM_OBJECT_SEND_PRIVATE_KEY)").boolValue
    static public private(set) var hideCategories = "$(HIDE_CATEGORIES)".split(separator: " ").compactMap {
        LogCategory(rawValue: String($0))
    }
    #if BEAM_BETA
    static public private(set) var branchType = "beta"
    #elseif BEAM_PUBLIC
    static public private(set) var branchType = "public"
    #else
    static public private(set) var branchType = "develop"
    #endif

}
