// https://gist.github.com/dmsl1805/ad9a14b127d0409cf9621dc13d237457

extension String {
  public func camelCaseToSnakeCase() -> String {
    let acronymPattern = "([A-Z]+)([A-Z][a-z]|[0-9])"
    let fullWordsPattern = "([a-z])([A-Z]|[0-9])"
    let digitsFirstPattern = "([0-9])([A-Z])"
    return self.processCamelCaseRegex(pattern: acronymPattern)?
      .processCamelCaseRegex(pattern: fullWordsPattern)?
      .processCamelCaseRegex(pattern: digitsFirstPattern)?.lowercased() ?? self.lowercased()
  }

  fileprivate func processCamelCaseRegex(pattern: String) -> String? {
    let regex = try? NSRegularExpression(pattern: pattern, options: [])
    let range = NSRange(location: 0, length: count)
    return regex?.stringByReplacingMatches(in: self, options: [], range: range, withTemplate: "$1_$2")
  }
}
