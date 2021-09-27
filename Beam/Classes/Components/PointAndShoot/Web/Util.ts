import { BeamElement, BeamWindow, BeamCoordinates } from "./BeamTypes"

export class Util {

  static getOffset(object: BeamElement, offset: BeamCoordinates): void {
    if (object) {
      offset.x += object.offsetLeft
      offset.y += object.offsetTop
      Util.getOffset(object.offsetParent, offset)
    }
  }

  static getScrolled(object: BeamElement, scrolled: BeamCoordinates): void {
    if (object) {
      scrolled.x += object.scrollLeft
      scrolled.y += object.scrollTop
      if (object.tagName.toLowerCase() != "html") {
        Util.getScrolled(object.parentNode as BeamElement, scrolled)
      }
    }
  }

  /**
   * Get top left X, Y coordinates of element taking into acocunt the scroll position 
   *
   * @static
   * @param {BeamElement} el
   * @return {*}  {BeamCoordinates}
   * @memberof Util
   */
  static getTopLeft(el: BeamElement): BeamCoordinates {
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
  static clamp(val: number, min: number, max: number): number {
    return val > max ? max : val < min ? min : val
  }

  /**
   * Remove null and undefined from array
   *
   * @static
   * @param {unknown[]} array
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
  static isNumberInRange(number: number, start: number, end: number): boolean {
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
   *
   * @static
   * @param {BeamWindow} win
   * @return {*}  {string}
   * @memberof Util
   */
  static uuid(win: BeamWindow): string {
    const buf = new Uint32Array(4)
    return win.crypto.getRandomValues(buf).join("-")
  }

  /**
   * Remove first matched item from array, Uses findIndex under the hood.
   *
   * @static
   * @param {(arrayElement) => boolean} matcher when matcher returns true that item is removed from array
   * @param {unknown[]} array input array
   * @return {*}  {unknown[]} return updated array
   * @memberof Util
   */
  static removeFromArray(matcher: (arrayElement) => boolean, array: unknown[]): unknown[] {
    const foundIndex = array.findIndex(matcher)
    // foundIndex is -1 when no match is found. Only remove found items from array
    if (foundIndex >= 0) {
      array.splice(foundIndex, 1)
    }

    return array
  }
}
