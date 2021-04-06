import {TextSelector} from "./TextSelector"

/**
 *
 * @param win {(BeamWindow)}
 * @param ui {UI}
 * @constructor
 */
export const PointAndShoot = (win, ui) => {
  const prefix = "__ID__"
  const vv = win.visualViewport
  console.log("PointAndShoot initializing")

  const datasetKey = `${prefix}Collect`

  let scrollWidth

  /**
   * Shoot elements.
   *
   * @type {HTMLElement[]}
   */
  const selectedEls = []

  /**
   * @param el {HTMLElement}
   * @param x {number}
   * @param y {number}
   */
  function point(el, x, y) {
    ui.point(el, x, y)
  }

  /**
   * @param el {HTMLElement}
   */
  function unpoint(el) {
    ui.unpoint(el)
    pointed = null
  }

  /**
   * Unselect an element.
   *
   * @param el {HTMLElement}
   * @return If the element has changed.
   */
  function unshoot(el) {
    const selectedIndex = selectedEls.indexOf(el)
    const alreadySelected = selectedIndex >= 0
    if (alreadySelected) {
      selectedEls.splice(selectedIndex, 1)
      ui.unshoot(el)
      delete el.dataset[datasetKey]
    }
    return alreadySelected
  }

  /**
   * The currently highlighted element
   * @type {HTMLElement}
   */
  let pointed

  function hidePopup() {
    ui.hidePopup()
  }

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
        hidePopup()
      }
    } else {
      hideStatus()
      if (pointed) {
        unpoint(pointed)
      }
    }
  }

  /**
   * @param el {HTMLElement}
   */
  function showStatus(el) {
    const data = el.dataset[datasetKey]
    const collected = JSON.parse(data)
    ui.showStatus(el, collected)
  }

  /**
   *
   */
  function hideStatus() {
    ui.hideStatus()
  }

  /**
   * Remember shoots in DOM
   */
  function assignCard(el, datasetKey, selectedCard) {
    el.dataset[datasetKey] = JSON.stringify(selectedCard)
  }

  /**
   * Select an HTML element to be added to a card.
   *
   * @param el {HTMLElement} The element to select.
   * @param x {number} Horizontal coordinate of click/touch
   * @param y {number} Vertical coordinate of click/touch
   * @param multi {boolean} If this is a multiple-selection action.
   */
  function shoot(el, x, y, multi) {
    const alreadySelected = unshoot(el)
    if (alreadySelected) {
      return
    }
    if (!multi && selectedEls.length > 0) {
      unshoot(selectedEls[0]) // previous selection will be replaced
    }
    selectedEls.push(el)
    // point(el, x, y)
    ui.shoot(el, x, y, selectedEls, () => {
      for (const el of selectedEls) {
        assignCard(el, datasetKey, this.selectedCard)
      }
    })
  }

  /**
   * Select an HTML element to be added to a card.
   *
   * @param ev {MouseEvent} The selection event (click or touch).
   * @param x {number} Horizontal coordinate of click/touch
   * @param y {number} Vertical coordinate of click/touch
   */
  function onShoot(ev, x, y) {
    const el = ev.target
    ev.preventDefault()
    ev.stopPropagation()
    const multi = ev.metaKey
    shoot(el, x, y, multi)
  }

  function onClick(ev) {
    if (ev.altKey) {
      onShoot(ev, ev.clientX, ev.clientY)
    }
  }

  function onlongtouch(ev) {
    const touch = ev.touches[0]
    onShoot(ev, touch.clientX, touch.clientY)
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
    }
  }

  function checkFrames() {
    const frameEls = win.document.querySelectorAll("iframe")
    const hasFrames = frameEls.length > 0
    /**
     * @type {FrameInfo[]}
     */
    const framesInfo = []
    if (hasFrames) {
      for (const frameEl of frameEls) {
        const bounds = frameEl.getBoundingClientRect()
        const frameInfo = {
          href: frameEl.src,
          bounds: {
            x: bounds.x,
            y: bounds.y,
            width: bounds.width,
            height: bounds.height
          }
        }
        framesInfo.push(frameInfo)
      }
    } else {
      console.log("No frames")
    }
    ui.setFramesInfo(framesInfo)
    return hasFrames
  }

  function onScroll(_ev) {
    // TODO: Throttle
    const doc = win.document
    const body = doc.body
    const documentEl = doc.documentElement
    scrollWidth = Math.max(
        body.scrollWidth, documentEl.scrollWidth,
        body.offsetWidth, documentEl.offsetWidth,
        body.clientWidth, documentEl.clientWidth
    )
    const scrollHeight = Math.max(
        body.scrollHeight, documentEl.scrollHeight,
        body.offsetHeight, documentEl.offsetHeight,
        body.clientHeight, documentEl.clientHeight
    )
    const scrollInfo = {x: win.scrollX, y: win.scrollY, width: scrollWidth, height: scrollHeight, scale: vv.scale}
    ui.setScrollInfo(scrollInfo)
    const hasFrames = checkFrames()
    console.log(hasFrames ? "Scroll updated frames info" : "Scroll did not update frames info since there is none")
  }

  function onResize(_ev) {
    const resizeInfo = {width: win.innerWidth, height: win.innerHeight}
    ui.setResizeInfo(resizeInfo, selectedEls)
  }

  function onLoad(_ev) {
    console.log("Page load. Checking frames")
    checkFrames()
  }

  checkFrames()
  onScroll()   // Init/refresh scroll info

  const textSelector = new TextSelector(win, ui.textSelector)

  function onPinch(ev) {
    ui.pinched({
      offsetTop: vv.offsetTop,
      pageTop: vv.pageTop,
      offsetLeft: vv.offsetLeft,
      pageLeft: vv.pageLeft,
      width: vv.width,
      height: vv.height,
      scale: vv.scale
    })
  }

  vv.addEventListener("onresize", onPinch);
  vv.addEventListener("scroll", onPinch);

  win.addEventListener("load", onLoad)
  win.addEventListener("resize", onResize)
  win.addEventListener("mousemove", onMouseMove)
  win.addEventListener("click", onClick)
  win.addEventListener("scroll", onScroll)
  win.addEventListener("touchstart", touchstart, false)
  win.addEventListener("touchend", touchend, false)
  win.document.addEventListener("keypress", onKeyPress)
}
