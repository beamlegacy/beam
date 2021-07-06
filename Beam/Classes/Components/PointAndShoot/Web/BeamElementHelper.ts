// Useful methods for HTML Elements
import {BeamElement} from "./BeamTypes";

export class BeamElementHelper {
  static getAttribute(attr: string, element: BeamElement): string {
    const attribute = element.attributes.getNamedItem(attr)
    return attribute?.value
  }

  static getType(element: BeamElement): string {
    return BeamElementHelper.getAttribute("type", element)
  }

  static getContentEditable(element: BeamElement): string {
    return BeamElementHelper.getAttribute("contenteditable", element) || "inherit"
  }
}