function log(emoji, type, args) {
    window.webkit.messageHandlers.beam_logging.postMessage(
        `${emoji} JS ${type}: ${Object.values(args)
            .map(v => {
                let str
                if (typeof v === "object") {
                    try {
                        str = JSON.stringify(v);
                    } catch (e) {
                        // will convert to simple String
                    }
                }
                if (!str) {
                    str = String(v)
                }
                return str
            })
            .map(v => v.substring(0, 3000)) // Limit msg to 3000 chars
            .join(", ")}`
    )
}

let originalLog = console.log
let originalWarn = console.warn
let originalError = console.error
let originalDebug = console.debug

console.log = function () {
    log("📗", "log", arguments);
    originalLog.apply(null, arguments)
}
console.warn = function () {
    log("📙", "warning", arguments);
    originalWarn.apply(null, arguments)
}
console.error = function () {
    log("📕", "error", arguments);
    originalError.apply(null, arguments)
}
console.debug = function () {
    log("📘", "debug", arguments);
    originalDebug.apply(null, arguments)
}

window.addEventListener("error", function (e) {
    log("💥", "Uncaught", [`${e.message} at ${e.filename}:${e.lineno}:${e.colno}: ${JSON.stringify(e.error)}`])
})
