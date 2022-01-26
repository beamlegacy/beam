export class PasswordManagerHelper {
  frameIdentifier = ""
  lastId = 0

  /**
   * Returns true if element is a textField element
   *
   * @param {*} element
   * @return {*}  {boolean}
   * @memberof Helpers
   */
  isTextField(element): boolean {
    if (element === null) {
      return false
    }
    if (element.getAttribute("list") !== null) {
      return false
    }
    const elementType = element.getAttribute("type")
    return elementType === "text" || elementType === "password" || elementType === "email" || elementType === "" || elementType === null
  }

  /**
   * Returns true if element has no "disabled" attribute
   *
   * @param {*} element
   * @return {*}  {boolean}
   * @memberof Helpers
   */
  isEnabled(element): boolean {
    if (element === null) {
      return false
    }
    if ("disabled" in element.attributes) {
      return !element.disabled
    }
    return true
  }

  /**
   * Returns new unique identifier. The identifier is unique to the 
   * window frame and each time this method is called the trailing 
   * number is incremented.
   *
   * @return {*}  {string}
   * @memberof Helpers
   */
  makeBeamId(): string {
    this.lastId++
    return "beam-" + this.frameIdentifier + "-" + this.lastId
  }

  /**
   * returns true if provided element has a "data-beam-id" in 
   * it's attributes.
   *
   * @param {*} element
   * @return {*}  {boolean}
   * @memberof Helpers
   */
  hasBeamId(element): boolean {
    return "data-beam-id" in element.attributes
  }

  /**
   * Returns the beam ID of the element. If no ID is found of the element
   * a unique ID will be created and assigned to the element attribute.
   *
   * @param {*} element
   * @return {*}  {string}
   * @memberof Helpers
   */
  getOrCreateBeamId(element): string {
    if (this.hasBeamId(element)) {
      return element.dataset.beamId
    }
    const beamId = this.makeBeamId()
    element.dataset.beamId = beamId
    return beamId
  }

  /**
   * Finds and returns element based on the beam ID
   *
   * @param {string} beamId
   * @return {*}  {}
   * @memberof Helpers
   */
  getElementById(beamId: string) {
    return document.querySelector("[data-beam-id='" + beamId + "']")
  }

  /**
   * Finds and returns all non-disabled text field elements in the document
   *
   * @return {*}  {Element[]}
   * @memberof Helpers
   */
  getTextFieldsInDocument(): Element[] {
    const textFields = []
    for (const tagName of ["input", "select", "textarea"]) {
      const inputElements = document.getElementsByTagName(tagName)
      for (let e = 0; e < inputElements.length; e++) {
        const element = inputElements.item(e)
        if (this.isTextField(element) && this.isEnabled(element)) {
          this.getOrCreateBeamId(element)
          const attributes = element.attributes
          const textField = {}
          for (let a = 0; a < attributes.length; a++) {
            const attr = attributes.item(a)
            textField[attr.name] = attr.value
          }
          textFields.push(textField)
        }
      }
    }
    return textFields
  }

  getFocusedField() {
    return document.activeElement?.getAttribute("data-beam-id")
  }

  getElementRects(ids_json) {
    const ids = JSON.parse(ids_json)
    const rects = ids.map(id => this.getElementById(id)?.getBoundingClientRect())
    return JSON.stringify(rects)
  }

  getTextFieldValues(ids_json) {
    const ids = JSON.parse(ids_json)
    const values = ids.map(id => {
      const element = this.getElementById(id) as HTMLInputElement
      return element.value
    })
    return JSON.stringify(values)
  }

  setTextFieldValues(fields_json) {
    const fields = JSON.parse(fields_json)
    for (const field of fields) {
      const element = this.getElementById(field.id)
      if (element?.tagName == "INPUT") {
        const nativeInputValueSetter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, "value").set
        nativeInputValueSetter.call(element, field.value)
        const event = new Event("input", { bubbles: true })
        // TODO: Fix this "simulated" value
        // event.simulated = true
        element.dispatchEvent(event)
        if (field.background) {
          const styleAttribute = document.createAttribute("style")
          styleAttribute.value = "background-color:" + field.background
          element.setAttributeNode(styleAttribute)
        } else {
          const styleAttribute = element.getAttributeNode("style")
          if (styleAttribute) {
            element.removeAttributeNode(styleAttribute)
          }
        }
      }
    }
  }

  togglePasswordFieldVisibility(fields_json, visibility) {
    const fields = JSON.parse(fields_json)
    for (const field of fields) {
      const passwordElement = this.getElementById(field.id)
      const elementType = passwordElement.getAttribute("type")
      if (elementType === "password" && (visibility == "true")) {
        passwordElement.setAttribute("type", "text")
      }
      if (elementType === "text" && (visibility == "false")) {
        passwordElement.setAttribute("type", "password")
      }
    }
  }

  setFrameIdentifier(frameIdentifier: string): void {
    this.frameIdentifier = frameIdentifier
  }
}