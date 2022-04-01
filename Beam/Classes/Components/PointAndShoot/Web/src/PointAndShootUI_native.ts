import {PointAndShootUI} from "./PointAndShootUI"
import {
  BeamElement,
  BeamElementBounds,
  BeamHTMLElement,
  BeamNodeType,
  BeamRange,
  BeamRangeGroup,
  BeamRect,
  BeamShootGroup,
  MessageHandlers,
  Native
} from "@beam/native-beamtypes"
import {BeamElementHelper, BeamRectHelper, BeamEmbedHelper, PointAndShootHelper} from "@beam/native-utils"
import {dequal as isDeepEqual} from "dequal"

export class PointAndShootUI_native implements PointAndShootUI {
  native
  /**
   * @param native {Native}
   */
  constructor(native: Native<MessageHandlers>) {
    this.native = native
    this.datasetKey = `${this.prefix}Collect`
    this.embedHelper = new BeamEmbedHelper(native.win)
  }
  prefix = "__ID__"
  datasetKey
  embedHelper: BeamEmbedHelper

  pointPayload = {}
  pointBounds(pointTarget?: BeamShootGroup) {
    if (!pointTarget) {
      return
    }
    const { id, element } = pointTarget
    const { rect } = this.elementBounds(element)
    
    const payload = {
      point: { 
        id, 
        rect
      }
    }

    if (!isDeepEqual(this.pointPayload, payload)) {
      this.pointPayload = payload
      this.native.sendMessage("pointBounds", payload)
    }
  }

  shootPayload = {}
  shootBounds(shootTargets: BeamShootGroup[]) {
    if (!shootTargets) {
      return
    }

    const targets = shootTargets.map(({ id, element }) => {
      const {element: boundsElement, rect} = this.elementBounds(element)
      return { 
        id, 
        rect, 
        html: this.getHtml(boundsElement),
        text: (<BeamHTMLElement>boundsElement).innerText ?? ""
      }
    }).filter(target => {
      if (Boolean(target.rect) == false) {
        // remove group from swift when no rect can be calculated
        this.native.sendMessage("dismissShootGroup", { id: target.id })
      }
      
      return Boolean(target.rect)
    })

    const payload = {
      shoot: targets
    }

    // only update targets when they are different than before
    if (!isDeepEqual(this.shootPayload, payload)) {
      this.shootPayload = payload
      this.native.sendMessage("shootBounds", payload)
    }
  }

  selectPayload = {}
  private getHtml(element: BeamHTMLElement | BeamElement): string {
    const { win } = this.native
    const parsedElement = BeamElementHelper.parseElementBasedOnStyles(element, win)
    return parsedElement.outerHTML
  }

  selectBounds(rangeGroups: BeamRangeGroup[]): void {
    const {win} = this.native

    if (!rangeGroups) {
      return
    }

    const rects = []
    rangeGroups.forEach((group) => {
      const { id, range } = group
      // Get the rectangles that make up the range
      let rangeRects = Array.from(range.getClientRects()) as BeamRect[]

      const parent = range.commonAncestorContainer as BeamElement

      // Get all childNotes directly under the parent
      const parentChildNodes = parent?.childNodes ?? []

      const arrayOfRectsToDismiss = []
      // For performance reasons, We want to skip doing complex calculations for a large number of childNotes.
      // This can happen when the commonAncestorContainer is a wrappen element around a large DOM.
      // 
      // When a parent element contains a large amount of direct childNodes under
      // Skip removing useless rects and use all of the rects provided to us.
      if (parentChildNodes.length < 150) {
        const childNodes = PointAndShootHelper.getElementAndTextChildNodesRecursively(parent, win)
        // For performance reasons, if we have a large amount of childNodes
        // Skip removing useless rects and use all of the rects provided to us
        if (childNodes.length < 150) {
          for (const child of childNodes) {
            switch (child?.nodeType) {
              case BeamNodeType.element: {
                const childElement = child as BeamElement
                if (PointAndShootHelper.isUselessOrChildrenAre(childElement, win)) {
                  const bounds = childElement.getBoundingClientRect() as BeamRect
                  // getBoundingClientRect takes the visual size. 
                  // scrollHeight and scrollWidth gets the actual size of the elements
                  bounds.height = childElement.scrollHeight
                  bounds.width = childElement.scrollWidth
                  arrayOfRectsToDismiss.push(bounds)
                }
              }
                break
            }
          }
        }
      }
      
      if (arrayOfRectsToDismiss.length > 0) {
        // By matching the areas of useless rects with the rangeRects, we can filter out the rects we don't need.
        rangeRects = BeamRectHelper.filterRectArrayByRectArray(rangeRects, arrayOfRectsToDismiss) 
      }

      const rectData = rangeRects.map((rangeRect, rectIndex) => {
        // add each rect to the targets array
        return {
          id: `${id}-${rectIndex}`,
          html: "",
          rect: {
            x: rangeRect.x,
            y: rangeRect.y,
            width: rangeRect.width,
            height: rangeRect.height
          }
        }
      })

      const rangeContents = range.cloneContents()
      rects.push({ id, rectData, html: this.rangeToHtml(range), text: rangeContents.textContent })
    })
    
    const payload = { select: rects }
    if (!isDeepEqual(this.selectPayload, payload)) {
      this.selectPayload = payload
      this.native.sendMessage("selectBounds", payload)
    }
  }

  clearSelection(id: string): void {
    this.native.sendMessage("clearSelection", { id })
  }

  hasSelection(hasSelection: boolean): void {
    this.native.sendMessage("hasSelection", { hasSelection })
  }
  
  typingOnWebView(isTypingOnWebView: boolean): void {
    this.native.sendMessage("isTypingOnWebView", { isTypingOnWebView })
  }

  private rangeToHtml(range: BeamRange) {
    return Array.prototype.reduce.call(
      range.cloneContents().childNodes,
      (result, node) => result + (node.outerHTML || node.nodeValue),
      ""
    )
  }

  /**
   * Update a given area's bounds with it's bounds and containerBounds
   *
   * @private
   * @param {*} area
   * @param {*} bounds
   * @param clippingArea
   * @return {*} {BeamRect}
   * @memberof PointAndShootUI_native
   */
  private setArea(area, bounds, clippingArea): BeamRect {
    let newArea

    if (area && bounds) {
      newArea = BeamRectHelper.boundingRect(area, bounds)
    } else if (bounds) {
      // No previous area, use bounds
      const {x, y, width, height} = bounds
      newArea = {x, y, width, height}
    }

    if (newArea && clippingArea) {
      newArea = BeamRectHelper.intersection(newArea, clippingArea)
    }

    return newArea
  }
  /**
   * Gets the visual bounds of a given element. If the element contains child nodes,
   * the sum of all child node bounds is used instead (recursively). If no meaningful elements
   * are found recurse upwards in the DOM.
   *
   * Supported child node types are:
   *  - Element
   *  - Text
   *  See: https://developer.mozilla.org/en-US/docs/Web/API/Node/nodeType
   *
   * @param {(BeamHTMLElement | BeamElement)} el
   * @param {BeamRect} [area]
   * @param {BeamRect} [clippingArea]
   * @param {number} [count=5]
   * @return {*}  {BeamElementBounds}
   * @memberof PointAndShootUI_native
   */
  elementBounds(el: BeamHTMLElement | BeamElement, area?: BeamRect, clippingArea?: BeamRect, count = 5): BeamElementBounds {
    const {win} = this.native

    // If we are inside an embeddable iframe, collect the whole frame
    if (this.embedHelper.isOnFullEmbeddablePage()) {
      const { width, height } = win.visualViewport
      return {
        element: el,
        rect: {
          x: 0,
          y: 0,
          width,
          height
        }
      }
    }
    // Find svg root if any and use it for bounds calculation
    const svgRoot = BeamElementHelper.getSvgRoot(el)
    if (svgRoot) {
      el = svgRoot
    }

    const bounds = el.getBoundingClientRect()
    // If we have a too large element, exit early
    if (BeamElementHelper.isLargerThanWindow(bounds, win)) {
      return {
        element: el,
        rect: area
      }
    }

    // Make sure the element has something we're interested in, otherwise recurse up to the parent element. 
    // If after 5 levels no meaningful element is found exit.
    if (!PointAndShootHelper.isMeaningfulOrChildrenAre(el, win)) {
      if (count >= 0 && Boolean(el.parentElement)) {
        const newCount = count--
        return this.elementBounds(el.parentElement, area, clippingArea, newCount)
      }
      return {
        element: el,
        rect: area
      }
    }

    // Get clipping area if previously undefined
    const computeClippingArea = el !== win.document.body && el !== win.document.documentElement
    if (!clippingArea && computeClippingArea) {
      const clippingContainers = BeamElementHelper.getClippingContainers(el, win)
      if (clippingContainers && clippingContainers.length > 0) {
        clippingArea = BeamElementHelper.getClippingArea(clippingContainers, win)
      }
    }

    const childElementTreeCount = el.querySelectorAll("*").length
    // For performance reasons, if an element contains a large DOM
    // return early with the simple element rect
    // check if the whole tree contains more than 150 html elements
    if (childElementTreeCount > 150) {
      return {
        element: el,
        rect: this.setArea(area, bounds, clippingArea)
      }
    }
    // check if the direct childNodes (this includes text nodes) are more than 150
    const childNodes = PointAndShootHelper.getMeaningfulChildNodes(el, win)
    // Filter useful childNodes
    if (childNodes.length > 150) {
      return {
        element: el,
        rect: this.setArea(area, bounds, clippingArea)
      }
    }

    // If it's an image or media, select the whole element
    const selectWholeElement = BeamElementHelper.isImage(el, win) || BeamElementHelper.isMedia(el) || this.embedHelper.isEmbeddableElement(el)

    // We have meaningful children, inspect them and compute their bounds
    if (childNodes.length > 0 && !selectWholeElement) {
      for (const child of childNodes) {
        switch (child.nodeType) {
          case BeamNodeType.element: {
            const childElement = child as BeamElement
            // If we have an SVG element return the SVG bounding rect
            if (childElement.tagName.toLowerCase() === "svg") {
              const childBounds = childElement.getBoundingClientRect()
              area = this.setArea(area, childBounds, clippingArea)
            } else {
              // For any other element recursively call `elementBounds`
              if (count >= 0) {
                const newCount = count--
                const { rect } = this.elementBounds(childElement, area, clippingArea, newCount)
                area = this.setArea(area, rect, clippingArea)
              }
            }
          }
            break
          case BeamNodeType.text: {
            // For text get the text bounding rect by creating selection.
            const nodeRange = win.document.createRange()
            nodeRange.selectNode(child)
            const rangeBounds = nodeRange.getBoundingClientRect()
            if (rangeBounds.width > 0 && rangeBounds.height > 0) {
              area = this.setArea(area, rangeBounds, clippingArea)
            }
          }
            break
        }
      }

      return {
        element: el,
        rect: area
      }
    }

    // No meaningful childNodes, check the element itself
    if (PointAndShootHelper.isMeaningful(el, win)) {
      area = this.setArea(area, bounds, clippingArea)
    }

    return {
      element: el,
      rect: area
    }
  }
}
