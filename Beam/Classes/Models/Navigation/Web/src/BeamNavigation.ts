import {BeamMessageHandler, BeamWindow} from "@beam/native-beamtypes"

export interface NavigationMessages {
  nav_locationChanged: BeamMessageHandler
}

export type NavigationWindow = BeamWindow<NavigationMessages>

export class BeamNavigation {

  constructor(private win: NavigationWindow) {
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
    const stateUrl = args?.[2]
    if (stateUrl) {
      const location = this.win.location
      let href = location.href
      if (href == "about:blank") {
        href = stateUrl
      }
      const type = e.type
      this.win.webkit.messageHandlers.nav_locationChanged.postMessage({
        href,
        type
      })
    }
  }

  locationChangedBackwards(e): void {
    const href = this.win.location.href
    const type = e.type
    this.win.webkit.messageHandlers.nav_locationChanged.postMessage({
      href,
      type
    })
  }

  startHistoryHandling(): void {
    history.pushState = this.decorate(history, "pushState")
    history.replaceState = this.decorate(history, "replaceState")

    // Move in place
    this.win.addEventListener("replaceState", this.locationChanged.bind(this))

    // Go forward either with link or forward in history
    this.win.addEventListener("pushState", this.locationChanged.bind(this))

    // Go back in history
    this.win.addEventListener("popstate", this.locationChangedBackwards.bind(this))
  }
}