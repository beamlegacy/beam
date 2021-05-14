import {BeamElement} from "./BeamTypes"

export class Util {
  /**
   *
   * @param callback The function to call
   * @param limit Time limit in ms
   * @returns {function(): void}
   */
  static throttle(callback, limit) {
    let waiting = false                     // Initially, we're not waiting
    return function () {                     // We return a throttled function
      if (!waiting) {                       // If we're not waiting
        callback.apply(this, arguments)     // Execute users function
        waiting = true                      // Prevent future invocations
        setTimeout(function () {     // After a period of time
          waiting = false                   // And allow future invocations
        }, limit)
      }
    }
  }

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
        Util.getScrolled(object.parentNode, scrolled)
      }
    }
  }

  static getTopLeft(el: BeamElement) {
    const offset = {x: 0, y: 0}
    Util.getOffset(el, offset)

    const scrolled = {x: 0, y: 0}
    Util.getScrolled(el.parentNode, scrolled)

    const x = offset.x - scrolled.x
    const y = offset.y - scrolled.y
    return {x, y}
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
    return val > max ? max : val < min ? min : val;
  }
}
