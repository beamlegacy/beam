function beam_isTextField(element) {
    if (element == null) {
        return false
    }
    if (element.id.length === 0) {
        return false
    }
    let elementType = element.getAttribute('type')
    return elementType === 'text' || elementType === 'password' || elementType === 'email' || elementType === '' || elementType === null
}

function beam_getTextFieldsInDocument(_doc, _frame) {
    const textFields = []
    for (let tagName of ['input', 'select', 'textarea']) {
        let inputElements = document.getElementsByTagName(tagName)
        for (let e = 0; e < inputElements.length; e++) {
            let element = inputElements.item(e)
            if (beam_isTextField(element)) {
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
        window.webkit.messageHandlers.password_textInputFocusIn.postMessage(event.target.id)
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
        window.webkit.messageHandlers.password_textInputFocusOut.postMessage(event.target.id)
    }
}

function beam_postSubmitMessage(event) {
    window.webkit.messageHandlers.password_formSubmit.postMessage(event.target.id)
}

function password_sendTextFields() {
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

function beam_getElementRects(ids_json) {
    let ids = JSON.parse(ids_json)
    let rects = ids.map(id => document.getElementById(id)?.getBoundingClientRect())
    return JSON.stringify(rects)
}

function beam_getTextFieldValues(ids_json) {
    let ids = JSON.parse(ids_json)
    let values = ids.map(id => document.getElementById(id)?.value)
    return JSON.stringify(values)
}

function beam_setTextFieldValues(fields_json) {
    let fields = JSON.parse(fields_json)
    for (let field of fields) {
        let element = document.getElementById(field.id)
        if (element) {
            element.value = field.value
            if (field.background) {
                var styleAttribute = document.createAttribute('style');
                styleAttribute.value = 'background-color:' + background;
                element.setAttributeNode(styleAttribute);
            }
        }
    }
}

function beam_togglePasswordFieldVisibility(fields_json, visibility) {
    let fields = JSON.parse(fields_json)
    for (let field of fields) {
        var passwordElement = document.getElementById(field.id);
        if (passwordElement.type === "password" && (visibility == 'true')) {
            passwordElement.type = "text";
        }
        if (passwordElement.type === "text" && (visibility == 'false')) {
            passwordElement.type = "password";
        }
    }
}

function beam_installFocusHandlers(ids_json) {
    let ids = JSON.parse(ids_json)
    for (id of ids) {
        document.getElementById(id)?.addEventListener('focus', password_elementDidGainFocus, false)
        document.getElementById(id)?.addEventListener('focusout', password_elementDidLoseFocus, false)
        window.addEventListener("resize", password_resize)
        window.addEventListener("scroll", password_scroll)
    }
}

function beam_installSubmitHandler() {
    let submitElements = document.getElementsByTagName('form')
    for (let e = 0; e < submitElements.length; e++) {
        let element = submitElements.item(e)
        element.addEventListener('submit', beam_postSubmitMessage)
    }
}

console.log('PasswordManager installed')
