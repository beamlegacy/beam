if (!window.beam) {
    window.beam = {};
}

window.beam.__ID__PMng = {

    beam_isTextField: function(element) {
        if (element === null) {
            return false
        }
        let elementType = element.getAttribute('type')
        return elementType === 'text' || elementType === 'password' || elementType === 'email' || elementType === '' || elementType === null
    },

    beam_isEnabled: function(element) {
        if (element === null) {
            return false
        }
        if ('disabled' in element.attributes) {
            return !element.disabled
        }
        return true
    },

    lastId: 0,
    beam_makeBeamId: function(element) {
        if (element.id.length != 0) {
            return 'id-' + element.id
        }
        this.lastId ++
        return 'beam-' + this.lastId
    },

    beam_hasBeamId: function(element) {
        return 'data-beam-id' in element.attributes
    },

    beam_getOrCreateBeamId: function(element) {
        if (this.beam_hasBeamId(element)) {
            return element.dataset.beamId
        }
        let beamId = this.beam_makeBeamId(element)
        element.dataset.beamId = beamId
        return beamId
    },

    beam_getElementById: function(beamId) {
        let elements = document.querySelectorAll("[data-beam-id='" + beamId + "']")
        if (elements.length == 0) {
            return null
        }
        return elements[0]
    },

    beam_getTextFieldsInDocument: function (_doc, _frame) {
        const textFields = []
        for (let tagName of ['input', 'select', 'textarea']) {
            let inputElements = document.getElementsByTagName(tagName)
            for (let e = 0; e < inputElements.length; e++) {
                let element = inputElements.item(e)
                if (this.beam_isTextField(element) && this.beam_isEnabled(element)) {
                    this.beam_getOrCreateBeamId(element)
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
    },

    password_elementDidGainFocus: function(event) {
        if (event.target !== null && this.beam_isTextField(event.target)) {
            let beamId = this.beam_getOrCreateBeamId(event.target)
            let text = event.target.value
            window.webkit.messageHandlers.password_textInputFocusIn.postMessage({id: beamId, text: text})
        }
    },

    password_resize: function(event) {
        if (event.target !== null ) {
            window.webkit.messageHandlers.password_resize.postMessage({width: window.innerWidth, height: window.innerHeight})
        }
    },

    password_scroll: function(_ev) {
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
    },

    password_elementDidLoseFocus: function(event) {
        if (event.target !== null && this.beam_isTextField(event.target)) {
            window.webkit.messageHandlers.password_textInputFocusOut.postMessage(this.beam_getOrCreateBeamId(event.target))
        }
    },

    beam_postSubmitMessage: function(event) {
        window.webkit.messageHandlers.password_formSubmit.postMessage(this.beam_getOrCreateBeamId(event.target))
    },

    beam_sendTextFields: function () {
        let observer = new MutationObserver(function (changes, observer) {
            let textFields = this.beam_getTextFieldsInDocument(document, null)
            window.webkit.messageHandlers.password_textInputFields.postMessage(JSON.stringify(textFields))
        }.bind(this));
        observer.observe(document, {childList: true, subtree: true})
        let textFields = this.beam_getTextFieldsInDocument(document, null)
        for (f = 0; f < window.frames.length; f++) {
            let frame = window.frames[f]
            try {
                const frameTextFields = this.beam_getTextFieldsInDocument(frame.contentDocument, frame.name)
                textFields = textFields.concat(frameTextFields)
            } catch (e) {
                console.error(e)
            }
        }
        window.webkit.messageHandlers.password_textInputFields.postMessage(JSON.stringify(textFields))
    },

    beam_getFocusedField: function() {
        return document.activeElement?.getAttribute('data-beam-id')
    },

    beam_getElementRects: function(ids_json) {
        let ids = JSON.parse(ids_json)
        let rects = ids.map(id => this.beam_getElementById(id)?.getBoundingClientRect())
        return JSON.stringify(rects)
    },

    beam_getTextFieldValues: function(ids_json) {
        let ids = JSON.parse(ids_json)
        let values = ids.map(id => this.beam_getElementById(id)?.value)
        return JSON.stringify(values)
    },

    beam_setTextFieldValues: function(fields_json) {
        let fields = JSON.parse(fields_json)
        for (let field of fields) {
            let element = this.beam_getElementById(field.id)
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
    },

    beam_togglePasswordFieldVisibility: function(fields_json, visibility) {
        let fields = JSON.parse(fields_json)
        for (let field of fields) {
            var passwordElement = this.beam_getElementById(field.id)
            if (passwordElement.type === "password" && (visibility == 'true')) {
                passwordElement.type = "text"
            }
            if (passwordElement.type === "text" && (visibility == 'false')) {
                passwordElement.type = "password"
            }
        }
    },

    beam_installFocusHandlers: function(ids_json) {
        let ids = JSON.parse(ids_json)
        for (id of ids) {
            // install handlers to all inputs
            this.beam_getElementById(id)?.addEventListener('focus', this.password_elementDidGainFocus.bind(this), false)
            this.beam_getElementById(id)?.addEventListener('focusout', this.password_elementDidLoseFocus.bind(this), false)
        }
        window.addEventListener("resize", this.password_resize.bind(this))
        window.addEventListener("scroll", this.password_scroll.bind(this))
    },

    beam_installSubmitHandler: function() {
        const forms = document.getElementsByTagName('form')
        for (let e = 0; e < forms.length; e++) {
            const form = forms.item(e)
            form.addEventListener('submit', this.beam_postSubmitMessage.bind(this))
        }
    },
};
