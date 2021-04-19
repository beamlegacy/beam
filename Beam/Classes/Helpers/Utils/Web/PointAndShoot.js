import {TextSelector} from "./TextSelector"
import {BeamMouseEvent} from "./Test/BeamMocks"

export class PointAndShoot {
  /**
   * @type PointAndShoot
   */
  static instance

  /**
   * @type string
   */
  prefix = "__ID__"

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
  selectedEls = []

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
   * @param ui {UI}
   * @return {PointAndShoot}
   */
  static getInstance(win, ui) {
    if (!PointAndShoot.instance) {
      PointAndShoot.instance = new PointAndShoot(win, ui)
    }
    return PointAndShoot.instance
  }

  /**
   * @param win {(BeamWindow)}
   * @param ui {UI}
   */
  constructor(win, ui) {
    this.log("initializing")
    this.datasetKey = `${this.prefix}Collect`
    this.ui = ui
    this.setWindow(win)
    this.textSelector = new TextSelector(win, ui.textSelector)
  }

  setWindow(win) {
    this.log("setWindow")
    this.win = win
    this.onScroll()   // Init/refresh scroll info

    win.addEventListener("load", this.onLoad.bind(this))
    win.addEventListener("resize", this.onResize.bind(this))
    win.addEventListener("mousemove", this.onMouseMove.bind(this))
    win.addEventListener("click", this.onClick.bind(this))
    win.addEventListener("scroll", this.onScroll.bind(this))
    win.addEventListener("touchstart", this.onTouchstart.bind(this), false)
    win.addEventListener("touchend", this.onTouchend.bind(this), false)
    win.addEventListener("keydown", this.onKeyDown.bind(this), false)
    win.addEventListener("keyup", this.onKeyUp.bind(this), false)

    win.document.addEventListener("keypress", this.onKeyPress.bind(this))

    const vv = win.visualViewport
    vv.addEventListener("onresize", this.onPinch.bind(this))
    vv.addEventListener("scroll", this.onPinch.bind(this))
    this.log("events registered")
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
    this.ui.point(el, x, y)
  }

  /**
   */
  unpoint(_el) {
    const changed = this.isPointing()
    if (changed) {
      this.ui.unpoint()
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

  /**
   * @param ev {BeamMouseEvent}
   */
  onMouseMove(ev) {
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
  assignNote(note, el = this.selectedEls[this.selectedEls.length - 1]) {
    this.log("assignNoteToElement()", "note", note, "el", el, "datasetKey", this.datasetKey)
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
    this.selectedEls.push(el)
    this.log("shoot()", "selected.length", this.selectedEls.length)
    this.status = "shooting"
    this.ui.shoot(el, x, y, this.selectedEls, (selectedNote) => {
       this.assignNote(selectedNote, el)
    })
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

  onClick(ev) {
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
    this.status = s
    this.ui.setStatus(this.status)
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
        this.setStatus("none")
      }
    }
    // this.log("setPointing", c, changed ? "changed" : "did not change")
    return changed
  }

  onKeyDown(ev) {
    this.log("onKeyDown", ev.key)
    if (ev.key === "Alt") {
      this.setPointing(true)
      const pointingEv = this.pointingEv
      if (pointingEv) {
        this.point(pointingEv.target, pointingEv.clientX, pointingEv.clientY)
      }
    }
  }

  onKeyUp(ev) {
    this.log("onKeyUp", ev.key)
    if (ev.key === "Alt") {
      this.setPointing(false)
      this.unpoint()
    }
  }

  checkFrames() {
    const frameEls = this.win.document.querySelectorAll("iframe")
    const hasFrames = frameEls.length > 0
    /**
     * @type {FrameInfo[]}
     */
    const framesInfo = []
    if (hasFrames) {
      for (const frameEl of frameEls) {
        const bounds = frameEl.getBoundingClientRect()
        const href = frameEl.src
        const frameInfo = {
          href: href,
          bounds: {
            x: bounds.x,
            y: bounds.y,
            width: bounds.width,
            height: bounds.height
          }
        }
        framesInfo.push(frameInfo)
      }
      this.ui.setFramesInfo(framesInfo)
    } else {
      console.log("No frames")
    }
    return hasFrames
  }

  onScroll(_ev) {
    // TODO: Throttle
    const doc = this.win.document
    const body = doc.body
    const documentEl = doc.documentElement
    const scrollWidth = this.scrollWidth = Math.max(
        body.scrollWidth, documentEl.scrollWidth,
        body.offsetWidth, documentEl.offsetWidth,
        body.clientWidth, documentEl.clientWidth
    )
    const scrollHeight = Math.max(
        body.scrollHeight, documentEl.scrollHeight,
        body.offsetHeight, documentEl.offsetHeight,
        body.clientHeight, documentEl.clientHeight
    )
    const scrollInfo = {
      x: this.win.scrollX,
      y: this.win.scrollY,
      width: scrollWidth,
      height: scrollHeight,
      scale: this.win.visualViewport.scale
    }
    this.ui.setScrollInfo(scrollInfo)
    const hasFrames = this.checkFrames()
    this.log(hasFrames ? "Scroll updated frames info" : "Scroll did not update frames info since there is none")
  }

  onResize(_ev) {
    const resizeInfo = {width: this.win.innerWidth, height: this.win.innerHeight}
    this.ui.setResizeInfo(resizeInfo, this.selectedEls)
  }

  onLoad(_ev) {
    this.log("Page load.", this.win.origin)
    this.log("Flushing frames.", this.win.origin)
    this.ui.setOnLoadInfo()

    this.log("Checking frames.", this.win.origin)
    this.checkFrames()

    // This timeout is here so SPA style sites have time to build the DOM
    // TODO: Add reliable TTI eventlistener for JS heavy sites
    setTimeout(() => {
      this.log('After 500ms running checkFrames again', this.win.origin)
      this.checkFrames()
    }, 500)
  }

  onPinch(ev) {
    const vv = this.win.visualViewport
    this.ui.pinched({
      offsetTop: vv.offsetTop,
      pageTop: vv.pageTop,
      offsetLeft: vv.offsetLeft,
      pageLeft: vv.pageLeft,
      width: vv.width,
      height: vv.height,
      scale: vv.scale
    })
  }

  toString() {
    return this.constructor.name
  }
}
