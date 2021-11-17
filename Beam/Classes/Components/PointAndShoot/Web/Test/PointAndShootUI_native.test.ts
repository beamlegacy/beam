import {PointAndShootUI_native} from "../PointAndShootUI_native"
import {NativeMock} from "../../../../Helpers/Utils/Web/Test/Mock/NativeMock"
import {BeamElement, BeamRange, BeamMessageHandler, MessageHandlers} from "../../../../Helpers/Utils/Web/BeamTypes"
import {BeamElementHelper} from "../../../../Helpers/Utils/Web/BeamElementHelper"
import {BeamRectHelper} from "../../../../Helpers/Utils/Web/BeamRectHelper"
import { PNSWindowMock } from "./PNSWindowMock"
import {BeamDocumentMock} from "../../../../Helpers/Utils/Web/Test/Mock/BeamDocumentMock"
import {BeamTextMock} from "../../../../Helpers/Utils/Web/Test/Mock/BeamTextMock"
import {BeamHTMLElementMock} from "../../../../Helpers/Utils/Web/Test/Mock/BeamHTMLElementMock"
import {BeamRangeMock} from "../../../../Helpers/Utils/Web/Test/Mock/BeamRangeMock"
import { PointAndShootHelper } from "../PointAndShootHelper"

jest.mock("debounce", () => ({
  debounce: jest.fn(fn => {
    return fn()
  })
}))

/**
 * @param frameEls {BeamHTMLElement[]}
 * @return {{pnsNativeUI: PointAndShootUI_native, testUI: PointAndShootUIMock}}
 */
function pointAndShootTestBed(frameEls = []) {
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
  const win = new PNSWindowMock(testDocument)
  const native = new NativeMock<MessageHandlers>(win, "pointAndShoot")
  const pnsNativeUI = new PointAndShootUI_native(native)

  return { pnsNativeUI, native }
}

test("test pointBounds payload", () => {
  const { pnsNativeUI, native } = pointAndShootTestBed()

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
  const attributes = { href: "/wiki/MongoDB" }
  const mostRightChild = new BeamHTMLElementMock("a", attributes)
  {
    mostRightChild.offsetLeft = 10
    mostRightChild.offsetTop = 5
    mostRightChild.width = 60
    mostRightChild.height = 16
    mostRightChild.appendChild(new BeamTextMock("MongoDB"))
    block.appendChild(mostRightChild)
  }

  pnsNativeUI.pointBounds({ id: "uuid", element: block })
  const events = native.events
  expect(events.length).toEqual(1)
  const event0 = events[0]
  expect(event0.name).toEqual("sendMessage pointBounds")

  const payload = event0.payload.point
  const pointRect = payload.rect
  expect(pointRect.x).toEqual(block.offsetLeft)
  expect(pointRect.y).toEqual(block.offsetTop)
  expect(pointRect.width).toEqual(mostRightChild.offsetLeft + mostRightChild.width - mostLeftChild.offsetLeft)
  expect(pointRect.height).toEqual(34 - mostTopChild.offsetTop)
  expect(payload.html).toEqual(undefined)
})

test("test shootBounds payload", () => {
  const { pnsNativeUI, native } = pointAndShootTestBed()

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
  const attributes = { href: "/wiki/MongoDB" }
  const mostRightChild = new BeamHTMLElementMock("a", attributes)
  {
    mostRightChild.offsetLeft = 10
    mostRightChild.offsetTop = 5
    mostRightChild.width = 60
    mostRightChild.height = 16
    mostRightChild.appendChild(new BeamTextMock("MongoDB"))
    block.appendChild(mostRightChild)
  }

  pnsNativeUI.shootBounds([{ id: "uuid", element: block }])
  const events = native.events
  expect(events.length).toEqual(1)
  const event0 = events[0]
  expect(event0.name).toEqual("sendMessage shootBounds")

  const payload = event0.payload.shoot[0]
  const pointRect = payload.rect
  expect(pointRect.x).toEqual(block.offsetLeft)
  expect(pointRect.y).toEqual(block.offsetTop)
  expect(pointRect.width).toEqual(mostRightChild.offsetLeft + mostRightChild.width - mostLeftChild.offsetLeft)
  expect(pointRect.height).toEqual(34 - mostTopChild.offsetTop)
  expect(payload.html).toEqual("<p><b>MEAN</b> (<a href=\"/wiki/MongoDB\">MongoDB</a></p>")
})

test("select event should return areas containing only x, y, width and height", () => {
  const { pnsNativeUI, native } = pointAndShootTestBed()
  // manually init selection with selection range
  const range = new BeamRangeMock() as BeamRange
  const node = new BeamHTMLElementMock("b")
  range.setStart(node, 2)
  range.setEnd(node, 3)
  const selectElements = [
    {
      id: "uuid",
      range: range
    }
  ]
  pnsNativeUI.selectBounds(selectElements)
  const events = native.events
  expect(events.length).toEqual(1)
  const event0 = events[0]
  expect(event0.name).toEqual("sendMessage selectBounds")
  const pointRects = event0.payload.select[0].rectData
  expect(pointRects.length).toEqual(1)
  expect(pointRects[0].rect).toEqual({ x: 0, y: 0, width: 0, height: 0 })
})

describe("Pointing mode overlay bounding area calculation", () => {
  const { pnsNativeUI, native } = pointAndShootTestBed()

  test("point area is based on children bounds", () => {
    const parent = new BeamHTMLElementMock("div")
    {
      parent.offsetLeft = 10
      parent.offsetTop = 10
      parent.width = 40
      parent.height = 40
    }
    const child = new BeamHTMLElementMock("div")
    {
      child.offsetLeft = 10
      child.offsetTop = 10
      child.width = 10
      child.height = 10
      child.appendChild(new BeamTextMock("Some text"))
      parent.appendChild(child)
    }

    const isParentVisible = BeamElementHelper.isVisible(parent as BeamElement, native.win)
    expect(isParentVisible).toBe(true)
    const isChildVisible = BeamElementHelper.isVisible(child as BeamElement, native.win)
    expect(isChildVisible).toBe(true)
    const area = pnsNativeUI.elementBounds(parent)
    const expected = { x: 20, y: 20, width: 10, height: 10 }
    expect(area).toMatchObject(expected)
  })

  test("point area extends based on visible children bounds", () => {
    const parent = new BeamHTMLElementMock("div")
    {
      parent.offsetLeft = 10
      parent.offsetTop = 10
      parent.width = 40
      parent.height = 40
    }
    const child = new BeamHTMLElementMock("div")
    {
      child.offsetLeft = 10
      child.offsetTop = 10
      child.width = 10
      child.height = 10
      child.appendChild(new BeamTextMock("Some text"))
      parent.appendChild(child)
    }
    const child2 = new BeamHTMLElementMock("div")
    {
      child2.offsetLeft = 50
      child2.offsetTop = 50
      child2.width = 60
      child2.height = 60
      child2.appendChild(new BeamTextMock("Some text"))
      parent.appendChild(child2)
    }

    const isParentVisible = BeamElementHelper.isVisible(parent as BeamElement, native.win)
    expect(isParentVisible).toBe(true)
    const isChildVisible = BeamElementHelper.isVisible(child as BeamElement, native.win)
    expect(isChildVisible).toBe(true)
    const isChild2Visible = BeamElementHelper.isVisible(child2 as BeamElement, native.win)
    expect(isChild2Visible).toBe(true)
    const area = pnsNativeUI.elementBounds(parent)
    const expected = { x: 20, y: 20, width: 100, height: 100 }
    expect(area).toMatchObject(expected)
  })

  test("zero width / height sized elements are not used for point area calculation", () => {
    const parent = new BeamHTMLElementMock("div")
    {
      parent.offsetLeft = 10
      parent.offsetTop = 10
      parent.width = 40
      parent.height = 40
    }
    const child = new BeamHTMLElementMock("div")
    {
      child.offsetLeft = 10
      child.offsetTop = 10
      child.width = 10
      child.height = 10
      child.appendChild(new BeamTextMock("Some text"))
      parent.appendChild(child)
    }
    // This children is implicitly invisible, it should stay out of the area calculation
    const child2 = new BeamHTMLElementMock("div")
    {
      child2.offsetLeft = 50
      child2.offsetTop = 50
      child2.width = 0
      child2.height = 0
      child2.appendChild(new BeamTextMock("Some text"))
      parent.appendChild(child2)
    }
    const isParentVisible = BeamElementHelper.isVisible(parent, native.win)
    expect(isParentVisible).toBe(true)
    const isChildVisible = BeamElementHelper.isVisible(child, native.win)
    expect(isChildVisible).toBe(true)
    const isChild2Visible = BeamElementHelper.isVisible(child2, native.win)
    expect(isChild2Visible).toBe(false)
    const area = pnsNativeUI.elementBounds(parent)
    const expected = { x: 20, y: 20, width: 10, height: 10 }
    expect(area).toMatchObject(expected)
  })

  test("elements must be visible to be included in selection area", () => {
    const parent = new BeamHTMLElementMock("div")
    {
      parent.offsetLeft = 10
      parent.offsetTop = 10
      parent.width = 40
      parent.height = 40
    }

    const testChild = (props?, expected = undefined) => {
      const child = new BeamHTMLElementMock("div")
      child.offsetLeft = 10
      child.offsetTop = 10
      child.width = 10
      child.height = 10
      child.appendChild(new BeamTextMock("Some text to make the element meaningful"))

      child.style = new CSSStyleDeclaration()
      for (const prop of props) {
        child.style.setProperty(prop[0], prop[1])
      }
      parent.appendChild(child)
      const area = pnsNativeUI.elementBounds(child)
      const isChildVisible = BeamElementHelper.isVisible(child as BeamElement, native.win)
      if (expected) {
        expect(isChildVisible).toBe(true)
        expect(area).toMatchObject(expected)
      } else {
        expect(isChildVisible).toBe(false)
        expect(area).toBeUndefined()
      }
      parent.removeChild(child)
    }

    const isParentVisible = BeamElementHelper.isVisible(parent as BeamElement, native.win)
    expect(isParentVisible).toBe(true)

    testChild([[]], { x: 20, y: 20, width: 10, height: 10 })
    testChild([["display", "none"]])
    testChild([["visibility", "hidden"]])
    testChild([["visibility", "collapse"]])
    testChild([["width", "1px"], ["height", "1px"]])
    testChild([["width", "0"]])
    testChild([["height", "0px"]])
    // Only absolutely positioned elements can have a `clip` property
    testChild([["clip", "rect(0, 0, 0, 0)"], ["position", "absolute"]])
    testChild([["clip", "rect(0, 0, 0, 0)"], ["position", "static"]], { x: 20, y: 20, width: 10, height: 10 })
    testChild([["clip-path", "inset(50%)"]])
    testChild([["clip-path", "inset(100%)"]])
    testChild([["clip-path", "inset(49%)"]], { x: 20, y: 20, width: 10, height: 10 })

  })
})


describe("isMeaningful filtering", () => {
  const { pnsNativeUI, native } = pointAndShootTestBed()
  test(
    "filter out empty element without any childNodes (including text nodes)",
    () => {
      const parent = new BeamHTMLElementMock("div")
      {
        parent.offsetLeft = 10
        parent.offsetTop = 10
        parent.width = 40
        parent.height = 40
      }

      const isParentVisible = BeamElementHelper.isVisible(parent as BeamElement, native.win)
      expect(isParentVisible).toBe(true)
      const area = pnsNativeUI.elementBounds(parent)
      expect(area).toBeUndefined()
    }
  )

  describe("image and media elements are allowed in selection despite being empty", () => {
    const testSelection = (tagName, cssProps = [], expectsTagToBeSelected = false) => {
      const element = new BeamHTMLElementMock(tagName)
      {
        element.offsetLeft = 10
        element.offsetTop = 10
        element.width = 40
        element.height = 40
        element.style = new CSSStyleDeclaration()
        for (const prop of cssProps) {
          element.style.setProperty(prop[0], prop[1])
        }
      }

      const isVisible = BeamElementHelper.isVisible(element as BeamElement, native.win)
      expect(isVisible).toBe(true)
      const area = pnsNativeUI.elementBounds(element)
      if (expectsTagToBeSelected) {
        const expected = { x: element.offsetLeft, y: element.offsetTop, width: element.width, height: element.height }
        expect(area).toMatchObject(expected)
      } else {
        expect(area).toBeUndefined()
      }

      // Image nested in parent
      const parent = new BeamHTMLElementMock("div")
      {
        parent.offsetLeft = 10
        parent.offsetTop = 10
        parent.width = 60
        parent.height = 60
        parent.appendChild(element)
      }

      const isVisible2 = BeamElementHelper.isVisible(parent as BeamElement, native.win)
      expect(isVisible2).toBe(true)
      const area2 = pnsNativeUI.elementBounds(parent)
      if (expectsTagToBeSelected) {
        const expected2 = {
          x: parent.offsetLeft + element.offsetLeft,
          y: parent.offsetTop + element.offsetTop,
          width: element.width,
          height: element.height
        }
        expect(area2).toMatchObject(expected2)
      } else {
        expect(area2).toBeUndefined()
      }
    }

    test(
      "empty image elements allowed in selection: <img> & <svg> tags or because it has a valid url() in css `background-image` property value",
      () => {
        testSelection("img", [], true)
        testSelection("svg", [], true)
        testSelection("div", [], false)
        testSelection(
          "div",
          [["background-image", "url(\"https://interactive-examples.mdn.mozilla.net/media/examples/balloon-small.jpg\")"]],
          true
        )
        testSelection(
          "div",
          [["background-image", "url(data:image/gif;base64,R0lGODlhEAAQAMQAAORHHOVSKudfOulrSOp3WOyDZu6QdvCchPGolfO0o/XBs/fNwfjZ0frl3/zy7////wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACH5BAkAABAALAAAAAAQABAAAAVVICSOZGlCQAosJ6mu7fiyZeKqNKToQGDsM8hBADgUXoGAiqhSvp5QAnQKGIgUhwFUYLCVDFCrKUE1lBavAViFIDlTImbKC5Gm2hB0SlBCBMQiB0UjIQA7)"]],
          true
        )
        testSelection(
          "div",
          [["background-image", "linear-gradient(to left, #333, #333 50%, #eee 75%, #333 75%)"]],
          false
        )
      }
    )

    test(
      "media elements <video> and <audio> allowed in selection",
      () => {

        testSelection("video", [], true)
        testSelection("audio", [], true)
        testSelection("div", [], false)
      }
    )
  })


  test(
    "filter out elements without any meaningful text",
    () => {
      const parent = new BeamHTMLElementMock("div")
      {
        parent.offsetLeft = 10
        parent.offsetTop = 10
        parent.width = 40
        parent.height = 40
        parent.appendChild(new BeamTextMock("•"))
      }

      const isParentVisible = BeamElementHelper.isVisible(parent as BeamElement, native.win)
      expect(isParentVisible).toBe(true)
      const area = pnsNativeUI.elementBounds(parent)
      expect(area).toBeUndefined()

      // Update text to be meaningful
      parent.removeChild(parent.childNodes[0])
      parent.appendChild(new BeamTextMock("• Hello"))
      const area2 = pnsNativeUI.elementBounds(parent)
      const expected = { x: 10, y: 10, width: 40, height: 40 }
      expect(area2).toMatchObject(expected)
    }
  )
})


describe("isTextMeaningful", () => {
  test("Return false for strings containing only '•'", () => {
    const input = "•"
    expect(PointAndShootHelper.isTextMeaningful(input)).toBe(false)
  })

  test("Return false for strings containing only '-'", () => {
    const input = "-"
    expect(PointAndShootHelper.isTextMeaningful(input)).toBe(false)
  })

  test("Return false for strings containing only '|'", () => {
    const input = "|"
    expect(PointAndShootHelper.isTextMeaningful(input)).toBe(false)
  })

  test("Return false for strings containing only '–'", () => {
    const input = "–"
    expect(PointAndShootHelper.isTextMeaningful(input)).toBe(false)
  })

  test("Return false for strings containing only '—'", () => {
    const input = "—"
    expect(PointAndShootHelper.isTextMeaningful(input)).toBe(false)
  })

  test("Return true for strings containing only '.'", () => {
    const input = "."
    expect(PointAndShootHelper.isTextMeaningful(input)).toBe(true)
  })

  test("Return true for strings containing only '#'", () => {
    const input = "#"
    expect(PointAndShootHelper.isTextMeaningful(input)).toBe(true)
  })

  test("Return true for strings containing only '$'", () => {
    const input = "$"
    expect(PointAndShootHelper.isTextMeaningful(input)).toBe(true)
  })

  test("Return true for strings containing a combination useless and useful characters like '@' and '|'", () => {
    const input = "|@|"
    expect(PointAndShootHelper.isTextMeaningful(input)).toBe(true)
  })

  test("Return true for strings containing a single word", () => {
    const input = "Beam"
    expect(PointAndShootHelper.isTextMeaningful(input)).toBe(true)
  })

  test("Return false for empty strings", () => {
    const input = ""
    expect(PointAndShootHelper.isTextMeaningful(input)).toBe(false)
  })
})

describe("overflow / clipping handling", () => {
  const { pnsNativeUI, native } = pointAndShootTestBed()
  test("pointing area is constrained to the overflowing parent bounds", () => {
    const parent = new BeamHTMLElementMock("div")
    {
      parent.offsetLeft = 10
      parent.offsetTop = 10
      parent.width = 100
      parent.height = 100

      parent.style = new CSSStyleDeclaration()
      parent.style.setProperty("overflow", "hidden")
    }
    const child = new BeamHTMLElementMock("div")
    {
      child.offsetLeft = 10
      child.offsetTop = 10
      child.width = 200
      child.height = 200
      child.appendChild(new BeamTextMock("Some un-sized text just to make the element meaningful"))
      parent.appendChild(child)
    }

    const isParentVisible = BeamElementHelper.isVisible(parent, native.win)
    expect(isParentVisible).toBe(true)
    const isChildVisible = BeamElementHelper.isVisible(child, native.win)
    expect(isChildVisible).toBe(true)

    const area = pnsNativeUI.elementBounds(parent)
    const expected = { x: 20, y: 20, width: 90, height: 90 }
    expect(area).toMatchObject(expected)
  })

  test("nested overflows result in the intersection area being the clipping area applied to the element bounds", () => {

    const overflowStyle = new CSSStyleDeclaration()
    overflowStyle.setProperty("overflow", "hidden")
    const parent = new BeamHTMLElementMock("div")
    {
      parent.offsetLeft = 10
      parent.offsetTop = 10
      parent.width = 100
      parent.height = 100
      parent.style = overflowStyle
    }
    const child = new BeamHTMLElementMock("div")
    {
      child.offsetLeft = 50
      child.offsetTop = 50
      child.width = 200
      child.height = 200
      child.style = overflowStyle
      parent.appendChild(child)
    }
    const child2 = new BeamHTMLElementMock("div")
    {
      child2.offsetLeft = -25
      child2.offsetTop = -25
      child2.width = 200
      child2.height = 200
      child2.appendChild(new BeamTextMock("Some un-sized text just to make the element meaningful"))
      child.appendChild(child2)
    }

    const isParentVisible = BeamElementHelper.isVisible(parent, native.win)
    expect(isParentVisible).toBe(true)
    const isChildVisible = BeamElementHelper.isVisible(child, native.win)
    expect(isChildVisible).toBe(true)
    const isChild2Visible = BeamElementHelper.isVisible(child2, native.win)
    expect(isChild2Visible).toBe(true)

    const area = pnsNativeUI.elementBounds(child2)
    const expected = { x: 60, y: 60, width: 50, height: 50 }
    expect(area).toMatchObject(expected)
  })

  test("overflow-x and overflow-y set to hidden without their counterpart", () => {

    const parent = new BeamHTMLElementMock("div")
    {
      parent.offsetLeft = 10
      parent.offsetTop = 10
      parent.width = 100
      parent.height = 100
      parent.style = new CSSStyleDeclaration()
      parent.style.setProperty("overflow-x", "hidden")
      parent.style.setProperty("overflow-y", "visible")
    }

    const child = new BeamHTMLElementMock("div")
    {
      child.offsetLeft = 50
      child.offsetTop = 50
      child.width = 200
      child.height = 200
      child.appendChild(new BeamTextMock("Some un-sized text just to make the element meaningful"))
      parent.appendChild(child)
    }

    const isParentVisible = BeamElementHelper.isVisible(parent, native.win)
    expect(isParentVisible).toBe(true)
    const isChildVisible = BeamElementHelper.isVisible(child, native.win)
    expect(isChildVisible).toBe(true)

    const area = pnsNativeUI.elementBounds(child)
    const clippingElements = BeamElementHelper.getClippingElements(child, native.win)
    const clippingArea = BeamElementHelper.getClippingArea(clippingElements, native.win)
    const _ = BeamRectHelper.intersection(child.getBoundingClientRect(), clippingArea)

    const expected = { x: 60, y: 60, width: 50, height: 200 }
    expect(area).toMatchObject(expected)
  })

  test("overflow escaping on absolute positioned elements", () => {
    // Basically, in order for an absolutely positioned element to appear outside
    // of an element with overflow: hidden, its closest positioned ancestor must
    // also be an ancestor of the element with overflow: hidden.
    // https://css-tricks.com/popping-hidden-overflow/

    const parent = new BeamHTMLElementMock("div")
    {
      parent.offsetLeft = 10
      parent.offsetTop = 10
      parent.width = 100
      parent.height = 100
      parent.style = new CSSStyleDeclaration()
      parent.style.setProperty("position", "absolute")
    }

    const child = new BeamHTMLElementMock("div")
    {
      child.offsetLeft = 50
      child.offsetTop = 50
      child.width = 200
      child.height = 200
      child.style = new CSSStyleDeclaration()
      child.style.setProperty("overflow", "hidden")
      parent.appendChild(child)
    }

    const child2 = new BeamHTMLElementMock("div")
    {
      child2.offsetLeft = -10
      child2.offsetTop = -10
      child2.width = 300
      child2.height = 300

      child2.style = new CSSStyleDeclaration()
      child2.style.setProperty("position", "absolute")
      child2.appendChild(new BeamTextMock("Some un-sized text just to make the element meaningful"))
      child.appendChild(child2)
    }

    const isParentVisible = BeamElementHelper.isVisible(parent, native.win)
    expect(isParentVisible).toBe(true)
    const isChildVisible = BeamElementHelper.isVisible(child, native.win)
    expect(isChildVisible).toBe(true)
    const isChild2Visible = BeamElementHelper.isVisible(child2, native.win)
    expect(isChild2Visible).toBe(true)

    const area = pnsNativeUI.elementBounds(child2)
    const expected = { x: 50, y: 50, width: 300, height: 300 }
    expect(area).toMatchObject(expected)
  })

  test("overflow escaping on fixed positioned elements", () => {
    // Basically, in order for an absolutely positioned element to appear outside
    // of an element with overflow: hidden, its closest positioned ancestor must
    // also be an ancestor of the element with overflow: hidden.
    // https://css-tricks.com/popping-hidden-overflow/

    const parent = new BeamHTMLElementMock("div")
    {
      parent.offsetLeft = 10
      parent.offsetTop = 10
      parent.width = 100
      parent.height = 100
      parent.style = new CSSStyleDeclaration()
      parent.style.setProperty("overflow", "hidden")
    }

    const child = new BeamHTMLElementMock("div")
    {
      child.offsetLeft = -10
      child.offsetTop = -10
      child.width = 200
      child.height = 200
      child.style = new CSSStyleDeclaration()
      child.appendChild(new BeamTextMock("Some un-sized text just to make the element meaningful"))
      child.style.setProperty("position", "fixed")
      parent.appendChild(child)
    }

    const isParentVisible = BeamElementHelper.isVisible(parent, native.win)
    expect(isParentVisible).toBe(true)
    const isChildVisible = BeamElementHelper.isVisible(child, native.win)
    expect(isChildVisible).toBe(true)

    const area = pnsNativeUI.elementBounds(child)
    const expected = { x: 0, y: 0, width: 200, height: 200 }
    expect(area).toMatchObject(expected)
  })

  test("element bounds are undefined when the element is outside of its overflowing container", () => {
    const parent = new BeamHTMLElementMock("div")
    {
      parent.offsetLeft = 10
      parent.offsetTop = 10
      parent.width = 100
      parent.height = 100

      parent.style = new CSSStyleDeclaration()
      parent.style.setProperty("overflow", "hidden")
    }
    const child = new BeamHTMLElementMock("div")
    {
      child.offsetLeft = -100
      child.offsetTop = -100
      child.width = 50
      child.height = 90
      child.appendChild(new BeamTextMock("Some un-sized text just to make the element meaningful"))
      parent.appendChild(child)
    }

    const isParentVisible = BeamElementHelper.isVisible(parent, native.win)
    expect(isParentVisible).toBe(true)
    const isChildVisible = BeamElementHelper.isVisible(child, native.win)
    expect(isChildVisible).toBe(true)

    const area = pnsNativeUI.elementBounds(parent)
    expect(area).toBeUndefined()
  })

  test("`clip` property resolve to the element bounds when different from `auto`", () => {
    const parent = new BeamHTMLElementMock("div")
    {
      parent.offsetLeft = 10
      parent.offsetTop = 10
      parent.width = 100
      parent.height = 100

      parent.style = new CSSStyleDeclaration()
      parent.style.setProperty("clip", "rect(1px, 10em, 3rem, 2ch)")
    }
    const child = new BeamHTMLElementMock("div")
    {
      child.offsetLeft = -100
      child.offsetTop = -100
      child.width = 500
      child.height = 500
      child.appendChild(new BeamTextMock("Some un-sized text just to make the element meaningful"))
      parent.appendChild(child)
    }

    const isParentVisible = BeamElementHelper.isVisible(parent, native.win)
    expect(isParentVisible).toBe(true)
    const isChildVisible = BeamElementHelper.isVisible(child, native.win)
    expect(isChildVisible).toBe(true)

    const area = pnsNativeUI.elementBounds(parent)
    const expected = { x: 10, y: 10, width: 100, height: 100 }
    expect(area).toMatchObject(expected)

    parent.style.setProperty("clip", "auto")
    const area2 = pnsNativeUI.elementBounds(parent)
    expect(area2).toMatchObject(expected)
  })

  test("`clip-path` property resolve to the element bounds when different from `none`, respectively", () => {
    const parent = new BeamHTMLElementMock("div")
    {
      parent.offsetLeft = 10
      parent.offsetTop = 10
      parent.width = 100
      parent.height = 100

      parent.style = new CSSStyleDeclaration()
      parent.style.setProperty("clip-path", "polygon(50% 0, 100% 50%, 50% 100%, 0 50%)")
    }
    const child = new BeamHTMLElementMock("div")
    {
      child.offsetLeft = -100
      child.offsetTop = -100
      child.width = 500
      child.height = 500
      child.appendChild(new BeamTextMock("Some un-sized text just to make the element meaningful"))
      parent.appendChild(child)
    }

    const isParentVisible = BeamElementHelper.isVisible(parent, native.win)
    expect(isParentVisible).toBe(true)
    const isChildVisible = BeamElementHelper.isVisible(child, native.win)
    expect(isChildVisible).toBe(true)

    const area = pnsNativeUI.elementBounds(parent)
    const expected = { x: 10, y: 10, width: 100, height: 100 }
    expect(area).toMatchObject(expected)

    parent.style.setProperty("clip-path", "none")
    const area2 = pnsNativeUI.elementBounds(parent)
    expect(area2).toMatchObject(expected)
  })
})

describe("parseElementBasedOnStyles", () => {
  const element = new BeamHTMLElementMock("div")
  const { native } = pointAndShootTestBed()

  beforeEach(() => {
    element.offsetLeft = 10
    element.offsetTop = 10
    element.width = 100
    element.height = 100
    element.style = new CSSStyleDeclaration()
  })

  test("background: url('logo.png'); should convert element to img tag", () => {
    element.style.setProperty("background", "url('logo.png')")

    const parsedElement = BeamElementHelper.parseElementBasedOnStyles(element, native.win)
    expect(parsedElement.tagName).toBe("img")
    expect(parsedElement.getAttribute("src")).toBe("logo.png")
  })


  test("background: url('logo.png') no-repeat center center; should convert element to img tag", () => {
    element.style.setProperty("background", "url('logo.png') no-repeat center center")

    const parsedElement = BeamElementHelper.parseElementBasedOnStyles(element, native.win)
    expect(parsedElement.tagName).toBe("img")
    expect(parsedElement.getAttribute("src")).toBe("logo.png")
  })

  test("background-image: url(data:image:gif;base64.....); style should convert to img tag", () => {
    element.style.setProperty("background", "url(data:image/gif;base64,R0lGODlhEAAQAMQAAORHHOVSKudfOulrSOp3WOyDZu6QdvCchPGolfO0o/XBs/fNwfjZ0frl3/zy7////wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACH5BAkAABAALAAAAAAQABAAAAVVICSOZGlCQAosJ6mu7fiyZeKqNKToQGDsM8hBADgUXoGAiqhSvp5QAnQKGIgUhwFUYLCVDFCrKUE1lBavAViFIDlTImbKC5Gm2hB0SlBCBMQiB0UjIQA7)")

    const parsedElement = BeamElementHelper.parseElementBasedOnStyles(element, native.win)
    expect(parsedElement.tagName).toBe("img")
    expect(parsedElement.getAttribute("src")).toBe("data:image/gif;base64,R0lGODlhEAAQAMQAAORHHOVSKudfOulrSOp3WOyDZu6QdvCchPGolfO0o/XBs/fNwfjZ0frl3/zy7////wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACH5BAkAABAALAAAAAAQABAAAAVVICSOZGlCQAosJ6mu7fiyZeKqNKToQGDsM8hBADgUXoGAiqhSvp5QAnQKGIgUhwFUYLCVDFCrKUE1lBavAViFIDlTImbKC5Gm2hB0SlBCBMQiB0UjIQA7")
  })


  test("background: rgba(0, 0, 0, 0) none repeat scroll 0% 0% / auto padding-box border-box; style should not convert", () => {
    element.style.setProperty("background", "rgba(0, 0, 0, 0) none repeat scroll 0% 0% / auto padding-box border-box")

    const parsedElement = BeamElementHelper.parseElementBasedOnStyles(element, native.win)
    expect(parsedElement.tagName).toBe("div")
  })

  test("background-image: none; style should not convert", () => {
    element.style.setProperty("background-image", "none")

    const parsedElement = BeamElementHelper.parseElementBasedOnStyles(element, native.win)
    expect(parsedElement.tagName).toBe("div")
  })

  test("'background-image: linear-gradient(to left, #333, #333 50%, #eee 75%, #333 75%)' style should not convert", () => {
    element.style.setProperty("background", "linear-gradient(to left, #333, #333 50%, #eee 75%, #333 75%)")

    const parsedElement = BeamElementHelper.parseElementBasedOnStyles(element, native.win)
    expect(parsedElement.tagName).toBe("div")
  })
})
