import { WebEvents } from "./WebEvents"
import { PointAndShootUI } from "./PointAndShootUI"
import {
  BeamWindow,
  BeamPNSStatus,
  BeamCollectedQuote,
  BeamQuoteId,
  BeamSelection,
  BeamRange,
} from "./BeamTypes"
import { Util } from "./Util"

const PNS_STATUS = Number(process.env.PNS_STATUS)

/**
 * Listen to events that hover and select web blocks with Option.
 */
export class PointAndShoot extends WebEvents<PointAndShootUI> {
  /**
   * Singleton.
   *
   * @type PointAndShoot
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
   * @type BeamPNSStatus
   */
  status: BeamPNSStatus = BeamPNSStatus.none

  /**
   * Collected quotes.
   *
   * @type {BeamCollectedQuote[]}
   */
  collectedQuotes: BeamCollectedQuote[] = []

  /**
   * Active selection element
   *
   * @type {BeamCollectedQuote[]}
   * @memberof PointAndShoot
   */
  selectionRanges: BeamCollectedQuote[]

  /**
   * The currently hovered element.
   *
   * This allows to remember what the cursor is pointing when entering in collect mode
   * just by hitting the Option key (not moving the mouse cursor).
   *
   * @type {BeamMouseEvent}
   */
  pointingEv

  /**
   * The currently highlighted target.
   * @type {BeamCollectedQuote}
   */
  pointedTarget: BeamCollectedQuote

  /**
   * The currently shooted target.
   * @type {BeamCollectedQuote}
   */
  shootingTarget: BeamCollectedQuote

  shootMouseLocation

  timer

  /**
   * Amount of time we want the user to touch before we do something
   *
   * @type {number}
   */
  touchDuration = 2500

  /**
   *
   * @param win {BeamWindow}
   * @param ui {PointAndShootUI}
   * @return {PointAndShoot}
   */
  static getInstance(win: BeamWindow, ui: PointAndShootUI) {
    if (!PointAndShoot.instance) {
      PointAndShoot.instance = new PointAndShoot(win, ui)
    }
    return PointAndShoot.instance
  }

  /**
   * @param win {(BeamWindow)}
   * @param ui {PointAndShootUI}
   */
  constructor(win: BeamWindow, ui: PointAndShootUI) {
    super(win, ui)
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

  /**
   * Enable pointing UI.
   * 
   * @param el {BeamHTMLElement}
   * @param x {number}
   * @param y {number}
   */
  point(el, x, y) {
    if (!this.hasSelection()) {
      this.log("KeyDown sending this.ui.point")
      const quoteId = el.dataset[this.datasetKey]
      this.ui.point(quoteId, el, x, y)
    }
  }

  /**
   */
  unpoint(el = this.pointingEv.target) {
    const changed = this.isPointing()
    if (changed) {
      this.ui.unpoint(el)
      this.pointedTarget = null
    }
    // this.log("unpoint", changed ? "changed" : "did not change")
    return changed
  }

  /**
   * Unselect an element.
   *
   * @param el {BeamHTMLElement}
   */
  unshoot(el) {
    this.shootingTarget = undefined
    this.ui.unshoot(el)
    this.setStatus(BeamPNSStatus.none)
  }

  hidePopup() {
    this.ui.hidePopup()
  }

  /**
   * Returns boolean if current status is pointing
   *
   * @return {Boolean} 
   * @memberof PointAndShoot
   */
  isPointing() {
    return this.status === BeamPNSStatus.pointing
  }

  /**
   * Returns boolean if current status is shooting
   *
   * @return {Boolean} 
   * @memberof PointAndShoot
   */
  isShooting() {
    return this.status === BeamPNSStatus.shooting
  }

  /**
   * Returns boolean if document has active selection
   *
   * @return {Boolean} 
   * @memberof PointAndShoot
   */
  hasSelection() {
    return Boolean(this.win.document.getSelection().toString())
  }

  /**
   * @param ev {BeamMouseEvent}
   */
  onMouseMove(ev) {
    if (!this.hasSelection()) {
      const withOption = ev.altKey
      // this.log("onMouseMove", withOption)
      this.pointingEv = ev
      // if (withOption) { // Don't unpoint if no alt, as for some reason it returns false when always pressed
      this.setPointing(withOption)
      // }
      if (this.isPointing()) {
        ev.preventDefault()
        ev.stopPropagation()
        if (this.pointedTarget?.el !== this.pointingEv.target) {
          if (this.pointedTarget) {
            this.log("pointed is changing from", this.pointedTarget.el, "to", this.pointingEv.target)
            this.unpoint(this.pointedTarget) // Remove previous
          }
          this.pointedTarget = {
            el: this.pointingEv.target,
            quoteId: this.pointingEv.target.dataset[this.datasetKey],
          }
          this.point(this.pointedTarget.el, ev.clientX, ev.clientY)
          let collected = this.pointedTarget.quoteId
          if (collected) {
            this.showStatus(this.pointedTarget)
          } else {
            this.hideStatus()
          }
        } else {
          this.hidePopup()
        }
      } else {
        this.hideStatus()
      }
    }
  }

  /**
   * @param el {HTMLElement}
   */
  showStatus(el) {
    const data = el.dataset[this.datasetKey]
    const collected = data
    this.ui.showStatus(el, collected)
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
   * @param note {object} The Note info
   * @param el {BeamHTMLElement} The element to assign the Note to.
   */
  assignNote(quoteId: BeamQuoteId) {
    const els = this.shootingTarget ? [this.shootingTarget] : this.selectionRanges
    els.forEach(({ el }) => {
      this.collectedQuotes.push({ el, quoteId })
      this.unshoot(el)
    })
    this.selectionRanges = []
  }

  /**
   * Select an HTML element to be added to a card.
   *
   * @param el {HTMLElement} The element to select.
   * @param x {number} Horizontal coordinate of click/touch
   * @param y {number} Vertical coordinate of click/touch
   * @param multi {boolean} If this is a multiple-selection action.
   */
  shoot(targetEl, x, y, multi) {
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
  onShoot(ev, x, y) {
    const el = ev.target
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
  setShooting(bool: Boolean = true) {
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
   * @memberof PointAndShoot
   */
  setStatus(newStatus: BeamPNSStatus) {
    if (this.status != newStatus) {
      this.status = newStatus
      this.ui.setStatus(newStatus)

      if (PNS_STATUS) {
        let debugEl = this.win.document.querySelector("#debug-beam")

        if (debugEl) {
          debugEl.innerText = `JS ${this.status}`
        }
      }
    }
  }

  /**
   * @param c {boolean}
   */
  setPointing(c) {
    let changed
    if (c) {
      changed = this.status === BeamPNSStatus.none
      if (changed) {
        this.setStatus(BeamPNSStatus.pointing)
      }
    } else {
      changed = this.status !== BeamPNSStatus.none
      if (changed) {
        this.pointedTarget = null
        if (this.isPointing()) {
          this.setStatus(BeamPNSStatus.none)
        }
      }
    }
    return changed
  }

  onKeyDown(ev) {
    this.log("onKeyDown", ev.key)
    if (ev.key === "Alt") {
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
    this.ui.select(this.selectionRanges)
  }

  /**
   * onSelection changes dispatch ui select event for each active selection range
   *
   * @param {*} _ev
   * @memberof PointAndShoot
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
   * @memberof PointAndShootUI_native
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
   * @memberof PointAndShoot
   */
  getSelection(): BeamSelection {
    return this.win.document.getSelection()
  }
}
