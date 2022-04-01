import {PointAndShoot} from "../src/PointAndShoot"
import {PointAndShootUIMock} from "./PointAndShootUIMock"
import {BeamDocumentMock, BeamHTMLIFrameElementMock} from "@beam/native-testmock"
import {BeamMouseEvent} from "@beam/native-beamtypes"
import { PNSWindowMock } from "./PNSWindowMock"

jest.mock("debounce", () => ({
  debounce: jest.fn(fn => {
    return fn()
  })
}))

const SENDBOUNDS_EVENTS = 5

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
  const pns = new PointAndShoot(win, testUI)
  win.pns = pns

  // Check registered event listeners
  const eventListeners = win.getEventListeners(win)
  expect(eventListeners["mousemove"]).toBeDefined()
  expect(eventListeners["scroll"]).toBeDefined()

  // Check initial state
  expect(testUI.eventsCount).toEqual(SENDBOUNDS_EVENTS*3)
  return {pns, testUI: testUI}
}

test("single iframe point", () => {
  const iframe1El = new BeamHTMLIFrameElementMock(new PNSWindowMock())
  iframe1El.src = "https://iframe1.com"
  iframe1El.width = 800
  iframe1El.height = 600
  iframe1El.clientLeft = 101
  iframe1El.clientTop = 102
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

    expect(testUI.eventsCount).toEqual(SENDBOUNDS_EVENTS*4)
    // Get all pointBound events and filter out those with undefined targets
    const pointBoundsEvents = testUI.events.filter(event => {
      return event.name == "pointBounds" && Boolean(event.pointTarget)
    })
    expect(pointBoundsEvents.length).toEqual(1)
    expect(pointBoundsEvents[0].pointTarget.element).toEqual(iframe1El)
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
    
    expect(testUI.eventsCount).toEqual(SENDBOUNDS_EVENTS*4)
    // Get all pointBound events and filter out those with undefined targets
    const pointBoundsEvents = testUI.events.filter(event => {
      return event.name == "pointBounds" && Boolean(event.pointTarget)
    })
    expect(pointBoundsEvents.length).toEqual(1)
    expect(pointBoundsEvents[0].pointTarget.element).toEqual(iframe1El)

    const delta = 50
    iframe1El.scrollY(delta)
    
    expect(iframe1testUI.eventsCount).toEqual(SENDBOUNDS_EVENTS*4)
  }
})