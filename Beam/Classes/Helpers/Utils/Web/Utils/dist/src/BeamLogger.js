"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.BeamLogger = void 0;
const native_beamtypes_1 = require("@beam/native-beamtypes");
class BeamLogger {
    constructor(win, category) {
        const componentPrefix = "beam_logger";
        this.native = new native_beamtypes_1.Native(win, componentPrefix);
        this.category = category;
    }
    log(...args) {
        const formattedMessage = this.convertArgsToMessage(args);
        this.sendMessage(formattedMessage, native_beamtypes_1.BeamLogLevel.log);
    }
    logWarning(...args) {
        const formattedMessage = this.convertArgsToMessage(args);
        this.sendMessage(formattedMessage, native_beamtypes_1.BeamLogLevel.warning);
    }
    logDebug(...args) {
        const formattedMessage = this.convertArgsToMessage(args);
        this.sendMessage(formattedMessage, native_beamtypes_1.BeamLogLevel.debug);
    }
    logError(...args) {
        const formattedMessage = this.convertArgsToMessage(args);
        this.sendMessage(formattedMessage, native_beamtypes_1.BeamLogLevel.error);
    }
    sendMessage(message, level) {
        this.native.sendMessage("log", {
            message,
            level,
            category: this.category
        });
    }
    convertArgsToMessage(args) {
        const messageArgs = Object.values(args).map((value) => {
            let str;
            if (typeof value === "object") {
                try {
                    str = JSON.stringify(value);
                }
                catch (error) {
                    console.error(error);
                }
            }
            if (!str) {
                str = String(value);
            }
            return str;
        });
        return messageArgs
            .map((v) => v.substring(0, 3000)) // Limit msg to 3000 chars
            .join(", ");
    }
}
exports.BeamLogger = BeamLogger;
//# sourceMappingURL=BeamLogger.js.map