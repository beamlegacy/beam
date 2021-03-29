
export const PointAndShoot = (ui) => {
  const prefix = "__ID__"
  const origin = document.body.baseURI
  console.log("PointAndShoot initializing", origin)

  const datasetKey = `${prefix}Collect`

  let scrollWidth

  /**
   * Shoot elements.
   */
  const selected = []

  function point(el, x, y) {
    ui.point(el, x, y)
  }

  function unpoint(el) {
    ui.unpoint(el)
    pointed = null
  }

  function removeSelected(selectedIndex, el) {
    selected.splice(selectedIndex, 1)
    ui.removeSelected(el)
    delete el.dataset[datasetKey]
  }

  /**
   * The currently highlighted element
   */
  let pointed

  function onMouseMove(ev) {
    if (ev.altKey) {
      ev.preventDefault()
      ev.stopPropagation()
      const el = ev.target
      if (pointed !== el) {
        if (pointed) {
          unpoint(pointed) // Remove previous
        }
        pointed = el
        point(pointed, ev.clientX, ev.clientY)
        let collected = pointed.dataset[datasetKey]
        if (collected) {
          showStatus(pointed)
        } else {
          hideStatus()
        }
      } else {
        ui.hidePopup()
      }
    } else {
      hideStatus()
      if (pointed) {
        unpoint(pointed)
      }
    }
  }

  function showStatus(el) {
    const data = el.dataset[datasetKey]
    const collected = JSON.parse(data)
    ui.showStatus(el, collected)
  }

  function hideStatus() {
    ui.hideStatus()
  }

  /**
   * Select an HTML element to be added to a card.
   *
   * @param ev The selection event (click or touch).
   * @param x Horizontal coordinate of click/touch
   * @param y Vertical coordinate of click/touch
   */
  function select(ev, x, y) {
    const el = ev.target
    ev.preventDefault()
    ev.stopPropagation()
    const selectedIndex = selected.indexOf(el)
    const alreadySelected = selectedIndex >= 0
    if (alreadySelected) {
      // Unselect
      removeSelected(selectedIndex, el)
      return
    }
    const multiSelect = ev.metaKey
    if (!multiSelect && selected.length > 0) {
      removeSelected(0, selected[0]) // previous selection will be replaced
    }
    selected.push(el)
    // point(el, x, y)
    ui.shoot(el, x, y, selected, () => {
      for (const s of selected) {
        s.dataset[datasetKey] = JSON.stringify(this.selectedCard) // Remember shoots in DOM
      }
    })
  }

  function onClick(ev) {
    if (ev.altKey) {
      select(ev, ev.clientX, ev.clientY)
    }
  }

  function onlongtouch(ev) {
    const touch = ev.touches[0]
    select(ev, touch.clientX, touch.clientY)
  }

  let timer
  const touchDuration = 2500 //length of time we want the user to touch before we do something

  function touchstart(ev) {
    if (!timer) {
      timer = setTimeout(() => onlongtouch(ev), touchDuration)
    }
  }

  function touchend(_ev) {
    if (timer) {
      clearTimeout(timer)
      timer = null
    }
  }

  function onKeyPress(ev) {
    if (ev.code === "Escape") {
      ui.hidePopup()
      ui.leaveSelection()
    }
  }

  function checkFrames() {
    const frameEls = document.querySelectorAll("iframe")
    const hasFrames = frameEls.length > 0
    const framesInfo = []
    if (hasFrames) {
      for (const frameEl of frameEls) {
        const bounds = frameEl.getBoundingClientRect()
        const frameInfo = {
          origin,
          href: frameEl.src,
          bounds: {
            x: bounds.x,
            y: bounds.y,
            width: bounds.width,
            height: bounds.height
          }
        }
        framesInfo.push(frameInfo)
        console.log(origin, "has frame", framesInfo)
      }
    } else {
      console.log("No frames")
    }
    ui.setFramesInfo(framesInfo)
    return hasFrames
  }

  function onScroll(_ev) {
    // TODO: Throttle
    const body = document.body
    const documentEl = document.documentElement
    scrollWidth = Math.max(
        body.scrollWidth,
        documentEl.scrollWidth,
        body.offsetWidth,
        documentEl.offsetWidth,
        body.clientWidth,
        documentEl.clientWidth
    )
    const scrollHeight = Math.max(
        body.scrollHeight,
        documentEl.scrollHeight,
        body.offsetHeight,
        documentEl.offsetHeight,
        body.clientHeight,
        documentEl.clientHeight
    )
    const scrollInfo = {
      x: window.scrollX,
      y: window.scrollY,
      width: scrollWidth,
      height: scrollHeight
    }
    ui.setScrollInfo(scrollInfo)
    const hasFrames = checkFrames()
    console.log(hasFrames ? "Scroll updated frames info" : "Scroll did not update frames info since there is none")
  }

  function onResize(_ev) {
    const resizeInfo = {
      width: window.innerWidth,
      height: window.innerHeight
    }
    ui.setResizeInfo(resizeInfo, selected)
  }

  function onSelectionChange(_ev) {
    const selection = document.getSelection()
    if (selection.isCollapsed) {
      ui.leaveSelection()
      return
    }
    ui.enterSelection(scrollWidth)

    for (let i = 0; i < selection.rangeCount; ++i) {
      const range = selection.getRangeAt(i)
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
      ui.selectAreas(i, selectedText, selectedHTML, textAreas)
    }
  }

  function onLoad(_ev) {
    console.log("Page load. Checking frames")
    checkFrames()
  }

  checkFrames()
  onScroll()   // Init/refresh scroll info

  window.addEventListener("load", onLoad)
  window.addEventListener("resize", onResize)
  window.addEventListener("mousemove", onMouseMove)
  window.addEventListener("click", onClick)
  window.addEventListener("scroll", onScroll)
  window.addEventListener("touchstart", touchstart, false);
  window.addEventListener("touchend", touchend, false);
  document.addEventListener("keypress", onKeyPress)
  document.addEventListener("selectionchange", onSelectionChange)
}


