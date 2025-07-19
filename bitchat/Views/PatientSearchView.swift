//
// PatientSearchView.swift
// bit-medic
//
// This is free and unencumbered software released into the public domain.
// For more information, see <https://unlicense.org>
//

import SwiftUI

struct PatientSearchView: View {
    @EnvironmentObject var viewModel: PatientViewModel
    @Environment(\.colorScheme) var colorScheme
    @FocusState private var isSearchFieldFocused: Bool
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color.black : Color.white
    }
    
    private var textColor: Color {
        colorScheme == .dark ? Color.green : Color(red: 0, green: 0.5, blue: 0)
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? Color.green.opacity(0.8) : Color(red: 0, green: 0.5, blue: 0).opacity(0.8)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            searchView
            Divider()
            resultsView
        }
        .background(backgroundColor)
        .foregroundColor(textColor)
        #if os(macOS)
        .frame(minWidth: 600, minHeight: 400)
        #endif
    }
    
    private var headerView: some View {
        HStack {
            Text("bit-medic*")
                .font(.system(size: 18, weight: .medium, design: .monospaced))
                .foregroundColor(textColor)
            
            Spacer()
            
            Text("Patient Search")
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .foregroundColor(textColor)
            
            Spacer()
            
            // Connection status indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(viewModel.isConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                
                if viewModel.connectedPeers.count > 0 {
                    Text("\(viewModel.connectedPeers.count)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(secondaryTextColor)
                }
            }
        }
        .frame(height: 44)
        .padding(.horizontal, 12)
        .background(backgroundColor.opacity(0.95))
    }
    
    private var searchView: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16))
                        .foregroundColor(secondaryTextColor)
                    
                    TextField("Search patients by name, phone, condition...", text: $viewModel.searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16, design: .monospaced))
                        .foregroundColor(textColor)
                        .focused($isSearchFieldFocused)
                        .autocorrectionDisabled()
                    
                    if !viewModel.searchQuery.isEmpty {
                        Button(action: {
                            viewModel.clearSearch()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(secondaryTextColor)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(secondaryTextColor.opacity(0.3), lineWidth: 1)
                )
            }
            
            Button(action: {
                // TODO: Implement add patient functionality
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                    Text("Add New Patient")
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                }
                .foregroundColor(backgroundColor)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(secondaryTextColor.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .disabled(true) // Disabled as requested
            .opacity(0.6)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 24)
    }
    
    private var resultsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: textColor))
                    Text("Searching...")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(secondaryTextColor)
                        .padding(.leading, 8)
                    Spacer()
                }
                .padding(.vertical, 24)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text(viewModel.displayMessage)
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(secondaryTextColor)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        Spacer()
                    }
                    
                    if !viewModel.allSearchResults.isEmpty {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(Array(viewModel.allSearchResults.enumerated()), id: \.offset) { index, section in
                                    VStack(alignment: .leading, spacing: 0) {
                                        // Section header
                                        HStack {
                                            Text(section.title)
                                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                                .foregroundColor(secondaryTextColor)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 8)
                                            Spacer()
                                            if !section.isLocal {
                                                Image(systemName: "wifi")
                                                    .font(.system(size: 10))
                                                    .foregroundColor(Color.blue)
                                                    .padding(.trailing, 16)
                                            }
                                        }
                                        .background(Color.gray.opacity(0.1))
                                        
                                        // Section patients
                                        ForEach(section.patients) { patient in
                                            PatientRowView(patient: patient, isRemote: !section.isLocal)
                                                .onTapGesture {
                                                    viewModel.selectPatient(patient)
                                                }
                                        }
                                        
                                        // Add spacing between sections
                                        if index < viewModel.allSearchResults.count - 1 {
                                            Rectangle()
                                                .frame(height: 8)
                                                .foregroundColor(Color.gray.opacity(0.2))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            isSearchFieldFocused = true
        }
    }
}

struct PatientRowView: View {
    let patient: Patient
    let isRemote: Bool
    @Environment(\.colorScheme) var colorScheme
    
    init(patient: Patient, isRemote: Bool = false) {
        self.patient = patient
        self.isRemote = isRemote
    }
    
    private var textColor: Color {
        colorScheme == .dark ? Color.green : Color(red: 0, green: 0.5, blue: 0)
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? Color.green.opacity(0.8) : Color(red: 0, green: 0.5, blue: 0).opacity(0.8)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(patient.displayName)
                            .font(.system(size: 16, weight: .medium, design: .monospaced))
                            .foregroundColor(textColor)
                        
                        if isRemote {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.system(size: 12))
                                .foregroundColor(Color.blue)
                        }
                    }
                    
                    if let age = patient.age {
                        Text("Age: \(age)")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(secondaryTextColor)
                    }
                    
                    if let phone = patient.phoneNumber {
                        Text(phone)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(secondaryTextColor)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    if !patient.medicalConditions.isEmpty {
                        Text("\(patient.medicalConditions.count) condition\(patient.medicalConditions.count == 1 ? "" : "s")")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(secondaryTextColor)
                    }
                    
                    if !patient.medications.isEmpty {
                        Text("\(patient.medications.count) medication\(patient.medications.count == 1 ? "" : "s")")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(secondaryTextColor)
                    }
                    
                    if !patient.allergies.isEmpty {
                        Text("\(patient.allergies.count) allergi\(patient.allergies.count == 1 ? "y" : "es")")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Color.orange)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.clear)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(secondaryTextColor.opacity(0.2)),
            alignment: .bottom
        )
    }
}