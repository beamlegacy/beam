import {
    BeamCrypto,
  BeamDocument,
  BeamHTMLElement,
  BeamLocation,
  BeamMessageHandler,
  BeamVisualViewport,
  BeamWindow
} from "../BeamTypes"
import {BeamDocumentMock, BeamLocationMock} from "./BeamMocks"
import {PointAndShoot} from "../PointAndShoot"
import {BeamEventTargetMock} from "./BeamEventTargetMock"

export class MessageHandlerMock implements BeamMessageHandler {
  events = []

  postMessage(payload): void {
    this.events.push({name: "postMessage", payload})
  }
}

export class BeamVisualViewportMock extends BeamEventTargetMock implements BeamVisualViewport {
  height: number
  offsetLeft: number
  offsetTop: number
  pageLeft: number
  pageTop: number
  scale: number
  width: number
}

export class BeamCryptoMock implements BeamCrypto {
    getRandomValues(buffer: []) {
      // Really basic mock for getting random numbers
      return buffer.map(item => {
        return Math.floor(Math.random() * 9999999)
      })
    }
}

export class BeamWindowMock extends BeamEventTargetMock implements BeamWindow {
  visualViewport = new BeamVisualViewportMock()

  readonly document: BeamDocument
  pns: PointAndShoot

  constructor(document: BeamDocument = new BeamDocumentMock(), location: BeamLocation = new BeamLocationMock()) {
    super()
    this.document = document
    this.location = location
    this.visualViewport.scale = 1
  }
  crypto = new BeamCryptoMock()
  frameElement: any
  frames: any

  scroll(xCoord: number, yCoord: number): void {
    this.scrollX = xCoord
    this.scrollY = yCoord
  }

  webkit = {
    messageHandlers: {
      pointAndShoot_frameBounds: new MessageHandlerMock()
    }
  }

  getEventListeners(_win: BeamWindow) {
    return this.eventListeners
  }

  getComputedStyle(el: BeamHTMLElement, pseudo?: string): CSSStyleDeclaration {
    if (pseudo) {
      throw new Error("getComputedStyle not implemented for pseudo elements")
    }
    return el.style
  }

  innerHeight
  innerWidth
  location
  origin
  scrollX = 0
  scrollY = 0
}
