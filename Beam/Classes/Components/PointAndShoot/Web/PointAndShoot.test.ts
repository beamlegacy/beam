import { BeamRange } from "./BeamTypes"
import { PointAndShoot } from "./PointAndShoot"
import {
  BeamDocumentMock,
  BeamHTMLElementMock, BeamHTMLInputElementMock, BeamHTMLTextAreaElementMock,
  BeamKeyEvent,
  BeamMouseEvent,
  BeamRangeMock,
  BeamSelectionMock
} from "./Test/BeamMocks"
import { BeamWindowMock } from "./Test/BeamWindowMock"
import { PointAndShootUIMock } from "./Test/PointAndShootUIMock"
import { BeamWebFactoryMock } from "./Test/BeamWebFactoryMock"
import { BeamElementHelper } from "./BeamElementHelper"

/**
 * @param frameEls {BeamHTMLElement[]}
 * @param documentAttributes {{}}
 * @return {{pns: PointAndShoot, testUI: PointAndShootUIMock}}
 */
function pointAndShootTestBed(frameEls = [], documentAttributes = {}) {
  const testUI = new PointAndShootUIMock()
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
    },
    querySelector: (_selector) => {
      return
    },
    ...documentAttributes
  })
  const win = new BeamWindowMock(testDocument)
  PointAndShoot.instance = null // Allow test suite to instantiate multiple PointAndShoots
  const pns = new PointAndShoot(win, testUI, new BeamWebFactoryMock())

  // Check registered event listeners
  const eventListeners = win.getEventListeners(win)
  expect(eventListeners["mousemove"]).toBeDefined()
  expect(eventListeners["scroll"]).toBeDefined()

  // Check initial state
  expect(testUI.eventsCount).toBeGreaterThanOrEqual(1)
  testUI.clearEvents() // To ease further events counting
  return { pns, testUI }
}

function createRange(): BeamRange {
  const { pns } = pointAndShootTestBed()
  const range = new BeamRangeMock()
  const node = pns.win.document.createElement("div")
  range.setStart(node, 2)
  range.setEnd(node, 3)
  return range
}

test("mouse move without Option", () => {
  // Note: option isn't taken into account on the JS side anymore
  const { pns, testUI } = pointAndShootTestBed()
  const hoveredElement = new BeamHTMLElementMock("p")
  hoveredElement.bounds = {
    width: 130,
    height: 120,
    x: 11,
    y: 12
  }
  hoveredElement.width = 130
  hoveredElement.height = 120
  const pointEvent = new BeamMouseEvent({ name: "mousemove", target: hoveredElement, clientX: 101, clientY: 102 })
  pns.onMouseMove(pointEvent)
  expect(testUI.eventsCount).toEqual(5)
  expect(testUI.findEventByName("hasSelection")).toEqual({ name: "hasSelection", hasSelection: false })
  expect(testUI.findEventByName("selectBounds")).toEqual({ name: "selectBounds", rangeGroups: [] })
  expect(testUI.findEventByName("shootBounds")).toEqual({ name: "shootBounds", shootTargets: [] })
  expect(testUI.findEventByName("pointBounds")).toBeTruthy()
  expect(testUI.findEventByName("frames")).toBeTruthy()
})

test("point with mouse move + Option", () => {
  // Note: option isn't taken into account on the JS side anymore
  const { pns, testUI } = pointAndShootTestBed()
  const pointedElement = new BeamHTMLElementMock("p")
  pointedElement.bounds = {
    width: 130,
    height: 120,
    x: 11,
    y: 12
  }
  pointedElement.width = 130
  pointedElement.height = 120

  const pointEvent = new BeamMouseEvent({
    name: "mousemove",
    target: pointedElement,
    altKey: true,
    clientX: 101,
    clientY: 102
  })
  pns.onMouseMove(pointEvent)

  expect(testUI.eventsCount).toEqual(5)
  const testEvent = testUI.findEventByName("pointBounds")
  expect(testEvent.pointTarget.element).toEqual(pointedElement)
})

test("point with mouse move + Option should be allowed on unfocused input elements", () => {
  const { pns, testUI } = pointAndShootTestBed()
  const pointedElement = new BeamHTMLInputElementMock("input")
  pointedElement.bounds = {
    width: 130,
    height: 120,
    x: 11,
    y: 12
  }
  pointedElement.width = 130
  pointedElement.height = 120

  const pointEvent = new BeamMouseEvent({
    name: "mousemove",
    target: pointedElement,
    altKey: true,
    clientX: 101,
    clientY: 102
  })
  pns.onMouseMove(pointEvent)

  expect(testUI.eventsCount).toEqual(5)
  const testEvent = testUI.findEventByName("pointBounds")
  expect(testEvent.pointTarget.element).toEqual(pointedElement)
})

const textualInputTypes = [
  "text", "email", "password",
  "date", "datetime-local", "month",
  "number", "search", "tel",
  "time", "url", "week",
  // for legacy support
  "datetime"
]

test.each(textualInputTypes)(
  "point with mouse move + Option should be prevented on active textual inputs",
  (type) => {
    const pointedElement = new BeamHTMLInputElementMock("input", {type: type})
    pointedElement.bounds = {
      width: 130,
      height: 120,
      x: 11,
      y: 12
    }
    pointedElement.width = 130
    pointedElement.height = 120
    const { pns, testUI } = pointAndShootTestBed([], {activeElement: pointedElement})

    const pointEvent = new BeamMouseEvent({
      name: "mousemove",
      target: pointedElement,
      altKey: true,
      clientX: 101,
      clientY: 102
    })
    pns.onMouseMove(pointEvent)

    expect(pointedElement.contains(pointedElement)).toEqual(true)
    expect(pointedElement.tagName).toEqual("input")
    expect(BeamElementHelper.getType(pointedElement)).toEqual(type)

    // expect no event on active text inputs
    expect(testUI.eventsCount).toEqual(0)
  }
)

test("point with mouse move + Option should be prevented on active text inputs", () => {
  const pointedElement = new BeamHTMLInputElementMock("input", {type: "text"})
  pointedElement.bounds = {
    width: 130,
    height: 120,
    x: 11,
    y: 12
  }
  pointedElement.width = 130
  pointedElement.height = 120
  const { pns, testUI } = pointAndShootTestBed([], {activeElement: pointedElement})

  const pointEvent = new BeamMouseEvent({
    name: "mousemove",
    target: pointedElement,
    altKey: true,
    clientX: 101,
    clientY: 102
  })
  pns.onMouseMove(pointEvent)

  expect(pointedElement.contains(pointedElement)).toEqual(true)
  expect(pointedElement.tagName).toEqual("input")
  expect(BeamElementHelper.getType(pointedElement)).toEqual("text")

  // expect no event on active text inputs
  expect(testUI.eventsCount).toEqual(0)
})

test("point with mouse move + Option should be prevented on active textarea", () => {
  const pointedElement = new BeamHTMLTextAreaElementMock("textarea")
  pointedElement.bounds = {
    width: 130,
    height: 120,
    x: 11,
    y: 12
  }
  pointedElement.width = 130
  pointedElement.height = 120
  const { pns, testUI } = pointAndShootTestBed([], {activeElement: pointedElement})

  const pointEvent = new BeamMouseEvent({
    name: "mousemove",
    target: pointedElement,
    altKey: true,
    clientX: 101,
    clientY: 102
  })
  pns.onMouseMove(pointEvent)

  expect(pointedElement.contains(pointedElement)).toEqual(true)
  expect(pointedElement.tagName).toEqual("textarea")

  // expect no event on active text inputs
  expect(testUI.eventsCount).toEqual(0)
})

test("point with mouse move + Option should be prevented on active contentEditable element", () => {
  const pointedElement = new BeamHTMLElementMock("div", {contenteditable: "true"})
  pointedElement.bounds = {
    width: 130,
    height: 120,
    x: 11,
    y: 12
  }
  pointedElement.width = 130
  pointedElement.height = 120
  const { pns, testUI } = pointAndShootTestBed([], {activeElement: pointedElement})

  const pointEvent = new BeamMouseEvent({
    name: "mousemove",
    target: pointedElement,
    altKey: true,
    clientX: 101,
    clientY: 102
  })
  pns.onMouseMove(pointEvent)

  expect(pointedElement.contains(pointedElement)).toEqual(true)
  expect(pointedElement.tagName).toEqual("div")
  expect(BeamElementHelper.getContentEditable(pointedElement)).toEqual("true")


  // expect no event on active text inputs
  expect(testUI.eventsCount).toEqual(0)
})

test("point with mouse move + Option should be prevented on elements nested within an active contentEditable element", () => {
  const parent = new BeamHTMLElementMock("div", {contenteditable: "true"})
  const pointedElement = new BeamHTMLElementMock("p")
  pointedElement.bounds = {
    width: 130,
    height: 120,
    x: 11,
    y: 12
  }
  pointedElement.width = 130
  pointedElement.height = 120
  parent.appendChild(pointedElement)

  expect(pointedElement.parentElement).toEqual(parent)
  expect(parent.contains(pointedElement)).toEqual(true)
  expect(BeamElementHelper.getContentEditable(pointedElement)).toEqual("inherit")
  expect(BeamElementHelper.getContentEditable(parent)).toEqual("true")

  const { pns, testUI } = pointAndShootTestBed([], {activeElement: parent})
  const pointEvent = new BeamMouseEvent({
    name: "mousemove",
    target: pointedElement,
    altKey: true,
    clientX: 101,
    clientY: 102
  })
  pns.onMouseMove(pointEvent)

  expect(pointedElement.contains(pointedElement)).toEqual(true)
  expect(pointedElement.tagName).toEqual("p")


  expect(BeamElementHelper.getContentEditable(pointedElement.parentElement)).toEqual("true")
  expect(BeamElementHelper.getContentEditable(pointedElement)).toEqual("inherit")
  // expect no event on active text inputs
  expect(testUI.eventsCount).toEqual(0)
})

test("mouse move + Option then click on an arbitrary input element should not shoot", () => {
  const pointedElement = new BeamHTMLInputElementMock("input", {type: "text"})
  pointedElement.bounds = {
    width: 130,
    height: 120,
    x: 11,
    y: 12
  }
  pointedElement.width = 130
  pointedElement.height = 120

  const { pns, testUI } = pointAndShootTestBed([], {activeElement: pointedElement})

  const pointEvent = new BeamMouseEvent({
    name: "mousemove",
    target: pointedElement,
    altKey: true,
    clientX: 101,
    clientY: 102
  })
  pns.onMouseMove(pointEvent)
  const clickEvent = new BeamMouseEvent({
    name: "mouseclick",
    target: pointedElement,
    altKey: true,
    clientX: 101,
    clientY: 102
  })
  pns.onClick(clickEvent)


  // expect no event on active text inputs
  expect(testUI.eventsCount).toEqual(0)
})

test("point with Option key down then mouse move", () => {
  const { pns, testUI } = pointAndShootTestBed()

  const keyEvent = new BeamKeyEvent({ key: "Alt" })
  pns.onKeyDown(keyEvent)

  const pointedElement = new BeamHTMLElementMock("p")
  pointedElement.bounds = {
    width: 130,
    height: 120,
    x: 11,
    y: 12
  }
  pointedElement.width = 130
  pointedElement.height = 120
  const pointEvent = new BeamMouseEvent({
    name: "mousemove",
    target: pointedElement,
    altKey: true,
    clientX: 101,
    clientY: 102
  })
  pns.onMouseMove(pointEvent)

  expect(testUI.eventsCount).toEqual(15) // aka 3 document events
  expect(testUI.findEventByName("hasSelection")).toEqual({ name: "hasSelection", hasSelection: false })
  expect(testUI.findEventByName("selectBounds")).toEqual({ name: "selectBounds", rangeGroups: [] })
  expect(testUI.findEventByName("shootBounds")).toEqual({ name: "shootBounds", shootTargets: [] })
  expect(testUI.findEventByName("pointBounds")).toBeTruthy()
  expect(testUI.findEventByName("frames")).toBeTruthy()
})

test("getSelectionRanges should return the number of available ranges", () => {
  const { pns } = pointAndShootTestBed()

  const selection = new BeamSelectionMock("p")
  selection.addRange(createRange())
  selection.addRange(createRange())
  selection.addRange(createRange())
  selection.addRange(createRange())
  const ranges = pns.getSelectionRanges(selection)

  expect(ranges.length).toEqual(4)
})

test("onSelection should create selection event in testUI", () => {
  const { pns, testUI } = pointAndShootTestBed()
  // grab empty selection instance from the document
  const selection = pns.win.document.getSelection()
  // manually init selection with selection range
  const range = new BeamRangeMock()
  const node = pns.win.document.createElement("div")
  range.setStart(node, 2)
  range.setEnd(node, 3)
  selection.addRange(range)
  // run onSelection event
  pns.onSelection()
  // expect:
  expect(testUI.eventsCount).toEqual(5)
  expect(testUI.findEventByName("selectBounds").rangeGroups.length).toEqual(1)
})
