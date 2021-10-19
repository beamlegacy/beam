import {BeamWindow, MessagePayload} from "./BeamTypes"

export class Native<M> {
  /**
   * Singleton
   */
  static instance: Native<any>

  readonly href: string

  protected readonly messageHandlers: M

  /**
   * @param win {BeamWindow}
   */
  static getInstance<M>(win: BeamWindow<M>): Native<M> {
    if (!Native.instance) {
      Native.instance = new Native<M>(win)
    }
    return Native.instance
  }

  log(...args): void {
    console.log(this.toString(), args)
  }

  /**
   * @param win {BeamWindow}
   */
  constructor(readonly win: BeamWindow<M>) {
    this.href = win.location.href
    console.log("href", this.href)
    this.messageHandlers = win.webkit && win.webkit.messageHandlers as M
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
