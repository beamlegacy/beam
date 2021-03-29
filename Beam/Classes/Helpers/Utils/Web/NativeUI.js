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
    const bounds = el.getBoundingClientRect()
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
        x: bounds.x,
        y: bounds.y,
        width: bounds.width,
        height: bounds.height
      }
    }
    this.sendMessage("point", pointPayload)
  }

  shootMessage(el, x, y) {
    const bounds = el.getBoundingClientRect()
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
        x: bounds.x,
        y: bounds.y,
        width: bounds.width,
        height: bounds.height
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

  removeSelected(el) {
    // TODO: message to un-shoot
  }

  submit(selected) {
    for (const s of selected) {
      s.dataset[this.datasetKey] = JSON.stringify(this.selectedCard)
    }
    this.hidePopup()
  }

  showPopup(el, x, y, selected) {
    // TODO: Send popup message?
  }

  hidePopup() {
    // TODO: Hide popup message?
  }

  shoot(el, x, y, selected, submitCb) {
    this.shootMessage(el, x, y)
    this.hidePopup()  // Hide previous, if any
    this.showPopup(el, x, y, selected)
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

  selectAreas(i, selectedText, selectedHTML, textAreas) {
    // TODO: Throttle
    this.sendMessage("textSelected", {index: i, text: selectedText, html: selectedHTML, areas: textAreas})
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
