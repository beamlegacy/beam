import {BeamMessageHandler, BeamWindow} from "../../../Helpers/Utils/Web/BeamTypes"

export interface NavigationMessages {
  nav_locationChanged: BeamMessageHandler
}

export type NavigationWindow = BeamWindow<NavigationMessages>

export class BeamNavigation {

  constructor(private win: NavigationWindow) {
  }

  isGoogleUrl(url): boolean {
    return /(.*)\.google.([a-z]+)/.test(url)
  }

  /**
   *
   */
  rewriteLinks(delay: number): void {
    /*    setTimeout(() => {
          const links = document.querySelectorAll("[target='_blank']")
          Array.prototype.forEach.call(links, link => {
            this.rewriteLink(link as HTMLAnchorElement)
          })
        }, delay)*/
  }

  rewriteLink(link: HTMLAnchorElement): void {
    const newLink = this.linkWithoutListeners(link)
    link.parentElement.replaceChild(newLink, link)
  }

  linkWithoutListeners(link: HTMLAnchorElement): HTMLAnchorElement {
    const newLink = document.createElement("a") as HTMLAnchorElement
    if (link.rel) {
      newLink.rel = link.rel
    }
    newLink.href = link.href
    newLink.target = link.target
    for (const dataAttr in link.dataset) {
      newLink.dataset[dataAttr] = link.dataset[dataAttr]
    }
    // newLink.ariadataset = link.ariadataset
    const draggable = newLink.getAttribute("draggable")
    if (draggable) {
      newLink.setAttribute("draggable", draggable)
    }
    const className = link.className
    if (className) {
      newLink.className = className
    }
    const style = link.getAttribute("style")
    if (style) {
      newLink.setAttribute("style", style)
    }
    newLink.innerHTML = link.innerHTML
    newLink.dataset.beam = "yes"
    return newLink
  }

  decorate(obj, apiName: string): any {
    const orig = obj[apiName]
    const self = this
    return function () {
      const result = orig.apply(this, arguments)
      const e = new Event(apiName)
      e["arguments"] = arguments
      self.win.dispatchEvent(e)
      return result
    }
  }

  /**
   * Sends a location change event to the native app.
   */
  locationChanged(e): void {
    const args = e.arguments
    const stateUrl = args[2]
    if (stateUrl) {
      const location = this.win.location
      const origin = this.win.origin
      const href = location.href
      const url = stateUrl.indexOf(origin) < 0 ? origin + stateUrl : stateUrl // TODO: Check stateUrl is same origin
      const type = e.type
      this.win.webkit.messageHandlers.nav_locationChanged.postMessage({
        href,
        type,
        url
      })
    }
  }

  startHistoryHandling(): void {
    history.pushState = this.decorate(history, "pushState")
    history.replaceState = this.decorate(history, "replaceState")

    const currentUrl = this.win.location.href
    if (this.isGoogleUrl(currentUrl)) {
      /*this.win.open = (...args) => {
        throw new Error(`Trying to open: ${JSON.stringify(args)}`)
      }*/
      this.win.addEventListener("popstate", () => this.rewriteLinks(900))
      this.win.addEventListener("pushState", () => this.rewriteLinks(900))
      this.win.addEventListener("replaceState", () => this.rewriteLinks(900))
      this.rewriteLinks(1000)
    }
    this.win.addEventListener("replaceState", this.locationChanged.bind(this))
    this.win.addEventListener("pushState", this.locationChanged.bind(this))
  }
}
