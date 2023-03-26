import { BeamWindow, MessagePayload } from "./BeamTypes";
export declare class Native<M> {
    /**
     * Singleton
     */
    static instance: Native<any>;
    win: BeamWindow<M>;
    readonly href: string;
    readonly componentPrefix: string;
    protected readonly messageHandlers: M;
    /**
     * @param win {BeamWindow}
     */
    static getInstance<M>(win: BeamWindow<M>, componentPrefix: string): Native<M>;
    /**
     * @param win {BeamWindow}
     */
    constructor(win: BeamWindow<M>, componentPrefix: string);
    /**
     * Message to the native part.
     *
     * @param name {string} Message name.
     *        Will be converted to ${prefix}_beam_${name} before sending.
     * @param payload {MessagePayload} The message data.
     *        An "href" property will always be added as the base URI of the current frame.
     */
    sendMessage(name: string, payload: MessagePayload): void;
    toString(): string;
}
