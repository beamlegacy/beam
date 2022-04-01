import { BeamHTMLElement } from "@beam/native-beamtypes"
import {
  BeamDocumentMock,
  BeamDocumentMockDefaults,
  BeamHTMLElementMock,
  BeamResizeObserverMock
} from "@beam/native-testmock"
import { EmbedNode } from "../src/EmbedNode"
import { EmbedNodeUIMock } from "./EmbedNodeUIMock"
import { EmbedNodeWindowMock } from "./EmbedNodeWindowMock"

interface TestBedElement {
  selector: string,
  element: BeamHTMLElementMock
}

/**
 * Create a mock component and mock component UI for test runs
 *
 * @return {*}  {{
 *   component: EmbedNode<EmbedNodeUIMock>
 *   componentUI: EmbedNodeUIMock
 * }}
 */
function testBed(elements?: TestBedElement[]): {
  component: EmbedNode<EmbedNodeUIMock>
  componentUI: EmbedNodeUIMock
} {
  const componentUI = new EmbedNodeUIMock()
  const documentEl = new BeamHTMLElementMock("body")
  elements.forEach(({selector, element}) => {
    documentEl.setQuerySelectorResult(selector, element)
  })
  const docattr = {
    ...BeamDocumentMockDefaults,
    querySelectorAll: (selector) => {
      return documentEl.querySelectorAll(selector)
    },
    querySelector: (selector) => {
      return documentEl.querySelector(selector)
    } 
  }
  const testDocument = new BeamDocumentMock(docattr)
  const windowMock = new EmbedNodeWindowMock(testDocument)
  EmbedNode.instance = null // Allow test suite to instantiate multiple instances
  const component = new EmbedNode(windowMock, componentUI)
  return { component, componentUI }
}

describe("EmbedNode", () => {
  window.ResizeObserver = BeamResizeObserverMock 
  test("toggleTweetTheme", () => {
    const mockElement = new BeamHTMLElementMock("iframe", { src:"https://mock.url.com/?dnt=false&amp;theme=light&amp;width=550px"})
    const elements = [{
      selector: "[data-tweet-id]",
      element: mockElement
    }]
    const { component } = testBed(elements)

    // Toggle theme
    component.toggleTweetTheme("light", "dark")

    // Assert
    const mockElementAfter = component.win.document.querySelector("[data-tweet-id]")
    expect((mockElementAfter as BeamHTMLElement).getAttribute("src")).toBe("https://mock.url.com/?dnt=false&amp;theme=dark&amp;width=550px")
  })
})

