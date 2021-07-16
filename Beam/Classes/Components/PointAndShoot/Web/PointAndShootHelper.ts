import {
  BeamElement,
  BeamHTMLElement,
  BeamHTMLInputElement,
  BeamNode,
  BeamNodeType,
  BeamText,
  BeamWindow
} from "./BeamTypes";
import {BeamElementHelper} from "./BeamElementHelper";

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
        || PointAndShootHelper.isTextMeaningful( BeamElementHelper.getTextValue(element) )
      )
      && BeamElementHelper.isVisible(element, win)
    )
  }

  /**
   * Recursively check for the presence of any meaningful child nodes within a given element
   *
   * @param element
   * @param win
   */
  static isMeaningfulOrChildrenAre(element: BeamElement, win: BeamWindow): boolean {
    if (PointAndShootHelper.isMeaningful(element, win)) {
      return true
    }
    return [...element.children].some(
      child => PointAndShootHelper.isMeaningful(child, win)
    )
  }

  static getMeaningfulChildNodes(element: BeamElement, win: BeamWindow): BeamNode[] {
    return [...element.childNodes].filter(
      child => (
        child.nodeType === BeamNodeType.element
        && PointAndShootHelper.isMeaningfulOrChildrenAre(child as BeamElement, win)
      ) || (
        child.nodeType === BeamNodeType.text
        && PointAndShootHelper.isTextMeaningful( (child as BeamText).data )
      )
    )
  }
}