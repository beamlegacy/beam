"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.BeamEmbedHelper = void 0;
const dequal_1 = require("dequal");
class BeamEmbedHelper {
    constructor(win) {
        this.embedPattern = "__EMBEDPATTERN__";
        this.win = win;
        this.embedRegex = new RegExp(this.embedPattern, "i");
        this.firstLocationLoaded = this.win.location;
    }
    /**
     * Returns true if element is Embed.
     *
     * @param {BeamElement} element
     * @param {BeamWindow} win
     * @return {*}  {boolean}
     * @memberof BeamEmbedHelper
     */
    isEmbeddableElement(element) {
        const isInsideIframe = this.isOnFullEmbeddablePage();
        // Check if current window location is matching embed url and is inside an iframe context
        if (isInsideIframe) {
            return isInsideIframe;
        }
        // check the element if it's embeddable
        switch (this.win.location.hostname) {
            case "twitter.com":
                return this.isTweet(element);
                break;
            case "www.youtube.com":
                return (this.isYouTubeThumbnail(element) ||
                    this.isEmbeddableIframe(element) ||
                    this.win.location.pathname.includes("/embed/"));
                break;
            default:
                return this.isEmbeddableIframe(element);
                break;
        }
    }
    getEmbeddableWindowLocation() {
        const urls = [this.win.location.href, this.firstLocationLoaded.href];
        if ((0, dequal_1.dequal)(urls, this.getEmbeddableWindowLocationLastUrls)) {
            return this.getEmbeddableWindowLocationLastResult;
        }
        const result = urls.find(url => {
            return this.embedRegex.test(url);
        });
        this.getEmbeddableWindowLocationLastUrls = urls;
        this.getEmbeddableWindowLocationLastResult = result;
        return result;
    }
    isOnFullEmbeddablePage() {
        return ((this.urlMatchesEmbedProvider([this.win.location.href, this.firstLocationLoaded.href])) &&
            this.isInsideIframe());
    }
    isEmbeddableIframe(element) {
        if (["iframe"].includes(element.tagName.toLowerCase())) {
            return this.urlMatchesEmbedProvider([element.src]);
        }
        return false;
    }
    urlMatchesEmbedProvider(urls) {
        if ((0, dequal_1.dequal)(urls, this.urlMatchesEmbedProviderLastUrls)) {
            return this.urlMatchesEmbedProviderLastResult;
        }
        const result = urls.some((url) => {
            if (!url)
                return false;
            return this.embedRegex.test(url) || url.includes("youtube.com/embed");
        });
        this.urlMatchesEmbedProviderLastUrls = urls;
        this.urlMatchesEmbedProviderLastResult = result;
        return result;
    }
    /**
     * Returns true if current window context is not the top level window context
     *
     * @return {*}  {boolean}
     * @memberof BeamEmbedHelper
     */
    isInsideIframe() {
        try {
            return window.self !== window.top;
        }
        catch (e) {
            return true;
        }
    }
    /**
     * Returns a url to the content to be inserted to the journal as embed.
     *
     * @param {BeamElement} element
     * @param {BeamWindow} win
     * @return {*}  {BeamHTMLElement}
     * @memberof this
     */
    parseElementForEmbed(element) {
        const { hostname } = this.win.location;
        switch (hostname) {
            case "twitter.com":
                // see if we target the tweet html
                return this.parseTwitterElementForEmbed(element);
                break;
            case "www.youtube.com":
                if (this.win.location.pathname.includes("/embed/")) {
                    const videoId = window.location.pathname.split("/").pop();
                    return this.createLinkElement(`https://www.youtube.com/watch?v=${videoId}`);
                }
                return this.parseYouTubeThumbnailForEmbed(element);
                break;
            default:
                if (element.src && this.urlMatchesEmbedProvider([element.src])) {
                    return this.createLinkElement(element.src);
                }
                break;
        }
    }
    /**
     * Convert element found on twitter.com to a anchor elemnt containing the tweet url.
     * returns undefined when element isn't a tweet
     *
     * @param {BeamElement} element
     * @param {BeamWindow<any>} win
     * @return {*}  {BeamHTMLElement}
     * @memberof this
     */
    parseTwitterElementForEmbed(element) {
        if (!this.isTweet(element)) {
            return;
        }
        // We are looking for a url like: <username>/status/1318584149247168513
        const linkElements = element.querySelectorAll("a[href*=\"/status/\"]");
        // return the href of the first element in NodeList
        const href = linkElements === null || linkElements === void 0 ? void 0 : linkElements[0].href;
        if (href) {
            return this.createLinkElement(href);
        }
        return;
    }
    /**
     * Returns if the provided element is a tweet. Should only be run on twitter.com
     *
     * @param {BeamElement} element
     * @return {*}  {boolean}
     * @memberof this
     */
    isTweet(element) {
        return element.getAttribute("data-testid") == "tweet";
    }
    /**
     * Returns if the provided element is a YouTube Thumbnail. Should only be run on youtube.com
     *
     * @param {BeamElement} element
     * @return {*}  {boolean}
     * @memberof this
     */
    isYouTubeThumbnail(element) {
        var _a, _b;
        const isThumb = Boolean((_a = element === null || element === void 0 ? void 0 : element.href) === null || _a === void 0 ? void 0 : _a.includes("/watch?v="));
        if (isThumb) {
            return true;
        }
        const parentLinkElement = this.hasParentOfType(element, "A", 5);
        return Boolean((_b = parentLinkElement === null || parentLinkElement === void 0 ? void 0 : parentLinkElement.href) === null || _b === void 0 ? void 0 : _b.includes("/watch?v="));
    }
    /**
     * Returns parent of node type. Maximum allowed recursive depth is 10
     *
     * @static
     * @param {BeamElement} node target node to start at
     * @param {string} type parent type to search for
     * @param {number} [count=10] maximum depth of recursion, defaults to 10
     * @return {*}  {(BeamElement | undefined)}
     * @memberof BeamEmbedHelper
     */
    hasParentOfType(element, type, count = 10) {
        if (count <= 0)
            return null;
        if (type !== "BODY" && (element === null || element === void 0 ? void 0 : element.tagName) === "BODY")
            return null;
        if (!(element === null || element === void 0 ? void 0 : element.parentElement))
            return null;
        if (type === (element === null || element === void 0 ? void 0 : element.tagName))
            return element;
        const newCount = count--;
        return this.hasParentOfType(element.parentElement, type, newCount);
    }
    /**
     * Parse html element into a Anchortag if it's a youtube thumbnail
     *
     * @param {BeamElement} element
     * @return {*}  {BeamHTMLElement}
     * @memberof this
     */
    parseYouTubeThumbnailForEmbed(element) {
        var _a, _b;
        if (!this.isYouTubeThumbnail(element)) {
            return;
        }
        // We are looking for a url like: /watch?v=DtC8Trc2Fe0
        if ((_a = element === null || element === void 0 ? void 0 : element.href) === null || _a === void 0 ? void 0 : _a.includes("/watch?v=")) {
            return this.createLinkElement(element === null || element === void 0 ? void 0 : element.href);
        }
        // Check parent link element
        const parentLinkElement = this.hasParentOfType(element, "A", 5);
        if ((_b = parentLinkElement === null || parentLinkElement === void 0 ? void 0 : parentLinkElement.href) === null || _b === void 0 ? void 0 : _b.includes("/watch?v=")) {
            return this.createLinkElement(parentLinkElement === null || parentLinkElement === void 0 ? void 0 : parentLinkElement.href);
        }
        return;
    }
    /**
     * Return BeamHTMLElement of an Anchortag with provided href attribute
     *
     * @param {string} href
     * @return {*}  {BeamHTMLElement}
     * @memberof this
     */
    createLinkElement(href) {
        const anchor = this.win.document.createElement("a");
        anchor.setAttribute("href", href);
        anchor.innerText = href;
        return anchor;
    }
}
exports.BeamEmbedHelper = BeamEmbedHelper;
//# sourceMappingURL=BeamEmbedHelper.js.map