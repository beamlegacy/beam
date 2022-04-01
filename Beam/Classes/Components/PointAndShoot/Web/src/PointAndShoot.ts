import { PointAndShootUI } from "./PointAndShootUI"
import {
  BeamHTMLElement,
  BeamLogCategory,
  BeamMouseLocation,
  BeamRange,
  BeamRangeGroup,
  BeamShootGroup,
  BeamWindow,
  BeamUIEvent,
  BeamMouseEvent,
  BeamKeyEvent
} from "@beam/native-beamtypes"
import { BeamLogger, PointAndShootHelper } from "@beam/native-utils"
import { debounce } from "debounce"

/**
 * Listen to events that hover and select web blocks with Option.
 */
export class PointAndShoot {
  win: BeamWindow
  ui: PointAndShootUI
  static instance: PointAndShoot
  prefix = "__ID__"
  logger: BeamLogger
  timer
  touchDuration = 2500
  mouseLocation: BeamMouseLocation = { x: 0, y: 0 }
  selectionUUID?: string
  pointTarget: BeamShootGroup
  shootTargets: BeamShootGroup[] = []
  selectionRangeGroups: BeamRangeGroup[] = []
  isTypingOnWebView = false
  /**
   * Returns the Point and Shoot instance. A new instance will be created if none exists yet.
   *
   * @static
   * @param {BeamWindow} win
   * @param {PointAndShootUI} ui
   * @return {*}  {PointAndShoot}
   * @memberof PointAndShoot
   */
  static getInstance(win: BeamWindow, ui: PointAndShootUI): PointAndShoot {
    if (!PointAndShoot.instance) {
      PointAndShoot.instance = new PointAndShoot(win, ui)
    }
    return PointAndShoot.instance
  }
  /**
   * Creates an instance of PointAndShoot.
   * @param {BeamWindow} win
   * @param {PointAndShootUI} ui
   * @memberof PointAndShoot
   */
  constructor(win: BeamWindow, ui: PointAndShootUI) {
    this.win = win
    this.ui = ui
    this.logger = new BeamLogger(this.win, BeamLogCategory.pointAndShoot)
    this.selectionUUID = PointAndShootHelper.uuid(win)
    this.registerEventListeners()
    this.sendBounds = this.sendBounds.bind(this)
  }
  /**
   * Registers all Event Listeners Point and Shoot requires.
   *
   * @memberof PointAndShoot
   */
  registerEventListeners(): void {
    this.win.addEventListener("mousemove", this.onMouseMove.bind(this))
    this.win.addEventListener("click", this.onClick.bind(this), true)
    this.win.addEventListener("touchstart", this.onTouchstart.bind(this), false)
    this.win.addEventListener("touchend", this.onTouchend.bind(this), false)
    this.win.addEventListener("keydown", this.onKeyDown.bind(this), {
      capture: true
    })
    this.win.addEventListener("mouseup", this.onMouseUp.bind(this))
    this.win.document.addEventListener(
      "selectionchange",
      this.onSelection.bind(this)
    )

    const immediate = true
    const debounceTimeout = 8 // 120fps
    this.win.addEventListener("scroll", this.onScroll.bind(this), true)
    this.win.addEventListener(
      "resize",
      debounce(this.onResize.bind(this), debounceTimeout, immediate),
      true
    )
    this.win.addEventListener(
      "orientationchange",
      this.onResize.bind(this),
      true
    )

    const vv = this.win.visualViewport
    vv.addEventListener(
      "onresize",
      debounce(this.onResize.bind(this), debounceTimeout, immediate)
    )
    vv.addEventListener(
      "scroll",
      debounce(this.onResize.bind(this), debounceTimeout, immediate)
    )

    this.win.onunload = function() {
      clearTimeout(this.timer)
      this.timer = null
    }
  }
  /**
   * Send updates to the UI.
   *
   * @memberof PointAndShoot
   */
  sendBounds(): void {
    // Remove DOM elements that are disconnected from the DOM
    this.removeDisconnectedDOMElements()
    // Send Boolean flags
    this.ui.hasSelection(PointAndShootHelper.hasSelection(this.win))
    this.ui.typingOnWebView(this.isTypingOnWebView)
    // Lastly send positioning bounds
    this.ui.pointBounds(this.pointTarget)
    this.ui.shootBounds(this.shootTargets)
    this.ui.selectBounds(this.selectionRangeGroups)
  }

  /**
   * DOM elements can be removed from the page. If we lose the reference to
   * any DOM elements in our stored targets. Remove them from the stored targets.
   * 
   * https://developer.mozilla.org/en-US/docs/Web/API/Node/isConnected
   *
   * @memberof PointAndShoot
   */
  removeDisconnectedDOMElements() {
    this.selectionRangeGroups = this.selectionRangeGroups.filter(target => {
      const startNodeIsConnected = target.range.startContainer.isConnected
      const endNodeIsConnected = target.range.endContainer.isConnected
      // Keep group if both start and end are connected
      return startNodeIsConnected && endNodeIsConnected
    })

    this.shootTargets = this.shootTargets.filter(target => {
      // Keep element if it's connected
      return target.element.isConnected
    })
  }
  /**
   * Upserts the target element to the shootTargets Array. Then triggers
   * a UI update.
   *
   * @param {BeamHTMLElement} targetEl
   * @memberof PointAndShoot
   */
  shoot(targetEl: BeamHTMLElement): void {
    const shootGroup = {
      id: PointAndShootHelper.uuid(this.win),
      element: targetEl
    }
    PointAndShootHelper.upsertShootGroup(shootGroup, this.shootTargets)
    this.sendBounds()
  }
  /**
   * Updates the point element with the target element. The pointTarget only
   * gets updated when the target is different. Then triggers a UI update.
   *
   * @param {BeamHTMLElement} targetEl
   * @memberof PointAndShoot
   */
  point(targetEl: BeamHTMLElement): void {
    // only assign new pointTarget when pointTarget is different
    if (this.pointTarget?.element != targetEl) {
      this.pointTarget = {
        id: PointAndShootHelper.uuid(this.win),
        element: targetEl
      }
    }

    this.sendBounds()
  }
  /**
   * Upserts the selectionRangeGroups Array with current Selection. A new
   * selectionRangeGroup is created when the current selection is collapsed,
   * this also messages the UI with a "clearSelection" event.
   *
   * The selectionRangeGroups Array is always updated. However updating the UI
   * with the new Bounds is debounced by 8ms (120fps). This reduces the amount
   * of expensive calculations.
   *
   * @memberof PointAndShoot
   */
  select(): void {
    const selection = PointAndShootHelper.getSelection(this.win)
    // reset the uuid to store a new selection next time
    if (selection.rangeCount == 0) {
      return
    }
    if (selection.isCollapsed) {
      // clear selectionTarget when we have a stored value
      this.ui.clearSelection(this.selectionUUID)
      this.selectionUUID = PointAndShootHelper.uuid(this.win)
      return
    }
    // Rangecount is always array of 1, unless programatically modified
    // https://developer.mozilla.org/en-US/docs/Web/API/Selection/rangeCount
    const range = selection.getRangeAt(0)

    const rangeGroup: BeamRangeGroup = {
      id: this.selectionUUID,
      range: range as BeamRange
    }

    PointAndShootHelper.upsertRangeGroup(rangeGroup, this.selectionRangeGroups)
    debounce(this.sendBounds, 8) // 120fps
  }
  /**
   * For performance reasons we want to stop listening to element we don't care
   * about. However due to limitations in the Swift to JS bridge in iframes we
   * can't rely on this happening all the time. For most browsing behaviour we
   * can remove unused targets resulting in greatly improved performance.
   *
   * @param {string} id - id of the target element to stop watching
   * @memberof PointAndShoot
   */
  removeTarget(id: string): void {
    this.removeSelectRangeGroup(id)
    this.removeShootTarget(id)
  }
  /**
   * Remove target with id from observed elements
   *
   * @param {string} id - id of target to remove
   * @memberof PointAndShoot
   */
  removeShootTarget(id: string): void {
    // Use removeFromArray so it exists after finding a match
    this.shootTargets = PointAndShootHelper.removeFromArray((target) => {
      return target.id === id
    }, this.shootTargets) as BeamShootGroup[]
  }
  /**
   * Remove target with id from observed ranges
   *
   * @param {string} id - id of target to remove
   * @memberof PointAndShoot
   */
  removeSelectRangeGroup(id: string): void {
    // Use removeFromArray so it exists after finding a match
    this.selectionRangeGroups = PointAndShootHelper.removeFromArray((target) => {
      return target.id === id
    }, this.selectionRangeGroups) as BeamRangeGroup[]
  }

  /**
   * ======================================================================
   * Eventlisteners =======================================================
   * ======================================================================
   */
  /**
   * When called it updates the pointing target when pointing isn't currently 
   * disabled. Then it sends updates to the UI. 
   *
   * @param {BeamUIEvent} ev
   * @memberof PointAndShoot
   */
  onScroll(ev: BeamUIEvent): void {
    if (
      this.mouseLocation?.x &&
      !PointAndShootHelper.isPointDisabled(this.win, ev.target)
    ) {
      const target = PointAndShootHelper.getElementAtMouseLocation(
        this.win,
        this.mouseLocation
      )
      this.point(target)
    } else {
      this.sendBounds()
    }
  }
  /**
   * When called it only sends UI updates when the mouseLocation has changed 
   * from the previous Coordinates and when the Alt key is pressed. If pointing 
   * is allowed the pointing target is updated and `isTypingOnWebView` is set 
   * to false.
   *
   * @param {BeamMouseEvent} ev
   * @memberof PointAndShoot
   */
  onMouseMove(ev: BeamMouseEvent): void {
    if (
      PointAndShootHelper.hasMouseLocationChanged(
        this.mouseLocation,
        ev.clientX,
        ev.clientY
      ) &&
      PointAndShootHelper.isOnlyAltKey(ev)
    ) {
      // Code when the (physical) mouse actually moves
      if (Boolean(ev.target) && !PointAndShootHelper.isPointDisabled(this.win, ev.target)) {
        this.point(ev.target)
        this.isTypingOnWebView = false
      } else {
        this.sendBounds()
      }
    }
    this.mouseLocation.x = ev.clientX
    this.mouseLocation.y = ev.clientY
  }
  /**
   * When the user clicks and pointing is allowed on the target element, a new 
   * Shoot target is created. onClick should always send updated bounds so the 
   * UI is updated.
   *
   * @param {BeamUIEvent} ev
   * @memberof PointAndShoot
   */
  onClick(ev: BeamUIEvent): void {
    if (PointAndShootHelper.isOnlyAltKey(ev)) {
      ev.preventDefault()
      ev.stopPropagation()
    }

    if (Boolean(ev.target) && !PointAndShootHelper.isPointDisabled(this.win, ev.target)) {
      this.shoot(ev.target)
    } else {
      this.sendBounds()
    }
  }
  /**
   * onClick but for touch events
   *
   * @param {BeamUIEvent} ev
   * @memberof PointAndShoot
   */
  onLongtouch(ev: BeamUIEvent): void {
    if (!PointAndShootHelper.isPointDisabled(this.win, ev.target)) {
      this.shoot(ev.target)
    } else {
      this.sendBounds()
    }
  }
  /**
   * onClick but for touch events
   *
   * @param {TouchEvent} ev
   * @memberof PointAndShoot
   */
  onTouchstart(ev: TouchEvent): void {
    if (!this.timer) {
      this.timer = setTimeout(this.onLongtouch.bind(this), this.touchDuration, ev)
    }
  }
  /**
   * onClick but for touch events
   *
   * @memberof PointAndShoot
   */
  onTouchend(): void {
    if (this.timer) {
      clearTimeout(this.timer)
      this.timer = null
    }
  }
  /**
   * When called while a the current activeElement is a text input,
   * `isTypingOnWebView` is set to true and the UI is updated. When it isn't an 
   * active text input `isTypingOnWebView` is set to false and the current 
   * pointTarget is set to the element underneath the Mouse Location.
   *
   * @param {BeamKeyEvent} _ev
   * @memberof PointAndShoot
   */
  onKeyDown(_ev: BeamKeyEvent): void {
    if (PointAndShootHelper.hasFocusedTextualInput(this.win)) {
      this.isTypingOnWebView = true
      this.sendBounds()
    } else {
      this.isTypingOnWebView = false
      const target = PointAndShootHelper.getElementAtMouseLocation(
        this.win,
        this.mouseLocation
      )
      this.point(target)
    }
  }
  /**
   * When called handle the selection
   *
   * @memberof PointAndShoot
   */
   onSelection(): void {
    this.select()
  }
  /**
   * When called update the UI
   *
   * @memberof PointAndShoot
   */
  onMouseUp(): void {
    this.sendBounds()
  }
  /**
   * When called update the UI
   *
   * @memberof PointAndShoot
   */
  onResize(): void {
    this.sendBounds()
  }
}
