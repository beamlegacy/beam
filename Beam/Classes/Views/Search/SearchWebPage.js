/* vim: set ts=2 sts=2 sw=2 et tw=80: */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

"use strict";

if (!window.beam) {
  window.beam = {};
}

window.beam.__ID__SearchWebPage = {

    lastEscapedQuery: "",
    lastFindOperation: null,
    lastReplacements: null,
    lastHighlights: null,
    activeHighlightIndex: -1,
    height: 1,

    highlightSpan: null,
    styleElement: null,

    constants: {
      MAXIMUM_HIGHLIGHT_COUNT: 999,
      SCROLL_OFFSET_Y: 40,

      HIGHLIGHT_CLASS_NAME: "__ID__find-highlight",
      HIGHLIGHT_CLASS_NAME_ACTIVE: "__ID__find-highlight-active",
      RESULT_CLASS_NAME: "__ID__find-result",

      HIGHLIGHT_COLOR: "rgba(255, 214, 0, 0.6)",
      HIGHLIGHT_COLOR_ACTIVE: "rgba(255, 153, 0, 0.8)",
      BUMP_ANIMATION_NAME: "__ID__bump",
    },

    buildCSS: function () {
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
        }`;
    },

    setupElements: function () {
      this.styleElement = document.createElement("style");
      this.styleElement.innerHTML = this.buildCSS();

      this.highlightSpan = document.createElement("span");
      this.highlightSpan.className = this.constants.HIGHLIGHT_CLASS_NAME;
    },

    find: function (query) {
      let trimmedQuery = query.trim();

      // If the trimmed query is empty, use it instead of the escaped
      // query to prevent searching for nothing but whitepsace.
      let escapedQuery = !trimmedQuery ? trimmedQuery : query.replace(/([.?*+^$[\]\\(){}|-])/g, "\\$1");
      if (escapedQuery === this.lastEscapedQuery) {
        return;
      }

      if (this.lastFindOperation) {
        this.lastFindOperation.cancel();
      }

      this.clear();

      var body = document.body,
          html = document.documentElement;

      this.height = Math.max(body.scrollHeight, body.offsetHeight,
                            html.clientHeight, html.scrollHeight, html.offsetHeight);

      this.lastEscapedQuery = escapedQuery;

      if (!escapedQuery) {
        window.webkit.messageHandlers.webPageSearch.postMessage({ currentResult: 0, totalResults: 0, positions: [], height: this.height, incompleteSearch: false  });
        return;
      }

      let queryRegExp = new RegExp("(" + escapedQuery + ")", "gi");
      this.lastFindOperation = this.getMatchingNodeReplacements(queryRegExp, (replacements, highlights, isMaximumHighlightCount) => {
        let replacement;
        for (let i = 0, length = replacements.length; i < length; i++) {
          replacement = replacements[i];
          replacement.originalNode.replaceWith(replacement.replacementFragment);
        }

        let positions = []
        for (let i = 0, length = highlights.length; i < length; i++) {
          let hightlight = highlights[i];

          let pos = hightlight.getBoundingClientRect();
          positions.push(pos.top + window.scrollY);
        }

        this.lastFindOperation = null;
        this.lastReplacements = replacements;
        this.lastHighlights = highlights;
        this.activeHighlightIndex = -1;

        let totalResults = highlights.length;
        window.webkit.messageHandlers.webPageSearch.postMessage({ totalResults: totalResults, positions: positions, height: this.height, incompleteSearch: isMaximumHighlightCount });

        this.findNext();
      });
    },

    findNext: function () {
      if (this.lastHighlights) {
        this.activeHighlightIndex = (this.activeHighlightIndex + this.lastHighlights.length + 1) % this.lastHighlights.length;
        this.updateActiveHighlight();
      }
    },

    findPrevious: function () {
      if (this.lastHighlights) {
        this.activeHighlightIndex = (this.activeHighlightIndex + this.lastHighlights.length - 1) % this.lastHighlights.length;
        this.updateActiveHighlight();
      }
    },

    findDone: function () {
      this.styleElement.remove();
      this.clear();

      this.lastEscapedQuery = "";
    },

    clear: function () {
      if (!this.lastHighlights) {
        return;
      }

      let replacements = this.lastReplacements;
      let highlights = this.lastHighlights;

      let highlight;
      for (let i = 0, length = highlights.length; i < length; i++) {
        highlight = highlights[i];

        this.removeHighlight(highlight);
      }

      this.lastReplacements = null;
      this.lastHighlights = null;
      this.activeHighlightIndex = -1;
    },

    updateActiveHighlight: function () {
      if (!this.styleElement.parentNode) {
        document.body.appendChild(this.styleElement);
      }

      let lastActiveHighlight = document.querySelector("." + this.constants.HIGHLIGHT_CLASS_NAME_ACTIVE);
      if (lastActiveHighlight) {
        lastActiveHighlight.classList.remove(this.constants.HIGHLIGHT_CLASS_NAME_ACTIVE);
      }

      if (!this.lastHighlights) {
        return;
      }

      let activeHighlight = this.lastHighlights[this.activeHighlightIndex];
      if (activeHighlight) {
        this.jumpToElement(activeHighlight);
        let selected = activeHighlight.getBoundingClientRect().top + window.scrollY;

        activeHighlight.classList.add(this.constants.HIGHLIGHT_CLASS_NAME, this.constants.HIGHLIGHT_CLASS_NAME_ACTIVE);

        window.webkit.messageHandlers.webPageSearch.postMessage({ currentResult: this.activeHighlightIndex + 1, currentSelected: selected, height: this.height });
      } else {
        window.webkit.messageHandlers.webPageSearch.postMessage({ currentResult: 0 });
      }
    },

    removeHighlight: function (highlight) {
      let parent = highlight.parentNode;

      if (parent) {
          //We are doubling firstChild because we wrap in two spans
        while (highlight.firstChild.firstChild) {
          parent.insertBefore(highlight.firstChild.firstChild, highlight);
        }
        highlight.remove();
        parent.normalize();
      }
    },

    chunkedLoop: function (condition, iterator, chunkSize) {
      return new Promise((resolve, reject) => {
        setTimeout(doChunk, 0);
        function doChunk() {
          let argument;
          for (let i = 0; i < chunkSize; i++) {
            argument = condition();
            if (!argument || iterator(argument) === false) {
              resolve();
              return;
            }
          }
          setTimeout(doChunk, 0);
        }
      });
    },

    asyncTextNodeWalker: function (iterator) {
      let operation = new this.Operation();
      let walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, null, false);

      let timeout = setTimeout(() => {
        this.chunkedLoop(() => { 
          return walker.nextNode(); 
        }, (node) => {
          if (operation.cancelled) {
            return false;
          }

          iterator(node);
          return true;
        }, 100).then(() => {
          operation.complete();
        });
      }, 50);

      operation.oncancelled = () => {
        clearTimeout(timeout);
      };

      return operation;
    },

    getMatchingNodeReplacements: function (regExp, callback) {
      let replacements = [];
      let highlights = [];
      let isMaximumHighlightCount = false;
      let operation = this.asyncTextNodeWalker((originalNode) => {
        if (!this.isTextNodeVisible(originalNode) || originalNode.parentElement.nodeName === "IFRAME") {
          return;
        }
        let originalTextContent = originalNode.textContent;
        let lastIndex = 0;
        let replacementFragment = document.createDocumentFragment();
        let hasReplacement = false;
        let match;

        while ((match = regExp.exec(originalTextContent))) {
          let matchTextContent = match[0];

          // Add any text before this match.
          if (match.index > 0) {
            let leadingSubstring = originalTextContent.substring(lastIndex, match.index);
            replacementFragment.appendChild(document.createTextNode(leadingSubstring));
          }

          // Add element for this match.
          let wrapper = this.highlightSpan.cloneNode(false);
          let element = document.createElement("span");
          wrapper.appendChild(element)
          element.textContent = matchTextContent;
          replacementFragment.appendChild(wrapper);
          highlights.push(wrapper);

          lastIndex = regExp.lastIndex;
          hasReplacement = true;

          if (highlights.length > this.constants.MAXIMUM_HIGHLIGHT_COUNT) {
            isMaximumHighlightCount = true;
            break;
          }
        }
        if (hasReplacement) {
          // Add any text after the matches.
          if (lastIndex < originalTextContent.length) {
            let trailingSubstring = originalTextContent.substring(lastIndex, originalTextContent.length);
            replacementFragment.appendChild(document.createTextNode(trailingSubstring));
          }

          replacements.push({
            originalNode: originalNode,
            replacementFragment: replacementFragment
          });
        }
        if (isMaximumHighlightCount) {
          operation.cancel();
          callback(replacements, highlights, isMaximumHighlightCount);
        }
      });

      // Callback for if/when the text node loop completes (should
      // happen unless the maximum highlight count is reached).
      operation.oncompleted = () => {
        callback(replacements, highlights, isMaximumHighlightCount);
      };
      return operation;
    },

    jumpToElement: function (element) {
      let rect = element.getBoundingClientRect();
      let targetX = this.clamp(rect.left + window.scrollX - window.innerWidth / 2, 0, document.body.scrollWidth);
      let targetY = this.clamp(this.constants.SCROLL_OFFSET_Y + rect.top + window.scrollY - window.innerHeight / 2 + 100, 0, this.height);

        window.scrollTo(targetX, targetY);
    },

    isTextNodeVisible: function (textNode) {
      let element = textNode.parentElement;
      if (!element) {
        return false;
      }
      return !!(element.offsetWidth || element.offsetHeight || element.getClientRects().length);
    },

    clamp: function (value, min, max) {
      return Math.max(min, Math.min(value, max));
    },

    getSelection: function () {
        var txt = document.getSelection().toString() ;
        window.webkit.messageHandlers.webSearchCurrentSelection.postMessage( {selection:txt} ) ;
    },

    Operation: function () {
      this.cancelled = false;
      this.completed = false;
    }
}

window.beam.__ID__SearchWebPage.setupElements();

window.beam.__ID__SearchWebPage.Operation.prototype.cancel = function() {
  this.cancelled = true;

  if (typeof this.oncancelled === "function") {
    this.oncancelled();
  }
};

window.beam.__ID__SearchWebPage.Operation.prototype.complete = function() {
  this.completed = true;

  if (typeof this.oncompleted === "function") {
    if (!this.cancelled) {
      this.oncompleted();
    }
  }
};
