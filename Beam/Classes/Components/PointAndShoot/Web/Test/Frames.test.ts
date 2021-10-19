import {PointAndShoot} from "../PointAndShoot"
import {PointAndShootUIMock} from "./PointAndShootUIMock"
import {BeamWebFactoryMock} from "../../../../Helpers/Utils/Web/Test/Mock/BeamWebFactoryMock"
import {BeamMouseEvent} from "../../../../Helpers/Utils/Web/BeamMouseEvent"
import {BeamDocumentMock} from "../../../../Helpers/Utils/Web/Test/Mock/BeamDocumentMock"
import {BeamNamedNodeMap} from "../../../../Helpers/Utils/Web/BeamNamedNodeMap"
import {PNSWindowMock} from "./PointAndShoot.test"
import {PNSBeamHTMLIFrameElementMock} from "./PNSBeamHTMLIFrameElementMock"

/**
 * @param frameEls {BeamHTMLElement[]}
 * @return {{pns: PointAndShoot, testUI: PointAndShootUIMock}}
 */
function pointAndShootTestBed(frameEls = []): {pns: PointAndShoot, testUI: PointAndShootUIMock} {
  const testUI = new PointAndShootUIMock()
  const scrollData = {
    scrollWidth: 800, scrollHeight: 0,
    offsetWidth: 800, offsetHeight: 0,
    clientWidth: 800, clientHeight: 0
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
  const win = new PNSWindowMock(testDocument)
  win.scrollX = 0
  win.scrollY = 0
  PointAndShoot.instance = null  // Allow test suite to instantiate multiple PointAndShoots
  const pns = new PointAndShoot(win, testUI, new BeamWebFactoryMock())
  win.pns = pns

  // Check registered event listeners
  const eventListeners = win.getEventListeners(win)
  expect(eventListeners["mousemove"]).toBeDefined()
  expect(eventListeners["scroll"]).toBeDefined()

  // Check initial state
  expect(testUI.eventsCount).toBeGreaterThanOrEqual(1)
  expect(testUI.eventsCount).toEqual(6)
  expect(testUI.findEventByName("hasSelection")).toBeTruthy()
  expect(testUI.findEventByName("selectBounds")).toBeTruthy()
  expect(testUI.findEventByName("shootBounds")).toBeTruthy()
  expect(testUI.findEventByName("pointBounds")).toBeTruthy()
  expect(testUI.findEventByName("frames")).toBeTruthy()
  testUI.clearEvents()  // To ease further events counting
  return {pns, testUI: testUI}
}

test("single iframe point", () => {
  const iframe1El = new PNSBeamHTMLIFrameElementMock(new PNSWindowMock(), new BeamNamedNodeMap({
    src: "https://iframe1.com",
    width: 800,
    height: 600,
    clientLeft: 101,
    clientTop: 102
  }))
  const iframeEls = [iframe1El]
  const {pns: rootPns, testUI} = pointAndShootTestBed(iframeEls)

  const {pns: iframe1Pns, testUI: iframe1testUI} = pointAndShootTestBed()
  iframe1El.contentWindow = iframe1Pns.win
  {
    const outsideFrame1PointEvent = new BeamMouseEvent({
      name: "mousemove",
      target: iframe1El,
      altKey: true,
      clientX: 51,
      clientY: 52
    })
    rootPns.onMouseMove(outsideFrame1PointEvent)

    expect(testUI.eventsCount).toEqual(6)
    expect(testUI.findEventByName("pointBounds").pointTarget.element).toEqual(iframe1El)
  }
  {
    const insideFrame1PointEvent = new BeamMouseEvent({
      name: "mousemove",
      target: iframe1El,
      altKey: true,
      clientX: 61,
      clientY: 62
    })
    iframe1Pns.onMouseMove(insideFrame1PointEvent)
    
    expect(testUI.eventsCount).toEqual(6)
    expect(testUI.findEventByName("pointBounds").pointTarget.element).toEqual(iframe1El)

    const delta = 50
    iframe1El.scrollY(delta)
    
    expect(iframe1testUI.eventsCount).toEqual(12) // aka 2 document events
  }
})
