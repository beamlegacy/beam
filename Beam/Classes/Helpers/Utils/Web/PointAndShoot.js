
const outlineWidth = 3;

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

/**
 * Shoot elements.
 */
const selected = [];

const existingCards = [
    {id: 1, title: "Michael Heizer"},
    {id: 2, title: "James Dean"},
    {id: 3, title: "Michael Jordan"},
];

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
const styleKey = `${prefix}Style`

function __ID__point(el) {
    el.classList.add(pointClass);
    const boundingClientRect = el.getBoundingClientRect();
    const pointMessage = {
        type: {
            tagName: el.tagName,
        },
        data: {
            text: el.innerText
        },
        area: {
            x: boundingClientRect.x,
            y: boundingClientRect.y,
            width: boundingClientRect.width,
            height: boundingClientRect.height,
        },
    };
    console.log("Sending beam_point", pointMessage)
    window.webkit.messageHandlers.beam_point.postMessage(pointMessage);
}

function __ID__removeOutline(el) {
    el.classList.remove(pointClass)
    el.style.cursor = ``;
}

function __ID__removeSelected(selectedIndex, el) {
    selected.splice(selectedIndex, 1);
    el.classList.remove(shootClass)
    delete el.dataset[datasetKey]
    __ID__removeOutline(el);
}

const popupId = `${prefix}-popup`;
const popupAnchor = document.body;
let popup;

function __ID__submit() {
    for (const s of selected) {
        s.dataset[datasetKey] = JSON.stringify(selectedCard)
    }
    __ID__hidePopup()
}

let inputTouched

function __ID__cardsToProposals(cards, txt) {
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

function __ID__cardInput(ev) {
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
    const proposals = __ID__cardsToProposals(possibles, txt);
    __ID__showProposals(proposals)
    inputTouched = true
}

function __ID__cardKeyDown(ev) {
    console.log(ev.key)
    switch (ev.key) {
        case "Escape":
            __ID__hidePopup();
            break;
        case "Enter":
            if (ev.metaKey) {
                __ID__submit();
            }
            break;
        case "ArrowDown":
            break;
        case "ArrowUp":
            break;
    }
}

let selectedCard

function __ID__selectProposal(id) {
    selectedCard = existingCards.find(c => c.id === id);
    __ID__cardInputEl().value = selectedCard.title
    __ID__proposalsEl().innerHTML = ""
}

const __ID__proposalsEl = function () {
    return document.querySelector(`#${popupId} #proposals`);
};

function __ID__showProposals(ps) {
    const pList = __ID__proposalsEl()
    let proposalsHTML = ""
    for (const p of ps) {
        proposalsHTML += `<li class="${proposalClass}" onclick="__ID__selectProposal(${p.key})">${p.value}</li>`
    }
    pList.innerHTML = proposalsHTML
}

function __ID__dropDown() {
    __ID__showProposals(__ID__cardsToProposals(existingCards, ""));
}

const cardInputId = `${prefix}-add-to`
const __ID__cardInputEl = function () {
    return document.getElementById(cardInputId);
};

function __ID__showPopup(el, x, y) {
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
<button type="button" aria-label="${msg.close}" class="${closeClass}" title="${msg.close}" onclick="__ID__hidePopup()">×</button>
<form action="javascript:submit()">
  <div class="${cardClass}">
    <label for="${cardInputId}" class="${labelClass}">${msg.addTo}</label>
    <div class="${comboClass}">
      <input class="${inputClass}" id="${cardInputId}" value="${value}" onkeydown="__ID__cardKeyDown(event)" oninput="__ID__cardInput(event)" autocomplete="off"/>
      <ul id="proposals" class="${proposalsClass}"></ul>
    </div>  
    <button type="button" class="${dropArrowClass}" title="${msg.dropArrow}" onclick="__ID__dropDown()">⌄</button>
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
    __ID__cardInputEl().focus();
}

function __ID__hidePopup() {
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
function __ID__showStatus(el) {
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

function __ID__hideStatus() {
    if (status) {
        status.remove()
        status = null
    }
}

function __ID__onMouseMove(ev) {
    if (ev.altKey) {
        ev.preventDefault();
        ev.stopPropagation();
        const el = ev.target;
        if (pointed !== el) {
            if (pointed) {
                __ID__removeOutline(pointed);
            }
            pointed = el;
            __ID__point(pointed);
            let collected = pointed.dataset[datasetKey];
            if (collected) {
                __ID__showStatus(pointed)
            } else {
                __ID__hideStatus()
            }
        } else {
            __ID__hidePopup();
        }
    } else {
        __ID__hideStatus();
    }
}

/**
 * Select an HTML element to be added to a card.
 *
 * @param ev The selection event (click or touch).
 * @param x Horizontal coordinate of click/touch
 * @param y Vertical coordinate of click/touch
 */
function __ID__select(ev, x, y) {
    const el = ev.target;
    ev.preventDefault();
    ev.stopPropagation();
    const selectedIndex = selected.indexOf(el);
    const alreadySelected = selectedIndex >= 0;
    if (alreadySelected) {
        // Unselect
        __ID__removeSelected(selectedIndex, el);
        return;
    }
    const multiSelect = ev.metaKey;
    if (!multiSelect && selected.length > 0) {
        __ID__removeSelected(0, selected[0]); // previous selection will be replaced
    }
    selected.push(el);
    __ID__point(el);
    el.classList.remove(pointClass);
    el.classList.add(shootClass);
    const count = selected.length > 1 ? "" + selected.length : "";
    for (const s of selected) {
        s.style.cursor = `url('data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" width="40" height="30" viewBox="20 0 30 55" style="stroke:rgb(165,165,165);stroke-linecap:round;stroke-width:3"><rect x="10" y="20" width="54" height="25" ry="10" style="stroke-width:1; fill:white"/><text x="15" y="39" style="font-size:20px;stroke-linecap:butt;stroke-width:1">${count}</text><line x1="35" y1="26" x2="50" y2="26"/><line x1="35" y1="32" x2="50" y2="32"/><line x1="35" y1="38" x2="45" y2="38"/><g id="Page-1" stroke="none" stroke-width="1" fill="none" fill-rule="evenodd"><g id="notallowed"><path d="M8,17.4219 L8,1.4069 L19.591,13.0259 L12.55,13.0259 L12.399,13.1499 L8,17.4219 Z" id="point-border" fill="white"/><path d="M9,3.814 L9,15.002 L11.969,12.136 L12.129,11.997 L17.165,11.997 L9,3.814 Z" id="point" fill="black"/></g></g></svg>') 5 5, auto`;
    }
    __ID__hidePopup();      // Go native?
    __ID__showPopup(el, x, y);    // Go native?
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
    console.log("Sending beam_shoot", shootMessage)
    window.webkit.messageHandlers.beam_shoot.postMessage(shootMessage);
}

function __ID__onClick(ev) {
    if (ev.altKey) {
        __ID__select(ev, ev.clientX, ev.clientY);
    }
}

function __ID__onlongtouch(ev) {
    const touch = ev.touches[0];
    __ID__select(ev, touch.clientX, touch.clientY);
}

let timer;
const touchDuration = 2500; //length of time we want the user to touch before we do something

function __ID__touchstart(ev) {
    if (!timer) {
        timer = setTimeout(() => __ID__onlongtouch(ev), touchDuration);
    }
}

function __ID__touchend(_ev) {
    if (timer) {
        clearTimeout(timer);
        timer = null;
    }
}

function __ID__onKeyPress(ev) {
    if (ev.code === "Escape") {
        __ID__hidePopup()
    }
}

document.addEventListener("keypress", __ID__onKeyPress);
window.addEventListener("mousemove", __ID__onMouseMove);
window.addEventListener("click", __ID__onClick);
//window.addEventListener("touchstart", touchstart, false);
//window.addEventListener("touchend", touchend, false);
