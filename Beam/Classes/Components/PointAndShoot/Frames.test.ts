import {PointAndShoot} from "./PointAndShoot"
import {BeamDocumentMock, BeamHTMLIFrameElementMock, BeamMouseEvent, BeamNamedNodeMap} from "./Test/BeamMocks"
import {BeamWindowMock} from "./Test/BeamWindowMock"
import {PointAndShootUIMock} from "./Test/PointAndShootUIMock"

/**
 * @param frameEls {BeamHTMLElement[]}
 * @return {{pns: PointAndShoot, testUI: PointAndShootUIMock}}
 */
function pointAndShootTestBed(frameEls = []): {pns: PointAndShoot, testUI: PointAndShootUIMock} {
  const testUi = new PointAndShootUIMock()
  const scrollData = {
    scrollWidth: 800, scrollHeight: 0,
    offsetWidth: 800, offsetHeight: 0,
    clientWidth: 800, clientHeight: 0
  }
  const styleData = {
    style: {
      zoom: 1
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
  const win = new BeamWindowMock(testDocument)
  win.scrollX = 0
  win.scrollY = 0
  PointAndShoot.instance = null  // Allow test suite to instantiate multiple PointAndShoots
  const pns = new PointAndShoot(win, testUi)
  win.pns = pns

  // Check registered event listeners
  const eventListeners = win.getEventListeners(win)
  expect(eventListeners["mousemove"]).toBeDefined()
  expect(eventListeners["scroll"]).toBeDefined()

  // Check initial state
  expect(pns.status === "none")
  expect(testUi.eventsCount).toBeGreaterThanOrEqual(1)
  expect(testUi.events[0]).toEqual({name: "scroll", x: 0, y: 0, width: 800, height: 0, scale: 1})
  testUi.clearEvents()  // To ease further events counting
  return {pns, testUI: testUi}
}

test("single iframe point", () => {
  const iframe1El = new BeamHTMLIFrameElementMock(new BeamNamedNodeMap({
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

    expect(rootPns.isPointing()).toEqual(true)
    expect(testUI.eventsCount).toEqual(3)
    expect(testUI.events[0]).toEqual({name: "setStatus", status: "pointing"})
    expect(testUI.events[1]).toEqual({name: "point", el: iframe1El, x: 51, y: 52})
    expect(testUI.events[2]).toEqual("hideStatus")
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

    expect(iframe1Pns.isPointing()).toEqual(true)
    expect(iframe1testUI.eventsCount).toEqual(3)
    expect(iframe1testUI.events[0]).toEqual({name: "setStatus", status: "pointing"})
    expect(iframe1testUI.events[1]).toEqual({name: "point", el: iframe1El, x: 61, y: 62})
    expect(testUI.events[2]).toEqual("hideStatus")

    const delta = 50
    iframe1El.scrollY(delta)
    expect(iframe1testUI.eventsCount).toEqual(4)
    const iframe1Body = iframe1Pns.win.document.body
    expect(iframe1testUI.events[3]).toEqual({
      name: "scroll",
      x: 0,
      y: delta,
      width: iframe1Body.scrollWidth,
      height: iframe1Body.scrollHeight,
      scale: 1
    })
  }
})
