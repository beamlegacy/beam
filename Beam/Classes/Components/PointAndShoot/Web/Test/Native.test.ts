import {Native} from "../../../../Helpers/Utils/Web/Native"
import {BeamLocationMock} from "../../../../Helpers/Utils/Web/Test/Mock/BeamLocationMock"
import {BeamDocumentMock} from "../../../../Helpers/Utils/Web/Test/Mock/BeamDocumentMock"
import { PNSWindowMock } from "./PNSWindowMock"
import { BeamHTMLIFrameElementMock } from "../../../../Helpers/Utils/Web/Test/Mock/BeamHTMLIFrameElementMock"

jest.mock("debounce", () => ({
  debounce: jest.fn(fn => {
    return fn()
  })
}))

/**
 *
 * @param href {string}
 * @param frameEls {BeamHTMLElement[]}
 * @return {BeamWindowMock}
 */
function nativeTestBed(href, frameEls = []) {
  const scrollData = {
    scrollWidth: 800,
    scrollHeight: 0,
    offsetWidth: 800,
    offsetHeight: 0,
    clientWidth: 800,
    clientHeight: 0
  }
  const styleData = {
    style: {
      zoom: "1"
    }
  }
  const testDocument = new BeamDocumentMock({
    body: {
      ...styleData,
      ...scrollData
    },
    documentElement: scrollData,
    querySelectorAll: (selector) => {
      if (selector === "iframe") {
        return frameEls
      }
    }
  })
  const windowMock = new PNSWindowMock(testDocument, new BeamLocationMock({href}))
  windowMock.scroll(0, 0)
  return windowMock
}

test("send frame href in message", () => {
  const mainWindow = new PNSWindowMock()
  const iframe1 = new BeamHTMLIFrameElementMock(mainWindow)
  Object.assign(iframe1, {
    src: "https://iframe1.com/about-us.html",
    clientLeft: 101,
    clientTop: 102,
    width: 800,
    height: 600
  })
  const iframes = [iframe1]
  const win = nativeTestBed(iframe1.src, iframes)
  const native = new Native(win, "pointAndShoot")
  expect(native.href).toEqual(iframe1.src)

  const frameInfo = {href: iframe1.src, bounds: {x: iframe1.clientLeft, y: iframe1.clientTop, width: iframe1.width}}
  native.sendMessage("frameBounds", frameInfo)
  const mockMessageHandlers = win.webkit.messageHandlers
  expect(mockMessageHandlers).toEqual({"pointAndShoot_frameBounds": {
    "events": [{
      name: "postMessage",
      payload: {...frameInfo, href: iframe1.src}
    }]
  }})
})
