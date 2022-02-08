//
//  ThirdPartyLibrariesManager+Sentry.swift
//  Beam
//
//  Created by Remi Santos on 23/01/2022.
//

import Foundation
import Sentry
import BeamCore

extension ThirdPartyLibrariesManager {
    func setupSentry() {
        guard Configuration.sentryEnabled else {
            Logger.shared.logDebug("Sentry is disabled", category: .sentry)
            return
        }

        Logger.shared.logDebug("Sentry enabled: https://\(Configuration.Sentry.key[0..<3])...@\(Configuration.Sentry.hostname)/\(Configuration.Sentry.projectID)",
                               category: .sentry)

        SentrySDK.start { options in
            options.dsn = "https://\(Configuration.Sentry.key)@\(Configuration.Sentry.hostname)/\(Configuration.Sentry.projectID)"
            options.beforeSend = { event in
                Logger.shared.logDebug("Event: \(event.type ?? "-") \(event.level) \(event.message?.message ?? "-")",
                                       category: .sentry)
                return event
            }
            options.beforeBreadcrumb = { event in
                Logger.shared.logDebug("Breadcrumb: \(event.type ?? "-") \(event.category) \(event.message ?? "-") \(event.data?.description ?? "-")",
                                       category: .sentry)
                return event
            }
            options.debug = false
            options.tracesSampleRate = 1.0
            options.releaseName = Information.appVersionAndBuild
        }

        setupSentryScope()
        setSentryUser()
    }

    private func setupSentryScope() {
        let currentHost = Host.current().name ?? ""

        let sentryEnv: String = {
            let appEnv = Configuration.env
            switch appEnv {
            case .release:
                return Configuration.branchType?.rawValue ?? "develop"
            default:
                return appEnv.rawValue
            }
        }()

        SentrySDK.configureScope { scope in
            scope.setEnvironment(sentryEnv)
            scope.setDist(Information.appBuild)
            scope.setTag(value: currentHost, key: "hostname")

            if let mergeRequestSourceBranche = ProcessInfo.processInfo.environment["CI_MERGE_REQUEST_SOURCE_BRANCH_NAME"] {
                scope.setTag(value: mergeRequestSourceBranche, key: "MERGE_REQUEST")
            }

            if let ciJobId = ProcessInfo.processInfo.environment["CI_JOB_ID"] {
                scope.setTag(value: "https://gitlab.com/beamgroup/beam/-/jobs/\(ciJobId)", key: "CI_JOB_ID")
            }

            if let scheme = Configuration.buildSchemeName {
                scope.setTag(value: scheme, key: "SCHEME")
            }
        }
    }

    func setSentryUser() {
        guard let email = Persistence.Authentication.email else { return }
        let user = Sentry.User()
        user.email = email
        SentrySDK.setUser(user)
        sentryUser = user
    }
}
