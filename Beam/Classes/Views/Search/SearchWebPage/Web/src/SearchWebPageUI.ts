
export interface SearchWebPageUI {
  webPageSearch(payload: {
    currentResult?: number
    totalResults?: number
    positions?: undefined[]
    height?: number
    incompleteSearch?: boolean
    currentSelected?: boolean
  })
  webSearchCurrentSelection(selection: string)
}
