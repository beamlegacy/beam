import {BeamWindow} from "./BeamTypes"
import {TextSelectorUI} from "./TextSelectorUI"

/**
 * Listen to events that select text with Option.
 *
 * @see PointAndShoot for block selection.
 */
export class TextSelector {

  private selectionsList = []

  /**
   *
   * @param win {(BeamWindow)}
   * @param ui {TextSelectorUI}
   */
  constructor(protected win: BeamWindow, protected ui: TextSelectorUI) {
    win.addEventListener("mouseup", this.onMouseUp.bind(this))
    win.document.addEventListener("selectionchange", (ev) => this.onSelectionChange(ev))
    this.log('Initialized')
  }

  log(...args) {
    console.log(this.toString(), args)
  }

  enterSelection() {
    this.log("enterSelection")
    this.selectionsList = []
    this.ui.enterSelection()
  }

  leaveSelection() {
    this.log("leaveSelection")
    this.ui.leaveSelection()
    this.selectionsList = []
  }

  onMouseUp(_ev) {
    const selectionsCount = this.selectionsList.length
    if (selectionsCount > 0) {
      for (let i = 0; i < selectionsCount; ++i) {
        this.ui.textSelected(this.selectionsList[i])
      }
      getSelection().removeAllRanges()
      this.leaveSelection()
    }
  }

  onSelectionChange(_ev) {
    this.log("onSelectionChange")
    const docSelection = this.getSelection()
    if (docSelection.isCollapsed) {
      this.leaveSelection()
      return
    }
    this.enterSelection()

    const count = docSelection.rangeCount
    for (let i = 0; i < count; ++i) {
      const range = docSelection.getRangeAt(i)
      const selectedText = range.toString()
      const selectedFragment = range.cloneContents()
      const selectedHTML = Array.prototype.reduce.call(
          selectedFragment.childNodes,
          (result, node) => result + (node.outerHTML || node.nodeValue),
          ""
      )
      const rangeRects = range.getClientRects()
      const textAreas = []
      for (let r = 0; r < rangeRects.length; r++) {
        const rangeRect = rangeRects[r]
        const rect = {
          x: rangeRect.x,
          y: rangeRect.y,
          width: rangeRect.width,
          height: rangeRect.height
        }
        textAreas.push(rect)
      }
      const selection = {index: i, text: selectedText, html: selectedHTML, areas: textAreas}
      this.selectionsList.push(selection)
      this.ui.addTextSelection(selection)
    }
  }

  getSelection() {
    return this.win.document.getSelection()
  }

  toString() {
    return this.constructor.name
  }
}
