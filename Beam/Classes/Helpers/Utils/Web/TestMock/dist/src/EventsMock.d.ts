export declare class EventsMock {
    /**
     * Recorded calls to this mock UI
     * @type {[]}
     */
    events: any[];
    constructor();
    get eventsCount(): number;
    get latestEvent(): any;
    findEventByName(name: string): any;
    clearEvents(): void;
    log(...args: any[]): void;
    toString(): string;
}
