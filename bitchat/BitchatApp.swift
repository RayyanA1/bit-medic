//
// BitchatApp.swift
// bit-medic
//
// This is free and unencumbered software released into the public domain.
// For more information, see <https://unlicense.org>
//

import SwiftUI

@main
struct BitchatApp: App {
    @StateObject private var patientViewModel = PatientViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(patientViewModel)
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        #endif
    }
}