//
//  PasswordGeneratorSettingsCell.swift
//  Beam
//
//  Created by Frank Lefebvre on 02/04/2021.
//

import SwiftUI

struct PasswordGeneratorSettingsCell: View {
    @ObservedObject var viewModel: PasswordGeneratorViewModel

    var body: some View {
        PasswordManagerMenuCell(type: .autofill, height: 56, onChange: handleStateChange) {
            HStack {
                OptionSelector(value: $viewModel.generatorOption)
                Spacer()
                switch viewModel.generatorOption {
                case .passphrase:
                    Text("Words: ")
                    StepperControl(min: 2, max: 6, value: $viewModel.generatorPassphraseWordCount)
                case .password:
                    Text("Length: ")
                    StepperControl(min: 8, max: 30, value: $viewModel.generatorPasswordLength)
                }
            }
        }
    }

    private func handleStateChange(_: PasswordManagerMenuCellState) {
    }
}

struct PasswordGeneratorSettingsCell_Previews: PreviewProvider {
    static var previews: some View {
        PasswordGeneratorSettingsCell(viewModel: PasswordGeneratorViewModel())
    }
}
