(function PointAndShoot() {
      const origin = document.body.baseURI
      console.log("PointAndShoot initializing", origin)

      let scrollWidth

      function beamMessage(name, payload) {
        console.log("Send message", name, payload)
        if (
            window.webkit &&
            window.webkit.messageHandlers &&
            window.webkit.messageHandlers[name]
        ) {
          window.webkit.messageHandlers[name].postMessage({origin, ...payload})
        } else {
          // Local test
        }
      }

      const outlineWidth = 4
      const enabled = true

      const messages = {
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
      const navigatorLanguage = navigator.language.substring(0, 2)
      const documentLanguage = document.lang
      const lang = navigatorLanguage || documentLanguage

      const existingCards = [
        {id: 1, title: "Michael Heizer"},
        {id: 2, title: "James Dean"},
        {id: 3, title: "Michael Jordan"}
      ]

      /**
       * Shoot elements.
       */
      const selected = []

      const prefix = "__ID__"

      const prefixClass = prefix
      const shootClass = `${prefix}-shoot`
      const pointClass = `${prefix}-point`
      const popupClass = `${prefix}-popup`
      const cardClass = `${prefix}-card`
      const noteClass = `${prefix}-note`
      const labelClass = `${prefix}-label`
      const inputClass = `${prefix}-input`
      const proposalsClass = `${prefix}-proposals`
      const proposalClass = `${prefix}-proposal`
      const statusClass = `${prefix}-status`
      const formRowClass = `${prefix}-form-row`
      const overlayId = `${prefix}-overlay`
      const backdropId = `${prefix}-backdrop`
      const selectionClass = `${prefix}-selection`

      const datasetKey = `${prefix}Collect`

      function pointMessage(el, x, y) {
        const bounds = el.getBoundingClientRect()
        const pointMessage = {
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
        beamMessage("beam_point", pointMessage)
      }

      function point(el, x, y) {
        if (enabled) {
          el.classList.add(pointClass)
        }
        pointMessage(el, x, y)
      }

      function unpoint(el) {
        el.classList.remove(pointClass)
        el.style.cursor = ``
        pointed = null
        beamMessage("beam_point", pointed)
      }

      function removeSelected(selectedIndex, el) {
        selected.splice(selectedIndex, 1)
        el.classList.remove(shootClass)
        delete el.dataset[datasetKey]
        unpoint(el)
      }

      const popupId = `${prefix}-popup`
      const popupAnchor = document.body
      let popup

      function submit() {
        for (const s of selected) {
          s.dataset[datasetKey] = JSON.stringify(selectedCard)
        }
        hidePopup()
      }

      let inputTouched

      function cardsToProposals(cards, txt) {
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

      let newCard

      function onCardInput(ev) {
        const input = ev.target
        if (!inputTouched) {
          input.value = ev.data
        }
        let inputValue = input.value
        let possibles = existingCards
        if (inputValue) {
          input.value =
              inputValue.substring(0, 1).toUpperCase() + inputValue.substring(1)
          newCard.title = input.value
          possibles = existingCards.concat(newCard)
        }
        const txt = inputValue.toLowerCase()
        const proposals = cardsToProposals(possibles, txt)
        showProposals(proposals)
        inputTouched = true
      }

      function cardKeyDown(ev) {
        console.log(ev.key)
        switch (ev.key) {
          case "Escape":
            hidePopup()
            break
          case "Enter":
            submit()
            break
          case "ArrowDown":
            break
          case "ArrowUp":
            break
        }
      }

      let selectedCard

      function selectProposal(id) {
        selectedCard = existingCards.find((c) => c.id === id)
        cardInputEl().value = selectedCard.title
        proposalsEl().innerHTML = ""
      }

      const proposalsEl = function() {
        return document.querySelector(`#${popupId} #proposals`)
      }

      function showProposals(ps) {
        const pList = proposalsEl()
        pList.innerHTML = ""
        for (const p of ps) {
          const li = document.createElement("LI")
          li.className = proposalClass
          li.addEventListener("click", () => selectProposal(p.key))
          li.innerHTML = p.value
          pList.appendChild(li)
        }
      }

      function dropDown() {
        showProposals(cardsToProposals(existingCards, ""))
      }

      const cardInputId = `${prefix}-add-to`
      const cardInputEl = function() {
        return document.getElementById(cardInputId)
      }

      function showPopup(el, x, y) {
        shootMessage(el, x, y)
        if (enabled) {
          const msg = messages[lang]
          popup = document.createElement("DIV")
          popup.id = popupId
          popup.classList.add(prefixClass)
          popup.classList.add(popupClass)
          newCard = {id: 0, title: "", hint: "– New card"}
          selectedCard = existingCards.length > 0 ? existingCards[0] : newCard
          const value = selectedCard.title
          inputTouched = false
          popup.innerHTML = `
    <form action="javascript:submit()">
      <div class="${cardClass}">
        <div class="${formRowClass}">
          <label for="${cardInputId}" class="${labelClass}">${msg.addTo}</label>
          <input class="${inputClass}" id="${cardInputId}" value="${value}" autocomplete="off"/>
          <span class="shortcut hint">↵</span>
        </div>
        <ul id="proposals" class="${proposalsClass}"></ul>
      </div>
      <div class="${formRowClass} ${noteClass}">
        <input class="${inputClass}" placeholder="${msg.addNote}"/>
      </div>
    </form>
    `
          popupAnchor.append(popup)

          const cardInput = popup.querySelector(`#${cardInputId}`)
          cardInput.addEventListener("keydown", cardKeyDown)
          cardInput.addEventListener("input", onCardInput)

          popup.style.left = `${x}px`
          const popupTop = window.scrollY + y
          popup.style.top = `${popupTop}px`
          cardInputEl().focus()
        }
      }

      function hidePopup() {
        if (popup) {
          popup.remove()
          popup = null
        }
      }

      /**
       * The currently highlighted element
       */
      let pointed

      const statusId = `${prefix}-status`
      let status

      /**
       * Show the if a given was added to a card.
       */
      function showStatus(el) {
        if (enabled) {
          const msg = messages[lang]
          status = document.createElement("DIV")
          el.classList.add(prefixClass)
          el.classList.add(statusClass)
          const data = pointed.dataset[datasetKey]
          const collected = JSON.parse(data)
          status.innerHTML = `${msg.addedTo} ${collected.title}`
          popupAnchor.append(status)
          const bounds = el.getBoundingClientRect()
          status.style.left = `${bounds.x}px`
          const statusTop = window.scrollY + bounds.bottom + outlineWidth
          status.style.top = `${statusTop}px`
        }
      }

      function hideStatus() {
        if (status) {
          status.remove()
          status = null
        }
      }

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
            hidePopup()
          }
        } else {
          hideStatus()
          if (pointed) {
            unpoint(pointed)
          }
        }
      }

      function shootMessage(el, x, y) {
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
        beamMessage("beam_shoot", shootMessage)
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
        point(el, x, y)
        el.classList.remove(pointClass)
        el.classList.add(shootClass)
        const count = selected.length > 1 ? "" + selected.length : ""
        for (const s of selected) {
          s.style.cursor = `url('data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" width="40" height="30" viewBox="20 0 30 55" style="stroke:rgb(165,165,165);stroke-linecap:round;stroke-width:3"><rect x="10" y="20" width="54" height="25" ry="10" style="stroke-width:1; fill:white"/><text x="15" y="39" style="font-size:20px;stroke-linecap:butt;stroke-width:1">${count}</text><line x1="35" y1="26" x2="50" y2="26"/><line x1="35" y1="32" x2="50" y2="32"/><line x1="35" y1="38" x2="45" y2="38"/><g id="Page-1" stroke="none" stroke-width="1" fill="none" fill-rule="evenodd"><g id="notallowed"><path d="M8,17.4219 L8,1.4069 L19.591,13.0259 L12.55,13.0259 L12.399,13.1499 L8,17.4219 Z" id="point-border" fill="white"/><path d="M9,3.814 L9,15.002 L11.969,12.136 L12.129,11.997 L17.165,11.997 L9,3.814 Z" id="point" fill="black"/></g></g></svg>') 5 5, auto`
        }
        hidePopup() // Go native?
        showPopup(el, x, y) // Go native?
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

      let overlayEl
      let backdropEl

      function enterSelection() {
        if (enabled && !overlayEl) {
          backdropEl = document.createElement("div")
          backdropEl.id = backdropId
          overlayEl = document.createElement("div")
          overlayEl.id = overlayId
          let body = document.body
          overlayEl.style.width = (scrollWidth || window.innerWidth) + "px"
          body.appendChild(backdropEl)
          body.appendChild(overlayEl)
        }
      }

      function leaveSelection() {
        if (overlayEl) {
          document.body.removeChild(overlayEl)
          document.body.removeChild(backdropEl)
          overlayEl = null
        }
      }

      function onKeyPress(ev) {
        if (ev.code === "Escape") {
          hidePopup()
          leaveSelection()
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
        beamMessage("beam_frameBounds", {frames: framesInfo})
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
        beamMessage("beam_onScrolled", {
          x: window.scrollX,
          y: window.scrollY,
          width: scrollWidth,
          height: scrollHeight,
        })
        const hasFrames = checkFrames()
        console.log(hasFrames ? "Scroll updated frames info" : "Scroll did not update frames info since there is none")
      }

      function onResize(_ev) {
        beamMessage("beam_resize", {
          width: window.innerWidth,
          height: window.innerHeight,
        })
        for (const someSelected of selected) {
          shootMessage(someSelected, -1, -1)
        }
      }

      function onSelectionChange(_ev) {
        const selection = document.getSelection()
        if (selection.isCollapsed) {
          leaveSelection()
          return
        }
        enterSelection()

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
          if (enabled) {
            overlayEl.innerHTML = ""
            const padding = 5
            for (let r = 0; r < textAreas.length; r++) {
              const rect = textAreas[r]
              const rectSelection = document.createElement("div")
              rectSelection.className = selectionClass
              rectSelection.style.position = "absolute"
              rectSelection.style.left = rect.x + "px"
              rectSelection.style.top = rect.y - padding + "px"
              rectSelection.style.width = rect.width + "px"
              rectSelection.style.height = rect.height + padding * 2 + "px"
              overlayEl.appendChild(rectSelection)
            }
          }
          // TODO: Throttle
          beamMessage("beam_textSelected", {index: i, text: selectedText, html: selectedHTML, areas: textAreas})
        }
      }

      function onLoad(_ev) {
        console.log("Page load. Checking frames")
        checkFrames()
      }

      checkFrames()
      onScroll();   // Init/refresh scroll info

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

