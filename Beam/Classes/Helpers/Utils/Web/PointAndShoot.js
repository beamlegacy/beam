(function PointAndShoot() {

    function beamMessage(name, payload) {
        console.log("Send message", name, payload)
        window.webkit.messageHandlers[name].postMessage(payload);
    }

    const outlineWidth = 3;
    const enabled = __ENABLED__ || false

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
    };
    const navigatorLanguage = navigator.language.substring(0, 2);
    const documentLanguage = document.lang
    const lang = navigatorLanguage || documentLanguage;

    const existingCards = [
        {id: 1, title: "Michael Heizer"},
        {id: 2, title: "James Dean"},
        {id: 3, title: "Michael Jordan"},
    ];

    /**
     * Shoot elements.
     */
    const selected = [];

    const prefix = "__ID__"

    const prefixClass = prefix
    const shootClass = `${prefix}-shoot`
    const pointClass = `${prefix}-point`
    const popupClass = `${prefix}-popup`
    const cardClass = `${prefix}-card`
    const noteClass = `${prefix}-note`
    const labelClass = `${prefix}-label`
    const inputClass = `${prefix}-input`
    const closeClass = `${prefix}-close`
    const dropArrowClass = `${prefix}-drop-arrow`
    const comboClass = `${prefix}-combo`
    const proposalsClass = `${prefix}-proposals`
    const proposalClass = `${prefix}-proposal`
    const statusClass = `${prefix}-status`

    const datasetKey = `${prefix}Collect`

    function currentFrameAbsolutePosition() {
        let currentWindow = window;
        let currentParentWindow;
        let positions = [];
        let rect;

        while (currentWindow !== window.top) {
            currentParentWindow = currentWindow.parent;
            for (let idx = 0; idx < currentParentWindow.frames.length; idx++)
                if (currentParentWindow.frames[idx] === currentWindow) {
                    for (let frameElement of currentParentWindow.document.getElementsByTagName('iframe')) {
                        if (frameElement.contentWindow === currentWindow) {
                            rect = frameElement.getBoundingClientRect();
                            positions.push({x: rect.x, y: rect.y});
                        }
                    }
                    currentWindow = currentParentWindow;
                    break;
                }
        }
        return positions.reduce((accumulator, currentValue) => {
            return {
                x: accumulator.x + currentValue.x,
                y: accumulator.y + currentValue.y
            };
        }, {x: 0, y: 0});
    }

    function pointMessage(el, x, y) {
        const boundsInFrame = el.getBoundingClientRect();
        let frameOffset = currentFrameAbsolutePosition();
        console.log("frameOffset", frameOffset)
        const pointMessage = {
            type: {
                tagName: el.tagName,
            },
            location: {
                x: frameOffset.x + x,
                y: frameOffset.y + y
            },
            data: {
                text: el.innerText
            },
            area: {
                x: frameOffset.x + boundsInFrame.x,
                y: frameOffset.y + boundsInFrame.y,
                width: boundsInFrame.width,
                height: boundsInFrame.height,
            },
        };
        beamMessage("beam_point", pointMessage);
    }

    function point(el, x, y) {
        if (enabled) {
            el.classList.add(pointClass);
        }
        pointMessage(el, x, y);
    }

    function unpoint(el) {
        el.classList.remove(pointClass)
        el.style.cursor = ``;
        pointed = null
        beamMessage("beam_point", null);
    }

    function removeSelected(selectedIndex, el) {
        selected.splice(selectedIndex, 1);
        el.classList.remove(shootClass)
        delete el.dataset[datasetKey]
        unpoint(el);
    }

    const popupId = `${prefix}-popup`;
    const popupAnchor = document.body;
    let popup;

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
            let title = c.title;
            let matchPos = title.toLowerCase().indexOf(txt);
            if (matchPos >= 0) {
                let value = `${title.substr(0, matchPos)}<b>${title.substr(matchPos, txt.length)}</b>${title.substr(matchPos + txt.length)}`;
                let hint = c.hint;
                if (hint) {
                    value += ` <span class="hint">${hint}</span>`
                }
                proposals.push({key: c.id, value})
            }
        }
        return proposals;
    }

    let newCard

    function cardInput(ev) {
        const input = ev.target;
        if (!inputTouched) {
            input.value = ev.data
        }
        let inputValue = input.value;
        let possibles = existingCards
        if (inputValue) {
            input.value = inputValue.substring(0, 1).toUpperCase() + inputValue.substring(1)
            newCard.title = input.value
            possibles = existingCards.concat(newCard)
        }
        const txt = inputValue.toLowerCase()
        const proposals = cardsToProposals(possibles, txt);
        showProposals(proposals)
        inputTouched = true
    }

    function cardKeyDown(ev) {
        console.log(ev.key)
        switch (ev.key) {
            case "Escape":
                hidePopup();
                break;
            case "Enter":
                if (ev.metaKey) {
                    submit();
                }
                break;
            case "ArrowDown":
                break;
            case "ArrowUp":
                break;
        }
    }

    let selectedCard

    function selectProposal(id) {
        selectedCard = existingCards.find(c => c.id === id);
        cardInputEl().value = selectedCard.title
        proposalsEl().innerHTML = ""
    }

    const proposalsEl = function () {
        return document.querySelector(`#${popupId} #proposals`);
    };

    function showProposals(ps) {
        const pList = proposalsEl()
        let proposalsHTML = ""
        for (const p of ps) {
            proposalsHTML += `<li class="${proposalClass}" onclick="selectProposal(${p.key})">${p.value}</li>`
        }
        pList.innerHTML = proposalsHTML
    }

    function dropDown() {
        showProposals(cardsToProposals(existingCards, ""));
    }

    const cardInputId = `${prefix}-add-to`
    const cardInputEl = function () {
        return document.getElementById(cardInputId);
    };

    function showPopup(el, x, y) {
        shootMessage(el, x, y);
        if (enabled) {
            const msg = messages[lang];
            popup = document.createElement("DIV");
            popup.id = popupId;
            popup.classList.add(prefixClass)
            popup.classList.add(popupClass)
            newCard = {id: 0, title: "", hint: "- New card"}
            selectedCard = existingCards.length > 0 ? existingCards[0] : newCard;
            const value = selectedCard.title;
            inputTouched = false
            popup.innerHTML = `
    <button type="button" aria-label="${msg.close}" class="${closeClass}" title="${msg.close}" onclick="hidePopup()">×</button>
    <form action="javascript:submit()">
      <div class="${cardClass}">
        <label for="${cardInputId}" class="${labelClass}">${msg.addTo}</label>
        <div class="${comboClass}">
          <input class="${inputClass}" id="${cardInputId}" value="${value}" onkeydown="cardKeyDown(event)" oninput="cardInput(event)" autocomplete="off"/>
          <ul id="proposals" class="${proposalsClass}"></ul>
        </div>  
        <button type="button" class="${dropArrowClass}" title="${msg.dropArrow}" onclick="dropDown()">⌄</button>
        <span class="shortcut hint">⌘↵</span>
      </div>
      <div class="${noteClass}">
        <input class="${inputClass}" placeholder="${msg.addNote}"/>
      </div>
    </form>
    `;
            popupAnchor.append(popup);
            popup.style.left = `${x}px`;
            const popupTop = window.scrollY + y;
            popup.style.top = `${popupTop}px`;
            cardInputEl().focus();
        }
    }

    function hidePopup() {
        if (popup) {
            popup.remove();
            popup = null;
        }
    }

    /**
     * The currently highlighted element
     */
    let pointed;


    const statusId = `${prefix}-status`
    let status

    /**
     * Show the if a given was added to a card.
     */
    function showStatus(el) {
        if (enabled) {
            const msg = messages[lang];
            status = document.createElement("DIV");
            el.classList.add(prefixClass);
            el.classList.add(statusClass);
            const data = pointed.dataset[datasetKey];
            const collected = JSON.parse(data);
            status.innerHTML = `${msg.addedTo} ${collected.title}`;
            popupAnchor.append(status);
            const bounds = el.getBoundingClientRect();
            status.style.left = `${bounds.x}px`;
            const statusTop = window.scrollY + bounds.bottom + outlineWidth;
            status.style.top = `${statusTop}px`;
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
            ev.preventDefault();
            ev.stopPropagation();
            const el = ev.target;
            if (pointed !== el) {
                if (pointed) {
                    unpoint(pointed);     // Remove previous
                }
                pointed = el;
                point(pointed, ev.clientX, ev.clientY);
                let collected = pointed.dataset[datasetKey];
                if (collected) {
                    showStatus(pointed)
                } else {
                    hideStatus()
                }
            } else {
                hidePopup();
            }
        } else {
            hideStatus();
            if (pointed) {
                unpoint(pointed);
            }
        }
    }

    function shootMessage(el, x, y) {
        const bounds = el.getBoundingClientRect();
        const shootMessage = {
            type: {
                tagName: el.tagName,
            },
            data: {
                text: el.innerText
            },
            location: {
                x,
                y
            },
            area: {
                x: bounds.x,
                y: bounds.y,
                width: bounds.width,
                height: bounds.height,
            },
        };
        beamMessage("beam_shoot", shootMessage);
    }

    /**
     * Select an HTML element to be added to a card.
     *
     * @param ev The selection event (click or touch).
     * @param x Horizontal coordinate of click/touch
     * @param y Vertical coordinate of click/touch
     */
    function select(ev, x, y) {
        const el = ev.target;
        ev.preventDefault();
        ev.stopPropagation();
        const selectedIndex = selected.indexOf(el);
        const alreadySelected = selectedIndex >= 0;
        if (alreadySelected) {
            // Unselect
            removeSelected(selectedIndex, el);
            return;
        }
        const multiSelect = ev.metaKey;
        if (!multiSelect && selected.length > 0) {
            removeSelected(0, selected[0]); // previous selection will be replaced
        }
        selected.push(el);
        point(el, x, y);
        el.classList.remove(pointClass);
        el.classList.add(shootClass);
        const count = selected.length > 1 ? "" + selected.length : "";
        for (const s of selected) {
            s.style.cursor = `url('data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" width="40" height="30" viewBox="20 0 30 55" style="stroke:rgb(165,165,165);stroke-linecap:round;stroke-width:3"><rect x="10" y="20" width="54" height="25" ry="10" style="stroke-width:1; fill:white"/><text x="15" y="39" style="font-size:20px;stroke-linecap:butt;stroke-width:1">${count}</text><line x1="35" y1="26" x2="50" y2="26"/><line x1="35" y1="32" x2="50" y2="32"/><line x1="35" y1="38" x2="45" y2="38"/><g id="Page-1" stroke="none" stroke-width="1" fill="none" fill-rule="evenodd"><g id="notallowed"><path d="M8,17.4219 L8,1.4069 L19.591,13.0259 L12.55,13.0259 L12.399,13.1499 L8,17.4219 Z" id="point-border" fill="white"/><path d="M9,3.814 L9,15.002 L11.969,12.136 L12.129,11.997 L17.165,11.997 L9,3.814 Z" id="point" fill="black"/></g></g></svg>') 5 5, auto`;
        }
        hidePopup();      // Go native?
        showPopup(el, x, y);    // Go native?
    }

    function onClick(ev) {
        if (ev.altKey) {
            select(ev, ev.clientX, ev.clientY);
        }
    }

    function onlongtouch(ev) {
        const touch = ev.touches[0];
        select(ev, touch.clientX, touch.clientY);
    }

    let timer;
    const touchDuration = 2500; //length of time we want the user to touch before we do something

    function touchstart(ev) {
        if (!timer) {
            timer = setTimeout(() => onlongtouch(ev), touchDuration);
        }
    }

    function touchend(_ev) {
        if (timer) {
            clearTimeout(timer);
            timer = null;
        }
    }

    function onKeyPress(ev) {
        if (ev.code === "Escape") {
            hidePopup()
        }
    }

    function onScroll(_ev) {
        const body = document.body;
        const documentEl = document.documentElement;
        const scrollWidth = Math.max(
            body.scrollWidth, documentEl.scrollWidth,
            body.offsetWidth, documentEl.offsetWidth,
            body.clientWidth, documentEl.clientWidth
        );
        const scrollHeight = Math.max(
            body.scrollHeight, documentEl.scrollHeight,
            body.offsetHeight, documentEl.offsetHeight,
            body.clientHeight, documentEl.clientHeight
        );
        beamMessage("beam_onScrolled", {
            x: window.scrollX,
            y: window.scrollY,
            width: scrollWidth,
            height: scrollHeight
        });
    }

    function onResize(ev) {
        console.log("resize", ev)
        beamMessage("beam_resize", {
            width: window.innerWidth,
            height: window.innerHeight,
        })
    }

    const vv = window.visualViewport

    function onPinch(ev) {
        console.log("gesturestart", ev)
        beamMessage("beam_pinch", {
            offsetTop: vv.offsetTop,
            pageTop: vv.pageTop,
            offsetLeft: vv.offsetLeft,
            pageLeft: vv.pageLeft,
            width: vv.width,
            height: vv.height,
            scale: vv.scale
        })
    }

    vv.addEventListener("onresize", onPinch);
    vv.addEventListener("scroll", onPinch);
    window.addEventListener("resize", onResize);
    window.addEventListener("mousemove", onMouseMove);
    window.addEventListener("click", onClick);
    window.addEventListener('scroll', onScroll);
    document.addEventListener("keypress", onKeyPress);
    // window.addEventListener("touchstart", touchstart, false);
    // window.addEventListener("touchend", touchend, false);
})()