import {PointAndShootUI_native} from "../PointAndShootUI_native"
import {NativeMock} from "../../../../Helpers/Utils/Web/Test/Mock/NativeMock"
import {BeamRange, MessageHandlers} from "../../../../Helpers/Utils/Web/BeamTypes"
import {measure} from "jest-measure"
import { PNSWindowMock } from "./PNSWindowMock"
import {BeamDocumentMock} from "../../../../Helpers/Utils/Web/Test/Mock/BeamDocumentMock"
import {BeamTextMock} from "../../../../Helpers/Utils/Web/Test/Mock/BeamTextMock"
import {BeamHTMLElementMock} from "../../../../Helpers/Utils/Web/Test/Mock/BeamHTMLElementMock"
import {BeamRangeMock} from "../../../../Helpers/Utils/Web/Test/Mock/BeamRangeMock"

describe.skip("Performance Benchmarks: elementBounds", () => {

  const { pnsNativeUI } = pointAndShootTestBed()
  /**
   * This DOM structure only tests the recursion of child elements
   * DOM structure:
   * - div
   * (2000x)
   *   - span 
   *     - some text span
   *     - h1
   *       - some text h1
   *   - p
   *     - some text p 
   */
  measure("Pointing: complex DOM", () => {
    const parent = createComplexTree()
    const t0 = performance.now()
    const _ = pnsNativeUI.elementBounds(parent)
    const t1 = performance.now()
    const time = t1 - t0
    return { time }
  })

  measure("Selection: complex DOM", () => {
    const parent = createComplexTree()
    const range = new BeamRangeMock() as BeamRange
    range.setStart(parent, 2)
    range.setEnd(parent, 3)
    const t0 = performance.now()
    const selectElements = [
      {
        id: "uuid",
        range: range
      }
    ]
    pnsNativeUI.selectBounds(selectElements)
    const t1 = performance.now()
    const time = t1 - t0
    return { time }
  })
  
  /**
   * This DOM structure only tests the recursion of child elements
   * DOM structure:
   * - div
   *     - h1
   *       - some text h1
   *          - h1
   *            - some text h1
   *              (... 200x)
   */
  measure("Pointing: deeply nested DOM", () => {
    const parent = createDeeplyNestedTree()
    const t0 = performance.now()
    const _ = pnsNativeUI.elementBounds(parent)
    const t1 = performance.now()
    const time = t1 - t0
    return { time }
  })

  measure("Selection: deeply nested DOM", () => {
    const parent = createDeeplyNestedTree()
    const range = new BeamRangeMock() as BeamRange
    range.setStart(parent, 2)
    range.setEnd(parent, 3)
    const t0 = performance.now()
    const selectElements = [
      {
        id: "uuid",
        range: range
      }
    ]
    pnsNativeUI.selectBounds(selectElements)
    const t1 = performance.now()
    const time = t1 - t0
    return { time }
  })
  /**
   * This DOM structure only tests the recursion of child elements
   * DOM structure:
   * - div
   *     - h1
   *       - some text h1
   *          - h1
   *            - some text h1
   *              (... 200x)
   */
  measure("Pointing: deeply nested DOM with images", () => {
    const parent = createDeeplyNestedTreeWithImages()
    const t0 = performance.now()
    const _ = pnsNativeUI.elementBounds(parent)
    const t1 = performance.now()
    const time = t1 - t0
    return { time }
  })

  measure("Selection: deeply nested DOM with images", () => {
    const parent = createDeeplyNestedTreeWithImages()
    const range = new BeamRangeMock() as BeamRange
    range.setStart(parent, 2)
    range.setEnd(parent, 3)
    const t0 = performance.now()
    const selectElements = [
      {
        id: "uuid",
        range: range
      }
    ]
    pnsNativeUI.selectBounds(selectElements)
    const t1 = performance.now()
    const time = t1 - t0
    return { time }
  })

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

function createComplexTree() {
  const parent = new BeamHTMLElementMock("div")
  {
    parent.offsetLeft = 10
    parent.offsetTop = 10
    parent.width = 140
    parent.height = 240
  }

  for (let index = 0; index < 200000; index++) {
    const block1 = new BeamHTMLElementMock("h1")
    {
      block1.offsetLeft = 14 * index
      block1.offsetTop = 7 * index
      block1.width = 140 * index
      block1.height = 340 * index
      block1.appendChild(new BeamTextMock("Some text h1"))
    }

    const block2 = new BeamHTMLElementMock("span")
    {
      block2.offsetLeft = 14 * index
      block2.offsetTop = 7 * index
      block2.width = 140 * index
      block2.height = 440 * index
      block2.appendChild(new BeamTextMock("Some text span"))
    }

    block2.appendChild(block1)
    block2.setQuerySelectorResult("h1", block1)

    const block3 = new BeamHTMLElementMock("p")
    {
      block3.offsetLeft = 40 * index
      block3.offsetTop = 70 * index
      block3.width = 140 * index
      block3.height = 540 * index
      block3.appendChild(new BeamTextMock("Some text p"))
    }

    parent.appendChild(block2)
    parent.setQuerySelectorResult("span", block2)
    parent.appendChild(block3)
    parent.setQuerySelectorResult("p", block3)
  }

  return parent
}

function createDeeplyNestedTree() {
  const parent = new BeamHTMLElementMock("div")
  {
    parent.offsetLeft = 10
    parent.offsetTop = 10
    parent.width = 140
    parent.height = 240
  }

  let lastChild = parent
  for (let index = 0; index < 200; index++) {
    const block1 = new BeamHTMLElementMock("h1")
    parent.setQuerySelectorResult("h1", block1)
    block1.offsetLeft = 14 * index
    block1.offsetTop = 7 * index
    block1.width = 140 * index
    block1.height = 340 * index
    block1.appendChild(new BeamTextMock(`child #${index}`))

    lastChild.appendChild(block1)
    lastChild = block1
  }

  return parent
}

function createDeeplyNestedTreeWithImages() {
  const parent = new BeamHTMLElementMock("div")
  {
    parent.offsetLeft = 10
    parent.offsetTop = 10
    parent.width = 140
    parent.height = 240
  }

  let lastChild = parent
  for (let index = 0; index < 200; index++) {
    const block1 = new BeamHTMLElementMock("h1")
    parent.setQuerySelectorResult("h1", block1)
    block1.offsetLeft = 14 * index
    block1.offsetTop = 7 * index
    block1.width = 140 * index
    block1.height = 340 * index
    block1.appendChild(new BeamTextMock(`child #${index}`))

    lastChild.appendChild(block1)
    lastChild = block1
  }

  for (let index = 0; index < 5; index++) {
    const img = new BeamHTMLElementMock("img")
    parent.setQuerySelectorResult("img", img)
    parent.appendChild(img)
  }
  return parent
}

})
