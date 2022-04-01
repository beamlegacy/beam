import { EventsMock } from "@beam/native-testmock"
import { GeolocationUI } from "../src/GeolocationUI"

export class GeolocationUIMock extends EventsMock implements GeolocationUI {
  listenerAdded(): void {
    throw new Error("Method not implemented.")
  }
  listenerRemmoved(): void {
    throw new Error("Method not implemented.")
  }
}
