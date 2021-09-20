function beam_isTextField(element) {
    if (element === null) {
        return false
    }
    let elementType = element.getAttribute('type')
    return elementType === 'text' || elementType === 'password' || elementType === 'email' || elementType === '' || elementType === null
}

function beam_isEnabled(element) {
    if (element === null) {
        return false
    }
    if ('disabled' in element.attributes) {
        return !element.disabled
    }
    return true
}

var lastId = 0
function beam_makeBeamId(element) {
    if (element.id.length != 0) {
        return 'id-' + element.id
    }
    lastId ++
    return 'beam-' + lastId
}

function beam_hasBeamId(element) {
    return 'data-beam-id' in element.attributes
}

function beam_getOrCreateBeamId(element) {
    if (beam_hasBeamId(element)) {
        return element.dataset.beamId
    }
    let beamId = beam_makeBeamId(element)
    element.dataset.beamId = beamId
    return beamId
}

function beam_getElementById(beamId) {
    let elements = document.querySelectorAll("[data-beam-id='" + beamId + "']")
    if (elements.length == 0) {
        return null
    }
    return elements[0]
}

function beam_getTextFieldsInDocument(_doc, _frame) {
    const textFields = []
    for (let tagName of ['input', 'select', 'textarea']) {
        let inputElements = document.getElementsByTagName(tagName)
        for (let e = 0; e < inputElements.length; e++) {
            let element = inputElements.item(e)
            if (beam_isTextField(element) && beam_isEnabled(element)) {
                beam_getOrCreateBeamId(element)
                let attributes = element.attributes
                const textField = {}
                for (let a = 0; a < attributes.length; a++) {
                    let attr = attributes.item(a)
                    textField[attr.name] = attr.value
                }
                textFields.push(textField)
            }
        }
    }
    return textFields
}

function password_elementDidGainFocus(event) {
    if (event.target !== null && beam_isTextField(event.target)) {
        window.webkit.messageHandlers.password_textInputFocusIn.postMessage(beam_getOrCreateBeamId(event.target))
    }
}

function password_resize(event) {
    if (event.target !== null ) {
        window.webkit.messageHandlers.password_resize.postMessage({width: window.innerWidth, height: window.innerHeight})
    }
}

function password_scroll(_ev) {
    const win = window
    const doc = win.document
    const body = doc.body
    const documentEl = doc.documentElement
    const scrollWidth = this.scrollWidth = Math.max(
                                                    body.scrollWidth, documentEl.scrollWidth,
                                                    body.offsetWidth, documentEl.offsetWidth,
                                                    body.clientWidth, documentEl.clientWidth
                                                    )
    const scrollHeight = Math.max(
                                  body.scrollHeight, documentEl.scrollHeight,
                                  body.offsetHeight, documentEl.offsetHeight,
                                  body.clientHeight, documentEl.clientHeight
                                  )
    const scrollInfo = {
    x: win.scrollX,
    y: win.scrollY,
    width: scrollWidth,
    height: scrollHeight,
    scale: win.visualViewport.scale
    }
    window.webkit.messageHandlers.password_scroll.postMessage(scrollInfo)
}

function password_elementDidLoseFocus(event) {
    if (event.target !== null && beam_isTextField(event.target)) {
        window.webkit.messageHandlers.password_textInputFocusOut.postMessage(beam_getOrCreateBeamId(event.target))
    }
}

function beam_postSubmitMessage(event) {
    window.webkit.messageHandlers.password_formSubmit.postMessage(beam_getOrCreateBeamId(event.target))
}

function beam_mutationCallback(changes, observer) {
    let textFields = beam_getTextFieldsInDocument(document, null)
    window.webkit.messageHandlers.password_textInputFields.postMessage(JSON.stringify(textFields))
}

function beam_sendTextFields() {
    let observer = new MutationObserver(beam_mutationCallback)
    observer.observe(document, {childList: true, subtree: true})
    let textFields = beam_getTextFieldsInDocument(document, null)
    for (f = 0; f < window.frames.length; f++) {
        let frame = window.frames[f]
        try {
            const frameTextFields = beam_getTextFieldsInDocument(frame.contentDocument, frame.name)
            textFields = textFields.concat(frameTextFields)
        } catch (e) {
            console.error(e)
        }
    }
    window.webkit.messageHandlers.password_textInputFields.postMessage(JSON.stringify(textFields))
}

function beam_getFocusedField() {
    return document.activeElement?.getAttribute('data-beam-id')
}

function beam_getElementRects(ids_json) {
    let ids = JSON.parse(ids_json)
    let rects = ids.map(id => beam_getElementById(id)?.getBoundingClientRect())
    return JSON.stringify(rects)
}

function beam_getTextFieldValues(ids_json) {
    let ids = JSON.parse(ids_json)
    let values = ids.map(id => beam_getElementById(id)?.value)
    return JSON.stringify(values)
}

function beam_setTextFieldValues(fields_json) {
    let fields = JSON.parse(fields_json)
    for (let field of fields) {
        let element = beam_getElementById(field.id)
        if (element?.tagName == 'INPUT') {
            const nativeInputValueSetter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, "value").set
            nativeInputValueSetter.call(element, field.value)
            var event = new Event('input', {bubbles: true})
            event.simulated = true
            element.dispatchEvent(event)
            if (field.background) {
                var styleAttribute = document.createAttribute('style')
                styleAttribute.value = 'background-color:' + field.background
                element.setAttributeNode(styleAttribute)
            } else {
                let styleAttribute = element.getAttributeNode('style')
                if (styleAttribute) {
                    element.removeAttributeNode(styleAttribute)
                }
            }
        }
    }
}

function beam_togglePasswordFieldVisibility(fields_json, visibility) {
    let fields = JSON.parse(fields_json)
    for (let field of fields) {
        var passwordElement = beam_getElementById(field.id)
        if (passwordElement.type === "password" && (visibility == 'true')) {
            passwordElement.type = "text"
        }
        if (passwordElement.type === "text" && (visibility == 'false')) {
            passwordElement.type = "password"
        }
    }
}

function beam_installFocusHandlers(ids_json) {
    let ids = JSON.parse(ids_json)
    for (id of ids) {
        // install handlers to all inputs
        beam_getElementById(id)?.addEventListener('focus', password_elementDidGainFocus, false)
        beam_getElementById(id)?.addEventListener('focusout', password_elementDidLoseFocus, false)
    }
    window.addEventListener("resize", password_resize)
    window.addEventListener("scroll", password_scroll)
}

function beam_installSubmitHandler() {
    const forms = document.getElementsByTagName('form')
    for (let e = 0; e < forms.length; e++) {
        const form = forms.item(e)
        form.addEventListener('submit', beam_postSubmitMessage)
    }
}

console.log('PasswordManager installed')
