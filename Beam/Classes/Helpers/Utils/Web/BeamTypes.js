/*
 * Types used by Beam API (to exchange messages, typically).
 */

export class BeamSize {
  /**
   * @type {number}
   */
  width

  /**
   * @type {number}
   */
  height
}

export class BeamRect extends BeamSize {
  /**
   * @type {number}
   */
  x

  /**
   * @type {number}
   */
  y
}

export class NoteInfo {
  /**
   * @type string
   */
  id   // Should not be nullable once we get it

  /**
   * @type string
   */
  title
}
