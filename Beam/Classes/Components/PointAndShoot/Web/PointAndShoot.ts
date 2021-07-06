import { WebEvents } from "./WebEvents"
import { PointAndShootUI } from "./PointAndShootUI"
import {
  BeamWindow,
  BeamPNSStatus,
  BeamCollectedQuote,
  BeamQuoteId,
  BeamSelection,
  BeamRange,
  BeamHTMLElement, BeamElement, BeamNode,
} from "./BeamTypes"
import { Util } from "./Util"
import { WebFactory } from "./WebFactory"
import { BeamMouseEvent } from "./Test/BeamMocks"
import { BeamElementHelper } from "./BeamElementHelper"

const PNS_STATUS = process.env.PNS_STATUS

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
  datasetKey

  /**
   * @type number
   */
  scrollWidth

  /**
   *
   */
  status: BeamPNSStatus = BeamPNSStatus.none

  /**
   * Collected quotes.
   */
  collectedQuotes: BeamCollectedQuote[] = []

  /**
   * Active selection element
   */
  selectionRanges: BeamCollectedQuote[]

  /**
   * The currently hovered element.
   *
   * This allows to remember what the cursor is pointing when entering in collect mode
   * just by hitting the Option key (not moving the mouse cursor).
   */
  pointingEv: BeamMouseEvent

  /**
   * The currently highlighted target.
   */
  pointedTarget: BeamCollectedQuote = null

  /**
   * The currently shooted target.
   */
  shootingTarget: BeamCollectedQuote

  shootMouseLocation

  timer

  /**
   * Amount of time we want the user to touch before we do something
   */
  touchDuration = 2500

  /**
   *
   * @param win {BeamWindow}
   * @param ui {PointAndShootUI}
   * @param webFactory
   * @return {PointAndShoot}
   */
  static getInstance(win: BeamWindow, ui: PointAndShootUI, webFactory: WebFactory) {
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
  }

  setWindow(win) {
    super.setWindow(win)
    this.log("setWindow")

    win.addEventListener("mousemove", this.onMouseMove.bind(this))
    win.addEventListener("click", this.onClick.bind(this))
    win.addEventListener("touchstart", this.onTouchstart.bind(this), false)
    win.addEventListener("touchend", this.onTouchend.bind(this), false)
    win.addEventListener("keydown", this.onKeyDown.bind(this), false)
    win.addEventListener("keyup", this.onKeyUp.bind(this), false)

    win.addEventListener("mouseup", this.onMouseUp.bind(this))
    win.document.addEventListener("selectionchange", (ev) => this.onSelection(ev))

    win.document.addEventListener("keypress", this.onKeyPress.bind(this))
    this.log("events registered")
    if (PNS_STATUS) {
      win.document.body.innerHTML =
        `<div id="debug-beam" style="bottom: 0px;right: 0;padding: 1rem;background: #7373FF; color: white;">JS ${this.status} | ${this.win.location.href}</div>` +
        win.document.body.innerHTML
    }
  }

  log(...args) {
    console.log(this.toString(), args)
  }

  cursor(x, y) {
    this.ui.cursor(x, y)
  }

  /**
   * Enable pointing UI.
   *
   * @param el {BeamHTMLElement}
   * @param x {number}
   * @param y {number}
   */
  point(el, x, y) {
    if (this.pointedTarget) {
      this.unpoint(this.pointedTarget) // Before creating new point, unpoint
    } else {
      const framesInfo = this.getFramesInfo()
      this.ui.setFramesInfo(framesInfo) // Not yet set, update frameInfo
    }

    // Only create point if no active selection on page
    if (!this.hasSelection()) {
      const quoteId = el.dataset[this.datasetKey]
      this.pointedTarget = { el, quoteId }
      this.ui.point(quoteId, el, x, y, () => {
        // if point gets canceled clear pointedTarget element
        this.pointedTarget = null
      })
    }
  }

  /**
   * Disables / clears pointing UI
   *
   * @param {*} [el=this.pointingEv.target]
   * @return {*}
   * @memberof PointAndShoot
   */
  unpoint(el = this.pointingEv.target) {
    const changed = this.isPointing()
    if (changed) {
      this.ui.unpoint(el)
      this.pointedTarget = null
    }
    return changed
  }

  /**
   * Unselect an element.
   *
   * @param el {BeamHTMLElement}
   */
  unshoot(el: BeamHTMLElement) {
    this.shootingTarget = undefined
    this.ui.unshoot(el)
    this.setStatus(BeamPNSStatus.none)
  }

  hidePopup() {
    this.ui.hidePopup()
  }

  /**
   * Returns boolean if current status is pointing
   */
  isPointing(): boolean {
    return this.status === BeamPNSStatus.pointing
  }

  /**
   * Returns boolean if current status is shooting
   */
  isShooting(): boolean {
    return this.status === BeamPNSStatus.shooting
  }

  /**
   * Returns boolean if document has active selection
   */
  hasSelection(): boolean {
    return Boolean(this.win.document.getSelection().toString())
  }

  /**
   * @param ev {BeamMouseEvent}
   */
  onMouseMove(ev: BeamMouseEvent) {
    if (!this.hasSelection()) {
      this.pointingEv = ev
      // Enable pointing if alt is pressed
      this.setPointing(this.isOnlyAltKey(ev))
      // Ignore pointing if the pointed element isn't assimilable to an active text input
      const isActiveTextualInput = this.isActiveTextualInput(ev)
      if (isActiveTextualInput || !this.isPointing()) {
        if (
          isActiveTextualInput
          || (
            this.status === BeamPNSStatus.none && !this.hasSelection()
          )
        ) {
          this.cursor(ev.clientX, ev.clientY)
        }
        this.hideStatus()
        return
      }

      ev.preventDefault()
      ev.stopPropagation()

      this.point(this.pointingEv.target, ev.clientX, ev.clientY)
      this.displayStatus(this.pointingEv.target)
    }
  }

  /**
   * Show the status when pointedTarget is collected note
   *
   * @memberof PointAndShoot
   */
  displayStatus(el) {
    const data = el.dataset[this.datasetKey]
    if (Boolean(data)) {
      this.showStatus(el, data)
      return
    }

    this.hideStatus()
  }

  /**
   * Show
   *
   * @param {HTMLElement} el
   * @param {*} data
   * @memberof PointAndShoot
   */
  showStatus(el: BeamHTMLElement, data) {
    this.ui.showStatus(el, data)
  }

  /**
   *
   */
  hideStatus() {
    this.ui.hideStatus()
  }

  /**
   * Remember shoots in DOM.
   *
   * @param quoteId: BeamQuoteId
   */
  assignNote(quoteId: BeamQuoteId) {
    const els = this.shootingTarget ? [this.shootingTarget] : this.selectionRanges
    els.forEach(({ el }) => {
      this.collectedQuotes.push({ el, quoteId })
      this.unshoot(el as BeamHTMLElement)
    })
    this.selectionRanges = []
  }

  /**
   * Select an HTML element to be added to a card.
   *
   * @param targetEl {BeamHTMLElement} The element to select.
   * @param x {number} Horizontal coordinate of click/touch
   * @param y {number} Vertical coordinate of click/touch
   * @param multi {boolean} If this is a multiple-selection action.
   */
  shoot(targetEl: BeamHTMLElement, x: number, y: number, multi: boolean) {
    this.shootingTarget = {
      el: targetEl,
      quoteId: targetEl.dataset[this.datasetKey],
    }
    this.shootMouseLocation = {
      x,
      y,
    }
    this.ui.shoot(this.shootingTarget.quoteId, this.shootingTarget.el, x, y, this.collectedQuotes)
    this.setShooting()
  }

  /**
   * Select an HTML element to be added to a card.
   *
   * @param ev {MouseEvent} The selection event (click or touch).
   * @param x {number} Horizontal coordinate of click/touch
   * @param y {number} Vertical coordinate of click/touch
   */
  onShoot(ev: MouseEvent, x: number, y: number) {
    const el = ev.target as BeamHTMLElement
    ev.preventDefault()
    ev.stopPropagation()
    const multi = ev.metaKey
    this.shoot(el, x, y, multi)
  }

  /**
   * Set status to BeamPNSStatus.shooting
   *
   * @param {Boolean} [bool=true]
   * @memberof PointAndShoot
   */
  setShooting(bool: boolean = true) {
    if (bool) {
      this.setStatus(BeamPNSStatus.shooting)
    }
  }

  onClick(ev) {
    this.log("onClick called!", ev.altKey, this.status)
    this.setPointing(ev.altKey)
    if (this.isPointing()) {
      // We still have to check whether or not the target is assimilable to a textual input
      // if so, we only send a cursor event, if not we proceed to shoot
      if (this.isEventTargetTextualInput(ev)) {
        this.cursor(ev.clientX, ev.clientY)
      } else {
        this.pointingEv = ev
        this.onShoot(ev, ev.clientX, ev.clientY)
      }
    } else if (this.isShooting()) {
      this.setStatus(BeamPNSStatus.none)
    }
  }

  onlongtouch(ev) {
    const touch = ev.touches[0]
    this.onShoot(ev, touch.clientX, touch.clientY)
  }

  onTouchstart(ev) {
    if (!this.timer) {
      this.timer = setTimeout(() => this.onlongtouch(ev), this.touchDuration)
    }
  }

  onTouchend(_ev) {
    if (this.timer) {
      clearTimeout(this.timer)
      this.timer = null
    }
  }

  onKeyPress(ev) {
    if (ev.code === "Escape") {
      this.ui.hidePopup()
    }
  }

  syncStatus(newStatus: BeamPNSStatus) {
    // When recieving new status from swift, don't broadcast that change
    this.setStatus(newStatus, false)
  }

  /**
   * Update the Point and Shoot status
   *
   * @param {BeamPNSStatus} newStatus
   */
  setStatus(newStatus: BeamPNSStatus, broadcast: boolean = true) {
    // this.setChildFrameStatus(newStatus)
    if (this.status != newStatus) {
      this.status = newStatus
      this.updateDebugStatusUI()

      if (broadcast) {
        this.ui.setStatus(newStatus)
      }
    }
  }

  /**
   * Re-draws the PNS debug status UI with updated value
   *
   * @memberof PointAndShoot
   */
  updateDebugStatusUI() {
    if (PNS_STATUS) {
      let debugEl = this.win.document.querySelector("#debug-beam")

      if (debugEl) {
        debugEl.innerText = `JS ${this.status} | ${this.win.location.href}`
      }
    }
  }

  /**
   * Enable pointing based on boolean param. Only permits going from  `status.none` to `status.pointing`.
   *
   * @param c {boolean}
   */
  setPointing(c: boolean) {
    if (c) {
      if (this.status === BeamPNSStatus.none) {
        this.setStatus(BeamPNSStatus.pointing)
      }
    } else {
      if (this.status !== BeamPNSStatus.none) {
        this.pointedTarget = null
        if (this.isPointing()) {
          this.setStatus(BeamPNSStatus.none)
        }
      }
    }
  }

  isOnlyAltKey(ev) {
    const altKey = ev.altKey || ev.key == "Alt"
    return altKey && !ev.ctrlKey && !ev.metaKey && !ev.shiftKey
  }

  /**
   * Check for textarea and input elements with matching type attribute
   *
   * @param element {BeamElement} The DOM Element to check.
   * @return If the element is some kind of text input.
   */

  isTextualInputType(element: BeamElement): boolean {
    const tag = element.tagName.toLowerCase();
    if (tag === 'textarea') {
      return true
    } else if (tag === 'input') {
      const types = [
        "text", "email", "password",
        "date", "datetime-local", "month",
        "number", "search", "tel",
        "time", "url", "week",
        // for legacy support
        "datetime"
      ]
      return types.includes(BeamElementHelper.getType(element))
    }

    return false
  }

  // In addition to the target.type we have to check for contentEditable values
  isExplicitlyContentEditable(element) {
    return ["true", "plaintext-only"].includes(
      BeamElementHelper.getContentEditable(element)
    )
  }

  /**
   * Check for inherited contenteditable attribute value by traversing
   * the ancestors until an explicitly set value is found
   *
   * @param element {(BeamNode)} The DOM node to check.
   * @return If the element inherits from an actual contenteditable valid values
   *         ("true", "plaintext-only")
   */
  getInheritedContentEditable(element: BeamElement ): boolean {
    let isEditable = this.isExplicitlyContentEditable(element)
    const parent = element.parentElement
    if (
      parent
      && BeamElementHelper.getContentEditable(element) === "inherit"
    ) {
      isEditable = this.getInheritedContentEditable(parent)
    }
    return isEditable
  }

  isEventTargetTextualInput(ev: BeamMouseEvent): boolean {
    return (
      this.isTextualInputType(ev.target)
      || this.getInheritedContentEditable(ev.target)
    )
  }

  isEventTargetActive(ev: BeamMouseEvent): boolean {
    return !!(
      this.win.document.activeElement
      && this.win.document.activeElement !== this.win.document.body
      && this.win.document.activeElement.contains(ev.target)
    )
  }

  isActiveTextualInput(ev: BeamMouseEvent): boolean {
    return (
      this.isEventTargetActive(ev)
      && this.isEventTargetTextualInput(ev)
    )
  }

  onKeyDown(ev) {
    const processEvent = (
      this.isOnlyAltKey(ev)
      && !this.isActiveTextualInput(ev)
    )
    if (processEvent) {
      if (this.hasSelection()) {
        // Enable shooting mode
        this.setShooting()
      } else {
        this.setPointing(true)
        const pointingEv = this.pointingEv
        if (pointingEv) {
          this.log("KeyDown sending point")
          this.point(pointingEv.target, pointingEv.clientX, pointingEv.clientY)
        }
      }
    }
  }

  protected resizeInfo(): any {
    const resizeInfo = super.resizeInfo()
    const elementArray = [].concat(this.shootingTarget, this.pointedTarget, this.selectionRanges)
    const activeAndStoredElements = this.collectedQuotes.concat(elementArray)
    const selected = Util.compact(activeAndStoredElements)
    return {
      ...resizeInfo,
      selected: selected,
      datasetKey: this.datasetKey,
      coordinates: this.shootMouseLocation,
    }
  }

  onKeyUp(ev) {
    if (ev.key === "Alt") {
      if (this.hasSelection() || this.isShooting()) {
        this.unpoint()
      }
      this.setPointing(false)
    }
  }

  onMouseUp(_ev) {
    // TODO: replace with actual value
    if (this.selectionRanges) {
      this.ui.select(this.selectionRanges)
    }
  }

  /**
   * onSelection changes dispatch ui select event for each active selection range
   *
   * @param {*} _ev
   */
  onSelection(_ev) {
    const selection = this.getSelection()
    if (selection.isCollapsed) {
      return
    }
    const ranges = this.getSelectionRanges(selection)
    this.selectionRanges = ranges.map((range) => {
      return {
        quoteId: undefined,
        el: range,
      }
    })
    this.ui.select(this.selectionRanges)
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
      ranges.push(selection.getRangeAt(index))
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
