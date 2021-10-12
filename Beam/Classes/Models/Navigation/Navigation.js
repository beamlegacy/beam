if (!window.beam) {
  window.beam = {}
}
window.beam.__ID__Nav = {

  isGoogleUrl(url) {
    return /(.*)\.google.([a-z]+)/.test(url)
  },

  /**
   *
   */
  rewriteLinks(delay) {
    setTimeout(() => {
      const links = document.querySelectorAll("[target='_blank']")
      for (let link of links) {
        const newLink = document.createElement("a")
        newLink.rel = link.rel
        newLink.href = link.href
        newLink.textContent = link.textContent
        newLink.target = "_blank"
        newLink.className = link.className
        newLink.style = link.style
        newLink.dataset.beam = "yes"
        link.parentElement.replaceChild(newLink, link)
      }
    }, delay)
  },

  decorate: function(obj, apiName) {
    const orig = obj[apiName]
    return function() {
      const result = orig.apply(this, arguments)
      const e = new Event(apiName)
      e.arguments = arguments
      window.dispatchEvent(e)
      return result
    }
  },

  /**
   * Sends a location change event to the native app.
   * @param e
   */
  locationChanged: function(e) {
    const args = e.arguments
    const stateUrl = args[2]
    if (stateUrl) {
      const location = window.location
      const origin = window.origin
      const href = location.href
      const url = stateUrl.indexOf(origin) < 0 ? origin + stateUrl : stateUrl // TODO: Check stateUrl is same origin
      const type = e.type
      window.webkit.messageHandlers.nav_locationChanged.postMessage({
        href,
        type,
        url
      })
    }
  },

  startHistoryHandling: function() {
    history.pushState = this.decorate(history, "pushState")
    history.replaceState = this.decorate(history, "replaceState")

    let currentUrl = window.location.href
    if (this.isGoogleUrl(currentUrl)) {
      window.open = (ev) => {
        throw new Error("Trying to open", arguments)
      }
      window.addEventListener("popstate", () => this.rewriteLinks(900))
      window.addEventListener("pushState", () => this.rewriteLinks(900))
      window.addEventListener("replaceState", () => this.rewriteLinks(900))
      this.rewriteLinks(1000)
    }

    window.addEventListener("replaceState", this.locationChanged.bind(this))
    window.addEventListener("pushState", this.locationChanged.bind(this))
  }

}

window.beam.__ID__Nav.startHistoryHandling()
