function beamLog(type, args) {
  const messageArgs = Object.values(args)
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
  const message = messageArgs
      .map(v => v.substring(0, 3000)) // Limit msg to 3000 chars
      .join(", ")
  window.webkit.messageHandlers.beam_logging.postMessage({type, message})
}

let originalLog = console.log
let originalWarn = console.warn
let originalError = console.error
let originalDebug = console.debug

console.log = function () {
    beamLog("log", arguments);
    originalLog.apply(null, arguments)
}
console.warn = function () {
    beamLog("warning", arguments);
    originalWarn.apply(null, arguments)
}
console.error = function () {
    beamLog("error", arguments);
    originalError.apply(null, arguments)
}
console.debug = function () {
    beamLog("debug", arguments);
    originalDebug.apply(null, arguments)
}

window.addEventListener("error",  (e) => {
    beamLog("uncaught", [`${e.message} at ${e.filename}:${e.lineno}:${e.colno}: ${JSON.stringify(e.error.stack)}`])
})
