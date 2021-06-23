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
struct EnvironmentVariables {
    struct Oauth {
        struct Google {
            static private(set) var consumerKey = "$(GOOGLE_CONSUMER_KEY)"
            static private(set) var consumerSecret = "$(GOOGLE_CONSUMER_SECRET)"
            static private(set) var callbackURL = "$(GOOGLE_REDIRECT_URL)"
        }

        struct Github {
            static private(set) var consumerKey = "$(GITHUB_CONSUMER_KEY)"
            static private(set) var consumerSecret = "$(GITHUB_CONSUMER_SECRET)"
            static private(set) var callbackURL = "$(GITHUB_REDIRECT_URL)"
        }
    }

    struct Sentry {
        static private(set) var key = "$(SENTRY_KEY)"
    }

    struct Account {
        static private(set) var testPassword = "$(TEST_ACCOUNT_PASSWORD)"
    }

    static private(set) var env = "$(ENV)"
    static private(set) var autoUpdate = NSString("$(AUTOMATIC_UPDATE)").boolValue
    static private(set) var networkStubs = NSString("$(NETWORK_STUBS)").boolValue
    static private(set) var sentryEnabled = NSString("$(SENTRY_ENABLED)").boolValue
    static private(set) var networkEnabled = NSString("$(NETWORK_ENABLED)").boolValue
    static private(set) var encryptionEnabled = NSString("$(ENCRYPTION_ENABLED)").boolValue
    static private(set) var pnsStatus = NSString("$(PNS_STATUS)").boolValue
}
