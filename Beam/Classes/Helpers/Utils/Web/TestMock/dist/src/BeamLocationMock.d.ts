import { BeamLocation } from "@beam/native-beamtypes";
export declare class BeamLocationMock implements BeamLocation {
    constructor(attributes?: {});
    ancestorOrigins: DOMStringList;
    hash: string;
    host: string;
    hostname: string;
    href: string;
    toString(): string;
    origin: string;
    pathname: string;
    port: string;
    protocol: string;
    search: string;
    assign(url: string): void;
    reload(): void;
    reload(forcedReload: boolean): void;
    replace(url: string): void;
}
