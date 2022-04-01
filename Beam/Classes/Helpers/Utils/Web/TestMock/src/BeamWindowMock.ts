import {
  BeamCrypto,
  BeamHTMLElement,
  BeamLocation,
  BeamMessageHandler,
  BeamVisualViewport,
  BeamWebkit,
  BeamWindow
} from "@beam/native-beamtypes"
import {BeamEventTargetMock} from "./BeamEventTargetMock"
import {BeamLocationMock} from "./BeamLocationMock"
import {BeamDocumentMock} from "./BeamDocumentMock"

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

export abstract class BeamWindowMock<M> extends BeamEventTargetMock implements BeamWindow<M> {

  visualViewport = new BeamVisualViewportMock()

  readonly document: BeamDocumentMock

  protected constructor(doc: BeamDocumentMock = new BeamDocumentMock(), location: BeamLocation = new BeamLocationMock()) {
    super()
    this.document = doc
    this.location = location
    this.visualViewport.scale = 1
  }
  scrollTo(xCoord: number, yCoord: number) {
    throw new Error("Method not implemented.")
  }
  onunload: () => void
  matchMedia(arg0: string) {}
  addListener: () => void
  crypto = new BeamCryptoMock()
  frameElement: any
  frames: any

  scroll(xCoord: number, yCoord: number): void {
    this.scrollX = xCoord
    this.scrollY = yCoord
  }

  webkit: BeamWebkit<M>

  abstract create(doc: BeamDocumentMock, location: BeamLocation): BeamWindowMock<M>

  getEventListeners(_win: BeamWindow<any>) {
    return this.eventListeners
  }

  getComputedStyle(el: BeamHTMLElement, pseudo?: string): CSSStyleDeclaration {
    if (pseudo) {
      throw new Error("getComputedStyle not implemented for pseudo elements")
    }
    return el.style
  }

  open(url?: string, name?: string, specs?: string, replace?: boolean): BeamWindow<M> | null {
    console.log(`opening ${url}`)
    return this.create(new BeamDocumentMock(), new BeamLocationMock({href: url}))
  }

  innerHeight
  innerWidth
  location
  origin
  scrollX = 0
  scrollY = 0
}
