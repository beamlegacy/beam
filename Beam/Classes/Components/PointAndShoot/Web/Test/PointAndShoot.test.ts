import {
  BeamRange} from "../../../../Helpers/Utils/Web/BeamTypes"
import { PointAndShoot } from "../PointAndShoot"
import { PointAndShootUIMock } from "./PointAndShootUIMock"
import { BeamElementHelper } from "../../../../Helpers/Utils/Web/BeamElementHelper"
import { BeamMouseEvent } from "../../../../Helpers/Utils/Web/BeamMouseEvent"
import { BeamKeyEvent } from "../../../../Helpers/Utils/Web/BeamKeyEvent"
import { BeamDocumentMock } from "../../../../Helpers/Utils/Web/Test/Mock/BeamDocumentMock"
import { BeamHTMLInputElementMock } from "../../../../Helpers/Utils/Web/Test/Mock/BeamHTMLInputElementMock"
import { BeamHTMLTextAreaElementMock } from "../../../../Helpers/Utils/Web/Test/Mock/BeamHTMLTextAreaElementMock"
import { BeamSelectionMock } from "../../../../Helpers/Utils/Web/Test/Mock/BeamSelectionMock"
import { BeamHTMLElementMock } from "../../../../Helpers/Utils/Web/Test/Mock/BeamHTMLElementMock"
import { BeamRangeMock } from "../../../../Helpers/Utils/Web/Test/Mock/BeamRangeMock"
import { PointAndShootHelper } from "../PointAndShootHelper"
import { PNSWindowMock } from "./PNSWindowMock"

jest.mock("debounce", () => ({
  debounce: jest.fn(fn => {
    return fn()
  })
}))

const SENDBOUNDS_EVENTS = 5

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
  const win = new PNSWindowMock(testDocument)
  PointAndShoot.instance = null // Allow test suite to instantiate multiple PointAndShoots
  const pns = new PointAndShoot(win, testUI)

  // Check registered event listeners
  const eventListeners = win.getEventListeners(win)
  expect(eventListeners["mousemove"]).toBeDefined()
  expect(eventListeners["scroll"]).toBeDefined()
  // Check initial state
  expect(testUI.eventsCount).toEqual(SENDBOUNDS_EVENTS*3)
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
  const pointEvent = new BeamMouseEvent({
    name: "mousemove",
    target: hoveredElement,
    clientX: 101,
    clientY: 102
  })
  pns.onMouseMove(pointEvent)
  expect(testUI.eventsCount).toEqual(0)
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

  expect(testUI.eventsCount).toEqual(SENDBOUNDS_EVENTS)
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

  expect(testUI.eventsCount).toEqual(SENDBOUNDS_EVENTS)
  const testEvent = testUI.findEventByName("pointBounds")
  expect(testEvent.pointTarget.element).toEqual(pointedElement)
})

const textualInputTypes = [
  "text",
  "email",
  "password",
  "date",
  "datetime-local",
  "month",
  "number",
  "search",
  "tel",
  "time",
  "url",
  "week",
  // for legacy support
  "datetime"
]

test.each(textualInputTypes)(
  "point with mouse move + Option should be prevented on active textual inputs",
  (type) => {
    const pointedElement = new BeamHTMLInputElementMock("input", {
      type: type
    })
    pointedElement.bounds = {
      width: 130,
      height: 120,
      x: 11,
      y: 12
    }
    pointedElement.width = 130
    pointedElement.height = 120
    const { pns, testUI } = pointAndShootTestBed([], {
      activeElement: pointedElement
    })

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

    // expect events on active text inputs, but no shootTargets added
    expect(testUI.eventsCount).toEqual(SENDBOUNDS_EVENTS)
    expect(pns.shootTargets.length).toEqual(0)
    expect(pns.selectionRangeGroups.length).toEqual(0)
  }
)

test("point with mouse move + Option should be prevented on active text inputs", () => {
  const pointedElement = new BeamHTMLInputElementMock("input", {
    type: "text"
  })
  pointedElement.bounds = {
    width: 130,
    height: 120,
    x: 11,
    y: 12
  }
  pointedElement.width = 130
  pointedElement.height = 120
  const { pns, testUI } = pointAndShootTestBed([], {
    activeElement: pointedElement
  })

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

  // expect events on active text inputs, but no shootTargets added
  expect(testUI.eventsCount).toEqual(SENDBOUNDS_EVENTS)
  expect(pns.shootTargets.length).toEqual(0)
  expect(pns.selectionRangeGroups.length).toEqual(0)
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
  const { pns, testUI } = pointAndShootTestBed([], {
    activeElement: pointedElement
  })

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

  // expect events on active text inputs, but no shootTargets added
  expect(testUI.eventsCount).toEqual(SENDBOUNDS_EVENTS)
  expect(pns.shootTargets.length).toEqual(0)
  expect(pns.selectionRangeGroups.length).toEqual(0)
})

test("point with mouse move + Option should be prevented on active contentEditable element", () => {
  const pointedElement = new BeamHTMLElementMock("div", {
    contenteditable: "true"
  })
  pointedElement.bounds = {
    width: 130,
    height: 120,
    x: 11,
    y: 12
  }
  pointedElement.width = 130
  pointedElement.height = 120
  const { pns, testUI } = pointAndShootTestBed([], {
    activeElement: pointedElement
  })

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

  // expect events on active text inputs, but no shootTargets added
  expect(testUI.eventsCount).toEqual(SENDBOUNDS_EVENTS)
  expect(pns.shootTargets.length).toEqual(0)
  expect(pns.selectionRangeGroups.length).toEqual(0)
})

test("point with mouse move + Option should be prevented on elements nested within an active contentEditable element", () => {
  const parent = new BeamHTMLElementMock("div", { contenteditable: "true" })
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
  expect(BeamElementHelper.getContentEditable(pointedElement)).toEqual(
    "inherit"
  )
  expect(BeamElementHelper.getContentEditable(parent)).toEqual("true")

  const { pns, testUI } = pointAndShootTestBed([], { activeElement: parent })
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

  expect(
    BeamElementHelper.getContentEditable(pointedElement.parentElement)
  ).toEqual("true")
  expect(BeamElementHelper.getContentEditable(pointedElement)).toEqual(
    "inherit"
  )
  // expect events on active text inputs, but no shootTargets added
  expect(testUI.eventsCount).toEqual(SENDBOUNDS_EVENTS)
  expect(pns.shootTargets.length).toEqual(0)
  expect(pns.selectionRangeGroups.length).toEqual(0)
})

test("mouse move + Option then click on an arbitrary input element should not shoot", () => {
  const pointedElement = new BeamHTMLInputElementMock("input", {
    type: "text"
  })
  pointedElement.bounds = {
    width: 130,
    height: 120,
    x: 11,
    y: 12
  }
  pointedElement.width = 130
  pointedElement.height = 120

  const { pns, testUI } = pointAndShootTestBed([], {
    activeElement: pointedElement
  })

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

  // expect events on active text inputs, but no shootTargets added
  expect(testUI.eventsCount).toEqual(SENDBOUNDS_EVENTS * 2)
  expect(pns.shootTargets.length).toEqual(0)
  expect(pns.selectionRangeGroups.length).toEqual(0)
})

test("point with Option key down then mouse move", () => {
  const pointedElement = new BeamHTMLElementMock("p")
  pointedElement.bounds = {
    width: 130,
    height: 120,
    x: 11,
    y: 12
  }
  pointedElement.width = 130
  pointedElement.height = 120

  const { pns, testUI } = pointAndShootTestBed([], {
    activeElement: pointedElement
  })

  const keyEvent = new BeamKeyEvent({ key: "Alt" })
  pns.onKeyDown(keyEvent)

  const pointEvent = new BeamMouseEvent({
    name: "mousemove",
    target: pointedElement,
    altKey: true,
    clientX: 101,
    clientY: 102
  })
  pns.onMouseMove(pointEvent)

  expect(testUI.eventsCount).toEqual(SENDBOUNDS_EVENTS * 2) // aka 2 document events
  expect(testUI.findEventByName("hasSelection")).toEqual({
    name: "hasSelection",
    hasSelection: false
  })
  expect(testUI.findEventByName("selectBounds")).toEqual({
    name: "selectBounds",
    rangeGroups: []
  })
  expect(testUI.findEventByName("shootBounds")).toEqual({
    name: "shootBounds",
    shootTargets: []
  })
  expect(testUI.findEventByName("pointBounds")).toBeTruthy()
})

test("getSelectionRanges should return the number of available ranges", () => {
  const { pns } = pointAndShootTestBed()

  const selection = new BeamSelectionMock("p")
  selection.addRange(createRange())
  selection.addRange(createRange())
  selection.addRange(createRange())
  selection.addRange(createRange())
  const ranges = PointAndShootHelper.getSelectionRanges(selection)

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
  expect(testUI.eventsCount).toEqual(SENDBOUNDS_EVENTS)
  expect(testUI.findEventByName("selectBounds").rangeGroups.length).toEqual(1)
})

test("When keydown (A) on input element set isTypingOnWebView", () => {
  const inputElement = new BeamHTMLInputElementMock("input", { type: "text" })
  inputElement.bounds = {
    width: 130,
    height: 120,
    x: 11,
    y: 12
  }
  inputElement.width = 130
  inputElement.height = 120

  const { pns } = pointAndShootTestBed([], { activeElement: inputElement })

  expect(pns.isTypingOnWebView).toEqual(false)
  const keyEvent = new BeamKeyEvent({ key: "A", target: inputElement })
  pns.onKeyDown(keyEvent)
  expect(pns.isTypingOnWebView).toEqual(true)
})

test("Keydown (A) on input element, then mouseMove should keep isTypingOnWebView set to true", () => {
  // Setup elements
  const inputElement = new BeamHTMLInputElementMock("input", { type: "text" })
  inputElement.bounds = {
    width: 13,
    height: 12,
    x: 11,
    y: 12
  }
  inputElement.width = 13
  inputElement.height = 12

  const otherElement = new BeamHTMLInputElementMock("p")
  otherElement.bounds = {
    width: 130,
    height: 120,
    x: 110,
    y: 120
  }
  otherElement.width = 130
  otherElement.height = 120

  const { pns } = pointAndShootTestBed([], { activeElement: inputElement })
  // initally we expect typing to be false
  expect(pns.isTypingOnWebView).toEqual(false)

  const keyEvent = new BeamKeyEvent({ key: "A", target: inputElement })
  pns.onKeyDown(keyEvent)

  // when typing we expect true
  expect(pns.isTypingOnWebView).toEqual(true)

  const pointEvent = new BeamMouseEvent({
    name: "mousemove",
    target: otherElement,
    altKey: true,
    clientX: 141,
    clientY: 152
  })

  pns.onMouseMove(pointEvent)
  // Because the activeElement didn't change we expect it to stay true
  expect(pns.isTypingOnWebView).toEqual(true)
})

test("Keydown (A) on input element, then unsetting the acitve element, then mouseMove should set isTypingOnWebView back to false", () => {
  // Setup elements
  const inputElement = new BeamHTMLInputElementMock("input", { type: "text" })
  inputElement.bounds = {
    width: 13,
    height: 12,
    x: 11,
    y: 12
  }
  inputElement.width = 13
  inputElement.height = 12

  const otherElement = new BeamHTMLInputElementMock("p")
  otherElement.bounds = {
    width: 130,
    height: 120,
    x: 110,
    y: 120
  }
  otherElement.width = 130
  otherElement.height = 120

  const { pns } = pointAndShootTestBed([], { activeElement: inputElement })
  // initally we expect typing to be false
  expect(pns.isTypingOnWebView).toEqual(false)

  const keyEvent = new BeamKeyEvent({ key: "A", target: inputElement })
  pns.onKeyDown(keyEvent)

  // when typing we expect true
  expect(pns.isTypingOnWebView).toEqual(true)

  pns.win.document.activeElement = undefined

  const pointEvent = new BeamMouseEvent({
    name: "mousemove",
    target: otherElement,
    altKey: true,
    clientX: 141,
    clientY: 152
  })

  pns.onMouseMove(pointEvent)
  // after mousemove we expect false again
  expect(pns.isTypingOnWebView).toEqual(false)
})

test("Keydown (Alt) on input element, keep isTypingOnWebView set to true", () => {
  // Setup elements
  const inputElement = new BeamHTMLInputElementMock("input", { type: "text" })
  inputElement.bounds = {
    width: 13,
    height: 12,
    x: 11,
    y: 12
  }
  inputElement.width = 13
  inputElement.height = 12

  const otherElement = new BeamHTMLInputElementMock("p")
  otherElement.bounds = {
    width: 130,
    height: 120,
    x: 110,
    y: 120
  }
  otherElement.width = 130
  otherElement.height = 120

  const { pns } = pointAndShootTestBed([], { activeElement: inputElement })
  // initally we expect typing to be false
  expect(pns.isTypingOnWebView).toEqual(false)

  const keyEvent = new BeamKeyEvent({ key: "Alt", target: inputElement })
  pns.onKeyDown(keyEvent)

  // when type Alt on inputElement we expect true
  expect(pns.isTypingOnWebView).toEqual(true)

  const pointEvent = new BeamMouseEvent({
    name: "mousemove",
    target: otherElement,
    altKey: true,
    clientX: 141,
    clientY: 152
  })

  pns.onMouseMove(pointEvent)
  // Because the activeElement didn't change we expect it to stay true
  expect(pns.isTypingOnWebView).toEqual(true)
})

test("Remove target when found in shootTargets array", () => {
  const { pns } = pointAndShootTestBed([])
  // Assign shootTargets
  const testElement = new BeamHTMLInputElementMock("p")
  pns.shootTargets = [
    {
      id: "shoot-1065773605-3737781321-1233950792",
      element: testElement
    },
    {
      id: "shoot-1006106738-1762695678-2244185447",
      element: testElement
    },
    {
      id: "shoot-3086421495-1150594309-1521447044",
      element: testElement
    }
  ]
  // Expect full array of 3 items
  expect(pns.shootTargets.length).toEqual(3)
  // Remove one target
  pns.removeTarget("shoot-1065773605-3737781321-1233950792")
  // Expect 1 item to be removed
  expect(pns.shootTargets.length).toEqual(2)
})

test("Remove no targets when target isn't found in shootTargets array", () => {
  const { pns } = pointAndShootTestBed([])
  // Assign shootTargets
  const testElement = new BeamHTMLInputElementMock("p")
  pns.shootTargets = [
    {
      id: "shoot-1065773605-3737781321-1233950792",
      element: testElement
    },
    {
      id: "shoot-1006106738-1762695678-2244185447",
      element: testElement
    },
    {
      id: "shoot-3086421495-1150594309-1521447044",
      element: testElement
    }
  ]
  // Expect full array of 3 items
  expect(pns.shootTargets.length).toEqual(3)
  // Remove one target
  pns.removeTarget("id-that-doesnt-exist-in-array")
  // Expect no items to be removed
  expect(pns.shootTargets.length).toEqual(3)
})

test("Remove target when found in selectionRangeGroups array", () => {
  const { pns } = pointAndShootTestBed([])
  // Assign selectionRangeGroups
  const testRange = new BeamRangeMock()
  pns.selectionRangeGroups = [
    {
      id: "selection-2829002974-4275350176-104943234",
      range: testRange
    },
    {
      id: "selection-2829002974-4275350176-104943098",
      range: testRange
    },
    {
      id: "selection-2829002974-4275350176-104943567",
      range: testRange
    }
  ]
  // Expect full array of 3 items
  expect(pns.selectionRangeGroups.length).toEqual(3)
  // Remove one target
  pns.removeTarget("selection-2829002974-4275350176-104943234")
  // Expect 1 item to be removed
  expect(pns.selectionRangeGroups.length).toEqual(2)
})

test("Remove no targets when target isn't found in selectionRangeGroups array", () => {
  const { pns } = pointAndShootTestBed([])
  // Assign selectionRangeGroups
  const testRange = new BeamRangeMock()
  pns.selectionRangeGroups = [
    {
      id: "selection-2829002974-4275350176-104943234",
      range: testRange
    },
    {
      id: "selection-2829002974-4275350176-104943098",
      range: testRange
    },
    {
      id: "selection-2829002974-4275350176-104943567",
      range: testRange
    }
  ]
  // Expect full array of 3 items
  expect(pns.selectionRangeGroups.length).toEqual(3)
  // Remove one target
  pns.removeTarget("id-that-doesnt-exist-in-array")
  // Expect no items to be removed
  expect(pns.selectionRangeGroups.length).toEqual(3)
})

test("Remove target from selectionRangeGroups array without changing shootGroups arary", () => {
  const { pns } = pointAndShootTestBed([])
  // Assign shootTargets
  const testElement = new BeamHTMLInputElementMock("p")
  pns.shootTargets = [
    {
      id: "shoot-1065773605-3737781321-1233950792",
      element: testElement
    },
    {
      id: "shoot-1006106738-1762695678-2244185447",
      element: testElement
    },
    {
      id: "shoot-3086421495-1150594309-1521447044",
      element: testElement
    }
  ]
  // Assign selectionRangeGroups
  const testRange = new BeamRangeMock()
  pns.selectionRangeGroups = [
    {
      id: "selection-2829002974-4275350176-104943234",
      range: testRange
    },
    {
      id: "selection-2829002974-4275350176-104943098",
      range: testRange
    },
    {
      id: "selection-2829002974-4275350176-104943567",
      range: testRange
    }
  ]
  // Expect full array of 3 shoot targets
  expect(pns.shootTargets.length).toEqual(3)
  // Remove one selection target
  pns.removeTarget("selection-2829002974-4275350176-104943234")
  // Expect full array of 3 shoot targets
  expect(pns.shootTargets.length).toEqual(3)
})

test("element should be removed when it isn't connected anymore", () => {
  const { pns, testUI } = pointAndShootTestBed()
  const element = new BeamHTMLElementMock("p")
  element.bounds = {
    width: 130,
    height: 120,
    x: 11,
    y: 12
  }
  element.width = 130
  element.height = 120
  element.isConnected = true

  pns.shoot(element)

  expect(pns.shootTargets).toHaveLength(1)
  pns.sendBounds()
  // Disconnect element
  element.isConnected = false
  pns.sendBounds()
  // Expect element to be removed
  expect(pns.shootTargets).toHaveLength(0)
})