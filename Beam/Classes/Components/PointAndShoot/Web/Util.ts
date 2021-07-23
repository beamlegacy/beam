import { BeamElement, BeamWindow } from "./BeamTypes"

export class Util {

  static getOffset(object, offset) {
    if (object) {
      offset.x += object.offsetLeft
      offset.y += object.offsetTop
      Util.getOffset(object.offsetParent, offset)
    }
  }

  static getScrolled(object: BeamElement, scrolled) {
    if (object) {
      scrolled.x += object.scrollLeft
      scrolled.y += object.scrollTop
      if (object.tagName.toLowerCase() != "html") {
        Util.getScrolled(object.parentNode as BeamElement, scrolled)
      }
    }
  }

  static getTopLeft(el: BeamElement) {
    const offset = { x: 0, y: 0 }
    Util.getOffset(el, offset)

    const scrolled = { x: 0, y: 0 }
    Util.getScrolled(el.parentNode as BeamElement, scrolled)

    const x = offset.x - scrolled.x
    const y = offset.y - scrolled.y
    return { x, y }
  }

  /**
   * Return value clamped between min and max
   *
   * @static
   * @param {number} val
   * @param {number} min
   * @param {number} max
   * @return {number}
   * @memberof Util
   */
  static clamp(val: number, min: number, max: number) {
    return val > max ? max : val < min ? min : val
  }

  /**
   * Remove null and undefined from array
   *
   * @static
   * @param {any[]} array
   * @return {*}  {any[]}
   * @memberof Util
   */
  static compact(array: any[]): any[] {
    return array.filter((item) => {
      return item != null
    })
  }

  /**
   * Check if number is in range
   *
   * @static
   * @param {number} number The number to check.
   * @param {number} start The start of the range.
   * @param {number} end The end of the range.
   * @returns {boolean} Returns `true` if `number` is in the range, else `false`.
   * @memberof Util
   */
  static isNumberInRange(number, start, end) {
    return Number(number) >= Math.min(start, end) && number <= Math.max(start, end)
  }

  /**
   * Maps value, from range to range
   *
   * For example mapping 10 degrees Celcius to Fahrenheit
   * `mapRangeToRange([0, 100], [32, 212], 10)`
   *
   * @static
   * @param {[number, number]} from
   * @param {[number, number]} to
   * @param {number} s
   * @return {*}  {number}
   * @memberof Util
   */
  static mapRangeToRange(from: [number, number], to: [number, number], s: number): number {
    return to[0] + ((s - from[0]) * (to[1] - to[0])) / (from[1] - from[0])
  }
  /**
   * Generates a good enough non-compliant UUID.
   */
  static uuid(win: BeamWindow) {
    const buf = new Uint32Array(4)
    return win.crypto.getRandomValues(buf).join("-")
  }
}
