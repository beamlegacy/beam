"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.EventsMock = void 0;
class EventsMock {
    constructor() {
        /**
         * Recorded calls to this mock UI
         * @type {[]}
         */
        this.events = [];
        this.log("instantiated");
    }
    get eventsCount() {
        return this.events.length;
    }
    get latestEvent() {
        return this.events[this.eventsCount - 1];
    }
    findEventByName(name) {
        return this.events.find(event => {
            return event.name == name;
        });
    }
    clearEvents() {
        this.events = [];
    }
    log(...args) {
        console.log(this.toString(), args);
    }
    toString() {
        return this.constructor.name;
    }
}
exports.EventsMock = EventsMock;
//# sourceMappingURL=EventsMock.js.map