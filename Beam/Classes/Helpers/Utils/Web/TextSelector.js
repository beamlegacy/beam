export class TextSelector {

  selections = []

  constructor(ui) {
    this.ui = ui
    document.addEventListener("selectionchange", (ev) => this.onSelectionChange(ev))
    window.addEventListener("mouseup", this.onMouseUp.bind(this))
    console.log("Text selector initialized")
  }

  enterSelection() {
    this.selections = []
    this.ui.enterSelection()
  }

  leaveSelection() {
    this.ui.leaveSelection()
    this.selections = []
  }

  onMouseUp(_ev) {
    const selectionsCount = this.selections.length
    if (selectionsCount > 0) {
      for (let i = 0; i < selectionsCount; ++i) {
        this.ui.textSelected(this.selections[i])
      }
      this.leaveSelection()
    }
  }

  onSelectionChange(_ev) {
    console.log("this", this)
    const docSelection = document.getSelection()
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
      let selectedHTML = Array.prototype.reduce.call(
          selectedFragment.childNodes,
          (result, node) => result + (node.outerHTML || node.nodeValue),
          ""
      )
      const rects = range.getClientRects()
      const textAreas = []
      let frameX = window.scrollX
      let frameY = window.scrollY
      for (let r = 0; r < rects.length; r++) {
        const rect = rects[r]
        textAreas.push({x: frameX + rect.x, y: frameY + rect.y, width: rect.width, height: rect.height})
      }
      const selection = {index: i, text: selectedText, html: selectedHTML, areas: textAreas}
      this.selections.push(selection)
      this.ui.addTextSelection(selection)
    }
  }
}
