//
//  MockAutocompleteStores.swift
//  Beam
//
//  Created by Frank Lefebvre on 31/05/2021.
//
import BeamCore

class MockCreditCardStore: CreditCardsStore {

    static let shared = MockCreditCardStore()
    private var creditCards: [CreditCard] = []

    init() {
        creditCards.append(CreditCard(cardDescription: "Black Card", cardNumber: 000000000000000, cardHolder: "Jean-Louis Darmon", cardDate: BeamDate.now))
    }

    func save(creditCard: CreditCard) {
        creditCards.append(creditCard)
    }

    func fetchAll() -> [CreditCard] {
        return creditCards
    }

    func update(id: UUID, creditCard: CreditCard) {
        var creditCardUpdated = creditCard
        creditCardUpdated.id = id
    }

    func delete(id: UUID) {
        if let index = creditCards.firstIndex(where: {$0.id == id}) {
            creditCards.remove(at: index)
        }
    }
}

class MockUserInformationsStore: UserInformationsStore {

    static let shared = MockUserInformationsStore()

    private var userInformations: [UserInformations] = []

    init() {
        userInformations.append(UserInformations(country: 1,
                                                 organization: "Beam",
                                                 firstName: "John",
                                                 lastName: "BeamBeam",
                                                 adresses: "123 Rue de Beam",
                                                 postalCode: "69001",
                                                 city: "BeamCity",
                                                 phone: "0628512605",
                                                 email: "john@beamapp.co"))
    }

    func save(userInfo: UserInformations) {
        userInformations.append(userInfo)
    }

    func update(userInfoUUIDToUpdate: UUID, updatedUserInformations: UserInformations) {
        var userInfoUpdated = updatedUserInformations
        userInfoUpdated.id = userInfoUUIDToUpdate
        // update userInfoUpdated
    }

    func fetchAll() -> [UserInformations] {
        return userInformations
    }

    func fetchFirst() -> UserInformations {
        guard let userInfo = self.userInformations.first else {
            return UserInformations(country: 1,
                                    organization: "Beam",
                                    firstName: "John",
                                    lastName: "BeamBeam",
                                    adresses: "123 Rue de Beam",
                                    postalCode: "69001",
                                    city: "BeamCity",
                                    phone: "0628512605",
                                    email: "john@beamapp.co")
        }
        return userInfo
    }

    func delete(id: UUID) {
        if let index = userInformations.firstIndex(where: {$0.id == id}) {
            userInformations.remove(at: index)
        }
    }
}
