import { BeamLogCategory, BeamWindow } from "@beam/native-beamtypes"
import { BeamLogger } from "@beam/native-utils"
import {
  isProbablyReaderable,
  Readability as MozReadability
} from "@mozilla/readability"

type ReadOptions = {
  enableFallbackReadabilityParser: boolean
}

export class Readability {
  win: BeamWindow
  logger: BeamLogger

  /**
   * Singleton
   *
   * @type Readability
   */
  static instance: Readability
  readerableOptions = {
    minContentLength: 80,
    minScore: 19
  }

  lastParseResult: {
    title: string
    byline: string
    dir: string
    content: string
    textContent: string
    length: number
    excerpt: string
    siteName: string
  }
  articleContent: HTMLElement

  /**
   * @param win {(BeamWindow)}
   * @param ui {ReadabilityUI}
   */
  constructor(win: BeamWindow<any>) {
    this.win = win
    this.logger = new BeamLogger(win, BeamLogCategory.embedNode)
  }

  isProbablyReaderable = isProbablyReaderable

  parse(readOptions: ReadOptions) {
    const document = this.win.document as unknown as Document

    if (!isProbablyReaderable(document, this.readerableOptions)) {
      return this.fallbackReadability(readOptions)
    }

    // document.cloneNode() can cause the webview to break (bug 1128774).
    // Serialize and then parse the document instead.
    const docStr = new XMLSerializer().serializeToString(document)

    // Do not attempt to parse DOM if this document contains a <frameset/>
    // element. This causes the WKWebView content process to crash (Bug 1489543).
    if (docStr.indexOf("<frameset ") > -1) {
      return this.fallbackReadability(readOptions)
    }

    const doc = new DOMParser().parseFromString(docStr, "text/html")

    // capture articleContent Element for clustering parser
    const options = {
      serializer: (el: HTMLElement) => {
        this.articleContent = el
        return el.innerHTML
      }
    }
    const reader = new MozReadability(doc, options)

    return {
      ...reader.parse(),
      textContentForClustering: this.textContentForClustering(),
      isFallback: false
    }
  }

  fallbackReadability(readOptions: ReadOptions) {
    if (readOptions.enableFallbackReadabilityParser) { 
      const innerText = this.win.document.body.innerText
      return {
        title: document.title,
        textContent: innerText,
        textContentForClustering: this.fallbackClusteringText(),
        isFallback: true
      }
    } else {
      return { title: document.title }
    }
  }

  fallbackClusteringMeta() {
    const alternateCleanedText = []
    const selectors = "meta[name=\"Description\"], meta[name=\"description\"], meta[property=\"og:description\"], meta[name=\"twitter:description\"]"
    const elements = Array.from(document.querySelectorAll(selectors))

    elements.forEach((paragraph) => {
      const myText = paragraph.getAttribute("content").trim()
      if (myText.length) {
        alternateCleanedText.push(myText)
      }
    })

    return alternateCleanedText
  }

  fallbackClusteringText() {
    const alternateCleanedText = []
    // add content of meta tags
    alternateCleanedText.push(...this.fallbackClusteringMeta())

    const selectors = "h1, h2, h3, h4, h5, h6, p, u, i, strong, a"
    const paragraphs = Array.from(document.querySelectorAll(selectors))

    paragraphs.forEach((paragraph) => {
      const myText = paragraph.textContent
        .split("\n")
        .reduce(function (prevVal, currVal, _idx) {
          return prevVal.trim() + " " + currVal.trim()
        }, "")

      if (!alternateCleanedText.includes(myText)) {
        const str = myText.trim()
        if (str.length) {
          alternateCleanedText.push(str)
        }
      }
    })

    return alternateCleanedText
  }

  textContentForClustering() {
    const alternateCleanedText = []

    const paragraphs = Array.from(this.articleContent.querySelectorAll("p"))

    paragraphs.forEach((paragraph) => {
      const myText = paragraph.textContent.trim()

      if (!alternateCleanedText.includes(myText)) {
        alternateCleanedText.push(myText)
      }
    })

    return alternateCleanedText
  }

  toString(): string {
    return this.constructor.name
  }
}
