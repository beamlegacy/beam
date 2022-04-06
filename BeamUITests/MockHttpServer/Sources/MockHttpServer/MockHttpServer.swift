import Foundation
import Kitura
import KituraStencil
import LoggerAPI
import Logging
import LoggingOSLog

public class MockHttpServer {
    private static var loggerInitialized = false
    private static var instances: [Int: MockHttpServer] = [:]

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

    public static func stop() {
        guard loggerInitialized else { return }
        Kitura.stop(unregister: false)
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
        router.all("/view", middleware: BodyParser())
        router.post("/view", handler: submitHandler)
        router.all("/signinstep2", middleware: BodyParser())
        router.post("/signinstep2", handler: step2Handler)
        Kitura.addHTTPServer(onPort: port, with: router)
    }

    private func installFormHandlers(to router: Router) {
        for form in formNames {
            router.get("/\(form)") { request, response, next in
                self.renderStencil(request, response, "form/\(form)")
                next()
            }
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

    private func rootHandler(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) {
        if let formTemplateName = request.hostname.removingSuffix(".form.lvh.me") {
            renderStencil(request, response, "form/\(formTemplateName)")
        } else if let browserTemplateName = request.hostname.removingSuffix(".browser.lvh.me") {
            renderStencil(request, response, "browser/\(browserTemplateName)")
        } else {
            return listHandler(request: request, response: response, next: next)
        }
        next()
    }

    private func formPathHandler(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) {
        guard let form = request.parameters["form"] else {
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

    private func listHandler(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) {
        struct Parameters: Encodable {
            var browser: [String]
            var forms: [String]
            var styles: [String]
            var port: Int
        }
        let parameters = Parameters(browser: browserNames.sorted(), forms: formNames.sorted(), styles: styleNames.sorted(), port: request.port)
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

    private var formNames: [String] {
        Bundle.module.paths(forResourcesOfType: "stencil", inDirectory: "/Resources/templates/form")
            .compactMap { $0.lastPathComponent.removingSuffix(".stencil") }
            .filter { $0 != "main" && $0 != "view" }
    }

    private var browserNames: [String] {
        Bundle.module.paths(forResourcesOfType: "stencil", inDirectory: "/Resources/templates/browser")
            .compactMap { $0.lastPathComponent.removingSuffix(".stencil") }
            .filter { $0 != "main" && $0 != "view" }
    }

    private var styleNames: [String] {
        Bundle.module.paths(forResourcesOfType: "css", inDirectory: "/Resources/static")
            .compactMap { $0.lastPathComponent.removingSuffix(".css") }
    }

    fileprivate func renderStencil(_ request: RouterRequest, _ response: RouterResponse, _ stencilName: String) {
        do {
            let style = request.queryParameters["style"] ?? "default"
            let parameters = ["style": style]
            try response.render("\(stencilName).stencil", with: parameters, forKey: "params")
        } catch {
            response.status(.notFound).send(String(describing: error))
        }
    }
}

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
