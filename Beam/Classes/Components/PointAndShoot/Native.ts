import {BeamMessageHandler, BeamWindow} from "./BeamTypes";

export class Native {
  /**
   * @type Native
   */
  static instance: Native

  readonly origin: string;
  protected readonly messageHandlers: BeamMessageHandler[];

  /**
   * @param win {BeamWindow}
   */
  static getInstance(win: BeamWindow) {
    if (!Native.instance) {
      Native.instance = new Native(win)
    }
    return Native.instance
  }

  log(...args) {
    console.log(this.toString(), args)
  }

  /**
   * @param win {BeamWindow}
   */
  constructor(readonly win: BeamWindow) {
    this.origin = win.origin
    console.log("origin", this.origin)
    this.messageHandlers = win.webkit && win.webkit.messageHandlers
    if (!this.messageHandlers) {
      throw Error("Could not find webkit message handlers")
    }
    this.log(`${this.toString()} instantiated`)
  }

  /**
   * Message to the native part.
   *
   * @param name {string} Message name.
   *        Will be converted to ${prefix}_beam_${name} before sending.
   * @param payload {any} The message data.
   *        An "origin" property will always be added as the base URI of the current frame.
   */
  sendMessage(name: string, payload: {}) {
    this.log("sendMessage", name, payload)
    const messageKey = `pointAndShoot_${name}`
    const messageHandler = this.messageHandlers[messageKey]
    if (messageHandler) {
      const origin = this.origin
      messageHandler.postMessage({origin, ...payload}, origin)
    } else {
      throw Error(`No message handler for message "${name}"`)
    }
  }

  toString() {
    return this.constructor.name
  }
}
