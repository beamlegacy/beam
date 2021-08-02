import { PointAndShootUI } from "./PointAndShootUI"
import { Native } from "./Native"
import { WebEventsUI_native } from "./WebEventsUI_native"
import { BeamElement, BeamNodeType, BeamRect, BeamRange, BeamRangeGroup, BeamShootGroup } from "./BeamTypes"
import { BeamElementHelper } from "./BeamElementHelper"
import { BeamRectHelper } from "./BeamRectHelper"
import { PointAndShootHelper } from "./PointAndShootHelper"
import { dequal as isDeepEqual } from "dequal"

export class PointAndShootUI_native extends WebEventsUI_native implements PointAndShootUI {
  /**
   * @param native {Native}
   */
  constructor(native: Native) {
    super(native)
    this.datasetKey = `${this.prefix}Collect`
  }
  protected prefix = "__ID__"
  datasetKey

  pointPayload = {}
  pointBounds(pointTarget?: BeamShootGroup) {
    if (!pointTarget) {
      return
    }
    const { id, element } = pointTarget
    const rect = this.elementBounds(element)

    const payload = {
      point: { id, rect, html: element.outerHTML }
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
      const rect = this.elementBounds(element)
      return { id, rect, html: element.outerHTML }
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
  selectBounds(rangeGroups: BeamRangeGroup[]) {
    if (!rangeGroups) {
      return
    }

    const rects = []
    rangeGroups.forEach((group) => {
      const { id, range } = group
      // Get the rectangles that make up the range
      const rangeRects = Array.from(range.getClientRects())
      const rectData = rangeRects.map((rangeRect, rectIndex) => {
        // add each rect to the targets array
        return {
          id: `${id}-${rectIndex}`,
          html: this.rangeToHtml(range),
          rect: {
            x: rangeRect.x,
            y: rangeRect.y,
            width: rangeRect.width,
            height: rangeRect.height
          }
        }
      })

      rects.push({ id, rectData })
    })

    const payload = { select: rects }
    if (!isDeepEqual(this.selectPayload, payload)) {
      this.selectPayload = payload
      this.native.sendMessage("selectBounds", payload)
    }
  }

  hasSelection(hasSelection: boolean) {
    this.native.sendMessage("hasSelection", { hasSelection })
  }
  
  isTypingOnWebView(isTypingOnWebView: boolean): void {
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
   * the sum of all child node bounds is used instead (recursively)
   *
   * Supported child node types are:
   *  - Element
   *  - Text
   *  See: https://developer.mozilla.org/en-US/docs/Web/API/Node/nodeType
   *
   * @param {BeamElement} el
   * @param {BeamRect} area
   * @param clippingArea
   * @return {*} {BeamRect}
   * @memberof PointAndShootUI_native
   */
  elementBounds(el: BeamElement, area?: BeamRect, clippingArea?: BeamRect): BeamRect {
    const {win} = this.native

    // Find svg root if any and use it for bounds calculation
    const svgRoot = BeamElementHelper.getSvgRoot(el)
    if (svgRoot) {
      el = svgRoot
    }

    // Make sure the element has something we're interested in
    if (!PointAndShootHelper.isMeaningfulOrChildrenAre(el, win)) {
      return
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
    // check if the whole tree contains more than 50 html elements
    if (childElementTreeCount > 50) {
      const area = el.getBoundingClientRect()
      return this.setArea(area, area, clippingArea)
    }
    // check if the direct childNodes (this includes text nodes) are more than 50
    const childNodes = PointAndShootHelper.getMeaningfulChildNodes(el, win)
    // Filter useful childNodes
    if (childNodes.length > 50) {
      const area = el.getBoundingClientRect()
      return this.setArea(area, area, clippingArea)
    }

    // If it's an image or media, select the whole element
    const selectWholeElement = BeamElementHelper.isImage(el, win) || BeamElementHelper.isMedia(el)

    // We have meaningful children, inspect them and compute their bounds
    if (childNodes.length > 0 && !selectWholeElement) {
      for (const child of childNodes) {
        switch (child.nodeType) {
          case BeamNodeType.element: {
            const childElement = child as BeamElement
            if (childElement.tagName.toLowerCase() === "svg") {
              const childBounds = childElement.getBoundingClientRect()
              area = this.setArea(area, childBounds, clippingArea)
            } else {
              const bounds = this.elementBounds(childElement, area, clippingArea)
              area = this.setArea(area, bounds, clippingArea)
            }
          }
            break
          case BeamNodeType.text: {
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

      return area
    }

    // No meaningful childNodes, check the element itself
    if (PointAndShootHelper.isMeaningful(el, win)) {
      const elementBounds = el.getBoundingClientRect()
      area = this.setArea(area, elementBounds, clippingArea)
    }

    return area
  }
}
