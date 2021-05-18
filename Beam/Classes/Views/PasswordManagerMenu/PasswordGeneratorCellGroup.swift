//
//  PasswordGeneratorCellGroup.swift
//  Beam
//
//  Created by Frank Lefebvre on 02/04/2021.
//

import SwiftUI

struct PasswordGeneratorCellGroup: View {
    @ObservedObject var viewModel: PasswordGeneratorViewModel

    var body: some View {
        Group {
            PasswordGeneratorSuggestionCell(viewModel: viewModel)
            if viewModel.showPreferences {
                Separator(horizontal: true)
                PasswordGeneratorSettingsCell(viewModel: viewModel)
            }
        }.frame(height: 81, alignment: .center)
    }
}

struct PasswordGeneratorCellGroup_Previews: PreviewProvider {
    static var previews: some View {
        PasswordGeneratorCellGroup(viewModel: PasswordGeneratorViewModel())
    }
}
