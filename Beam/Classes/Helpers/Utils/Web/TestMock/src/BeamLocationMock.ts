import {BeamLocation} from "@beam/native-beamtypes"

export class BeamLocationMock implements BeamLocation {

  constructor(attributes = {}) {
    Object.assign(this, attributes)
  }

  ancestorOrigins: DOMStringList
  hash: string
  host: string
  hostname: string
  href: string

  toString(): string {
    throw new Error("Method not implemented.")
  }

  origin: string
  pathname: string
  port: string
  protocol: string
  search: string

  assign(url: string): void {
    throw new Error("Method not implemented.")
  }

  reload(): void
  reload(forcedReload: boolean): void
  reload(forcedReload?: any) {
    throw new Error("Method not implemented.")
  }

  replace(url: string): void {
    throw new Error("Method not implemented.")
  }
}
