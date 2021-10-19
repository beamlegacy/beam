/**
 * We need this for tests as some properties of UIEvent (target) are readonly.
 */
export class BeamUIEvent {
  /**
   * @type BeamHTMLElement
   */
  target

  preventDefault() {
    // TODO: Shouldn't we implement it?
  }

  stopPropagation() {
    // TODO: Shouldn't we implement it?
  }
}
