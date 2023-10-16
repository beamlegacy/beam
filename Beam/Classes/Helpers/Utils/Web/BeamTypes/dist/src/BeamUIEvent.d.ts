/**
 * We need this for tests as some properties of UIEvent (target) are readonly.
 */
export declare class BeamUIEvent {
    /**
     * @type BeamHTMLElement
     */
    target: any;
    preventDefault(): void;
    stopPropagation(): void;
}
