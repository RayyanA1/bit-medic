//
// ContentView.swift
// bit-medic
//
// This is free and unencumbered software released into the public domain.
// For more information, see <https://unlicense.org>
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: PatientViewModel

    
    var body: some View {
        PatientSearchView()
            .environmentObject(viewModel)
    }
}
