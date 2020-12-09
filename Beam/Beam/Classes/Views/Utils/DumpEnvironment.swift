//
//  DumpEnvironment.swift
//  Beam
//
//  Created by Sebastien Metrot on 30/10/2020.
//

import SwiftUI

struct DumpingEnvironment<V: View>: View {
    @Environment(\.self) var env
    let content: V
    var body: some View {
        dump(env)
        return content
    }
}
