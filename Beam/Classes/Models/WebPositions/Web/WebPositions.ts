import type {
  BeamHTMLIFrameElement,
  BeamMutationObserver,
  BeamNode,
  BeamResizeInfo,
  BeamWindow,
  FrameInfo
} from "../../../Helpers/Utils/Web/BeamTypes"
import type {WebPositionsUI as WebPositionsUI} from "./WebPositionsUI"
import debounce from "debounce"

export class WebPositions<UI extends WebPositionsUI> {
  win: BeamWindow

  /**
   * Singleton
   *
   * @type WebPositions
   */
  static instance: WebPositions<any>

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
   * @param ui {WebPositionsUI}
   */
  constructor(win: BeamWindow<any>, protected ui: UI) {
    this.win = win
    this.onScroll() // Init/refresh scroll info
    this.sendFramesInfo()
    this.registerEventListeners()
    this.setObserver("body", this.zoomMutationCallback)
  }

  log(...args): void {
    console.log(this.toString(), args)
  }

  registerEventListeners(): void {
    this.win.addEventListener("load", this.onLoad.bind(this))
    this.win.addEventListener("beam_historyLoad", this.onLoad.bind(this))
    this.win.addEventListener("scroll", this.onScroll.bind(this), true)
    this.win.addEventListener("resize", this.onResize.bind(this), true)
  }

  setObserver(query, fn): void {
    const self = this
    this.mutationObserver = this.createMutationObserver((records) => fn(records, self))
    const target = this.win.document.querySelector(query) as unknown as BeamNode
    const options = {
      attributes: true,
      attributeFilter: ["style"]
    }
    this.mutationObserver.observe(target, options)
  }

  createMutationObserver(fn): BeamMutationObserver {
    return new MutationObserver(fn) as unknown as BeamMutationObserver
  }

  zoomMutationCallback(mutationRecords, self): void {
    mutationRecords.map((mutationRecord) => {
      if (mutationRecord.attributeName == "style") {
        const resizeInfo = self.resizeInfo()
        self.ui.setResizeInfo(resizeInfo)
      }
    })
  }

  sendFramesInfo(): void {
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
          height: bounds.height
        }
      }
      framesInfo.push(frameInfo)
    }

    framesInfo.push({
      href: this.win.location.href,
      bounds: {
        x: 0,
        y: 0,
        width: this.win.innerWidth,
        height: this.win.innerHeight
      }
    })
    this.ui.setFramesInfo(framesInfo)
  }

  onScroll(_ev?): void {
    const scrollInfo = {
      x: this.win.scrollX,
      y: this.win.scrollY
    }
    this.ui.setScrollInfo(scrollInfo)
    const immediate = true
    debounce(this.sendFramesInfo, 200, immediate)
  }

  onResize(_ev): void {
    const resizeInfo = this.resizeInfo()
    this.ui.setResizeInfo(resizeInfo)
  }

  protected resizeInfo(): BeamResizeInfo  {
    return { width: this.win.innerWidth, height: this.win.innerHeight }
  }

  onLoad(_ev): void {
    this.onScroll()
    this.sendFramesInfo()
  }

  toString(): string {
    return this.constructor.name
  }
}
