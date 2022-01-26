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
        router.all("/view", middleware: BodyParser())
        router.post("/view", handler: submitHandler)
        Kitura.addHTTPServer(onPort: port, with: router)
    }

    private func installFormHandlers(to router: Router) {
        for form in formNames {
            router.get("/\(form)") { request, response, next in
                let style = request.parameters["style"] ?? "default"
                let parameters = ["style": style]
                do {
                    try response.render("\(form).stencil", with: parameters, forKey: "params")
                }
                catch {
                    response.status(.internalServerError).send(String(describing: error))
                }
                next()
            }
        }
    }

    private func rootHandler(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) {
        guard let form = request.hostname.removingSuffix(".form.lvh.me") else {
            return listHandler(request: request, response: response, next: next)
        }
        let style = request.queryParameters["style"] ?? "default"
        let parameters = ["style": style]
        do {
            try response.render("\(form).stencil", with: parameters, forKey: "params")
        } catch {
            response.status(.notFound).send(String(describing: error))
        }
        next()
    }

    private func formPathHandler(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) {
        guard let form = request.parameters["form"] else {
            return listHandler(request: request, response: response, next: next)
        }
        let style = request.queryParameters["style"] ?? "default"
        let parameters = ["style": style]
        do {
            try response.render("\(form).stencil", with: parameters, forKey: "params")
        } catch {
            response.status(.notFound).send(String(describing: error))
        }
        next()
    }

    private func listHandler(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) {
        struct Parameters: Encodable {
            var forms: [String]
            var styles: [String]
            var port: Int
        }
        let parameters = Parameters(forms: formNames.sorted(), styles: styleNames.sorted(), port: request.port)
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
        let parameters = formParams.map { ["key": $0.key, "value": $0.value] }.sorted { $0["key"]! < $1["key"]! }
        do {
            try response.render("view.stencil", with: parameters, forKey: "params")
        } catch {
            response.status(.internalServerError).send(String(describing: error))
        }
        next()
    }

    private var formNames: [String] {
        Bundle.module.paths(forResourcesOfType: "stencil", inDirectory: "/Resources/templates")
            .compactMap { $0.lastPathComponent.removingSuffix(".stencil") }
            .filter { $0 != "main" && $0 != "view" }
    }

    private var styleNames: [String] {
        Bundle.module.paths(forResourcesOfType: "css", inDirectory: "/Resources/static")
            .compactMap { $0.lastPathComponent.removingSuffix(".css") }
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
