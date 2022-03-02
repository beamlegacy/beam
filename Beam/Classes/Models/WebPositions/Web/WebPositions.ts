import {
  BeamHTMLIFrameElement,
  BeamLogCategory,
  BeamMutationObserver,
  BeamNode,
  BeamResizeInfo,
  BeamWindow,
  FrameInfo
} from "../../../Helpers/Utils/Web/BeamTypes"
import type {WebPositionsUI as WebPositionsUI} from "./WebPositionsUI"
import debounce from "debounce"
import {dequal as isDeepEqual} from "dequal"
import { BeamLogger } from "../../../Helpers/Utils/Web/BeamLogger"

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
  frameMutationObserver: BeamMutationObserver
  bodyZoomMutationObserver: BeamMutationObserver
  logger: BeamLogger

  /**
   * @param win {(BeamWindow)}
   * @param ui {WebPositionsUI}
   */
  constructor(win: BeamWindow<any>, protected ui: UI) {
    this.win = win
    this.logger = new BeamLogger(win, BeamLogCategory.webpositions)
    this.onScroll() // Init/refresh scroll info
    this.sendFramesInfo()
    this.registerEventListeners()
    this.createFrameMutationObserver()
    this.createZoomMutationObserver("body", this.zoomMutationCallback.bind(this))
  }

  framesInfo = []

  registerEventListeners(): void {
    this.win.addEventListener("load", this.onLoad.bind(this))
    this.win.addEventListener("beam_historyLoad", this.onLoad.bind(this))
    this.win.addEventListener("scroll", this.onScroll.bind(this), true)
    this.win.addEventListener("resize", this.onResize.bind(this), true)
  }

  createZoomMutationObserver(query, fn): void {
    const self = this
    this.bodyZoomMutationObserver = this.createMutationObserver((records) => fn(records, self))
    const target = this.win.document.querySelector(query) as unknown as BeamNode
    const options = {
      attributes: true,
      attributeFilter: ["style"]
    }
    this.bodyZoomMutationObserver.observe(target, options)
  }

  createMutationObserver(fn): BeamMutationObserver {
    return new MutationObserver(fn) as unknown as BeamMutationObserver
  }

  zoomMutationCallback(mutationRecords, _self): void {
    mutationRecords.map((mutationRecord) => {
      if (mutationRecord.attributeName == "style") {
        const resizeInfo = this.resizeInfo()
        this.ui.setResizeInfo(resizeInfo)
      }
    })
  }

  createFrameMutationObserver(): void {
    const observer = this.createMutationObserver(this.frameMutationCallback.bind(this))
    const options = {
      childList: true,
      subtree: true
    }
    observer.observe(this.win.document, options)
  }

  frameMutationCallback(mutationRecords, _self): void {
    mutationRecords.map((mutationRecord) => {
      for (const node of mutationRecord.removedNodes) {
        if (node.nodeName == "IFRAME") {
          this.sendFramesInfo(false)
        }
      }

      for (const node of mutationRecord.addedNodes) {
        if (node.nodeName == "IFRAME") {
          this.sendFramesInfo(false)
        }
      }
    })
  }

  sendFramesInfo(includeMainFrame = true): void {
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

    if (includeMainFrame) {
      framesInfo.push({
        href: this.win.location.href,
        bounds: {
          x: 0,
          y: 0,
          width: this.win.innerWidth,
          height: this.win.innerHeight
        }
      })
    }
    if (!isDeepEqual(framesInfo, this.framesInfo)) {
      this.framesInfo = framesInfo
      this.ui.setFramesInfo(framesInfo)
    }
  }

  onScroll(_ev?): void {
    const scrollInfo = {
      x: this.win.scrollX,
      y: this.win.scrollY
    }
    this.ui.setScrollInfo(scrollInfo)
    this.debouncedFrameInfoLeading()
  }

  onResize(_ev): void {
    const resizeInfo = this.resizeInfo()
    this.ui.setResizeInfo(resizeInfo)
    // Because iframe postions can update when resizing we want to re-send their coordinates
    this.debouncedFrameInfoTrailling()
  }
  debouncedFrameInfoLeading = debounce(this.sendFramesInfo.bind(this), 200, true)
  debouncedFrameInfoTrailling = debounce(this.sendFramesInfo.bind(this), 200, false)

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
