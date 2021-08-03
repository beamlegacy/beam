import { WebEvents } from "./WebEvents"
import { PointAndShootUI } from "./PointAndShootUI"
import {
  BeamWindow,
  BeamSelection,
  BeamRange,
  BeamHTMLElement,
  BeamElement,
  BeamRangeGroup,
  BeamShootGroup
} from "./BeamTypes"
import { Util } from "./Util"
import { WebFactory } from "./WebFactory"
import { BeamMouseEvent, BeamUIEvent } from "./Test/BeamMocks"
import { BeamElementHelper } from "./BeamElementHelper"

/**
 * Listen to events that hover and select web blocks with Option.
 */
export class PointAndShoot extends WebEvents<PointAndShootUI> {
  /**
   * Singleton.
   */
  static instance: PointAndShoot

  /**
   * @type string
   */
  datasetKey: string

  /**
   * Amount of time we want the user to touch before we do something
   */
  timer
  touchDuration = 2500
  mouseLocation = { x: 0, y: 0 }
  selectionUUID?: string
  pointTarget: BeamShootGroup
  shootTargets: BeamShootGroup[] = []
  selectionRangeGroups: BeamRangeGroup[] = []
  isTypingOnWebView = false

  /**
   *
   * @param win {BeamWindow}
   * @param ui {PointAndShootUI}
   * @param webFactory
   * @return {PointAndShoot}
   */
  static getInstance(win: BeamWindow, ui: PointAndShootUI, webFactory: WebFactory): PointAndShoot {
    if (!PointAndShoot.instance) {
      PointAndShoot.instance = new PointAndShoot(win, ui, webFactory)
    }
    return PointAndShoot.instance
  }

  /**
   * @param win {(BeamWindow)}
   * @param ui {PointAndShootUI}
   * @param webFactory
   */
  constructor(win: BeamWindow, ui: PointAndShootUI, webFactory: WebFactory) {
    super(win, ui, webFactory)
    this.datasetKey = `${this.prefix}Collect`
    this.selectionUUID = Util.uuid(win)
  }

  setWindow(win: BeamWindow): void {
    super.setWindow(win)
    this.log("setWindow")

    win.addEventListener("mousemove", this.onMouseMove.bind(this))
    win.addEventListener("click", this.onClick.bind(this), true)
    win.addEventListener("touchstart", this.onTouchstart.bind(this), false)
    win.addEventListener("touchend", this.onTouchend.bind(this), false)
    win.addEventListener("keydown", this.onKeyDown.bind(this), false)
    win.addEventListener("mouseup", this.onMouseUp.bind(this))
    win.document.addEventListener("selectionchange", () => this.onSelection())
    win.addEventListener("scroll", this.onScroll.bind(this), true)
    this.log("events registered")

    win.addEventListener("resize", this.onResize.bind(this), true)
    win.addEventListener("orientationchange", this.onResize.bind(this), true)

    const vv = win.visualViewport
    vv.addEventListener("onresize", this.onResize.bind(this))
    vv.addEventListener("scroll", this.onResize.bind(this))
  }

  log(...args: unknown[]): void {
    console.log(this.toString(), args)
  }

  sendBounds(): void {
    // First send frame positioning
    this.sendFramesInfo()
    // Second send Boolean flags
    this.ui.hasSelection(this.hasSelection())
    this.ui.isTypingOnWebView(this.isTypingOnWebView)
    // Lastly send positioning bounds
    // When we have an active selection we don't want to update any other bounds
    if (!this.hasSelection()) {
      this.ui.pointBounds(this.pointTarget)
      this.ui.shootBounds(this.shootTargets)
    }
    this.ui.selectBounds(this.selectionRangeGroups)
  }

  shoot(targetEl: BeamHTMLElement): void {
    const shootGroup = {
      id: Util.uuid(this.win),
      element: targetEl
    }
    this.upsertShootGroup(shootGroup, this.shootTargets)
    this.sendBounds()
  }

  point(targetEl: BeamHTMLElement): void {
    // only assign new pointTarget when pointTarget is different
    if (this.pointTarget?.element != targetEl) {
      this.pointTarget = {
        id: Util.uuid(this.win),
        element: targetEl
      }
    }

    this.sendBounds()
  }

  select(): void {
    const selection = this.getSelection()
    // reset the uuid to store a new selection next time
    if (selection.rangeCount == 0) { return }
    if (selection.isCollapsed) {
      this.selectionUUID = Util.uuid(this.win)
    }
    // Rangecount is always array of 1, unless programatically modified
    // https://developer.mozilla.org/en-US/docs/Web/API/Selection/rangeCount
    const range = selection.getRangeAt(0)

    const rangeGroup: BeamRangeGroup = {
      id: this.selectionUUID,
      range: range as BeamRange
    }

    this.upsertRangeGroup(rangeGroup, this.selectionRangeGroups)

    this.sendBounds()
  }

  /**
   * Returns boolean if document has active selection
   */
  hasSelection(): boolean {
    return Boolean(this.win.document.getSelection().toString())
  }

  /**
   * ======================================================================
   * Eventlisteners =======================================================
   * ======================================================================
   */

  onScroll(ev: BeamUIEvent): void {
    this.sendBounds()
    if (this.mouseLocation?.x) {
      if (!this.isPointDisabled(ev)) {
        const target = this.win.document.elementFromPoint(this.mouseLocation.x, this.mouseLocation.y)
        this.point(target)
      }
    }
  }

  onMouseMove(ev: BeamMouseEvent): void {
    if (this.mouseLocation?.x !== ev.clientX || this.mouseLocation?.y !== ev.clientY) {
      // Code when the (physical) mouse actually moves
      if (!this.isPointDisabled(ev)) {
        this.point(ev.target)
        this.isTypingOnWebView = false
      }
    }
    this.mouseLocation.x = ev.clientX
    this.mouseLocation.y = ev.clientY
  }

  onClick(ev: BeamUIEvent): void {    
    if (this.isOnlyAltKey(ev)) {
      ev.preventDefault()
      ev.stopPropagation()
    }

    if (!this.isPointDisabled(ev)) {
      this.shoot(ev.target)
    }
  }

  onlongtouch(ev: BeamUIEvent): void {
    if (!this.isPointDisabled(ev)) {
      this.shoot(ev.target)
    }
  }

  onTouchstart(ev: TouchEvent): void {
    if (!this.timer) {
      this.timer = setTimeout(() => this.onlongtouch(ev), this.touchDuration)
    }
  }

  onTouchend(): void {
    if (this.timer) {
      clearTimeout(this.timer)
      this.timer = null
    }
  }

  onKeyDown(ev: BeamMouseEvent): void {
    this.sendBounds()
    if (this.isPointDisabled(ev)) {
      this.isTypingOnWebView = true
    } else {
      const target = this.win.document.elementFromPoint(this.mouseLocation.x, this.mouseLocation.y)
      this.point(target)
    }
  }

  onMouseUp(): void {
    this.sendBounds()
  }

  onSelection(): void {
    this.select()
  }

  onResize(): void {
    this.sendBounds()
  }
  /**
   * ======================================================================
   * Helpers ==============================================================
   * ======================================================================
   */
   
   isOnlyAltKey(ev): boolean {
     const altKey = ev.altKey || ev.key == "Alt"
     return altKey && !ev.ctrlKey && !ev.metaKey && !ev.shiftKey
   }
 

  upsertShootGroup(newItem: BeamShootGroup, groups: BeamShootGroup[]): void {
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

  upsertRangeGroup(newItem: BeamRangeGroup, groups: BeamRangeGroup[]): void {
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
   * Check for textarea and input elements with matching type attribute
   *
   * @param element {BeamElement} The DOM Element to check.
   * @return If the element is some kind of text input.
   */
  isTextualInputType(element: BeamElement): boolean {
    const tag = element.tagName.toLowerCase()
    if (tag === "textarea") {
      return true
    } else if (tag === "input") {
      const types = [
        "text",
        "email",
        "password",
        "date",
        "datetime-local",
        "month",
        "number",
        "search",
        "tel",
        "time",
        "url",
        "week",
        // for legacy support
        "datetime"
      ]
      return types.includes(BeamElementHelper.getType(element))
    }

    return false
  }

  // In addition to the target.type we have to check for contentEditable values
  isExplicitlyContentEditable(element: BeamHTMLElement): boolean {
    return ["true", "plaintext-only"].includes(BeamElementHelper.getContentEditable(element))
  }

  /**
   * Check for inherited contenteditable attribute value by traversing
   * the ancestors until an explicitly set value is found
   *
   * @param element {(BeamNode)} The DOM node to check.
   * @return If the element inherits from an actual contenteditable valid values
   *         ("true", "plaintext-only")
   */
  getInheritedContentEditable(element: BeamHTMLElement): boolean {
    let isEditable = this.isExplicitlyContentEditable(element)
    const parent = element.parentElement as BeamHTMLElement
    if (parent && BeamElementHelper.getContentEditable(element) === "inherit") {
      isEditable = this.getInheritedContentEditable(parent)
    }
    return isEditable
  }

  isEventTargetTextualInput(ev: BeamUIEvent): boolean {
    return BeamElementHelper.isTextualInputType(ev.target) || this.getInheritedContentEditable(ev.target)
  }

  isEventTargetActive(ev: BeamUIEvent): boolean {
    return !!(
      this.win.document.activeElement &&
      this.win.document.activeElement !== this.win.document.body &&
      this.win.document.activeElement.contains(ev.target)
    )
  }

  isActiveTextualInput(ev: BeamUIEvent): boolean {
    return this.isEventTargetActive(ev) && this.isEventTargetTextualInput(ev)
  }

  isPointDisabled(ev: BeamUIEvent): boolean {
    return this.isActiveTextualInput(ev) || this.hasSelection()
  }

  /**
   * Returns an array of ranges for a given HTML selection
   *
   * @param {BeamSelection} selection
   * @return {*}  {BeamRange[]}
   */
  getSelectionRanges(selection: BeamSelection): BeamRange[] {
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
  getSelection(): BeamSelection {
    return this.win.document.getSelection()
  }
}
