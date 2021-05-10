import {BeamMouseEvent} from "./Test/BeamMocks"
import {WebEvents} from "./WebEvents"
import {PointAndShootUI} from "./PointAndShootUI";
import {BeamWindow, BeamHTMLElement} from "./BeamTypes";

const PNS_STATUS = Number(process.env.PNS_STATUS)

/**
 * Listen to events that hover and select web blocks with Option.
 *
 * @see TextSelector for text selection.
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
   * @type string
   */
  status = "none"

  /**
   * Shoot elements.
   *
   * @type {BeamHTMLElement[]}
   */
  selectedEls: BeamHTMLElement[] = []

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
   * The currently highlighted element.
   * @type {BeamHTMLElement}
   */
  pointedEl

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

    win.document.addEventListener("keypress", this.onKeyPress.bind(this))
    this.log("events registered")
    if (PNS_STATUS) {
      win.document.body.innerHTML = win.document.body.innerHTML + `<div id="debug-beam" style="position: fixed;bottom: 0px;right: 0;padding: 1rem;background: #7373FF; color: white;">JS ${this.status}</div>`;
    }
  }

  log(...args) {
    console.log(this.toString(), args)
  }

  /**
   * @param el {BeamHTMLElement}
   * @param x {number}
   * @param y {number}
   */
  point(el, x, y) {
    if (!this.hasSelection()) {
      this.log("KeyDown sending this.ui.point")
      this.ui.point(el, x, y)
    }
  }

  /**
   */
  unpoint(el = this.pointingEv.target) {
    const changed = this.isPointing()
    if (changed) {
      this.ui.unpoint(el)
      this.pointedEl = null
    }
   // this.log("unpoint", changed ? "changed" : "did not change")
    return changed
  }

  /**
   * Unselect an element.
   *
   * @param el {BeamHTMLElement}
   * @return If the element has changed.
   */
  unshoot(el = this.pointingEv.target) {
    const selectedIndex = this.selectedEls.indexOf(el)
    const alreadySelected = selectedIndex >= 0
    if (alreadySelected) {
      this.selectedEls.splice(selectedIndex, 1)
      this.ui.unshoot(el)
      delete el.dataset[this.datasetKey]
      this.setStatus("none")
    }
    return alreadySelected
  }

  hidePopup() {
    this.ui.hidePopup()
  }

  isPointing() {
    return this.status === "pointing"
  }

  isShooting() {
    return this.status === "shooting"
  }

  hasSelection() {
    return  Boolean( this.win.document.getSelection().toString() )
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
        if (this.pointedEl !== this.pointingEv.target) {
          if (this.pointedEl) {
            this.log("pointed is changing from", this.pointedEl, "to", this.pointingEv.target)
            this.unpoint(this.pointedEl) // Remove previous
          }
          this.pointedEl = this.pointingEv.target
          this.point(this.pointedEl, ev.clientX, ev.clientY)
          let collected = this.pointedEl.dataset[this.datasetKey]
          if (collected) {
            this.showStatus(this.pointedEl)
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
    const collected = JSON.parse(data)
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
  assignNote(note, el = this.pointedEl) {
    this.log("assignNote()", "note", note, "el", el, "datasetKey", this.datasetKey)
    el.dataset[this.datasetKey] = JSON.stringify(note)
  }

  /**
   * Select an HTML element to be added to a card.
   *
   * @param el {HTMLElement} The element to select.
   * @param x {number} Horizontal coordinate of click/touch
   * @param y {number} Vertical coordinate of click/touch
   * @param multi {boolean} If this is a multiple-selection action.
   */
  shoot(el, x, y, multi) {
    const alreadySelected = this.unshoot(el)
    if (alreadySelected) {
      return
    }
    if (!multi && this.selectedEls.length > 0) {
      this.unshoot(this.selectedEls[0]) // previous selection will be replaced
    }
    this.ui.shoot(el, x, y, this.selectedEls, (selectedNote) => {
      this.selectedEls.push(el)
      this.assignNote(selectedNote, el)
    })
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
   * Set status to "shooting"
   *
   * @param {Boolean} [bool=true]
   * @memberof PointAndShoot
   */
  setShooting(bool: Boolean = true) {
    if (bool) {
      this.setStatus("shooting");
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

  setStatus(s) {
    if (this.status != s) {
      this.status = s
      this.ui.setStatus(s)
      
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
      changed = this.status === "none"
      if (changed) {
        this.setStatus("pointing")
      }
    } else {
      changed = this.status !== "none"
      if (changed) {
        this.pointedEl = null
        if (this.isPointing()) {
          this.setStatus("none")
        }
      }
    }
    // this.log("setPointing", c, changed ? "changed" : "did not change")
    return changed
  }

  onKeyDown(ev) {
    this.log("onKeyDown", ev.key)
    if (ev.key === "Alt") {
      if (this.hasSelection()) {
        this.setShooting();
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
    const resizeInfo = super.resizeInfo();
    return {...resizeInfo, selected: this.selectedEls};
  }

  onKeyUp(ev) {
    if (ev.key === "Alt") {
      if (this.hasSelection() || this.isShooting()) {
        this.unpoint()
     }
     this.setPointing(false)
    }
  }
}
