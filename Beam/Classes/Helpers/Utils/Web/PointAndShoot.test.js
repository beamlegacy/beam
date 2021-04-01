import {PointAndShoot} from "./PointAndShoot"
import {BeamVisualViewport, BeamWindow} from "./Beam"

class BeamWindowDecorator extends BeamWindow {
  /**
   * @param delegate {BeamWindow|Window}
   */
  constructor(delegate) {
    super()
    this.delegate = delegate
    this.document = delegate.document
    this.visualViewport = new BeamVisualViewport()
  }
}

class TestWindow extends BeamWindow {
  eventListeners = {}

  visualViewport = new BeamVisualViewport()

  getEventListeners() {
    return this.eventListeners
  }

  addEventListener(eventName, cb) {
    this.eventListeners[eventName] = cb
  }
}

class TestUI {

  setFramesInfo(framesInfo) {
    this.framesInfo = framesInfo
  }

  setScrollInfo(scrollInfo) {
    this.scrollInfo = scrollInfo
  }
}

test("instantiate", () => {
  const ui = new TestUI()
  const win = new BeamWindowDecorator(window)
  const pns = PointAndShoot(win, ui)
  /* const eventListeners = win.getEventListeners(win)
   const mouseMoveCb = eventListeners["mousemove"]
   expect(mouseMoveCb).toBeDefined()*/
})
