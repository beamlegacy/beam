import { BeamLogger } from "@beam/native-utils"
import {BeamHTMLElement, BeamLogCategory, BeamRangeGroup, BeamShootGroup} from "@beam/native-beamtypes"
import {PointAndShootUI} from "./PointAndShootUI"

export class PointAndShootUI_web implements PointAndShootUI {
  prefix= "__ID__"
  shootClass = `${this.prefix}-shoot`

  pointClass = `${this.prefix}-point`

  overlayId = `${this.prefix}-overlay`

  backdropId = `${this.prefix}-backdrop`

  selectingClass = `${this.prefix}-selecting`

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

  existingCards = [
    {id: 1, title: "Michael Heizer"},
    {id: 2, title: "James Dean"},
    {id: 3, title: "Michael Jordan"}
  ]

  private prefixClass = this.prefix

  private popupClass = `${this.prefix}-popup`

  private cardClass = `${this.prefix}-card`

  private noteClass = `${this.prefix}-note`

  private labelClass = `${this.prefix}-label`

  private inputClass = `${this.prefix}-input`

  private proposalsClass = `${this.prefix}-proposals`

  private proposalClass = `${this.prefix}-proposal`

  private statusClass = `${this.prefix}-status`

  private formRowClass = `${this.prefix}-form-row`

  private popupId = `${this.prefix}-popup`

  private popupAnchor = document.body

  private popup

  private cardInputId = `${this.prefix}-add-to`

  // private statusId = `${this.prefix}-status`

  private inputTouched

  private overlayEl

  private backdropEl

  private statusEl

  /**
   * @type {(BeamWindow)}
   */
  win
  lang: any
  logger: BeamLogger

  /**
   * @param win {BeamWindow}
   */
  constructor(win) {
    this.win = win
    this.logger = new BeamLogger(win, BeamLogCategory.pointAndShoot)
    this.logger.log(`${this.toString()} instantiated`)
  }
  log(arg0: string): void {
    throw new Error("Method not implemented.")
  }
  clearSelection(_id: string): void {
    throw new Error("Method not implemented.")
  }
  typingOnWebView(_isTypingOnWebView: boolean): void {
      throw new Error("Method not implemented.")
  }
  pointBounds(_pointTarget?: BeamShootGroup): void {
      throw new Error("Method not implemented.")
  }
  shootBounds(_shootTargets: BeamShootGroup[]): void {
      throw new Error("Method not implemented.")
  }
  selectBounds(_rangeGroups: BeamRangeGroup[]): void {
      throw new Error("Method not implemented.")
  }
  hasSelection(_hasSelection: boolean): void {
      throw new Error("Method not implemented.")
  }
  cursor(_x: any, _y: any) {
    throw new Error("Method not implemented.")
  }

  unselect(_selection: any) {
    throw new Error("Method not implemented.")
  }

  getMouseLocation(_el: any, _x: any, _y: any) {
    // not used in web
  }

  point(_quoteId: string, el: BeamHTMLElement, _x: number, _y: number) {
    this.enterSelection()
    el.classList.add(this.pointClass)
  }

  unpoint(el) {
    el.classList.remove(this.pointClass)
    el.style.cursor = ""
    this.leaveSelection()
  }

  shoot(_quoteId: string, el: BeamHTMLElement, x: number, y: number, selectedEls) {
    el.classList.remove(this.pointClass)
    el.classList.add(this.shootClass)
    const count = selectedEls.length > 1 ? `${selectedEls.length}` : ""
    for (let i = 0; i < selectedEls.length; i++) {
      const s = selectedEls[i]
      s.style.cursor = `url('data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" width="40" height="30" viewBox="20 0 30 55" style="stroke:rgb(165,165,165);stroke-linecap:round;stroke-width:3"><rect x="10" y="20" width="54" height="25" ry="10" style="stroke-width:1; fill:white"/><text x="15" y="39" style="font-size:20px;stroke-linecap:butt;stroke-width:1">${count}</text><line x1="35" y1="26" x2="50" y2="26"/><line x1="35" y1="32" x2="50" y2="32"/><line x1="35" y1="38" x2="45" y2="38"/><g stroke="none" stroke-width="1" fill="none" fill-rule="evenodd"><g><path d="M8,17.4219 L8,1.4069 L19.591,13.0259 L12.55,13.0259 L12.399,13.1499 L8,17.4219 Z" fill="white"/><path d="M9,3.814 L9,15.002 L11.969,12.136 L12.129,11.997 L17.165,11.997 L9,3.814 Z" fill="black"/></g></g></svg>') 5 5, auto`
    }
    this.hidePopup()  // Hide previous, if any
    // TODO: remove submitCB completely 
    this.showPopup(el, x, y, () => {
      // Nothing to do here
    })
  }

  unshoot(el: BeamHTMLElement) {
    el.classList.remove(this.shootClass)
  }

  isSelecting() {
    return Boolean(this.overlayEl)
  }

  enterSelection() {
    if (!this.isSelecting()) {
      const doc = this.win.document
      this.backdropEl = doc.createElement("div")
      this.backdropEl.id = this.backdropId
      this.overlayEl = doc.createElement("div")
      this.overlayEl.id = this.overlayId
      const body = doc.body
      body.classList.add(this.selectingClass)
      body.appendChild(this.backdropEl)
      body.appendChild(this.overlayEl)
    }
  }

  leaveSelection() {
    if (this.isSelecting()) {
      const doc = this.win.document
      const body = doc.body
      body.classList.remove(this.selectingClass)
      body.removeChild(this.overlayEl)
      body.removeChild(this.backdropEl)
      this.overlayEl = null
    }
  }

  /**
   * @param selection {TextSelection}
   * @param className {string}
   */
  paintSelection(selection, className) {
    const textAreas = selection.areas
    this.overlayEl.innerHTML = ""
    const padding = 5
    for (let r = 0; r < textAreas.length; r++) {
      const textRect = textAreas[r]
      const rectSelection = document.createElement("div")
      rectSelection.className = className
      rectSelection.style.position = "absolute"
      rectSelection.style.left = textRect.x + "px"
      rectSelection.style.top = textRect.y - padding + "px"
      rectSelection.style.width = textRect.width + "px"
      rectSelection.style.height = textRect.height + padding * 2 + "px"
      this.overlayEl.appendChild(rectSelection)
    }
  }

  hidePopup() {
    if (this.popup) {
      this.popup.remove()
      this.popup = null
    }
  }

  /**
   * Show the if a given was added to a card.
   */
  showStatus(el: BeamHTMLElement, collected) {
    const msg = this.messages[this.lang]
    const statusEl = this.statusEl = document.createElement("DIV")
    el.classList.add(this.prefixClass)
    el.classList.add(this.statusClass)
    statusEl.innerHTML = `${msg.addedTo} ${collected.title}`
    this.popupAnchor.append(this.statusEl)
    const bounds = el.getBoundingClientRect()
    statusEl.style.left = `${bounds.x}px`
    const statusTop = this.win.scrollY + bounds.bottom + this.outlineWidth
    statusEl.style.top = `${statusTop}px`
  }

  hideStatus() {
    if (this.statusEl) {
      this.statusEl.remove()
      this.statusEl = null
    }
  }

  setStatus(_status) {
    // No impact on web UI
  }

  cardToProposal(c, txt, proposals) {
    const title = c.title
    const matchPos = title.toLowerCase().indexOf(txt)
    if (matchPos >= 0) {
      let value = `${title.substr(0, matchPos)}<b>${title.substr(
          matchPos,
          txt.length
      )}</b>${title.substr(matchPos + txt.length)}`
      const hint = c.hint
      if (hint) {
        value += ` <span class="hint">${hint}</span>`
      }
      proposals.push({key: c.id, value})
    }
  }

  cardsToProposals(cards, txt) {
    const proposals = []
    for (const c of cards) {
      this.cardToProposal(c, txt, proposals)
    }
    return proposals
  }

  proposalsEl() {
    return document.querySelector(`#${this.popupId} #proposals`)
  }

  selectedNote

  /**
   * @param id {string} The Note unique id
   */
  selectProposal(id) {
    this.selectedNote = this.existingCards.find((c) => c.id === id)
    this.cardInputEl().value = this.selectedNote.title
    this.proposalsEl().innerHTML = ""
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

  onCardInput(ev) {
    const input = ev.target
    if (!this.inputTouched) {
      input.value = ev.data
    }
    const inputValue = input.value
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

  submit(submitCb) {
    this.hidePopup()
    submitCb(this.selectedNote)
  }

  cardInputEl(): HTMLInputElement {
    return document.getElementById(this.cardInputId) as HTMLInputElement
  }

  cardKeyDown(ev, submitCb) {
    this.logger.log(ev.key)
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

  newCard

  showPopup(_el, x, y, submitCb) {
    const msg = this.messages[this.lang]
    this.popup = document.createElement("DIV")
    this.popup.id = this.popupId
    this.popup.classList.add(this.prefixClass)
    this.popup.classList.add(this.popupClass)
    this.newCard = {id: 0, title: "", hint: "– New card"}
    this.selectedNote = this.existingCards.length > 0 ? this.existingCards[0] : this.newCard
    const value = this.selectedNote.title
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

    const form = this.popup.querySelector("form")
    form.addEventListener("submit", () => this.submit(submitCb))
    const cardInput = this.popup.querySelector(`#${this.cardInputId}`)
    cardInput.addEventListener("keydown", (ev) => this.cardKeyDown(ev, submitCb))
    cardInput.addEventListener("input", this.onCardInput.bind(this))

    this.popup.style.left = `${x}px`
    const popupTop = this.win.scrollY + y
    this.popup.style.top = `${popupTop}px`
    this.cardInputEl().focus()
  }

  dropDown() {
    this.showProposals(this.cardsToProposals(this.existingCards, ""))
  }

  addTextSelection(selection) {
    this.paintSelection(selection, this.pointClass)
  }
}
