if (!window.beam) {
    window.beam = {};
}

window.beam.__ID__MouseOverLink = {

    mouseOverAnchorElement: false,

    mouseover: function(event) {
        const anchorElement = this.findParentAnchorElement(event.target);
        if (!anchorElement || !anchorElement.href) { return; }

        this.mouseOverAnchorElement = true;

        const message = {
            url: anchorElement.href,
            target: anchorElement.target
        };

        window.webkit.messageHandlers.linkMouseOver.postMessage(message);
    },

    mouseout: function() {
        if (!this.mouseOverAnchorElement) { return; }
        this.mouseOverAnchorElement = false;
        window.webkit.messageHandlers.linkMouseOut.postMessage({});
    },

    findParentAnchorElement: function(element) {
        if (element == null || element == document.body) { return null; }
        if (element.tagName == "A") { return element; }
        return this.findParentAnchorElement(element.parentElement);
    }

};

window.addEventListener("mouseover", window.beam.__ID__MouseOverLink.mouseover.bind(window.beam.__ID__MouseOverLink));
window.addEventListener("mouseout", window.beam.__ID__MouseOverLink.mouseout.bind(window.beam.__ID__MouseOverLink));
