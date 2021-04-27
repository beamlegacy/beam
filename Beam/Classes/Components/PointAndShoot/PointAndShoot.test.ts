import {PointAndShoot} from "./PointAndShoot"
import {BeamDocumentMock, BeamHTMLElementMock, BeamKeyEvent, BeamMouseEvent, BeamUIEvent} from "./Test/BeamMocks"
import {BeamWindowMock} from "./Test/BeamWindowMock"
import {PointAndShootUIMock} from "./Test/PointAndShootUIMock"
import {TextSelectorUI_mock} from "./Test/TextSelectorUI_mock";
import {TextSelector} from "./TextSelector";

/**
 * @param frameEls {BeamHTMLElement[]}
 * @return {{pns: PointAndShoot, testUI: PointAndShootUIMock}}
 */
function pointAndShootTestBed(frameEls = []) {
    const testUI = new PointAndShootUIMock()
    const scrollData = {
        scrollWidth: 800, scrollHeight: 0,
        offsetWidth: 800, offsetHeight: 0,
        clientWidth: 800, clientHeight: 0,
    }
    const testDocument = new BeamDocumentMock({
        body: scrollData,
        documentElement: scrollData,
        querySelectorAll: (selector) => {
            if (selector === "iframe") {
                return frameEls
            }
        }
    })
    const win = new BeamWindowMock(testDocument)
    PointAndShoot.instance = null  // Allow test suite to instantiate multiple PointAndShoots
    const textSelector = new TextSelector(win, new TextSelectorUI_mock())
    const pns = PointAndShoot.getInstance(win, testUI)

  // Check registered event listeners
    const eventListeners = win.getEventListeners(win)
    expect(eventListeners["mousemove"]).toBeDefined()
    expect(eventListeners["scroll"]).toBeDefined()

    // Check initial state
    expect(pns.status === "none")
    expect(testUI.eventsCount).toBeGreaterThanOrEqual(1)
    expect(testUI.events[0]).toEqual({name: "scroll", x: 0, y: 0, width: 800, height: 0, scale: 1})
    testUI.clearEvents()  // To ease further events counting
    return {pns, testUI}
}

test("move mouse without Option", () => {
    const {pns, testUI} = pointAndShootTestBed()

    const hoveredElement = new BeamHTMLElementMock("p")
    const pointEvent = new BeamMouseEvent({name: "mousemove", target: hoveredElement, clientX: 101, clientY: 102})
    pns.onMouseMove(pointEvent)
    expect(pns.status).toEqual("none")
    expect(testUI.eventsCount).toEqual(1)
    expect(testUI.latestEvent).toEqual("hideStatus")
})

test("point with mouse move + Option", () => {
    const {pns, testUI} = pointAndShootTestBed()

    const pointedElement = new BeamHTMLElementMock("p")
    const pointEvent = new BeamMouseEvent({
        name: "mousemove",
        target: pointedElement,
        altKey: true,
        clientX: 101,
        clientY: 102
    })
    pns.onMouseMove(pointEvent)

    expect(pns.isPointing()).toEqual(true)
    expect(pns.status).toEqual("pointing")  // Check low level too because it will be in a postMessage
    expect(testUI.eventsCount).toEqual(3)
    expect(testUI.events[0]).toEqual({name: "setStatus", status: "pointing"})
    expect(testUI.events[1]).toEqual({name: "point", el: pointedElement, x: 101, y: 102})
    expect(testUI.events[2]).toEqual("hideStatus")
})

test("point with Option key down then mouse move", () => {
    const {pns, testUI} = pointAndShootTestBed()

    const keyEvent = new BeamKeyEvent({key: "Alt"})
    pns.onKeyDown(keyEvent)

    const pointedElement = new BeamHTMLElementMock("p")
    const pointEvent = new BeamMouseEvent({
        name: "mousemove",
        target: pointedElement,
        altKey: true,
        clientX: 101,
        clientY: 102
    })
    pns.onMouseMove(pointEvent)

    expect(pns.isPointing()).toEqual(true)
    expect(pns.status).toEqual("pointing")  // Check low level too because it will be in a postMessage
    expect(testUI.eventsCount).toEqual(3)
    expect(testUI.events[0]).toEqual({name: "setStatus", status: "pointing"})
    expect(testUI.events[1]).toEqual({name: "point", el: pointedElement, x: 101, y: 102})
    expect(testUI.events[2]).toEqual("hideStatus")
})

test("point with mouse move then key down", () => {
    const {pns, testUI} = pointAndShootTestBed()

    const pointedElement = new BeamHTMLElementMock("p")
    const pointEvent = new BeamMouseEvent({
        name: "mousemove",
        target: pointedElement,
        altKey: false,
        clientX: 101,
        clientY: 102
    })
    pns.onMouseMove(pointEvent)

    pns.onKeyDown(new BeamKeyEvent({key: "Alt"}))

    expect(pns.isPointing()).toEqual(true)
    expect(pns.status).toEqual("pointing")  // Check low level too because it will be in a postMessage
    expect(testUI.eventsCount).toEqual(3)
    expect(testUI.events[0]).toEqual("hideStatus")
    expect(testUI.events[1]).toEqual({name: "setStatus", status: "pointing"})
    expect(testUI.events[2]).toEqual({name: "point", el: pointedElement, x: 101, y: 102})
})

test("point then release Option", () => {
    const {pns, testUI} = pointAndShootTestBed()

    const pointedElement = new BeamHTMLElementMock("p")
    const pointEvent = new BeamMouseEvent({
        name: "mousemove",
        altKey: true,
        target: pointedElement,
        clientX: 101,
        clientY: 102
    })
    pns.onMouseMove(pointEvent)
    expect(testUI.eventsCount).toEqual(3)

    // Move mouse with Option key released
    const unpointEvent = new BeamMouseEvent({
        name: "mousemove",
        altKey: false,
        target: pointedElement,
        clientX: 101,
        clientY: 102
    })
    pns.onMouseMove(unpointEvent)
    pns.onKeyUp(new BeamKeyEvent({key: "Alt"}))   // Release option

    expect(pns.status).toEqual("none")
    expect(testUI.eventsCount).toEqual(5)
    expect(testUI.events[3]).toEqual({name: "setStatus", status: "none"})
    expect(testUI.events[4]).toEqual("hideStatus")
})

test("point with mouse move + Option, then scroll", () => {
    const {pns, testUI} = pointAndShootTestBed()

    const pointedElement = new BeamHTMLElementMock("p")
    const pointEvent = new BeamMouseEvent({
        name: "mousemove",
        target: pointedElement,
        altKey: true,
        clientX: 101,
        clientY: 102
    })
    pns.onMouseMove(pointEvent)

    // Scroll with Option still pressed
    const scrollEvent = new BeamUIEvent()
    Object.assign(scrollEvent, {name: "scroll", target: pointedElement})
    pns.onScroll(scrollEvent)
    expect(pns.isPointing()).toEqual(true)  // Pointing was not disabled by scroll
    expect(testUI.eventsCount).toEqual(4)
    expect(testUI.latestEvent).toEqual({name: "scroll", height: 0, width: 800, x: 0, y: 0, scale: 1})
})

test("point then shoot, then cancel", () => {
    const {pns, testUI} = pointAndShootTestBed()

    const pointedElement = new BeamHTMLElementMock("p")
    const pointEvent = new BeamMouseEvent({
        name: "mousemove",
        target: pointedElement,
        altKey: true,
        clientX: 101,
        clientY: 102
    })
    pns.onMouseMove(pointEvent)
    expect(pns.status).toEqual("pointing")
    expect(testUI.eventsCount).toEqual(3)
    expect(testUI.events[1]).toEqual({name: "point", el: pointedElement, x: 101, y: 102})

    // Shoot
    const shotElement = new BeamHTMLElementMock("p")
    const clickEvent = new BeamMouseEvent()
    Object.assign(clickEvent, {name: "mouseclick", clientX: 103, clientY: 104, target: shotElement, altKey: true})
    pns.onClick(clickEvent)
    expect(pns.status).toEqual("shooting")
    expect(testUI.eventsCount).toEqual(4)
    expect(testUI.latestEvent).toEqual({name: "shoot", el: pointedElement, x: 103, y: 104, selectedEls: [shotElement]})

    // Cancel shoot
    pns.unshoot()
    expect(pns.status).toEqual("none")
    expect(testUI.eventsCount).toEqual(6)
    expect(testUI.events[4]).toEqual({name: "unshoot", el: pointedElement})
    expect(testUI.events[5]).toEqual({name: "setStatus", status: "none"})

})
