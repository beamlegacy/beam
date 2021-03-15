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

/* animation: beam-shoot-anim 3s infinite alternate !important;*/

/**
 * Shoot elements.
 */
const selected = [];

const existingCards = [
    {id: 1, title: "Michael Heizer"},
    {id: 2, title: "James Dean"},
    {id: 3, title: "Michael Jordan"},
];

const styles = {
    beamClass: {
        selector: "beam",
        style: "font-family: sans-serif; font-size: 16px;"
    },
    shootClass: {
        selector: "beam-shoot",
        style: "outline: 3px solid #25c26d !important"
    },
    pointedClass: {
        selector: "beam-point",
        style: "outline: 3px solid rgba(37, 194, 109, 0.5) !important"
    },
    popupClass: {
        selector: "beam-popup",
        style: `position: absolute; background-color: white; box-shadow: darkgray 0 10px 20px 0; border-radius: 0.5rem; border: 1px solid lightgray; padding: 0.5em 1.5em; transition: all 0.3s ease;`
    },
    card: {
        selector: "card",
        style: `margin: 1.5rem`
    },
    note: {
        selector: "note",
        style: `margin: 1.5rem`
    },
    label: {
        selector: "label",
        style: `float: left; margin-right: 0.25em;`
    },
    input: {
        selector: "input",
        style: `font-weight: bold; color: #8bc0d4;`
    },
    close: {
        selector: "close",
        style: `user-select: none; appearance: none; color: graytext; border: none; padding: 0.5rem 1rem; position: absolute; background: none; cursor: pointer; left: 0; top: 0;`
    },
    combo: {
        selector: "combo",
        style: `display: inline-block; position: relative;`
    },
    proposals: {
        selector: "proposals",
        style: `background-color: white; list-style: none; margin: 0; padding: 0;`
    },
    proposal: {
        selector: "proposal",
        style: `padding: 0.5em; cursor: pointer;`
    },
    status: {
        selector: "beam-status",
        style: `position: absolute; background-color: white`
    }
}

const datasetKey = "beamCollect"
const styleKey = "beamStyle"

let stylesheet = false

function addClass(el, style) {
    console.log("style", style)
    if (stylesheet) {
        el.classList.add(style.selector);
    } else {
        let oldStyle = el.getAttribute("style");
        el.dataset[styleKey] = oldStyle
        let newStyle
        if (oldStyle) {
            newStyle = oldStyle
        } else {
            newStyle = ""
        }
        newStyle += style.style
        console.log("newStyle", newStyle)
        el.setAttribute("style", newStyle)
    }
}

function classStyle(style) {
    console.log("classStyle", style)
    if (stylesheet) {
        return `class="${style.selector}"`
    } else {
        return `style="${style.style}"`
    }
}

function removeClass(el, style) {
    if (stylesheet) {
        el.classList.remove(style.selector);
    } else {
        const oldStyle = el.dataset[styleKey]
        delete el.dataset[styleKey]
        el.style = oldStyle
    }
}

function setOutline(el) {
    addClass(el, styles.pointedClass);
    /*
      let source = document.body.innerHTML;
      console.log(source.substring(source.indexOf(".beam")))
     */
}

function removeOutline(el) {
    removeClass(el, styles.pointedClass)
    el.style.cursor = ``;
}

function removeSelected(selectedIndex, el) {
    selected.splice(selectedIndex, 1);
    removeClass(el, styles.shootClass);
    delete el.dataset[datasetKey]
    removeOutline(el);
}

const popupId = `beam-popup`;
const popupAnchor = document.body;
let popup;

function submit() {
    for (const s of selected) {
        s.dataset.beamCollect = JSON.stringify(selectedCard)
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
            let value = title.substr(0, matchPos)
                + "<b>" + title.substr(matchPos, txt.length) + "</b>"
                + title.substr(matchPos + txt.length);
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
        proposalsHTML += `<li ${classStyle(styles.proposal)} onclick="selectProposal(${p.key})">${p.value}</li>`
    }
    console.log("proposalsHTML", proposalsHTML)
    pList.innerHTML = proposalsHTML
}

function dropDown() {
    showProposals(cardsToProposals(existingCards, ""));
}

const cardInputId = "beam-add-to"
const cardInputEl = function () {
    return document.getElementById(cardInputId);
};

function showPopup(el) {
    const msg = messages[lang];
    popup = document.createElement("DIV");
    popup.id = popupId;
    addClass(popup, styles.beamClass);
    addClass(popup, styles.popupClass);
    newCard = {id: 0, title: "", hint: "- New card"}
    console.log("newCard", newCard)
    if (existingCards.length > 0) {
        selectedCard = existingCards[0];
    } else {
        selectedCard = newCard;
    }
    console.log("selectedCard", selectedCard)
    const value = selectedCard.title;
    inputTouched = false
    popup.innerHTML = `
<button type="button" aria-label="${msg.close}" ${classStyle(styles.close)} title="${msg.close}" onclick="hidePopup()">×</button>
<form action="javascript:submit()">
  <div ${classStyle(styles.card)}>
    <label for="${cardInputId}" ${classStyle(styles.label)}>${msg.addTo}</label>
    <div ${classStyle(styles.combo)}>
      <input ${classStyle(styles.input)} id="${cardInputId}" value="${value}" onkeydown="cardKeyDown(event)" oninput="cardInput(event)" autocomplete="off"/>
      <ul id="proposals" ${classStyle(styles.proposals)}></ul>
    </div>  
    <button type="button" class="drop-arrow" title="${msg.dropArrow}" onclick="dropDown()">⌄</button>
    <span class="shortcut hint">⌘↵</span>
  </div>
  <div ${classStyle(styles.note)}>
    <input id="beam-add-note" placeholder="${msg.addNote}"/>
  </div>
</form>
`;
    popupAnchor.append(popup);
    const bounds = el.getBoundingClientRect();
    popup.style.left = `${bounds.x}px`;
    const popupTop = window.scrollY + bounds.bottom + outlineWidth;
    popup.style.top = `${popupTop}px`;
    cardInputEl().focus();
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


const statusId = "beam-status"
let status

/**
 * Show the if a given was added to a card.
 */
function showStatus(el) {
    const msg = messages[lang];
    status = document.createElement("DIV");
    addClass(el, styles.beamClass);
    addClass(el, styles.status);
    const data = pointed.dataset[datasetKey];
    const beamCollect = JSON.parse(data);
    status.innerHTML = `${msg.addedTo} ${beamCollect.title}`;
    popupAnchor.append(status);
    const bounds = el.getBoundingClientRect();
    status.style.left = `${bounds.x}px`;
    const statusTop = window.scrollY + bounds.bottom + outlineWidth;
    status.style.top = `${statusTop}px`;
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
                removeOutline(pointed);
            }
            pointed = el;
            setOutline(pointed);
            let beamCollect = pointed.dataset[datasetKey];
            if (beamCollect) {
                showStatus(pointed)
            } else {
                hideStatus()
            }
        } else {
            hidePopup();
        }
    } else {
        hideStatus();
    }
}

/**
 * Select an HTML element to be added to a card.
 *
 * @param ev The selection event (click or touch).
 */
function select(ev) {
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
    setOutline(el);
    removeClass(el, styles.pointedClass);
    addClass(el, styles.shootClass);
    const count = selected.length > 1 ? "" + selected.length : "";
    for (const s of selected) {
        s.style.cursor = `url('data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" width="40" height="30" viewBox="20 0 30 55" style="stroke:rgb(165,165,165);stroke-linecap:round;stroke-width:3"><rect x="10" y="20" width="54" height="25" ry="10" style="stroke-width:1; fill:white"/><text x="15" y="39" style="font-size:20px;stroke-linecap:butt;stroke-width:1">${count}</text><line x1="35" y1="26" x2="50" y2="26"/><line x1="35" y1="32" x2="50" y2="32"/><line x1="35" y1="38" x2="45" y2="38"/><g id="Page-1" stroke="none" stroke-width="1" fill="none" fill-rule="evenodd"><g id="notallowed"><path d="M8,17.4219 L8,1.4069 L19.591,13.0259 L12.55,13.0259 L12.399,13.1499 L8,17.4219 Z" id="point-border" fill="white"/><path d="M9,3.814 L9,15.002 L11.969,12.136 L12.129,11.997 L17.165,11.997 L9,3.814 Z" id="point" fill="black"/></g></g></svg>') 5 5, auto`;
    }
    hidePopup();
    showPopup(el);
}

function onClick(ev) {
    if (ev.altKey) {
        select(ev);
    }
}

function onlongtouch(ev) {
    select(ev);
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

console.log("Point and shoot registering")
document.addEventListener("keypress", onKeyPress);
window.addEventListener("mousemove", onMouseMove);
window.addEventListener("click", onClick);
//window.addEventListener("touchstart", touchstart, false);
//window.addEventListener("touchend", touchend, false);
console.log("Point and shoot registered")
