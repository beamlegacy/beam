import {PointAndShootUI} from "./PointAndShootUI"

export class PointAndShootUI_web extends PointAndShootUI {
  prefix = "__ID__"

  shootClass = `${this.prefix}-shoot`

  pointClass = `${this.prefix}-point`

  overlayId = `${this.prefix}-overlay`
  backdropId = `${this.prefix}-backdrop`
  selectingClass = `${this.prefix}-selecting`

  /**
   * @type {(BeamWindow)}
   */
  win

  /**
   * @param win {BeamWindow}
   */
  constructor(win) {
    super()
    this.win = win
    console.log(`${this} instantiated`)
  }

  point(el, _x, _y) {
    this.enterSelection()
    el.classList.add(this.pointClass)
  }

  unpoint(el) {
    el.classList.remove(this.pointClass)
    el.style.cursor = ``
    this.leaveSelection()
  }

  shoot(el, x, y, selectedEls, submitCb) {
    el.classList.remove(this.pointClass)
    el.classList.add(this.shootClass)
  }

  unshoot(el) {
    el.classList.remove(this.shootClass)
  }

  isSelecting() {
    return Boolean(this.overlayEl)
  }

  enterSelection() {
    if (!this.isSelecting()) {
      const doc = this.win.document
      this.backdropEl = doc.createElement("div")
      this.backdropEl.id = this.backdropId
      this.overlayEl = doc.createElement("div")
      this.overlayEl.id = this.overlayId
      const body = doc.body
      body.classList.add(this.selectingClass)
      body.appendChild(this.backdropEl)
      body.appendChild(this.overlayEl)
    }
  }

  leaveSelection() {
    if (this.isSelecting()) {
      const doc = this.win.document
      const body = doc.body
      body.classList.remove(this.selectingClass)
      body.removeChild(this.overlayEl)
      body.removeChild(this.backdropEl)
      this.overlayEl = null
    }
  }

  /**
   * @param selection {TextSelection}
   * @param className {string}
   */
  paintSelection(selection, className) {
    const textAreas = selection.areas
    this.overlayEl.innerHTML = ""
    const padding = 5
    for (let r = 0; r < textAreas.length; r++) {
      const textRect = textAreas[r]
      const rectSelection = document.createElement("div")
      rectSelection.className = className
      rectSelection.style.position = "absolute"
      rectSelection.style.left = textRect.x + "px"
      rectSelection.style.top = textRect.y - padding + "px"
      rectSelection.style.width = textRect.width + "px"
      rectSelection.style.height = textRect.height + padding * 2 + "px"
      this.overlayEl.appendChild(rectSelection)
    }
  }

  toString() {
    return this.constructor.name
  }
}
