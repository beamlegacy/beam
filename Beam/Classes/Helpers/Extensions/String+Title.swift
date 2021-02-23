import Foundation
import Fakery

extension String {
    static func randomTitle() -> String {
        return Faker(locale: "en-US").commerce.productName() + " " + String.random(length: 40)
    }
}
