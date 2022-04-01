import { EventsMock } from "@beam/native-testmock"
import { SearchWebPageUI } from "../src/SearchWebPageUI"

export class SearchWebPageUIMock extends EventsMock implements SearchWebPageUI {
  webPageSearch(payload: { currentResult?: number; totalResults?: number; positions?: undefined[]; height?: number; incompleteSearch?: boolean; currentSelected?: boolean }) {
    throw new Error("Method not implemented.")
  }
  webSearchCurrentSelection(selection: string) {
    throw new Error("Method not implemented.")
  }
}
