import { WebEvents } from "./WebEvents"
import { PointAndShootUI } from "./PointAndShootUI"
import {
  BeamWindow,
  BeamPNSStatus,
  BeamCollectedQuote,
  BeamQuoteId,
  BeamSelection,
  BeamRange,
  BeamHTMLElement,
} from "./BeamTypes"
import { Util } from "./Util"
import { WebFactory } from "./WebFactory"
import { BeamMouseEvent } from "./Test/BeamMocks"

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
  pointedTarget: BeamCollectedQuote

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
        win.document.body.innerHTML +
        `<div id="debug-beam" style="position: fixed;bottom: 0px;right: 0;padding: 1rem;background: #7373FF; color: white;">JS ${this.status}</div>`
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
    // Before creating new point, unpoint
    if (this.pointedTarget) {
      this.unpoint(this.pointedTarget)
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
      const withOption = this.isOnlyAltKey(ev)
      this.setPointing(withOption)
      if (!this.isPointing()) {
        if (this.status === BeamPNSStatus.none && !this.hasSelection()) {
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
   * Show the status when poitedTarget is collected note
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
      this.pointingEv = ev
      this.onShoot(ev, ev.clientX, ev.clientY)
      return
    }

    if (this.isShooting()) {
      this.setStatus(BeamPNSStatus.none)
      return
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

  /**
   * Update the Point and Shoot status
   *
   * @param {BeamPNSStatus} newStatus
   */
  setStatus(newStatus: BeamPNSStatus) {
    if (this.status != newStatus) {
      this.status = newStatus
      this.ui.setStatus(newStatus)
      this.updateDebugStatusUI()
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
        debugEl.innerText = `JS ${this.status}`
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

  onKeyDown(ev) {
    if (this.isOnlyAltKey(ev)) {
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
