import type { BeamHTMLIFrameElement, BeamMutationObserver, BeamNode, BeamWindow } from "./BeamTypes"
import type { WebEventsUI } from "./WebEventsUI"
import { FrameInfo } from "./WebEventsUI"
import { WebFactory } from "./WebFactory"

export class WebEvents<UI extends WebEventsUI> {
  win: BeamWindow

  /**
   * Singleton
   *
   * @type WebEvents
   */
  static instance: WebEvents<any>

  /**
   * @type string
   */
  protected prefix = "__ID__"

  /**
   * @type number
   */
  scrollWidth

  timer

  /**
   * Amount of time we want the user to touch before we do something
   *
   * @type {number}
   */
  touchDuration = 2500
  mutationObserver: BeamMutationObserver

  /**
   * @param win {(BeamWindow)}
   * @param ui {WebEventsUI}
   * @param webFactory
   */
  constructor(win: BeamWindow, protected ui: UI, webFactory: WebFactory) {
    this.log("initializing")
    this.setWindow(win)
    this.setObserver(webFactory, "body", this.zoomMutationCallback)
  }

  setObserver(webFactory: WebFactory, query, fn) {
    const self = this
    this.mutationObserver = webFactory.createMutationObserver((records) => fn(records, self))
    const target = this.win.document.querySelector(query) as unknown as BeamNode
    const options = {
      attributes: true,
      attributeFilter: ["style"],
    }
    this.mutationObserver.observe(target, options)
  }

  setWindow(win: BeamWindow) {
    this.log("setWindow")
    this.win = win
    this.onScroll() // Init/refresh scroll info

    win.addEventListener("load", this.onLoad.bind(this))
    win.addEventListener("beam_historyLoad", this.onLoad.bind(this))
    win.addEventListener("resize", this.onResize.bind(this))
    win.addEventListener("scroll", this.onScroll.bind(this))

    const vv = win.visualViewport
    vv.addEventListener("onresize", this.onPinch.bind(this))
    vv.addEventListener("scroll", this.onPinch.bind(this))

    this.log("events registered")
  }

  log(...args) {
    console.log(this.toString(), args)
  }

  /**
   * Unifies the document zoom and viewport scaling.
   * The document zoom level is used in webkit for macOS < 11.0
   */
  getScale(): number {
    let zoom = this.getZoomLevel() || 1
    let scale = this.win.visualViewport.scale
    return Number(zoom) * scale
  }

  getZoomLevel(): number {
    let zoomLevel = 1
    const zoom = this.win.document.body.style.zoom
    if (zoom) {
      switch (true) {
        case zoom.endsWith("%"):
          zoomLevel = parseFloat(zoom) / 100
          break
        case Boolean(parseFloat(zoom)):
          zoomLevel = parseFloat(zoom)
          break
      }
    }
    return zoomLevel
  }

  zoomMutationCallback(mutationRecords, self) {
    mutationRecords.map((mutationRecord) => {
      if (mutationRecord.attributeName == "style") {
        const resizeInfo = self.resizeInfo()
        self.ui.setResizeInfo(resizeInfo)
      }
    })
  }

  checkFrames() {
    const framesInfo = this.getFramesInfo()
    this.ui.setFramesInfo(framesInfo)
  }

  getFramesInfo(): FrameInfo[] {
    const frameEls = this.win.document.querySelectorAll("iframe") as BeamHTMLIFrameElement[]
    const framesInfo: FrameInfo[] = []
    for (const frameEl of frameEls) {
      const bounds = frameEl.getBoundingClientRect()
      const href = frameEl.src
      const frameInfo = {
        href: href,
        bounds: {
          x: bounds.x,
          y: bounds.y,
          width: bounds.width,
          height: bounds.height,
        },
      }
      framesInfo.push(frameInfo)
    }

    framesInfo.push({
      href: this.win.location.href,
      bounds: {
        x: 0,
        y: 0,
        width: this.win.innerWidth,
        height: this.win.innerHeight,
      },
    })
    return framesInfo
  }

  onScroll(_ev?) {
    // TODO: Throttle
    const doc = this.win.document
    const body = doc.body
    const documentEl = doc.documentElement
    const scrollWidth = (this.scrollWidth = Math.max(
      body.scrollWidth,
      documentEl.scrollWidth,
      body.offsetWidth,
      documentEl.offsetWidth,
      body.clientWidth,
      documentEl.clientWidth
    ))
    const scrollHeight = Math.max(
      body.scrollHeight,
      documentEl.scrollHeight,
      body.offsetHeight,
      documentEl.offsetHeight,
      body.clientHeight,
      documentEl.clientHeight
    )
    const scrollInfo = {
      x: this.win.scrollX,
      y: this.win.scrollY,
      width: scrollWidth,
      height: scrollHeight,
      scale: this.getScale(),
    }
    this.ui.setScrollInfo(scrollInfo)
  }

  onResize(_ev) {
    const resizeInfo = this.resizeInfo()
    this.ui.setResizeInfo(resizeInfo)
  }

  protected resizeInfo() {
    return { width: this.win.innerWidth, height: this.win.innerHeight, scale: this.getScale() }
  }

  onLoad(_ev) {
    this.log("Page load.", this.win.location.href)
    this.log("Flushing frames.", this.win.location.href)
    const framesInfo: FrameInfo[] = this.getFramesInfo()
    this.ui.setOnLoadInfo(framesInfo)
  }

  onPinch(_ev) {
    const vv = this.win.visualViewport
    this.ui.pinched({
      offsetTop: vv.offsetTop,
      pageTop: vv.pageTop,
      offsetLeft: vv.offsetLeft,
      pageLeft: vv.pageLeft,
      width: vv.width,
      height: vv.height,
      scale: this.getScale(),
    })
  }

  toString() {
    return this.constructor.name
  }
}
