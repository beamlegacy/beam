import {
  BeamElement,
  BeamHTMLElement,
  BeamMouseLocation,
  BeamNode,
  BeamNodeType,
  BeamRange,
  BeamRangeGroup,
  BeamSelection,
  BeamShootGroup,
  BeamText,
  BeamWindow
} from "../../../Helpers/Utils/Web/BeamTypes"
import { BeamElementHelper } from "../../../Helpers/Utils/Web/BeamElementHelper"

export class PointAndShootHelper {
  /**
   * Check if string matches any items in array of strings. For a minor performance
   * improvement we check first if the string is a single character.
   *
   * @static
   * @param {string} text
   * @return {*}  {boolean} true if text matches
   * @memberof PointAndShootHelper
   */
  static isOnlyMarkupChar(text: string): boolean {
    if (text.length == 1) {
      return ["•", "-", "|", "–", "—", "·"].includes(text)
    } else {
      return false
    }
  }
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
      return !!trimmed && !this.isOnlyMarkupChar(trimmed)
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
      (BeamElementHelper.isEmbed(element, win) ||
        BeamElementHelper.isMedia(element) ||
        BeamElementHelper.isImageContainer(element, win) ||
        PointAndShootHelper.isTextMeaningful(BeamElementHelper.getTextValue(element))) &&
      BeamElementHelper.isVisible(element, win)
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
    return [...element.children].some((child) => PointAndShootHelper.isMeaningful(child, win))
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
      (child) =>
        (child.nodeType === BeamNodeType.element &&
          PointAndShootHelper.isMeaningfulOrChildrenAre(child as BeamElement, win)) ||
        (child.nodeType === BeamNodeType.text && PointAndShootHelper.isTextMeaningful((child as BeamText).data))
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
  static getElementAndTextChildNodesRecursively(element: BeamElement, win: BeamWindow): BeamNode[] {
    if (!element?.childNodes) {
      return [element]
    }

    const nodes = [];

    [...element.childNodes].forEach((child) => {
      switch (child.nodeType) {
        case BeamNodeType.element:
          nodes.push(child)
          // eslint-disable-next-line no-case-declarations
          const childNodesOfChild = this.getElementAndTextChildNodesRecursively(child as BeamElement, win)
          nodes.push(...childNodesOfChild)
          break
        case BeamNodeType.text:
          nodes.push(child)
          break
        default:
          break
      }
    })

    if (nodes.length == 0) {
      return [element]
    }

    return nodes
  }

  /**
   * Returns true if only the altKey is pressed. Alt is equal to Option is MacOS.
   *
   * @static
   * @param {*} ev
   * @return {*}  {boolean}
   * @memberof PointAndShootHelper
   */
  static isOnlyAltKey(ev): boolean {
    const altKey = ev.altKey || ev.key == "Alt"
    return altKey && !ev.ctrlKey && !ev.metaKey && !ev.shiftKey
  }

  static upsertShootGroup(newItem: BeamShootGroup, groups: BeamShootGroup[]): void {
    // Update existing rangeGroup
    const index = groups.findIndex(({ element }) => {
      return element == newItem.element
    })
    if (index != -1) {
      groups[index] = newItem
    } else {
      groups.push(newItem)
    }
  }

  static upsertRangeGroup(newItem: BeamRangeGroup, groups: BeamRangeGroup[]): void {
    // Update existing rangeGroup
    const index = groups.findIndex(({ id }) => {
      return id == newItem.id
    })
    if (index != -1) {
      groups[index] = newItem
    } else {
      groups.push(newItem)
    }
  }
  /**
   * Returns true when the target has `contenteditable="true"` or `contenteditable="plaintext-only"`
   *
   * @static
   * @param {BeamHTMLElement} target
   * @return {*}  {boolean}
   * @memberof PointAndShootHelper
   */
  static isExplicitlyContentEditable(target: BeamHTMLElement): boolean {
    return ["true", "plaintext-only"].includes(BeamElementHelper.getContentEditable(target))
  }
  /**
   * Check for inherited contenteditable attribute value by traversing
   * the ancestors until an explicitly set value is found
   *
   * @param element {(BeamNode)} The DOM node to check.
   * @return If the element inherits from an actual contenteditable valid values
   *         ("true", "plaintext-only")
   */
  static getInheritedContentEditable(element: BeamHTMLElement): boolean {
    let isEditable = this.isExplicitlyContentEditable(element)
    const parent = element.parentElement as BeamHTMLElement
    if (parent && BeamElementHelper.getContentEditable(element) === "inherit") {
      isEditable = this.getInheritedContentEditable(parent)
    }
    return isEditable
  }
  /**
   * Returns true when target is a text input. Specificly when either of these conditions is true:
   *  - The target is an text <input> tag
   *  - The target or it's parent element is contentEditable
   *
   * @static
   * @param {BeamHTMLElement} target
   * @return {*}  {boolean}
   * @memberof PointAndShootHelper
   */
  static isTargetTextualInput(target: BeamHTMLElement): boolean {
    return BeamElementHelper.isTextualInputType(target) || this.getInheritedContentEditable(target)
  }

  /**
   * Returns true when the Target element is the activeElement. It always returns false when the target Element is the document body.
   *
   * @static
   * @param {BeamWindow} win
   * @param {BeamHTMLElement} target
   * @return {*}  {boolean}
   * @memberof PointAndShootHelper
   */
  static isEventTargetActive(win: BeamWindow, target: BeamHTMLElement): boolean {
    return !!(
      win.document.activeElement &&
      win.document.activeElement !== win.document.body &&
      win.document.activeElement.contains(target)
    )
  }
  /**
   * Returns true when the Target Text Element is the activeElement (The current element with "Focus")
   *
   * @static
   * @param {BeamWindow} win
   * @param {BeamHTMLElement} target
   * @return {*}  {boolean}
   * @memberof PointAndShootHelper
   */
  static isActiveTextualInput(win: BeamWindow, target: BeamHTMLElement): boolean {
    return this.isEventTargetActive(win, target) && this.isTargetTextualInput(target)
  }
  /**
   * Checks if the MouseLocation Coordinates has changed from the provided X or Y Coordinates. Returns true when either X or Y is different
   *
   * @static
   * @param {BeamMouseLocation} mouseLocation
   * @param {number} clientX
   * @param {number} clientY
   * @return {*}  {boolean}
   * @memberof PointAndShootHelper
   */
  static hasMouseLocationChanged(mouseLocation: BeamMouseLocation, clientX: number, clientY: number): boolean {
    return mouseLocation?.x !== clientX || mouseLocation?.y !== clientY
  }
  /**
   * Returns true when the current document has an Text Input or ContentEditable element as activeElement (The current element with "Focus")
   *
   * @static
   * @param {BeamWindow} win
   * @return {*}  {boolean}
   * @memberof PointAndShootHelper
   */
  static hasFocusedTextualInput(win: BeamWindow): boolean {
    const target = win.document.activeElement as unknown as BeamHTMLElement
    if (target) {
      return  BeamElementHelper.isTextualInputType(target) || this.getInheritedContentEditable(target)
    } else {
      return false
    }
  }
  /**
   * Returns true when Pointing should be disabled. It checks if any of the following is true:
   *  - The event is on an active Text Input
   *  - The document has a focussed Text Input
   *  - The document has an active Text Selection
   *
   * @static
   * @param {BeamWindow} win
   * @param {BeamHTMLElement} target
   * @return {*}  {boolean}
   * @memberof PointAndShootHelper
   */
  static isPointDisabled(win: BeamWindow, target: BeamHTMLElement): boolean {
    return this.isActiveTextualInput(win, target) || this.hasFocusedTextualInput(win) || this.hasSelection(win)
  }
  /**
   * Returns boolean if document has active selection
   */
  static hasSelection(win: BeamWindow): boolean {
    return Boolean(win.document.getSelection().toString())
  }
  /**
   * Returns an array of ranges for a given HTML selection
   *
   * @param {BeamSelection} selection
   * @return {*}  {BeamRange[]}
   */
  static getSelectionRanges(selection: BeamSelection): BeamRange[] {
    const ranges = []
    const count = selection.rangeCount
    for (let index = 0; index < count; ++index) {
      const range = selection.getRangeAt(index)
      ranges.push(range)
    }
    return ranges
  }
  /**
   * Returns the current active (text) selection on the document
   *
   * @return {BeamSelection}
   */
  static getSelection(win: BeamWindow): BeamSelection {
    return win.document.getSelection()
  }
  /**
   * Returns the HTML element under the current Mouse Location Coordinates
   *
   * @static
   * @param {BeamWindow} win
   * @param {BeamMouseLocation} mouseLocation
   * @return {*}  {BeamHTMLElement}
   * @memberof PointAndShootHelper
   */
  static getElementAtMouseLocation(win: BeamWindow, mouseLocation: BeamMouseLocation): BeamHTMLElement {
    return win.document.elementFromPoint(mouseLocation.x, mouseLocation.y)
  }
}
