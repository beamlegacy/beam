import {BeamBody, BeamDocument, BeamMessageHandler, BeamVisualViewport, BeamWindow} from "../BeamTypes"
import {BeamDocumentMock} from "./BeamMocks";

export class MessageHandlerMock implements BeamMessageHandler {
  events = []

  postMessage(payload) {
    this.events.push({name: "postMessage", payload})
  }
}

export class BeamVisualViewportMock implements BeamVisualViewport {
  height;
  offsetLeft;
  offsetTop;
  pageLeft;
  pageTop;
  scale;
  width;

  addEventListener(name, cb) {
  }
}

export class TestWindow implements BeamWindow {

  visualViewport = new BeamVisualViewportMock()
  readonly document: BeamDocument;

  constructor(attributes = {}) {
    this.document = new BeamDocumentMock()
    Object.assign(this, attributes)
    this.visualViewport.scale = 1
  }

  eventListeners = {}

  webkit = {
    messageHandlers: {
      pointAndShoot_frameBounds: new MessageHandlerMock()
    }
  }

  getEventListeners(win: BeamWindow) {
    return this.eventListeners
  }

  addEventListener(eventName, cb) {
    this.eventListeners[eventName] = cb
  }

  innerHeight;
  innerWidth;
  location;
  origin;
  scrollX;
  scrollY;
}
