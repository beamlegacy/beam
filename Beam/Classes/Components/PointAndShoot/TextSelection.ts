export class TextSelection {
  /**
   * Selection range index.
   *
   * @type {number}
   */
  index

  /**
   * Selected text.
   *
   * @type {String}
   */
  text

  /**
   * Selected HTML.
   *
   * @type {String}
   */
  html

  /**
   * Selected rectangles.
   *
   * @type {{BeamRect}[]}
   */
  areas
}
