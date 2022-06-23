import Foundation
import Kitura
import KituraStencil
import LoggerAPI
import Logging
import LoggingOSLog

public class MockHttpServer {
    private static var loggerInitialized = false
    private static var instances: [Int: MockHttpServer] = [:]

    private static let loremipsum = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.\n"

    @discardableResult
    public static func start(port: Int = 8080) -> MockHttpServer {
        if !loggerInitialized {
            LoggingSystem.bootstrap(LoggingOSLog.init)
            loggerInitialized = true
        }
        let instance = Self.instances[port] ?? MockHttpServer(port: port)
        Self.instances[port] = instance
        Kitura.start()
        return instance
    }

    public static func stop(unregister: Bool = false) {
        guard loggerInitialized else { return }
        Kitura.stop(unregister: unregister)
        if unregister {
            instances.removeAll()
        }
    }

    private init(port: Int) {
        guard let basePath = Bundle.module.resourcePath else {
            fatalError("Resources not available.")
        }
        let staticFilesPath = basePath + "/Resources/static"
        let templatesPath = basePath + "/Resources/templates"
        let router = Router()
        router.all("/static", middleware: StaticFileServer(path: staticFilesPath))
        router.setDefault(templateEngine: StencilTemplateEngine())
        router.viewsPath = templatesPath
        router.get("/", handler: rootHandler)
        installFormHandlers(to: router)
        installBrowserHandlers(to: router)
        installRedirectionHandlers(to: router)
        installAdBlockHandlers(to: router)
        router.all("/view", middleware: BodyParser())
        router.post("/view", handler: submitHandler)
        router.all("/signinstep2", middleware: BodyParser())
        router.post("/signinstep2", handler: step2Handler)
        router.all("/signinpage9-2", middleware: BodyParser())
        router.post("/signinpage9-2", handler: step2Handler)
        router.all("/signuppage5-2", middleware: BodyParser())
        router.post("/signuppage5-2", handler: signupStep2Handler)
        router.get("/:param", handler: fileDownloadHandler)

        Kitura.addHTTPServer(onPort: port, with: router)
    }

    private func installFormHandlers(to router: Router) {
        for form in formNames {
            router.get("/\(form)") { request, response, next in
                self.renderStencil(request, response, "form/\(form)")
                next()
            }
        }
        router.get("/custom") { request, response, next in
            self.renderCustomFieldsStencil(request, response)
            next()
        }
    }

    private func installBrowserHandlers(to router: Router) {
        for templateName in browserNames {
            router.get("browser/\(templateName)") { request, response, next in
                self.renderStencil(request, response, "browser/\(templateName)")
                next()
            }
        }
    }
    
    private func installAdBlockHandlers(to router: Router) {
        for templateName in adblockNames {
            router.get("adblock/\(templateName)") { request, response, next in
                self.renderStencil(request, response, "adblock/\(templateName)")
                next()
            }
        }
    }

    private func rootHandler(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) {
        if let formTemplateName = request.hostname.removingSuffix(".form.lvh.me") {
            renderStencil(request, response, "form/\(formTemplateName)")
        } else if let browserTemplateName = request.hostname.removingSuffix(".browser.lvh.me") {
            renderStencil(request, response, "browser/\(browserTemplateName)")
        } else if let redirectionTemplateName = request.hostname.removingSuffix(".redirection.lvh.me") {
            renderStencil(request, response, "redirection/\(redirectionTemplateName)")
        } else if let redirectionTemplateName = request.hostname.removingSuffix(".adblock.lvh.me") {
            renderStencil(request, response, "adblock/\(redirectionTemplateName)")
        } else if request.hostname == "download.lvh.me" {
            fileDownloadHandler(request: request, response: response, next: next)
        } else {
            listHandler(request: request, response: response, next: next)
        }
    }

    private func formPathHandler(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) {
        guard let form = request.parameters["form"] ?? request.hostname.removingSuffix(".form.lvh.me") else {
            return listHandler(request: request, response: response, next: next)
        }
        renderStencil(request, response, "form/\(form)")
        next()
    }

    private func browserPathHandler(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) {
        guard let browser = request.parameters["browser"] else {
            return listHandler(request: request, response: response, next: next)
        }
        renderStencil(request, response, "browser/\(browser)")
        next()
    }
    
    private func adblockPathHandler(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) {
        guard let browser = request.parameters["adblock"] else {
            return listHandler(request: request, response: response, next: next)
        }
        renderStencil(request, response, "adblock/\(browser)")
        next()
    }

    private func fileDownloadHandler(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) {
        guard request.hostname == "download.lvh.me" else {
            return next()
        }
        guard let filename = request.parameters["param"] else {
            response.status(.notFound).send("Missing filename")
            return next()
        }
        let fileLength = request.queryParameters["length"].flatMap(Int.init) ?? 100_000
        response.headers.addAttachment(for: filename)
        response.headers.setType("txt", charset: "utf-8")
        response.headers["Content-Length"] = String(fileLength)
        let paragraphLength = Self.loremipsum.unicodeScalars.count
        var remaining = fileLength
        while remaining >= paragraphLength {
            response.send(Self.loremipsum)
            remaining -= paragraphLength
        }
        response.send(String(repeating: "*", count: remaining))
        try? response.end()
        next()
    }

    struct Parameters: Encodable {
        var browsers: [String]
        var adblock: [String]
        var forms: [String]
        var redirections: [String]
        var styles: [String]
        var port: Int
    }

    private func defaultParameters(for request: RouterRequest) -> Parameters {
        return Parameters(browsers: browserNames.sorted(), adblock: adblockNames.sorted(), forms: formNames.sorted(), redirections: redirectionNames.sorted(),
                          styles: styleNames.sorted(), port: request.port)
    }

    private func listHandler(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) {
        let parameters = defaultParameters(for: request)
        do {
            try response.render("main.stencil", with: parameters, forKey: "params")
        }
        catch {
            response.status(.internalServerError).send(String(describing: error))
        }
        next()
    }

    private func submitHandler(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) {
        guard let formParams = request.body?.asURLEncoded else {
            response.status(.badRequest)
            return next()
        }
        let parameters = formParams.map { ["key": $0.key, "value": $0.value] }
        let cookies = request.cookies.map { ["key": $0.key, "value": $0.value.value] }
        let merged = (parameters + cookies).sorted { $0["key"]! < $1["key"]! }
        do {
            try response.render("form/view.stencil", with: merged, forKey: "params")
        } catch {
            response.status(.internalServerError).send(String(describing: error))
        }
        next()
    }

    private func step2Handler(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) {
        guard let formParams = request.body?.asURLEncoded, let username = formParams["username"] else {
            response.status(.badRequest)
            return next()
        }
        response.headers.append("Set-Cookie", value: "username=\(username)")
        renderStencil(request, response, "form/signinstep2")
        next()
    }
    
    private func signupStep2Handler(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) {
        guard let formParams = request.body?.asURLEncoded, let email = formParams["email"] else {
            response.status(.badRequest)
            return next()
        }
        response.headers.append("Set-Cookie", value: "email=\(email)")
        renderStencil(request, response, "form/signuppage5-2")
        next()
    }

    private var formNames: [String] {
        Bundle.module.paths(forResourcesOfType: "stencil", inDirectory: "/Resources/templates/form")
            .compactMap { $0.lastPathComponent.removingSuffix(".stencil") }
            .filter { $0 != "main" && $0 != "view" && $0 != "customfields" }
    }
    
    private var adblockNames: [String] {
        Bundle.module.paths(forResourcesOfType: "stencil", inDirectory: "/Resources/templates/adblock")
            .compactMap { $0.lastPathComponent.removingSuffix(".stencil") }
    }

    private var browserNames: [String] {
        Bundle.module.paths(forResourcesOfType: "stencil", inDirectory: "/Resources/templates/browser")
            .compactMap { $0.lastPathComponent.removingSuffix(".stencil") }
    }

    private var styleNames: [String] {
        Bundle.module.paths(forResourcesOfType: "css", inDirectory: "/Resources/static")
            .compactMap { $0.lastPathComponent.removingSuffix(".css") }
    }

    fileprivate func renderStencil(_ request: RouterRequest, _ response: RouterResponse, _ stencilName: String) {
        renderStencil(request, response, stencilName, additionalParams: [String: String]())
    }

    fileprivate func renderStencil<T: Encodable>(_ request: RouterRequest, _ response: RouterResponse, _ stencilName: String, additionalParams: T? = nil) {
        guard stencilName != "form/custom" else {
            return renderCustomFieldsStencil(request, response)
        }
        do {
            var parameters = additionalParams
            if var stringDicParam = additionalParams as? [String:String] {
                let style = request.queryParameters["style"] ?? "default"
                stringDicParam["style"] = style
                parameters = stringDicParam as? T ?? parameters
            }
            try response.render("\(stencilName).stencil", with: parameters, forKey: "params")
        } catch {
            response.status(.notFound).send(String(describing: error))
        }
    }

    fileprivate func renderCustomFieldsStencil(_ request: RouterRequest, _ response: RouterResponse) {
        struct Params: Encodable {
            var style: String
            var fields: [Field]
        }
        struct Field: Encodable {
            var label: String
            var type: String
            var autocomplete: String?
            var name: String?
            var elemid: String
        }
        do {
            let style = request.queryParameters["style"] ?? "default"
            var fields = [Field]()
            var index = 1
            while let label = request.queryParameters["label\(index)"] {
                let field = Field(
                    label: label,
                    type: request.queryParameters["type\(index)", default: "text"],
                    autocomplete: request.queryParameters["autocomplete\(index)"],
                    name: request.queryParameters["name\(index)"],
                    elemid: request.queryParameters["id\(index)", default: label]
                )
                fields.append(field)
                index += 1
            }
            let parameters = Params(style: style, fields: fields)
            try response.render("form/customfields.stencil", with: parameters, forKey: "params")
        } catch {
            response.status(.notFound).send(String(describing: error))
        }
    }
}

// MARK: - Redirections

extension MockHttpServer {

    public enum RedirectionType: String, CaseIterable {
        /// Performs a redirection with html meta tag
        case html
        case http301
        case http302
        /// Performs a javascript history.pushState 200ms after page load
        case javascriptPush
        /// .javascriptPush redirect but the redirection happens 700ms after page load
        case javascriptPushSlow
        /// Performs a javascript history.replaceState on page load
        case javascriptReplace
        /// .javascriptReplace redirect but the redirection happens 700mss after page load
        case javascriptReplaceSlow
        case none
        case navigation
    }

    private enum RedirectionError: Swift.Error {
        case unknownRedirection
    }

    private static func redirectionBaseUrl(with port: Int) -> String {
        "http://localhost:\(port)/redirection"
    }

    public static func redirectionURL(for type: RedirectionType, port: Int) -> String {
        var urlString = "\(redirectionBaseUrl(with: port))"
        switch type {
        case .none:
            urlString += "/destination"
        case .navigation:
            urlString += "/navigation"
        default:
            urlString += "?type=\(type.rawValue)"
        }
        return urlString
    }

    public static func redirectionScriptToSimulateLinkRedirection(for type: RedirectionType) -> String {
        "clickOnRedirection('\(type.rawValue)')"
    }

    public static func navigationScriptToSimulateJSNavigation(for path: String, replace: Bool) -> String {
        "performNavigation('/redirection/navigation_\(path)', \(replace ? "true" : "false"))"
    }

    private var redirectionNames: [String] {
        Bundle.module.paths(forResourcesOfType: "stencil", inDirectory: "/Resources/templates/redirection")
            .compactMap { $0.lastPathComponent.removingSuffix(".stencil") }
    }

    private func installRedirectionHandlers(to router: Router) {
        router.get("/redirection", handler: redirectionPathHandler)
        router.get("/redirection/*", handler: redirectionPathHandler)
    }

    struct RedirectionParameters: Encodable {
        var destination: String
        var redirections: [String]
        var port: Int
        var replace: String?
        var delay: String?
    }

    private func redirectionPathHandler(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) {
        guard request.urlURL.pathComponents.contains("redirection") else {
            return listHandler(request: request, response: response, next: next)
        }
        var page = request.urlURL.lastPathComponent
        if page.hasPrefix("navigation") {
            page = "navigation"
        }
        do {
            if !page.isEmpty, redirectionNames.contains(page) {
                let destinationURL = Self.redirectionURL(for: .none, port: request.port)
                let redirections = RedirectionType.allCases.map { $0.rawValue }
                let parameters = RedirectionParameters(destination: destinationURL, redirections: redirections, port: request.port)
                try response.render("redirection/\(page).stencil", with: parameters, forKey: "params")
            } else {
                try performRedirect(request: request, response: response)
            }
        } catch {
            response.status(.notFound).send(String(describing: error))
        }
        next()
    }

    func performRedirect(request: RouterRequest, response: RouterResponse) throws {
        guard let typeString = request.queryParameters["type"], let type = RedirectionType(rawValue: typeString) else {
            throw RedirectionError.unknownRedirection
        }

        let destinationURL = Self.redirectionURL(for: .none, port: request.port)
        let redirections = RedirectionType.allCases.map { $0.rawValue }
        var parameters = RedirectionParameters(destination: destinationURL, redirections: redirections, port: request.port)
        switch type {
        case .http301, .http302:
            var statusCode = HTTPStatusCode.OK
            let codeString = type.rawValue.suffix(3)
            if let code = Int(codeString), let status = HTTPStatusCode(rawValue: code) {
                statusCode = status
            }
            try response.redirect(destinationURL, status: statusCode)
        case .html:
            renderStencil(request, response, "redirection/html_redirect", additionalParams: parameters)
            break
        case .javascriptPush, .javascriptPushSlow, .javascriptReplace, .javascriptReplaceSlow:
            if type == .javascriptReplace || type == .javascriptReplaceSlow {
                parameters.replace = "true"
            }
            if type == .javascriptPushSlow || type == .javascriptReplaceSlow {
                parameters.delay = "700"
            } else if type == .javascriptPush {
                parameters.delay = "200" //
            }
            renderStencil(request, response, "redirection/javascript_redirect", additionalParams: parameters)
            break
        case .navigation:
            renderStencil(request, response, "redirection/navigation", additionalParams: parameters)
        case .none:
            renderStencil(request, response, "redirection/destination", additionalParams: parameters)
        }
    }
}

// MARK: - Quick Helpers

private extension String {
    func removingSuffix(_ suffix: String) -> String? {
        guard hasSuffix(suffix) else { return nil }
        var prefix = self
        prefix.removeLast(suffix.count)
        return prefix
    }

    var lastPathComponent: String {
        guard let position = lastIndex(of: "/") else {
            return self
        }
        return String(self[position...].dropFirst())
    }
}
