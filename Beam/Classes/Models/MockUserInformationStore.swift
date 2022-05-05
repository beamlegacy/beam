//
//  MockUserInformationStore.swift
//  Beam
//
//  Created by Frank Lefebvre on 19/04/2022.
//
//  Extracted from MockAutocompleteStores.swift -- temporarily in Beam target, will move to BeamTests eventually

import BeamCore

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
