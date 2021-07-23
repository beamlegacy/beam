import {BeamMessageHandler, BeamWindow, MessagePayload} from "./BeamTypes"

export class Native {
  /**
   * Singleton
   */
  static instance: Native

  readonly href: string

  protected readonly messageHandlers: {
    [name: string]: BeamMessageHandler
  }

  /**
   * @param win {BeamWindow}
   */
  static getInstance(win: BeamWindow): Native {
    if (!Native.instance) {
      Native.instance = new Native(win)
    }
    return Native.instance
  }

  log(...args): void {
    console.log(this.toString(), args)
  }

  /**
   * @param win {BeamWindow}
   */
  constructor(readonly win: BeamWindow) {
    this.href = win.location.href
    console.log("href", this.href)
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
   * @param payload {MessagePayload} The message data.
   *        An "href" property will always be added as the base URI of the current frame.
   */
  sendMessage(name: string, payload: MessagePayload): void {
    const messageKey = `pointAndShoot_${name}`
    const messageHandler = this.messageHandlers[messageKey]
    if (messageHandler) {
      const href = this.href
      messageHandler.postMessage({href, ...payload}, href)
    } else {
      throw Error(`No message handler for message "${name}"`)
    }
  }

  toString(): string {
    return this.constructor.name
  }
}
