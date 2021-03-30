export class NativeUI {
  prefix = "__ID__"
  origin = document.body.baseURI

  constructor() {
    this.messageHandlers = window.webkit && window.webkit.messageHandlers
    if (!this.messageHandlers) {
      throw Error("Could not find webkit message handlers")
    }
    console.log(`${this} instantiated`)
  }

  toString() {
    return "NativeUI"
  }

  static getInstance() {
    let instance
    try {
      instance = new NativeUI()
    } catch (e) {
      console.error(e)
      instance = null
    }
    return instance
  }

  /**
   * Message to the native part.
   *
   * @param name Message name.
   *        Will be converted to ${prefix}_beam_${name} before sending.
   * @param payload The message data.
   *        An "origin" property will always be added as the base URI of the current frame.
   */
  sendMessage(name, payload) {
    console.log("sendMessage", name, payload)
    const messageKey = `beam_${name}`
    const messageHandler = this.messageHandlers[messageKey]
    if (messageHandler) {
      messageHandler.postMessage({origin, ...payload}, origin)
    } else {
      throw Error(`No message handler for message "${name}"`)
    }
  }

  pointMessage(el, x, y) {
    const pointBounds = el.getBoundingClientRect()
    const pointPayload = {
      origin,
      type: {
        tagName: el.tagName
      },
      location: {x, y},
      data: {
        text: el.innerText
      },
      area: {
        x: pointBounds.x,
        y: pointBounds.y,
        width: pointBounds.width,
        height: pointBounds.height
      }
    }
    this.sendMessage("point", pointPayload)
  }

  shootMessage(el, x, y) {
    const shootBounds = el.getBoundingClientRect()
    const shootMessage = {
      origin,
      type: {
        tagName: el.tagName
      },
      data: {
        text: el.innerText
      },
      location: {x, y},
      area: {
        x: shootBounds.x,
        y: shootBounds.y,
        width: shootBounds.width,
        height: shootBounds.height
      }
    }
    this.sendMessage("shoot", shootMessage)
  }

  point(el, x, y) {
    this.pointMessage(el, x, y)
  }

  unpoint() {
    this.sendMessage("point", null)
  }

  unshoot(el) {
    // TODO: message to un-shoot
  }

  hidePopup() {
    // TODO: Hide popup message?
  }

  shoot(el, x, y, selected, _submitCb) {
    /*
     * - Hide previous native popup if any
     * - Show native popup
     */
    this.shootMessage(el, x, y)
    // TODO: handle native popup result (probably not using submitCb, but rather through native explicitly invoking JS directly?)
  }

  /**
   * Show the if a given was added to a card.
   */
  showStatus(el, collected) {
    // TODO: Send message to display native status as "collected" data
  }

  hideStatus() {
    // TODO: Send message to hide native status display
  }

  enterSelection(scrollWidth) {
    // TODO: enter selction message
  }

  leaveSelection() {
    // TODO:
  }

  addTextSelection(selection) {
    // TODO: Throttle
    this.sendMessage("textSelection", selection)
  }

  textSelected(selection) {
    this.sendMessage("textSelected", selection)
  }

  setFramesInfos(framesInfo) {
    this.sendMessage("frameBounds", {frames: framesInfo})
  }

  setScrollInfo(scrollInfo) {
    this.sendMessage("onScrolled", scrollInfo)
  }

  setResizeInfo(resizeInfo, selected) {
    this.sendMessage("resize", resizeInfo)
    for (const someSelected of selected) {
      this.shootMessage(someSelected, -1, -1)
    }
  }
}
