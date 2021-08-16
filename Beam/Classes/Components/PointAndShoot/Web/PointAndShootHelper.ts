import {
  BeamElement,
  BeamNode,
  BeamNodeType,
  BeamText,
  BeamWindow
} from "./BeamTypes"
import {BeamElementHelper} from "./BeamElementHelper"
import { Util } from "./Util"

export class PointAndShootHelper {
  /**
   * Returns whether or not a text is deemed useful enough as a single unit
   * we should be very cautious with what we filter out, so instead of relying
   * on the text length > 1 char we're just having a blacklist of characters
   *
   * @param text
   */
  static isTextMeaningful(text: string): boolean {
    if (text) {
      const trimmed = text.trim()
      return !!trimmed && ![
        "•", "-", "|", "–", "—", "·"
      ].includes(trimmed)
    }
    return false
  }

  /**
   * Checks if an element meets the requirements to be considered meaningful
   * to be included within the highlighted area. An element is meaningful if
   * it's visible and if it's either an image or it has at least some actual
   * text content
   *
   * @param element
   * @param win
   */
  static isMeaningful(element: BeamElement, win: BeamWindow): boolean {
    return (
        (
            BeamElementHelper.isMedia(element)
            || BeamElementHelper.isImageContainer(element, win)
            || PointAndShootHelper.isTextMeaningful(BeamElementHelper.getTextValue(element))
        )
        && BeamElementHelper.isVisible(element, win)
    )
  }

  /**
   * Recursively check for the presence of any meaningful child nodes within a given element
   *
   * @static
   * @param {BeamElement} element The Element to query
   * @param {BeamWindow} win
   * @return {*}  {boolean} Boolean if element or any of it's children are meaningful
   * @memberof PointAndShootHelper
   */
  static isMeaningfulOrChildrenAre(element: BeamElement, win: BeamWindow): boolean {
    if (PointAndShootHelper.isMeaningful(element, win)) {
      return true
    }
    return [...element.children].some(
        child => PointAndShootHelper.isMeaningful(child, win)
    )
  }

  /**
   * Recursively check for the presence of any meaningful child nodes within a given element. 
   *
   * @static
   * @param {BeamElement} element The Element to query
   * @param {BeamWindow} win
   * @return {*}  {BeamNode[]} return the element's meaningful child nodes
   * @memberof PointAndShootHelper
   */
  static getMeaningfulChildNodes(element: BeamElement, win: BeamWindow): BeamNode[] {
    return [...element.childNodes].filter(
        child => (
            child.nodeType === BeamNodeType.element
            && PointAndShootHelper.isMeaningfulOrChildrenAre(child as BeamElement, win)
        ) || (
            child.nodeType === BeamNodeType.text
            && PointAndShootHelper.isTextMeaningful((child as BeamText).data)
        )
    )
  }

  /**
   * Recursively check for the presence of any Useless child nodes within a given element
   *
   * @static
   * @param {BeamElement} element The Element to query
   * @param {BeamWindow} win
   * @return {*}  {boolean} Boolean if element or any of it's children are Useless
   * @memberof PointAndShootHelper
   */
  static isUselessOrChildrenAre(element: BeamElement, win: BeamWindow): boolean {
    return PointAndShootHelper.isMeaningfulOrChildrenAre(element, win) == false
  }

  /**
   * Get all child nodes of type element or text
   *
   * @static
   * @param {BeamElement} element
   * @param {BeamWindow} win
   * @return {*}  {BeamNode[]}
   * @memberof PointAndShootHelper
   */
  static getChildNodes(element: BeamElement, win: BeamWindow): BeamNode[] {
    if (!element?.childNodes) {
      return [element]
    }
    // Filter childNodes down to the nodes we want.
    let childNodes = [...element.childNodes].filter(child => {
      return child.nodeType === (BeamNodeType.element || BeamNodeType.text)
    })

    // if no useless child nodes return the element itself
    if (childNodes.length == 0) {
      return [element]
    }

    // map through the nodes we have
    childNodes.forEach((node) => {
      // For element nodes we should get their children
      if (node.nodeType === BeamNodeType.element) {
        const nodes = this.getChildNodes(node as BeamElement, win)
        childNodes = [...childNodes, ...nodes]
      }

      // any others return the node
      childNodes.push(node)
    })

    return Util.compact(childNodes)
  }
}
