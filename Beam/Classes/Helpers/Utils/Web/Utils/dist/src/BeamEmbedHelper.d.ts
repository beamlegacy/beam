import { BeamElement, BeamHTMLElement, BeamWindow, MessageHandlers } from "@beam/native-beamtypes";
export declare class BeamEmbedHelper {
    embedPattern: string;
    embedRegex: RegExp;
    firstLocationLoaded?: Location;
    win: BeamWindow<MessageHandlers>;
    constructor(win: BeamWindow);
    /**
     * Returns true if element is Embed.
     *
     * @param {BeamElement} element
     * @param {BeamWindow} win
     * @return {*}  {boolean}
     * @memberof BeamEmbedHelper
     */
    isEmbeddableElement(element: any): boolean;
    /**
     * Returns the window location or first loaded location that matches
     * the embed or iframe regex
     *
     * @return {*}  {(string | undefined)}
     * @memberof BeamEmbedHelper
     */
    getEmbeddableWindowLocationLastUrls: string[];
    getEmbeddableWindowLocationLastResult: string;
    getEmbeddableWindowLocation(): string | undefined;
    isOnFullEmbeddablePage(): boolean;
    isEmbeddableIframe(element: BeamElement): boolean;
    urlMatchesEmbedProviderLastUrls: string[];
    urlMatchesEmbedProviderLastResult: boolean;
    urlMatchesEmbedProvider(urls: string[]): boolean;
    /**
     * Returns true if current window context is not the top level window context
     *
     * @return {*}  {boolean}
     * @memberof BeamEmbedHelper
     */
    isInsideIframe(): boolean;
    /**
     * Returns a url to the content to be inserted to the journal as embed.
     *
     * @param {BeamElement} element
     * @param {BeamWindow} win
     * @return {*}  {BeamHTMLElement}
     * @memberof this
     */
    parseElementForEmbed(element: BeamElement): BeamHTMLElement;
    /**
     * Convert element found on twitter.com to a anchor elemnt containing the tweet url.
     * returns undefined when element isn't a tweet
     *
     * @param {BeamElement} element
     * @param {BeamWindow<any>} win
     * @return {*}  {BeamHTMLElement}
     * @memberof this
     */
    parseTwitterElementForEmbed(element: BeamElement): BeamHTMLElement;
    /**
     * Returns if the provided element is a tweet. Should only be run on twitter.com
     *
     * @param {BeamElement} element
     * @return {*}  {boolean}
     * @memberof this
     */
    isTweet(element: BeamElement): boolean;
    /**
     * Returns if the provided element is a YouTube Thumbnail. Should only be run on youtube.com
     *
     * @param {BeamElement} element
     * @return {*}  {boolean}
     * @memberof this
     */
    isYouTubeThumbnail(element: BeamElement): boolean;
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
    hasParentOfType(element: BeamElement, type: string, count?: number): BeamElement | undefined;
    /**
     * Parse html element into a Anchortag if it's a youtube thumbnail
     *
     * @param {BeamElement} element
     * @return {*}  {BeamHTMLElement}
     * @memberof this
     */
    parseYouTubeThumbnailForEmbed(element: BeamElement): BeamHTMLElement;
    /**
     * Return BeamHTMLElement of an Anchortag with provided href attribute
     *
     * @param {string} href
     * @return {*}  {BeamHTMLElement}
     * @memberof this
     */
    createLinkElement(href: string): BeamHTMLElement;
}
