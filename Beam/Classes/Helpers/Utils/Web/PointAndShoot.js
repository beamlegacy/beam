// TODO: Put WebUI in another file
class WebUI {
  prefix = "__ID__"
  origin = document.body.baseURI

  outlineWidth = 4

  /**
   * Message translations for web UI, if required.
   */
  messages = {
    en: {
      close: "Close",
      addTo: "Add to",
      journal: "Journal",
      dropArrow: "Click to drop down cards list",
      addNote: "Add notes...",
      addedTo: "Added to"
    },
    fr: {
      close: "Fermer",
      addTo: "Ajouter à",
      journal: "Journal",
      dropArrow: "Cliquez pour dérouler la liste des cartes",
      addNote: "Ajouter des notes...",
      addedTo: "Ajouté à"
    }
  }
  navigatorLanguage = navigator.language.substring(0, 2)
  documentLanguage = document.lang
  lang = this.navigatorLanguage || this.documentLanguage

  existingCards = [
    {id: 1, title: "Michael Heizer"},
    {id: 2, title: "James Dean"},
    {id: 3, title: "Michael Jordan"}
  ]

  prefixClass = this.prefix
  shootClass = `${this.prefix}-shoot`
  pointClass = `${this.prefix}-point`
  popupClass = `${this.prefix}-popup`
  cardClass = `${this.prefix}-card`
  noteClass = `${this.prefix}-note`
  labelClass = `${this.prefix}-label`
  inputClass = `${this.prefix}-input`
  proposalsClass = `${this.prefix}-proposals`
  proposalClass = `${this.prefix}-proposal`
  statusClass = `${this.prefix}-status`
  formRowClass = `${this.prefix}-form-row`
  overlayId = `${this.prefix}-overlay`
  backdropId = `${this.prefix}-backdrop`
  selectionClass = `${this.prefix}-selection`

  popupId = `${this.prefix}-popup`
  popupAnchor = document.body
  popup

  statusId = `${this.prefix}-status`

  inputTouched

  overlayEl
  backdropEl

  point(el) {
    el.classList.add(this.pointClass)
  }

  unpoint(el) {
    el.classList.remove(this.pointClass)
    el.style.cursor = ``
  }

  removeSelected(el) {
    el.classList.remove(this.shootClass)
  }

  submit(submitCb) {
    this.hidePopup()
    submitCb()
  }

  showPopup(el, x, y, submitCb) {
    const msg = this.messages[this.lang]
    this.popup = document.createElement("DIV")
    this.popup.id = this.popupId
    this.popup.classList.add(this.prefixClass)
    this.popup.classList.add(this.popupClass)
    this.newCard = {id: 0, title: "", hint: "– New card"}
    this.selectedCard = this.existingCards.length > 0 ? this.existingCards[0] : this.newCard
    const value = this.selectedCard.title
    this.inputTouched = false
    this.popup.innerHTML = `
    <form>
      <div class="${this.cardClass}">
        <div class="${this.formRowClass}">
          <label for="${this.cardInputId}" class="${this.labelClass}">${msg.addTo}</label>
          <input class="${this.inputClass}" id="${this.cardInputId}" value="${value}" autocomplete="off"/>
          <span class="shortcut hint">↵</span>
        </div>
        <ul id="proposals" class="${this.proposalsClass}"></ul>
      </div>
      <div class="${this.formRowClass} ${this.noteClass}">
        <input class="${this.inputClass}" placeholder="${msg.addNote}"/>
      </div>
    </form>
    `
    this.popupAnchor.append(this.popup)

    const form = this.popup.querySelector(`form`)
    form.addEventListener("submit", () => this.submit())
    const cardInput = this.popup.querySelector(`#${this.cardInputId}`)
    cardInput.addEventListener("keydown", (ev) => this.cardKeyDown(ev, submitCb))
    cardInput.addEventListener("input", this.onCardInput)

    this.popup.style.left = `${x}px`
    const popupTop = window.scrollY + y
    this.popup.style.top = `${popupTop}px`
    this.cardInputEl().focus()
  }

  hidePopup() {
    if (this.popup) {
      this.popup.remove()
      this.popup = null
    }
  }

  newCard

  cardsToProposals(cards, txt) {
    const proposals = []
    for (const c of cards) {
      let title = c.title
      let matchPos = title.toLowerCase().indexOf(txt)
      if (matchPos >= 0) {
        let value = `${title.substr(0, matchPos)}<b>${title.substr(
            matchPos,
            txt.length
        )}</b>${title.substr(matchPos + txt.length)}`
        let hint = c.hint
        if (hint) {
          value += ` <span class="hint">${hint}</span>`
        }
        proposals.push({key: c.id, value})
      }
    }
    return proposals
  }

  onCardInput(ev) {
    const input = ev.target
    if (!this.inputTouched) {
      input.value = ev.data
    }
    let inputValue = input.value
    let possibles = this.existingCards
    if (inputValue) {
      input.value =
          inputValue.substring(0, 1).toUpperCase() + inputValue.substring(1)
      this.newCard.title = input.value
      possibles = this.existingCards.concat(this.newCard)
    }
    const txt = inputValue.toLowerCase()
    const proposals = this.cardsToProposals(possibles, txt)
    this.showProposals(proposals)
    this.inputTouched = true
  }

  cardKeyDown(ev, submitCb) {
    console.log(ev.key)
    switch (ev.key) {
      case "Escape":
        this.hidePopup()
        break
      case "Enter":
        this.submit(submitCb)
        break
      case "ArrowDown":
        break
      case "ArrowUp":
        break
    }
  }

  selectedCard

  selectProposal(id) {
    this.selectedCard = this.existingCards.find((c) => c.id === id)
    this.cardInputEl().value = this.selectedCard.title
    this.proposalsEl().innerHTML = ""
  }

  proposalsEl() {
    return document.querySelector(`#${this.popupId} #proposals`)
  }

  showProposals(ps) {
    const pList = this.proposalsEl()
    pList.innerHTML = ""
    for (const p of ps) {
      const li = document.createElement("LI")
      li.className = this.proposalClass
      li.addEventListener("click", () => this.selectProposal(p.key))
      li.innerHTML = p.value
      pList.appendChild(li)
    }
  }

  dropDown() {
    this.showProposals(this.cardsToProposals(this.existingCards, ""))
  }

  cardInputId = `${this.prefix}-add-to`

  cardInputEl() {
    return document.getElementById(this.cardInputId)
  }

  shoot(el, x, y, selected, submitCb) {
    el.classList.remove(this.pointClass)
    el.classList.add(this.shootClass)
    const count = selected.length > 1 ? "" + selected.length : ""
    for (const s of selected) {
      s.style.cursor = `url('data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" width="40" height="30" viewBox="20 0 30 55" style="stroke:rgb(165,165,165);stroke-linecap:round;stroke-width:3"><rect x="10" y="20" width="54" height="25" ry="10" style="stroke-width:1; fill:white"/><text x="15" y="39" style="font-size:20px;stroke-linecap:butt;stroke-width:1">${count}</text><line x1="35" y1="26" x2="50" y2="26"/><line x1="35" y1="32" x2="50" y2="32"/><line x1="35" y1="38" x2="45" y2="38"/><g id="Page-1" stroke="none" stroke-width="1" fill="none" fill-rule="evenodd"><g id="notallowed"><path d="M8,17.4219 L8,1.4069 L19.591,13.0259 L12.55,13.0259 L12.399,13.1499 L8,17.4219 Z" id="point-border" fill="white"/><path d="M9,3.814 L9,15.002 L11.969,12.136 L12.129,11.997 L17.165,11.997 L9,3.814 Z" id="point" fill="black"/></g></g></svg>') 5 5, auto`
    }
    this.hidePopup()  // Hide previous, if any
    this.showPopup(el, x, y, submitCb)
  }

  statusEl

  /**
   * Show the if a given was added to a card.
   */
  showStatus(el, collected) {
    const msg = this.messages[this.lang]
    const statusEl = this.statusEl = document.createElement("DIV")
    el.classList.add(this.prefixClass)
    el.classList.add(this.statusClass)
    statusEl.innerHTML = `${msg.addedTo} ${collected.title}`
    this.popupAnchor.append(this.statusEl)
    const bounds = el.getBoundingClientRect()
    statusEl.style.left = `${bounds.x}px`
    const statusTop = window.scrollY + bounds.bottom + this.outlineWidth
    statusEl.style.top = `${statusTop}px`
  }

  hideStatus() {
    if (this.statusEl) {
      this.statusEl.remove()
      this.statusEl = null
    }
  }

  enterSelection(scrollWidth) {
    if (!this.overlayEl) {
      this.backdropEl = document.createElement("div")
      this.backdropEl.id = this.backdropId
      this.overlayEl = document.createElement("div")
      this.overlayEl.id = this.overlayId
      let body = document.body
      this.overlayEl.style.width = (scrollWidth || window.innerWidth) + "px"
      body.appendChild(this.backdropEl)
      body.appendChild(this.overlayEl)
    }
  }

  leaveSelection() {
    if (this.overlayEl) {
      document.body.removeChild(this.overlayEl)
      document.body.removeChild(this.backdropEl)
      this.overlayEl = null
    }
  }

  selectAreas(textAreas) {
    this.overlayEl.innerHTML = ""
    const padding = 5
    for (let r = 0; r < textAreas.length; r++) {
      const rect = textAreas[r]
      const rectSelection = document.createElement("div")
      rectSelection.className = this.selectionClass
      rectSelection.style.position = "absolute"
      rectSelection.style.left = rect.x + "px"
      rectSelection.style.top = rect.y - padding + "px"
      rectSelection.style.width = rect.width + "px"
      rectSelection.style.height = rect.height + padding * 2 + "px"
      this.overlayEl.appendChild(rectSelection)
    }
  }
}

class NativeUI {
  prefix = "__ID__"
  origin = document.body.baseURI

  constructor() {
    this.messageHandlers = window.webkit && window.webkit.messageHandlers
    if (!this.messageHandlers) {
      throw Error("Could not find webkit message handlers")
    }
  }

  /**
   * Message to the native part.
   *
   * @param name Message name.
   *        Will be converted to ${prefix}_beam_${name} before sending.
   * @param payload The message data.
   *        An "origin" property will always be added as the base URI of the current frame.
   */
  sendMessage(name, payload) {
    console.log("sendMessage", name, payload)
    const messageKey = `beam_${name}`
    const messageHandler = this.messageHandlers[messageKey]
    if (messageHandler) {
      messageHandler.postMessage({origin, ...payload}, origin)
    } else {
      throw Error(`No message handler for message "${name}"`)
    }
  }

  pointMessage(el, x, y) {
    const bounds = el.getBoundingClientRect()
    const pointPayload = {
      origin,
      type: {
        tagName: el.tagName
      },
      location: {x, y},
      data: {
        text: el.innerText
      },
      area: {
        x: bounds.x,
        y: bounds.y,
        width: bounds.width,
        height: bounds.height
      }
    }
    this.sendMessage("point", pointPayload)
  }

  shootMessage(el, x, y) {
    const bounds = el.getBoundingClientRect()
    const shootMessage = {
      origin,
      type: {
        tagName: el.tagName
      },
      data: {
        text: el.innerText
      },
      location: {x, y},
      area: {
        x: bounds.x,
        y: bounds.y,
        width: bounds.width,
        height: bounds.height
      }
    }
    this.sendMessage("shoot", shootMessage)
  }

  point(el, x, y) {
    this.pointMessage(el, x, y)
  }

  unpoint() {
    this.sendMessage("point", null)
  }

  removeSelected(el) {
    // TODO: message to un-shoot
  }

  submit(selected) {
    for (const s of selected) {
      s.dataset[this.datasetKey] = JSON.stringify(this.selectedCard)
    }
    this.hidePopup()
  }

  showPopup(el, x, y, selected) {
    // TODO: Send popup message?
  }

  hidePopup() {
    // TODO: Hide popup message?
  }

  shoot(el, x, y, selected, submitCb) {
    this.shootMessage(el, x, y)
    this.hidePopup()  // Hide previous, if any
    this.showPopup(el, x, y, selected)
    // TODO: handle native popup result (probably not using submitCb, but rather through native explicitly invoking JS directly?)
  }

  /**
   * Show the if a given was added to a card.
   */
  showStatus(el, collected) {
    // TODO: Send message to display native status as "collected" data
  }

  hideStatus() {
    // TODO: Send message to hide native status display
  }

  enterSelection(scrollWidth) {
    // TODO: enter selction message
  }

  leaveSelection() {
    // TODO:
  }

  selectAreas(i, selectedText, selectedHTML, textAreas) {
    // TODO: Throttle
    this.sendMessage("textSelected", {index: i, text: selectedText, html: selectedHTML, areas: textAreas})
  }

  setFramesInfos(framesInfo) {
    this.sendMessage("frameBounds", {frames: framesInfo})
  }

  setScrollInfo(scrollInfo) {
    this.sendMessage("onScrolled", scrollInfo)
  }

  setResizeInfo(resizeInfo, selected) {
    this.sendMessage("resize", resizeInfo)
    for (const someSelected of selected) {
      this.shootMessage(someSelected, -1, -1)
    }
  }
}

const webUi = new WebUI()
const nativeUi = new NativeUI()

/**
 * UI that performs both Web and native UI.
 *
 * For debug purposes.
 */
class BothUI {

  point(el, x, y) {
    webUi.point(el)
    nativeUi.point(el, x, y)
  }

  unpoint(el) {
    webUi.unpoint(el)
    nativeUi.unpoint(el)
  }

  shoot(el, x, y, selected, submitCb) {
    webUi.shoot(el, x, y, selected, submitCb)
    nativeUi.shoot(el, x, y, selected, submitCb)
  }

  setFramesInfo(framesInfo) {
    nativeUi.setFramesInfos(framesInfo)
  }

  setScrollInfo(scrollInfo) {
    nativeUi.setScrollInfo(scrollInfo)
  }

  setResizeInfo(resizeInfo, selected) {
    nativeUi.setResizeInfo(resizeInfo, selected)
  }

  enterSelection(scrollWidth) {
    webUi.enterSelection(scrollWidth)
    nativeUi.enterSelection()
  }

  leaveSelection() {
    webUi.leaveSelection()
    nativeUi.leaveSelection()
  }

  selectAreas(i, selectedText, selectedHTML, textAreas) {
    webUi.selectAreas(textAreas)
    nativeUi.selectAreas(i, selectedText, selectedHTML, textAreas)
  }

  hideStatus() {
    webUi.hideStatus()
    nativeUi.hideStatus()
  }

  hidePopup() {
    webUi.hidePopup()
    nativeUi.hidePopup()
  }
}

const ui = new BothUI();

(function PointAndShoot() {
      const origin = document.body.baseURI
      console.log("PointAndShoot initializing", origin)

      const datasetKey = `${this.prefix}Collect`

      let scrollWidth

      /**
       * Shoot elements.
       */
      const selected = []

      function point(el, x, y) {
        ui.point(el, x, y)
      }

      function unpoint(el) {
        ui.unpoint(el)
        pointed = null
      }

      function removeSelected(selectedIndex, el) {
        selected.splice(selectedIndex, 1)
        ui.removeSelected(el)
        delete el.dataset[datasetKey]
      }

      /**
       * The currently highlighted element
       */
      let pointed

      function onMouseMove(ev) {
        if (ev.altKey) {
          ev.preventDefault()
          ev.stopPropagation()
          const el = ev.target
          if (pointed !== el) {
            if (pointed) {
              unpoint(pointed) // Remove previous
            }
            pointed = el
            point(pointed, ev.clientX, ev.clientY)
            let collected = pointed.dataset[datasetKey]
            if (collected) {
              showStatus(pointed)
            } else {
              hideStatus()
            }
          } else {
            ui.hidePopup()
          }
        } else {
          hideStatus()
          if (pointed) {
            unpoint(pointed)
          }
        }
      }

      function showStatus(el) {
        const data = el.dataset[this.datasetKey]
        const collected = JSON.parse(data)
        ui.showStatus(el, collected)
      }

      function hideStatus() {
        ui.hideStatus()
      }

      /**
       * Select an HTML element to be added to a card.
       *
       * @param ev The selection event (click or touch).
       * @param x Horizontal coordinate of click/touch
       * @param y Vertical coordinate of click/touch
       */
      function select(ev, x, y) {
        const el = ev.target
        ev.preventDefault()
        ev.stopPropagation()
        const selectedIndex = selected.indexOf(el)
        const alreadySelected = selectedIndex >= 0
        if (alreadySelected) {
          // Unselect
          removeSelected(selectedIndex, el)
          return
        }
        const multiSelect = ev.metaKey
        if (!multiSelect && selected.length > 0) {
          removeSelected(0, selected[0]) // previous selection will be replaced
        }
        selected.push(el)
        // point(el, x, y)
        ui.shoot(el, x, y, selected, () => {
          for (const s of selected) {
            s.dataset[datasetKey] = JSON.stringify(this.selectedCard) // Remember shoots in DOM
          }
        })
      }

      function onClick(ev) {
        if (ev.altKey) {
          select(ev, ev.clientX, ev.clientY)
        }
      }

      function onlongtouch(ev) {
        const touch = ev.touches[0]
        select(ev, touch.clientX, touch.clientY)
      }

      let timer
      const touchDuration = 2500 //length of time we want the user to touch before we do something

      function touchstart(ev) {
        if (!timer) {
          timer = setTimeout(() => onlongtouch(ev), touchDuration)
        }
      }

      function touchend(_ev) {
        if (timer) {
          clearTimeout(timer)
          timer = null
        }
      }

      function onKeyPress(ev) {
        if (ev.code === "Escape") {
          ui.hidePopup()
          ui.leaveSelection()
        }
      }

      function checkFrames() {
        const frameEls = document.querySelectorAll("iframe")
        const hasFrames = frameEls.length > 0
        const framesInfo = []
        if (hasFrames) {
          for (const frameEl of frameEls) {
            const bounds = frameEl.getBoundingClientRect()
            const frameInfo = {
              origin,
              href: frameEl.src,
              bounds: {
                x: bounds.x,
                y: bounds.y,
                width: bounds.width,
                height: bounds.height
              }
            }
            framesInfo.push(frameInfo)
            console.log(origin, "has frame", framesInfo)
          }
        } else {
          console.log("No frames")
        }
        ui.setFramesInfo(framesInfo)
        return hasFrames
      }

      function onScroll(_ev) {
        // TODO: Throttle
        const body = document.body
        const documentEl = document.documentElement
        scrollWidth = Math.max(
            body.scrollWidth,
            documentEl.scrollWidth,
            body.offsetWidth,
            documentEl.offsetWidth,
            body.clientWidth,
            documentEl.clientWidth
        )
        const scrollHeight = Math.max(
            body.scrollHeight,
            documentEl.scrollHeight,
            body.offsetHeight,
            documentEl.offsetHeight,
            body.clientHeight,
            documentEl.clientHeight
        )
        const scrollInfo = {
          x: window.scrollX,
          y: window.scrollY,
          width: scrollWidth,
          height: scrollHeight
        }
        ui.setScrollInfo(scrollInfo)
        const hasFrames = checkFrames()
        console.log(hasFrames ? "Scroll updated frames info" : "Scroll did not update frames info since there is none")
      }

      function onResize(_ev) {
        const resizeInfo = {
          width: window.innerWidth,
          height: window.innerHeight
        }
        ui.setResizeInfo(resizeInfo, selected)
      }

      function onSelectionChange(_ev) {
        const selection = document.getSelection()
        if (selection.isCollapsed) {
          ui.leaveSelection()
          return
        }
        ui.enterSelection(scrollWidth)

        for (let i = 0; i < selection.rangeCount; ++i) {
          const range = selection.getRangeAt(i)
          const selectedText = range.toString()
          const selectedFragment = range.cloneContents()
          let selectedHTML = Array.prototype.reduce.call(
              selectedFragment.childNodes,
              (result, node) => result + (node.outerHTML || node.nodeValue),
              ""
          )
          const rects = range.getClientRects()
          const textAreas = []
          let frameX = window.scrollX
          let frameY = window.scrollY
          for (let r = 0; r < rects.length; r++) {
            const rect = rects[r]
            textAreas.push({x: frameX + rect.x, y: frameY + rect.y, width: rect.width, height: rect.height})
          }
          ui.selectAreas(i, selectedText, selectedHTML, textAreas)
        }
      }

      function onLoad(_ev) {
        console.log("Page load. Checking frames")
        checkFrames()
      }

      checkFrames()
      onScroll()   // Init/refresh scroll info

      window.addEventListener("load", onLoad)
      window.addEventListener("resize", onResize)
      window.addEventListener("mousemove", onMouseMove)
      window.addEventListener("click", onClick)
      window.addEventListener("scroll", onScroll)
      document.addEventListener("keypress", onKeyPress)
      document.addEventListener("selectionchange", onSelectionChange)
      // window.addEventListener("touchstart", touchstart, false);
      // window.addEventListener("touchend", touchend, false);
    }
)()

