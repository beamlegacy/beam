import {BeamDocument, BeamMessageHandler, BeamVisualViewport, BeamWindow} from "./BeamMocks"

class MessageHandlerMock extends BeamMessageHandler {
events = []
  postMessage(payload) {
    this.events.push({name: "postMessage", payload})
  }
}

export class TestWindow extends BeamWindow {

  visualViewport = new BeamVisualViewport()

  constructor(attributes = {}) {
    super()
    this.document = new BeamDocument()
    Object.assign(this, attributes)
    this.visualViewport.scale = 1
  }

  eventListeners = {}
  webkit = {
    messageHandlers: {
      beam_frameBounds: new MessageHandlerMock()
    }
  }


  getEventListeners() {
    return this.eventListeners
  }

  addEventListener(eventName, cb) {
    this.eventListeners[eventName] = cb
  }
}
