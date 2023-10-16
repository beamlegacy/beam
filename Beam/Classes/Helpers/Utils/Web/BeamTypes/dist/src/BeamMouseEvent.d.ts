import { BeamUIEvent } from "./BeamUIEvent";
export declare class BeamMouseEvent extends BeamUIEvent {
    constructor(attributes?: {});
    /**
     * If the Option key was down during the event.
     *
     * @type boolean
     */
    altKey: any;
    /**
     * @type number
     */
    clientX: any;
    /**
     * @type number
     */
    clientY: any;
}
