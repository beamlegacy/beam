"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.Native = void 0;
class Native {
    /**
     * @param win {BeamWindow}
     */
    constructor(win, componentPrefix) {
        this.win = win;
        this.href = win.location.href;
        this.componentPrefix = componentPrefix;
        this.messageHandlers = win.webkit && win.webkit.messageHandlers;
        if (!this.messageHandlers) {
            throw Error("Could not find webkit message handlers");
        }
    }
    /**
     * @param win {BeamWindow}
     */
    static getInstance(win, componentPrefix) {
        if (!Native.instance) {
            Native.instance = new Native(win, componentPrefix);
        }
        return Native.instance;
    }
    /**
     * Message to the native part.
     *
     * @param name {string} Message name.
     *        Will be converted to ${prefix}_beam_${name} before sending.
     * @param payload {MessagePayload} The message data.
     *        An "href" property will always be added as the base URI of the current frame.
     */
    sendMessage(name, payload) {
        const messageKey = `${this.componentPrefix}_${name}`;
        const messageHandler = this.messageHandlers[messageKey];
        if (messageHandler) {
            const href = this.win.location.href;
            messageHandler.postMessage(Object.assign({ href }, payload), href);
        }
        else {
            throw Error(`No message handler for message "${messageKey}"`);
        }
    }
    toString() {
        return this.constructor.name;
    }
}
exports.Native = Native;
//# sourceMappingURL=Native.js.map