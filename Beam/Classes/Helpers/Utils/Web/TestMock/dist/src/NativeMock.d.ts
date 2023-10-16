import { BeamWindow, MessagePayload, Native } from "@beam/native-beamtypes";
export declare class NativeMock<M> extends Native<M> {
    events: any[];
    constructor(win: BeamWindow<M>, componentPrefix: string);
    sendMessage(name: string, payload: MessagePayload): void;
}
