import { BeamLogCategory, BeamWindow, Native } from "@beam/native-beamtypes";
export declare class BeamLogger {
    native: Native<any>;
    category: BeamLogCategory;
    constructor(win: BeamWindow, category: BeamLogCategory);
    log(...args: unknown[]): void;
    logWarning(...args: unknown[]): void;
    logDebug(...args: unknown[]): void;
    logError(...args: unknown[]): void;
    private sendMessage;
    private convertArgsToMessage;
}
