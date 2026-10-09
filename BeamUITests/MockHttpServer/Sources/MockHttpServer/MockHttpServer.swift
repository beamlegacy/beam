import Foundation
import Swifter
import Stencil
import PathKit

// MARK: - Helpers

private extension HttpRequest {
    func queryParam(_ name: String) -> String? {
        queryParams.first(where: { $0.0 == name })?.1
    }

    var hostname: String {
        headers["host"]?.split(separator: ":").first.map(String.init) ?? ""
    }

    var cookies: [String: String] {
        guard let cookieHeader = headers["cookie"] else { return [:] }
        var result: [String: String] = [:]
        for pair in cookieHeader.split(separator: ";") {
            let parts = pair.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                result[parts[0].trimmingCharacters(in: .whitespaces)] = String(parts[1])
            }
        }
        return result
    }

    var formBody: [String: String] {
        var result: [String: String] = [:]
        for (key, value) in parseUrlencodedForm() {
            result[key] = value
        }
        return result
    }
}

private func encodableToDict<T: Encodable>(_ value: T) -> [String: Any] {
    guard let data = try? JSONEncoder().encode(value),
          let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return [:]
    }
    return dict
}

// MARK: - MockHttpServer

public class MockHttpServer {
    private static var instances: [Int: MockHttpServer] = [:]
    private var serverPort: Int
    private var server: HttpServer
    private var stencilEnv: Environment

    private static let loremipsum = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.\n"

    @discardableResult
    public static func start(port: Int) -> MockHttpServer {
        let instance = Self.instances[port] ?? MockHttpServer(port: port)
        Self.instances[port] = instance
        do {
            try instance.server.start(in_port_t(port), forceIPv4: true)
        } catch {
            print("[MockHttpServer] Failed to start on port \(port): \(error)")
        }
        return instance
    }

    public static func stop(unregister: Bool = false) {
        for (_, instance) in instances {
            instance.server.stop()
        }
        if unregister {
            instances.removeAll()
        }
    }

    private init(port: Int) {
        self.serverPort = port
        self.server = HttpServer()

        guard let basePath = Bundle.module.resourcePath else {
            fatalError("Resources not available.")
        }
        let staticFilesPath = basePath + "/Resources/static"
        let templatesPath = basePath + "/Resources/templates"

        let fsLoader = FileSystemLoader(paths: [Path(templatesPath)])
        self.stencilEnv = Environment(loader: fsLoader)

        // Static files (with slow file support)
        server["/static/:path"] = { request in
            let fileName = request.path.split(separator: "/").last ?? ""
            if fileName.hasPrefix("slow_") {
                Thread.sleep(forTimeInterval: 0.5)
            }
            return shareFilesFromDirectory(staticFilesPath)(request)
        }

        // Root handler
        server["/"] = { [weak self] request in
            self?.rootHandler(request: request) ?? .notFound
        }

        // Form handlers
        for form in formNames(templatesPath: templatesPath) {
            server.GET["/\(form)"] = { [weak self] request in
                self?.renderStencil("form/\(form)", params: [:]) ?? .notFound
            }
        }
        server.GET["/custom"] = { [weak self] request in
            self?.renderCustomFieldsStencil(request: request) ?? .notFound
        }

        // Browser handlers
        for templateName in browserNames(templatesPath: templatesPath) {
            server.GET["/browser/\(templateName)"] = { [weak self] request in
                self?.renderStencil("browser/\(templateName)", params: [:]) ?? .notFound
            }
        }

        // Adblock handlers
        for templateName in adblockNames(templatesPath: templatesPath) {
            server.GET["/adblock/\(templateName)"] = { [weak self] request in
                self?.renderStencil("adblock/\(templateName)", params: [:]) ?? .notFound
            }
        }

        // Other frame handlers
        for templateName in otherFrameNames(templatesPath: templatesPath) {
            server.GET["/otherframe/\(templateName)"] = { [weak self] request in
                guard let self = self else { return .notFound }
                let topRedirect = request.queryParam("topredirect") ?? "true"
                return self.renderStencil("otherframe/\(templateName)", params: ["port": "\(self.serverPort)", "topredirect": topRedirect])
            }
        }

        // Readability handlers
        for templateName in readabilityNames(templatesPath: templatesPath) {
            server.GET["/readability/\(templateName)"] = { [weak self] request in
                self?.renderStencil("readability/\(templateName)", params: [:]) ?? .notFound
            }
        }

        // POST handlers
        server.POST["/view"] = { [weak self] request in
            self?.submitHandler(request: request) ?? .notFound
        }
        server.POST["/signinstep2"] = { [weak self] request in
            self?.step2Handler(request: request) ?? .notFound
        }
        server.POST["/signinpage9-2"] = { [weak self] request in
            self?.step2Handler(request: request) ?? .notFound
        }
        server.POST["/signuppage5-2"] = { [weak self] request in
            self?.signupStep2Handler(request: request) ?? .notFound
        }

        // Redirection handlers
        server.GET["/redirection"] = { [weak self] request in
            self?.redirectionPathHandler(request: request) ?? .notFound
        }
        server.GET["/redirection/:subpath"] = { [weak self] request in
            self?.redirectionPathHandler(request: request) ?? .notFound
        }

        // YouTube specific redirection pages
        server.GET["/youtube_redirected"] = { [weak self] request in
            self?.renderStencil("redirection/youtube_redirected", params: [:]) ?? .notFound
        }

        // File download handler (catch-all for root-level paths)
        server.GET["/:param"] = { [weak self] request in
            self?.fileDownloadOrRootHandler(request: request) ?? .notFound
        }
    }

    // MARK: - Template Rendering

    private func renderStencil(_ name: String, params: [String: Any]) -> HttpResponse {
        do {
            let rendered = try stencilEnv.renderTemplate(name: "\(name).stencil", context: ["params": params])
            return .ok(.html(rendered))
        } catch {
            return .raw(404, "Not Found", nil, { writer in
                try writer.write(Data(String(describing: error).utf8))
            })
        }
    }

    private func renderStencilEncodable<T: Encodable>(_ name: String, with value: T) -> HttpResponse {
        let dict = encodableToDict(value)
        return renderStencil(name, params: dict)
    }

    // MARK: - Route Handlers

    private func rootHandler(request: HttpRequest) -> HttpResponse {
        let host = request.hostname
        if let formTemplateName = host.removingSuffix(".form.lvh.me") {
            return renderStencil("form/\(formTemplateName)", params: [:])
        } else if let browserTemplateName = host.removingSuffix(".browser.lvh.me") {
            return renderStencil("browser/\(browserTemplateName)", params: ["port": "\(serverPort)"])
        } else if let redirectionTemplateName = host.removingSuffix(".redirection.lvh.me") {
            return renderStencil("redirection/\(redirectionTemplateName)", params: [:])
        } else if let redirectionTemplateName = host.removingSuffix(".adblock.lvh.me") {
            return renderStencil("adblock/\(redirectionTemplateName)", params: [:])
        } else if host == "download.lvh.me" {
            return fileDownloadHandler(request: request)
        } else if host == "otherframe.lvh.me" {
            return renderStencil("otherframe/index", params: ["port": "\(serverPort)"])
        } else {
            return listHandler(request: request)
        }
    }

    private func fileDownloadOrRootHandler(request: HttpRequest) -> HttpResponse {
        let host = request.hostname
        if host == "download.lvh.me" {
            return fileDownloadHandler(request: request)
        }
        // For non-download hosts, treat as root-like handler
        return rootHandler(request: request)
    }

    private func fileDownloadHandler(request: HttpRequest) -> HttpResponse {
        guard let filename = request.params[":param"] ?? request.path.split(separator: "/").last.map(String.init) else {
            return .raw(404, "Not Found", nil, { writer in
                try writer.write(Data("Missing filename".utf8))
            })
        }
        let fileLength = request.queryParam("length").flatMap(Int.init) ?? 100_000
        let headers: [String: String] = [
            "Content-Disposition": "attachment; filename=\"\(filename)\"",
            "Content-Type": "text/plain; charset=utf-8",
            "Content-Length": String(fileLength),
        ]
        let paragraphLength = Self.loremipsum.unicodeScalars.count
        return .raw(200, "OK", headers, { writer in
            var remaining = fileLength
            while remaining >= paragraphLength {
                try writer.write(Data(Self.loremipsum.utf8))
                remaining -= paragraphLength
            }
            try writer.write(Data(String(repeating: "*", count: remaining).utf8))
        })
    }

    struct Parameters: Encodable {
        var browsers: [String]
        var adblock: [String]
        var forms: [String]
        var redirections: [String]
        var styles: [String]
        var port: Int
    }

    private func defaultParameters() -> Parameters {
        guard let basePath = Bundle.module.resourcePath else { return Parameters(browsers: [], adblock: [], forms: [], redirections: [], styles: [], port: serverPort) }
        let templatesPath = basePath + "/Resources/templates"
        return Parameters(
            browsers: browserNames(templatesPath: templatesPath).sorted(),
            adblock: adblockNames(templatesPath: templatesPath).sorted(),
            forms: formNames(templatesPath: templatesPath).sorted(),
            redirections: redirectionNames(templatesPath: templatesPath).sorted(),
            styles: styleNames(basePath: basePath).sorted(),
            port: serverPort
        )
    }

    private func listHandler(request: HttpRequest) -> HttpResponse {
        return renderStencilEncodable("main", with: defaultParameters())
    }

    private func submitHandler(request: HttpRequest) -> HttpResponse {
        let formParams = request.formBody
        guard !formParams.isEmpty else {
            return .badRequest(nil)
        }
        let cookies = request.cookies
        let parameters = formParams.map { ["key": $0.key, "value": $0.value] }
        let cookieParams = cookies.map { ["key": $0.key, "value": $0.value] }
        let merged = (parameters + cookieParams).sorted { ($0["key"] ?? "") < ($1["key"] ?? "") }
        do {
            let rendered = try stencilEnv.renderTemplate(name: "form/view.stencil", context: ["params": merged])
            return .ok(.html(rendered))
        } catch {
            return .internalServerError
        }
    }

    private func step2Handler(request: HttpRequest) -> HttpResponse {
        let formParams = request.formBody
        guard let username = formParams["username"] else {
            return .badRequest(nil)
        }
        let headers: [String: String] = ["Set-Cookie": "username=\(username)"]
        do {
            let rendered = try stencilEnv.renderTemplate(name: "form/signinstep2.stencil", context: ["params": [String: Any]()])
            return .raw(200, "OK", headers, { writer in
                try writer.write(Data(rendered.utf8))
            })
        } catch {
            return .internalServerError
        }
    }

    private func signupStep2Handler(request: HttpRequest) -> HttpResponse {
        let formParams = request.formBody
        guard let email = formParams["email"] else {
            return .badRequest(nil)
        }
        let headers: [String: String] = ["Set-Cookie": "email=\(email)"]
        do {
            let rendered = try stencilEnv.renderTemplate(name: "form/signuppage5-2.stencil", context: ["params": [String: Any]()])
            return .raw(200, "OK", headers, { writer in
                try writer.write(Data(rendered.utf8))
            })
        } catch {
            return .internalServerError
        }
    }

    // MARK: - Template Name Helpers

    private func formNames(templatesPath: String) -> [String] {
        Bundle.module.paths(forResourcesOfType: "stencil", inDirectory: "/Resources/templates/form")
            .compactMap { $0.lastPathComponent.removingSuffix(".stencil") }
            .filter { $0 != "main" && $0 != "view" && $0 != "customfields" }
    }

    private func adblockNames(templatesPath: String) -> [String] {
        Bundle.module.paths(forResourcesOfType: "stencil", inDirectory: "/Resources/templates/adblock")
            .compactMap { $0.lastPathComponent.removingSuffix(".stencil") }
    }

    private func browserNames(templatesPath: String) -> [String] {
        Bundle.module.paths(forResourcesOfType: "stencil", inDirectory: "/Resources/templates/browser")
            .compactMap { $0.lastPathComponent.removingSuffix(".stencil") }
    }

    private func styleNames(basePath: String) -> [String] {
        Bundle.module.paths(forResourcesOfType: "css", inDirectory: "/Resources/static")
            .compactMap { $0.lastPathComponent.removingSuffix(".css") }
    }

    private func otherFrameNames(templatesPath: String) -> [String] {
        Bundle.module.paths(forResourcesOfType: "stencil", inDirectory: "/Resources/templates/otherframe")
            .compactMap { $0.lastPathComponent.removingSuffix(".stencil") }
    }

    private func readabilityNames(templatesPath: String) -> [String] {
        Bundle.module.paths(forResourcesOfType: "stencil", inDirectory: "/Resources/templates/readability")
            .compactMap { $0.lastPathComponent.removingSuffix(".stencil") }
    }

    private func redirectionNames(templatesPath: String) -> [String] {
        Bundle.module.paths(forResourcesOfType: "stencil", inDirectory: "/Resources/templates/redirection")
            .compactMap { $0.lastPathComponent.removingSuffix(".stencil") }
    }

    private func renderCustomFieldsStencil(request: HttpRequest) -> HttpResponse {
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

        let style = request.queryParam("style") ?? "default"
        var fields = [Field]()
        var index = 1
        while let label = request.queryParam("label\(index)") {
            let field = Field(
                label: label,
                type: request.queryParam("type\(index)") ?? "text",
                autocomplete: request.queryParam("autocomplete\(index)"),
                name: request.queryParam("name\(index)"),
                elemid: request.queryParam("id\(index)") ?? label
            )
            fields.append(field)
            index += 1
        }
        let parameters = Params(style: style, fields: fields)
        return renderStencilEncodable("form/customfields", with: parameters)
    }
}

// MARK: - Redirections

extension MockHttpServer {

    public enum RedirectionType: String, CaseIterable {
        case html
        case http301
        case http302
        case javascriptPush
        case javascriptPushSlow
        case javascriptReplace
        case javascriptReplaceClick
        case javascriptReplaceSlow
        case none
        case navigation
        case youtube
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

    private func redirectionPathHandler(request: HttpRequest) -> HttpResponse {
        let pathComponents = request.path.split(separator: "/")
        guard pathComponents.contains("redirection") else {
            return listHandler(request: request)
        }

        // Check if there's a query parameter for redirect type
        if let typeString = request.queryParam("type") {
            return performRedirect(type: typeString)
        }

        // Otherwise try to render a named page
        var page = String(pathComponents.last ?? "")
        if page == "redirection" {
            // /redirection with no sub-path and no query param
            return listHandler(request: request)
        }
        if page.hasPrefix("navigation") {
            page = "navigation"
        }

        guard let basePath = Bundle.module.resourcePath else { return .notFound }
        let templatesPath = basePath + "/Resources/templates"
        let names = redirectionNames(templatesPath: templatesPath)

        if names.contains(page) {
            let destinationURL = Self.redirectionURL(for: .none, port: serverPort)
            let redirections = RedirectionType.allCases.map { $0.rawValue }
            let parameters = RedirectionParameters(destination: destinationURL, redirections: redirections, port: serverPort)
            return renderStencilEncodable("redirection/\(page)", with: parameters)
        }

        return .notFound
    }

    struct RedirectionParameters: Encodable {
        var destination: String
        var redirections: [String]
        var port: Int
        var replace: String?
        var delay: String?
        var click: String?
    }

    private func performRedirect(type typeString: String) -> HttpResponse {
        guard let type = RedirectionType(rawValue: typeString) else {
            return .notFound
        }

        let destinationURL = Self.redirectionURL(for: .none, port: serverPort)
        let redirections = RedirectionType.allCases.map { $0.rawValue }
        var parameters = RedirectionParameters(destination: destinationURL, redirections: redirections, port: serverPort)

        switch type {
        case .http301:
            return .movedPermanently(destinationURL)
        case .http302:
            return .raw(302, "Found", ["Location": destinationURL], nil)
        case .html:
            return renderStencilEncodable("redirection/html_redirect", with: parameters)
        case .javascriptPush, .javascriptPushSlow, .javascriptReplace, .javascriptReplaceSlow, .javascriptReplaceClick:
            if type == .javascriptReplace || type == .javascriptReplaceSlow || type == .javascriptReplaceClick {
                parameters.replace = "true"
            }
            if type == .javascriptPushSlow || type == .javascriptReplaceSlow {
                parameters.delay = "700"
            } else if type == .javascriptPush || type == .javascriptReplaceClick || type == .javascriptReplace {
                parameters.delay = "200"
            }
            if type == .javascriptReplaceClick {
                parameters.click = "true"
            }
            return renderStencilEncodable("redirection/javascript_redirect", with: parameters)
        case .navigation:
            return renderStencilEncodable("redirection/navigation", with: parameters)
        case .none:
            return renderStencilEncodable("redirection/destination", with: parameters)
        case .youtube:
            return renderStencilEncodable("redirection/youtube", with: parameters)
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
