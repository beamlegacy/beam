import {BeamVisualViewport, BeamWindow} from "./Test/Mock/BeamMocks"

/**
 * Allows to decorate the standard Window to look like a BeamWindow.
 */
class BeamWindowDecorator extends BeamWindow {
  /**
   * @param delegate {Window}
   */
  constructor(delegate) {
    super()
    this.delegate = delegate
    this.document = delegate.document
    this.visualViewport = new BeamVisualViewport()
    this.location = delegate.location
  }
}
