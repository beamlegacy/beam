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

function beam_elementDidGainFocus(event) {
  if (event.target !== null && beam_isTextField(event.target)) {
    window.webkit.messageHandlers.beam_textInputFocusIn.postMessage(event.target.id)
  }
}

function beam_elementDidLoseFocus(event) {
  if (event.target !== null && beam_isTextField(event.target)) {
    window.webkit.messageHandlers.beam_textInputFocusOut.postMessage(event.target.id)
  }
}

function beam_postSubmitMessage(event) {
  window.webkit.messageHandlers.beam_formSubmit.postMessage(event.target.id)
}

function beam_sendTextFields() {
  let textFields = beam_getTextFieldsInDocument(document, null)
  for (f = 0; f < window.frames.length; f++) {
    let frame = window.frames[f]
    try {
      textFields = textFields.concat(beam_getTextFieldsInDocument(frame.contentDocument, frame.name))
    } catch {
    }
  }
  window.webkit.messageHandlers.beam_textInputFields.postMessage(JSON.stringify(textFields))
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
      if (field.value) {
        element.value = field.value
      }
      if (field.background) {
        var styleAttribute = document.createAttribute('style');
        styleAttribute.value = 'background-color:' + background;
        element.setAttributeNode(styleAttribute);
      }
    }
  }
}

function beam_installFocusHandlers(ids_json) {
  let ids = JSON.parse(ids_json)
  for (id of ids) {
    document.getElementById(id)?.addEventListener('focus', beam_elementDidGainFocus, false)
    document.getElementById(id)?.addEventListener('focusout', beam_elementDidLoseFocus, false)
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
