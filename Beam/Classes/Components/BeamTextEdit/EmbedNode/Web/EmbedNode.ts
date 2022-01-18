import {
  BeamElement,
  BeamLogCategory,
  BeamWindow
} from "../../../../Helpers/Utils/Web/BeamTypes"
import type { EmbedNodeUI as EmbedNodeUI } from "./EmbedNodeUI"
import { BeamLogger } from "../../../../Helpers/Utils/Web/BeamLogger"

export class EmbedNode<UI extends EmbedNodeUI> {
  win: BeamWindow
  logger: BeamLogger

  /**
   * Singleton
   *
   * @type EmbedNode
   */
  static instance: EmbedNode<any>

  /**
   * @param win {(BeamWindow)}
   * @param ui {EmbedNodeUI}
   */
  constructor(win: BeamWindow<any>, protected ui: UI) {
    this.win = win
    this.logger = new BeamLogger(win, BeamLogCategory.embedNode)
    this.registerEventListeners()
  }

  registerEventListeners(): void {
    this.win.addEventListener("load", this.onLoad.bind(this))
    this.win
      .matchMedia("(prefers-color-scheme: dark)")
      .addListener(this.switchTweetTheme.bind(this))
  }

  onLoad(): void {
    // assign resize obserer to iframe element
    const el = this.win.document.querySelector("body > .iframe")
    this.resizeObserver.observe(el as unknown as Element)
    this.mutationObserver.observe(
      el as unknown as Element,
      this.mutationObserverOptions
    )
  }

  /**
   * ResizeObserver specifically for the body element.
   *
   * @memberof EmbedNode
   */
  resizeObserver = new ResizeObserver((entries) => {
    entries.forEach((entry) => {
      const sizing = {
        width: 0,
        height: 0
      }
      const beamElement = entry.target as unknown as BeamElement
      // Use resizeObserver width and height because `getComputedStyle` might
      // return outdated size information and only update the values with a 100-200ms delay
      const styles = this.win.getComputedStyle(beamElement)
      sizing.width += entry.contentRect.width
      sizing.width += parseFloat(styles?.marginLeft)
      sizing.width += parseFloat(styles?.marginRight)
      sizing.height += entry.contentRect.height
      sizing.height += parseFloat(styles?.marginTop)
      sizing.height += parseFloat(styles?.marginBottom)
      this.ui.sendContentSize(sizing)
    })
  })

  mutationObserver = new MutationObserver((mutations, _observer) => {
    mutations.forEach((mutation) => {
      const sizing = {
        width: 0,
        height: 0
      }
      const beamElement = mutation.target as unknown as BeamElement
      // Use target getBoundingClientRect() width and height because `getComputedStyle` might
      // return outdated size information and only update the values with a 100-200ms delay
      const styles = this.win.getComputedStyle(beamElement)
      const bounds = beamElement.getBoundingClientRect()
      sizing.width += bounds.width
      sizing.width += parseFloat(styles?.marginLeft)
      sizing.width += parseFloat(styles?.marginRight)
      sizing.height += bounds.height
      sizing.height += parseFloat(styles?.marginTop)
      sizing.height += parseFloat(styles?.marginBottom)
      this.ui.sendContentSize(sizing)
    })
  })

  switchTweetTheme(event): void {
    const currentTheme = event.matches ? "light" : "dark"
    const targetTheme = event.matches ? "dark" : "light"
    this.toggleTweetTheme(currentTheme, targetTheme)
  }

  toggleTweetTheme(currentTheme, targetTheme): void {
    const tweets = document.querySelectorAll("[data-tweet-id]")
    tweets.forEach(function (tweet) {
      const src = tweet.getAttribute("src")
      tweet.setAttribute(
        "src",
        src.replace("theme=" + currentTheme, "theme=" + targetTheme)
      )
    })
  }

  mutationObserverOptions = { attributes: true, childList: true, subtree: true }

  toString(): string {
    return this.constructor.name
  }
}
