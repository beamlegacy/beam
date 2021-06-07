import {BeamDocumentMock, BeamHTMLElementMock, BeamRangeMock, BeamTextMock} from "./Test/BeamMocks"
import {BeamWindowMock} from "./Test/BeamWindowMock"
import {PointAndShootUI_native} from "./PointAndShootUI_native"
import {NativeMock} from "./Test/NativeMock"
import { BeamRange } from "./BeamTypes"

/**
 * @param frameEls {BeamHTMLElement[]}
 * @return {{pnsNativeUI: PointAndShootUI_native, testUI: PointAndShootUIMock}}
 */
function pointAndShootTestBed(frameEls = []) {
    const scrollData = {
        scrollWidth: 800, scrollHeight: 0,
        offsetWidth: 800, offsetHeight: 0,
        clientWidth: 800, clientHeight: 0,
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
    const win = new BeamWindowMock(testDocument)
    const native = new NativeMock(win)
    const pnsNativeUI = new PointAndShootUI_native(native)

    return {pnsNativeUI, native}
}

test("sends element nodes rectangles", () => {
    const {pnsNativeUI, native} = pointAndShootTestBed()

    const block = new BeamHTMLElementMock("p")
    block.offsetLeft = 11
    block.offsetTop = 12
    block.width = 100
    block.height = 200

    const mostLeftChild = new BeamHTMLElementMock("b")
    const mostTopChild = mostLeftChild
    {
        mostLeftChild.offsetLeft = 0
        mostLeftChild.offsetTop = 0
        mostLeftChild.width = 50
        mostLeftChild.height = 16
        mostLeftChild.appendChild(new BeamTextMock("MEAN"))
        block.appendChild(mostLeftChild)
    }
    const mostBottomChild = new BeamTextMock(" (")
    {
        mostBottomChild.bounds.x = 15
        mostBottomChild.bounds.y = 30
        mostBottomChild.bounds.width = 20
        mostBottomChild.bounds.height = 16
        block.appendChild(mostBottomChild)
    }
    const attributes = {href: "/wiki/MongoDB"}
    const mostRightChild = new BeamHTMLElementMock("a", attributes)
    {
        mostRightChild.appendChild(new BeamTextMock("MongoDB"))
        mostRightChild.offsetLeft = 10
        mostRightChild.offsetTop = 5
        mostRightChild.width = 60
        mostRightChild.height = 16
        block.appendChild(mostRightChild)
    }
    
    pnsNativeUI.point("quoteId", block, 70, 22)
    const events = native.events
    expect(events.length).toEqual(1)
    const event0 = events[0]
    expect(event0.name).toEqual("sendMessage point")
    const pointArea = event0.payload.areas[0]
    expect(pointArea.x).toEqual(block.offsetLeft)
    expect(pointArea.y).toEqual(block.offsetTop)
    expect(pointArea.width).toEqual(mostRightChild.offsetLeft + mostRightChild.width - mostLeftChild.offsetLeft)
   // expect(totalArea.height).toEqual(mostBottomChild.bounds.y + mostBottomChild.bounds.height - mostTopChild.offsetTop)
    expect(pointArea.height).toEqual(34 - mostTopChild.offsetTop)
    expect(event0.payload.html).toEqual(`<p><b>MEAN</b> (<a href="/wiki/MongoDB">MongoDB</a></p>`)
    expect(event0.payload.location).toEqual({x: 59, y: 10})

    pnsNativeUI.shoot("quoteId", block, 70, 22, null)
    expect(events.length).toEqual(2)
    const event1 = events[1]
    expect(event1.name).toEqual("sendMessage shoot")
    const shootArea = event1.payload.areas[0]
    expect(shootArea.x).toEqual(block.offsetLeft)
    expect(shootArea.y).toEqual(block.offsetTop)
    expect(shootArea.width).toEqual(mostRightChild.offsetLeft + mostRightChild.width - mostLeftChild.offsetLeft)
   // expect(totalArea.height).toEqual(mostBottomChild.bounds.y + mostBottomChild.bounds.height - mostTopChild.offsetTop)
    expect(shootArea.height).toEqual(34 - mostTopChild.offsetTop)
    expect(event1.payload.html).toEqual(`<p><b>MEAN</b> (<a href="/wiki/MongoDB">MongoDB</a></p>`)
    expect(event1.payload.location).toEqual({x: 59, y: 10})
})

test("select event should return areas containing only x, y, width and height", () => {
    const {pnsNativeUI, native} = pointAndShootTestBed()
    // manually init selection with selection range
    const range = new BeamRangeMock() as BeamRange
    const node = new BeamHTMLElementMock("b")
    range.setStart(node, 2);
    range.setEnd(node, 3);    
    let selectElements = [{
        quoteId: undefined, 
        el: range
    }]
    pnsNativeUI.select(selectElements)
    const events = native.events
    expect(events.length).toEqual(1)
    const event0 = events[0]
    expect(event0.name).toEqual("sendMessage select")
    const pointAreas = event0.payload.areas
    expect(pointAreas.length).toEqual(1)
    expect(pointAreas).toEqual([{ x: 0, y: 0, width: 0, height: 0 }])
   
})