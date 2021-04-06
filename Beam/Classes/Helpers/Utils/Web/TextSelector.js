export class TextSelector {

  selectionsList = []

  /**
   *
   * @param win {(BeamWindow)}
   * @param ui {TextSelectorUI}
   */
  constructor(win, ui) {
    this.ui = ui
    this.win = win
    win.addEventListener("mouseup", this.onMouseUp.bind(this))
    win.document.addEventListener("selectionchange", (ev) => this.onSelectionChange(ev))
    console.log(`Initialized ${this}`)
  }

  enterSelection() {
    this.selectionsList = []
    this.ui.enterSelection()
  }

  leaveSelection() {
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
    console.log("this", this)
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
          x: this.win.scrollX + rangeRect.x,
          y: this.win.scrollY + rangeRect.y,
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
    return "Text selector"
  }
}
