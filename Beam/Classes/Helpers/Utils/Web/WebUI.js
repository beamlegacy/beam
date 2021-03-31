export class WebUI {
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

  constructor() {
    console.log(`${this} instantiated`)
  }

  toString() {
    return "WebUI"
  }

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
      this.cardToProposal(c, txt, proposals)
    }
    return proposals
  }

  cardToProposal(c, txt, proposals) {
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

  enterSelection() {
    if (!this.overlayEl) {
      this.backdropEl = document.createElement("div")
      this.backdropEl.id = this.backdropId
      this.overlayEl = document.createElement("div")
      this.overlayEl.id = this.overlayId
      let body = document.body
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

  addTextSelection(selection) {
    const textAreas = selection.areas
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

  textSelected(selection) {
    // TODO: Shoot selected areas
  }

  setFramesInfo(framesInfo) {
    // Nothing to do in Web UI
  }

  setScrollInfo(scrollInfo) {
    // Nothing to do in Web UI
  }

  setResizeInfo(resizeInfo) {
    // Nothing to do in Web UI
  }

  static getInstance() {
    let instance
    try {
      instance = new WebUI()
    } catch (e) {
      console.error(e)
      instance = null
    }
    return instance
  }
}
