import {
  BeamElement,
  BeamLogCategory,
  BeamWindow
} from "@beam/native-beamtypes"
import type { SearchWebPageUI as SearchWebPageUI } from "./SearchWebPageUI"
import { BeamLogger } from "@beam/native-utils"

class Operation {
  cancelled = false
  completed = false
  onCancelled?: () => void 
  onCompleted?: () => void

  cancel(): void {
    this.cancelled = true
    this.onCancelled()
  }

  complete(): void {
    this.completed = true
    if (!this.cancelled) {
      this.onCompleted()
    }
  }
}

export class SearchWebPage<UI extends SearchWebPageUI> {
  win: BeamWindow
  logger: BeamLogger
  lastEscapedQuery = ""
  lastFindOperation = null
  lastReplacements = null
  lastHighlights = null
  activeHighlightIndex = -1
  height = 1

  highlightSpan = null
  styleElement = null
  constants = {
    MAXIMUM_HIGHLIGHT_COUNT: 999,
    SCROLL_OFFSET_Y: 40,

    HIGHLIGHT_CLASS_NAME: "__ID__find-highlight",
    HIGHLIGHT_CLASS_NAME_ACTIVE: "__ID__find-highlight-active",
    RESULT_CLASS_NAME: "__ID__find-result",

    HIGHLIGHT_COLOR: "rgba(255, 214, 0, 0.6)",
    HIGHLIGHT_COLOR_ACTIVE: "rgba(255, 153, 0, 0.8)",
    BUMP_ANIMATION_NAME: "__ID__bump"
  }

  /**
   * Singleton
   *
   * @type SearchWebPage
   */
  static instance: SearchWebPage<any>

  /**
   * @param win {(BeamWindow)}
   * @param ui {SearchWebPageUI}
   */
  constructor(win: BeamWindow<any>, protected ui: UI) {
    this.win = win
    this.logger = new BeamLogger(win, BeamLogCategory.embedNode)
    this.registerEventListeners()
  }

  registerEventListeners(): void {
    this.win.addEventListener("load", this.onLoad.bind(this))
  }

  onLoad(): void {
    this.setupElements()
  }

  buildCSS() {
    return `
      @keyframes ${this.constants.BUMP_ANIMATION_NAME} {
        0% {
          transform: scale(1);
        }

        100% {
          transform: scale(1.3);
        }
      }

      .${this.constants.HIGHLIGHT_CLASS_NAME} {
        color: #000 !important;
        display: inline-block;
        position: relative;
      }

      .${this.constants.HIGHLIGHT_CLASS_NAME} > span {
        background-color: transparent !important;
        position: relative;
      }

      .${this.constants.HIGHLIGHT_CLASS_NAME}::before {
        background-color: ${this.constants.HIGHLIGHT_COLOR};
        border-radius: 3px;
        bottom: 0;
        content: "";
        left: -2px;
        position: absolute;
        right: -2px;
        top: 0;
        transform-origin: center center;
        transition: all 0.2s ease;
      }

      .${this.constants.HIGHLIGHT_CLASS_NAME}.${this.constants.HIGHLIGHT_CLASS_NAME_ACTIVE}::before {
        animation:
          ${this.constants.BUMP_ANIMATION_NAME} 200ms cubic-bezier(0.42, 0, 1, 1) both,
          ${this.constants.BUMP_ANIMATION_NAME} 70ms cubic-bezier(0, 0, 0.58, 1) 200ms forwards reverse
        ;
        background-color: ${this.constants.HIGHLIGHT_COLOR_ACTIVE};
      }`
  }

  setupElements() {
    this.styleElement = this.win.document.createElement("style")
    this.styleElement.innerHTML = this.buildCSS()

    this.highlightSpan = this.win.document.createElement("span")
    this.highlightSpan.className = this.constants.HIGHLIGHT_CLASS_NAME
  }

  find(query) {
    const trimmedQuery = query.trim()

    // If the trimmed query is empty, use it instead of the escaped
    // query to prevent searching for nothing but whitepsace.
    const escapedQuery = !trimmedQuery ? trimmedQuery : query.replace(/([.?*+^$[\]\\(){}|-])/g, "\\$1")
    if (escapedQuery === this.lastEscapedQuery) {
      return
    }

    if (this.lastFindOperation) {
      this.lastFindOperation.cancel()
    }

    this.clear()

    const body = this.win.document.body,
        html = this.win.document.documentElement

    this.height = Math.max(body.scrollHeight, body.offsetHeight,
                          html.clientHeight, html.scrollHeight, html.offsetHeight)

    this.lastEscapedQuery = escapedQuery

    if (!escapedQuery) {
      this.ui.webPageSearch({ currentResult: 0, totalResults: 0, positions: [], height: this.height, incompleteSearch: false  })
      return
    }

    const queryRegExp = new RegExp("(" + escapedQuery + ")", "gi")
    this.lastFindOperation = this.getMatchingNodeReplacements(queryRegExp, (replacements, highlights, isMaximumHighlightCount) => {
      let replacement
      for (let i = 0, length = replacements.length; i < length; i++) {
        replacement = replacements[i]
        replacement.originalNode.replaceWith(replacement.replacementFragment)
      }

      const positions = []
      for (let i = 0, length = highlights.length; i < length; i++) {
        const hightlight = highlights[i]

        const pos = hightlight.getBoundingClientRect()
        positions.push(pos.top + this.win.scrollY)
      }

      this.lastFindOperation = null
      this.lastReplacements = replacements
      this.lastHighlights = highlights
      this.activeHighlightIndex = -1

      const totalResults = highlights.length
      this.ui.webPageSearch({ totalResults: totalResults, positions: positions, height: this.height, incompleteSearch: isMaximumHighlightCount })

      this.findNext()
    })
  }

  findNext() {
    if (this.lastHighlights) {
      this.activeHighlightIndex = (this.activeHighlightIndex + this.lastHighlights.length + 1) % this.lastHighlights.length
      this.updateActiveHighlight()
    }
  }

  findPrevious() {
    if (this.lastHighlights) {
      this.activeHighlightIndex = (this.activeHighlightIndex + this.lastHighlights.length - 1) % this.lastHighlights.length
      this.updateActiveHighlight()
    }
  }

  findDone() {
    this.styleElement.remove()
    this.clear()

    this.lastEscapedQuery = ""
  }

  clear() {
    if (!this.lastHighlights) {
      return
    }

    const replacements = this.lastReplacements
    const highlights = this.lastHighlights

    let highlight
    for (let i = 0, length = highlights.length; i < length; i++) {
      highlight = highlights[i]

      this.removeHighlight(highlight)
    }

    this.lastReplacements = null
    this.lastHighlights = null
    this.activeHighlightIndex = -1
  }

  updateActiveHighlight() {
    if (!this.styleElement.parentNode) {
      this.win.document.body.appendChild(this.styleElement)
    }

    const lastActiveHighlight = this.win.document.querySelector("." + this.constants.HIGHLIGHT_CLASS_NAME_ACTIVE) as BeamElement
    if (lastActiveHighlight) {
      lastActiveHighlight.classList.remove(this.constants.HIGHLIGHT_CLASS_NAME_ACTIVE)
    }

    if (!this.lastHighlights) {
      return
    }

    const activeHighlight = this.lastHighlights[this.activeHighlightIndex]
    if (activeHighlight) {
      this.jumpToElement(activeHighlight)
      const selected = activeHighlight.getBoundingClientRect().top + this.win.scrollY

      activeHighlight.classList.add(this.constants.HIGHLIGHT_CLASS_NAME, this.constants.HIGHLIGHT_CLASS_NAME_ACTIVE)

      this.ui.webPageSearch({ currentResult: this.activeHighlightIndex, currentSelected: selected, height: this.height })
    } else {
      this.ui.webPageSearch({ currentResult: 0 })
    }
  }

  removeHighlight(highlight) {
    const parent = highlight.parentNode

    if (parent) {
        //We are doubling firstChild because we wrap in two spans
      while (highlight.firstChild.firstChild) {
        parent.insertBefore(highlight.firstChild.firstChild, highlight)
      }
      highlight.remove()
      parent.normalize()
    }
  }

  chunkedLoop(condition, iterator, chunkSize) {
    return new Promise((resolve, reject) => {
      setTimeout(doChunk, 0)
      function doChunk() {
        let argument
        for (let i = 0; i < chunkSize; i++) {
          argument = condition()
          if (!argument || iterator(argument) === false) {
            resolve(null)
            return
          }
        }
        setTimeout(doChunk, 0)
      }
    })
  }

  asyncTextNodeWalker(iterator) {
    const operation = new Operation()
    const walker = this.win.document.createTreeWalker(this.win.document.body, NodeFilter.SHOW_TEXT, null, false)

    const timeout = setTimeout(() => {
      this.chunkedLoop(() => { 
        return walker.nextNode() 
      }, (node) => {
        if (operation.cancelled) {
          return false
        }

        iterator(node)
        return true
      }, 100).then(() => {
        operation.complete()
      })
    }, 50)

    operation.onCancelled = () => {
      clearTimeout(timeout)
    }

    return operation
  }

  getMatchingNodeReplacements(regExp, callback) {
    const replacements = []
    const highlights = []
    let isMaximumHighlightCount = false
    const operation = this.asyncTextNodeWalker((originalNode) => {
      if (!this.isTextNodeVisible(originalNode) || originalNode.parentElement.nodeName === "IFRAME") {
        return
      }
      const originalTextContent = originalNode.textContent
      let lastIndex = 0
      const replacementFragment = this.win.document.createDocumentFragment()
      let hasReplacement = false
      let match

      while ((match = regExp.exec(originalTextContent))) {
        const matchTextContent = match[0]

        // Add any text before this match.
        if (match.index > 0) {
          const leadingSubstring = originalTextContent.substring(lastIndex, match.index)
          replacementFragment.appendChild(this.win.document.createTextNode(leadingSubstring))
        }

        // Add element for this match.
        const wrapper = this.highlightSpan.cloneNode(false)
        const element = this.win.document.createElement("span")
        wrapper.appendChild(element)
        element.textContent = matchTextContent
        replacementFragment.appendChild(wrapper)
        highlights.push(wrapper)

        lastIndex = regExp.lastIndex
        hasReplacement = true

        if (highlights.length > this.constants.MAXIMUM_HIGHLIGHT_COUNT) {
          isMaximumHighlightCount = true
          break
        }
      }
      if (hasReplacement) {
        // Add any text after the matches.
        if (lastIndex < originalTextContent.length) {
          const trailingSubstring = originalTextContent.substring(lastIndex, originalTextContent.length)
          replacementFragment.appendChild(this.win.document.createTextNode(trailingSubstring))
        }

        replacements.push({
          originalNode: originalNode,
          replacementFragment: replacementFragment
        })
      }
      if (isMaximumHighlightCount) {
        operation.cancel()
        callback(replacements, highlights, isMaximumHighlightCount)
      }
    })

    // Callback for if/when the text node loop completes (should
    // happen unless the maximum highlight count is reached).
    operation.onCompleted = () => {
      callback(replacements, highlights, isMaximumHighlightCount)
    }
    return operation
  }

  jumpToElement(element) {
    const rect = element.getBoundingClientRect()
    const targetX = this.clamp(rect.left + this.win.scrollX - this.win.innerWidth / 2, 0, this.win.document.body.scrollWidth)
    const targetY = this.clamp(this.constants.SCROLL_OFFSET_Y + rect.top + this.win.scrollY - this.win.innerHeight / 2 + 100, 0, this.height)

      this.win.scrollTo(targetX, targetY)
  }

  isTextNodeVisible(textNode) {
    const element = textNode.parentElement
    if (!element) {
      return false
    }
    return !!(element.offsetWidth || element.offsetHeight || element.getClientRects().length)
  }

  clamp(value, min, max) {
    return Math.max(min, Math.min(value, max))
  }

  getSelection() {
      const txt = this.win.document.getSelection().toString() 
      this.ui.webSearchCurrentSelection(txt) 
  }

  toString(): string {
    return this.constructor.name
  }
}
