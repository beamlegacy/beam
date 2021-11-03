import {BeamWindow, MessagePayload} from "./BeamTypes"

export class Native<M> {
  /**
   * Singleton
   */
  static instance: Native<any>

  readonly href: string
  readonly componentPrefix: string

  protected readonly messageHandlers: M

  /**
   * @param win {BeamWindow}
   */
  static getInstance<M>(win: BeamWindow<M>, componentPrefix: string): Native<M> {
    if (!Native.instance) {
      Native.instance = new Native<M>(win, componentPrefix)
    }
    return Native.instance
  }

  log(...args): void {
    console.log(this.toString(), args)
  }

  /**
   * @param win {BeamWindow}
   */
  constructor(readonly win: BeamWindow<M>, componentPrefix: string) {
    this.href = win.location.href
    this.componentPrefix = componentPrefix
    this.messageHandlers = win.webkit && win.webkit.messageHandlers as M
    if (!this.messageHandlers) {
      throw Error("Could not find webkit message handlers")
    }
    console.log(componentPrefix, `${this.toString()} instantiated ${componentPrefix} in ${this.href}`)
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
    const messageKey = `${this.componentPrefix}_${name}`
    const messageHandler = this.messageHandlers[messageKey]
    if (messageHandler) {
      const href = this.href
      messageHandler.postMessage({href, ...payload}, href)
    } else {
      throw Error(`No message handler for message "${messageKey}"`)
    }
  }

  toString(): string {
    return this.constructor.name
  }
}
