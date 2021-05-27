function scorer_scroll(_ev) {
  const win = window
  const doc = win.document
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
    x: win.scrollX,
    y: win.scrollY,
    width: scrollWidth,
    height: scrollHeight,
    scale: win.visualViewport.scale
  }
  window.webkit.messageHandlers.score_scroll.postMessage(scrollInfo)
}
window.addEventListener("load", scorer_scroll)
window.addEventListener("scroll", scorer_scroll)
console.log('Scorer installed')
