import {
  BeamElement,
  BeamMutationObserver,
  BeamWindow
} from "../../../../Helpers/Utils/Web/BeamTypes"
import type { EmbedNodeUI as EmbedNodeUI } from "./EmbedNodeUI"
import debounce from "debounce"

export class EmbedNode<UI extends EmbedNodeUI> {
  win: BeamWindow

  /**
   * Singleton
   *
   * @type EmbedNode
   */
  static instance: EmbedNode<any>
  mutationObserver: BeamMutationObserver

  /**
   * @param win {(BeamWindow)}
   * @param ui {EmbedNodeUI}
   */
  constructor(win: BeamWindow<any>, protected ui: UI) {
    this.win = win
    this.registerEventListeners()
  }

  log(...args): void {
    console.log(this.toString(), args)
  }

  registerEventListeners(): void {
    this.win.addEventListener("load", this.onLoad.bind(this))
    this.win
      .matchMedia("(prefers-color-scheme: dark)")
      .addListener(this.switchTweetTheme.bind(this))
  }

  onLoad(): void {
    // assign resize obserer to body element
    const target = this.win.document.querySelector("body") as unknown as Element
    this.bodyResizeObserver.unobserve(target)
    this.bodyResizeObserver.observe(target)
    this.win.addEventListener("resize", this.sendSize.bind(this))
  }

  /**
   * ResizeObserver specifically for the body element.
   *
   * @memberof EmbedNode
   */
   bodyResizeObserver = new ResizeObserver((_entries) => {
    this.sendSize()
  })

  sendSize() {    
    const sizing = {
      width: 0,
      height: 0
    }
    // Get all child elements
    const els = this.win.document.querySelectorAll("body > *")

    // Loop through each of them and get the accumilated Width and Height
    Array.from(els).forEach((el) => {
      const styles = this.win.getComputedStyle(el as BeamElement)
      sizing.width += el.offsetWidth
      sizing.width += parseFloat(styles?.marginLeft)
      sizing.width += parseFloat(styles?.marginRight)
      sizing.height += el.offsetHeight
      sizing.height += parseFloat(styles?.marginTop)
      sizing.height += parseFloat(styles?.marginBottom)
    })

    // Send the total Width and total Height to the UI
    this.ui.sendContentSize(sizing)
  }

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

  debouncedSendSize = debounce(this.sendSize, 300, false) // sent on the trailing edge of timeout

  toString(): string {
    return this.constructor.name
  }
}
