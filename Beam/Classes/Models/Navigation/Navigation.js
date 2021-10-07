if (!window.beam) {
    window.beam = {};
}
window.beam.__ID__Nav = {


    decorate: function (obj, apiName) {
        const orig = obj[apiName]
        return function() {
            const result = orig.apply(this, arguments)
            const e = new Event(apiName)
            e.arguments = arguments
            window.dispatchEvent(e)
            return result
        }
    },

    locationChanged: function (e) {
        const args = e.arguments
        const stateUrl = args.length > 2 && args[2]
        if (stateUrl) {
            const location = window.location
            const origin = window.origin
            const href = location.href
            const url = stateUrl.indexOf(origin) < 0 ? origin + stateUrl : stateUrl
            const type = e.type
            window.webkit.messageHandlers.nav_locationChanged.postMessage({
                href,
                type,
                url
            })
        }
    },


    startHistoryHandling: function () {
        history.pushState = this.decorate(history, "pushState")
        history.replaceState = this.decorate(history, "replaceState")

        let currentUrl = window.location.href
        const isGoogle = /(.*)\.google.([a-z]+)/.test(currentUrl)
        if (isGoogle) {
            function keepLinksPrivacy() {
                setTimeout(() => {
                    const links = document.querySelectorAll("[target='_blank']")
                    for (let link of links) {
                        link.rel = "noopener,noreferrer"
                    }
                }, 1000)
            }

            window.open = this.decorate(window, undefined)
            window.addEventListener("popstate", () => keepLinksPrivacy())
            keepLinksPrivacy()
        }

        window.addEventListener("replaceState", this.locationChanged.bind(this))
        window.addEventListener("pushState", this.locationChanged.bind(this))
    },

};

window.beam.__ID__Nav.startHistoryHandling();
