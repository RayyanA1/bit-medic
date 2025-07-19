//
// BitMedicViewSimple.swift
// bitchat - BitMedic Custom UI (Simple Version)
//

import SwiftUI

struct Patient: Codable, Identifiable {
    let id: Int
    let name: String
    let DOB: String?
    let address: String?
    let phone_number: String?
    let number_of_previous_visits: Int?
    let number_of_previous_admissions: Int?
    let date_of_last_admission: String?
    let patient_notes: String?
    let last_record_update: String?
}

struct BitMedicViewSimple: View {
    @EnvironmentObject var viewModel: ChatViewModel
    @State private var searchText = ""
    @State private var debugMode = false
    @State private var patients: [Patient] = []
    @State private var showingSuggestions = false
    @State private var selectedPatient: Patient?
    @State private var isSearching = false
    
    var body: some View {
        VStack {
            // Header with debug toggle
            HStack {
                Text("BitMedic")
                    .font(.largeTitle)
                
                Spacer()
                
                Button(action: {
                    debugMode.toggle()
                }) {
                    HStack {
                        Image(systemName: debugMode ? "eye.slash" : "eye")
                        Text("Debug")
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            .padding()
            
            VStack(spacing: 0) {
                HStack {
                    TextField("Search for patients...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: searchText) { newValue in
                            handleSearchTextChange(newValue)
                        }
                    
                    if isSearching {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Button("Search") {
                            performSearch()
                        }
                        .disabled(searchText.isEmpty)
                    }
                }
                .padding(.horizontal)
                
                if showingSuggestions && !patients.isEmpty {
                    patientSuggestionsList
                }
            }
            
            if debugMode {
                debugChatView
            } else {
                Spacer()
            }
        }
        .onAppear {
            joinSecureChannel()
        }
    }
    
    private var debugChatView: some View {
        VStack(alignment: .leading) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Debug Chat Messages")
                        .font(.headline)
                        .foregroundColor(.orange)
                    Spacer()
                }
                
                // Connection status
                HStack {
                    Circle()
                        .fill(viewModel.isConnected ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    
                    Text("Mesh Network: \(viewModel.isConnected ? "Connected" : "Disconnected")")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text("Peers: \(viewModel.connectedPeers.count)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                HStack {
                    Text("Channel: #bitmedic_secure")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text("Joined: \(viewModel.joinedChannels.contains("#bitmedic_secure") ? "Yes" : "No")")
                        .font(.caption)
                        .foregroundColor(viewModel.joinedChannels.contains("#bitmedic_secure") ? .green : .red)
                }
            }
            .padding(.horizontal)
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    let messages = getDebugMessages()
                    
                    if messages.isEmpty {
                        Text("No messages yet. Try searching to see mesh network activity.")
                            .foregroundColor(.gray)
                            .italic()
                            .padding()
                    } else {
                        ForEach(messages, id: \.id) { message in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(message.sender)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(message.sender == "system" ? .orange : .blue)
                                    
                                    Spacer()
                                    
                                    Text(formatTime(message.timestamp))
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                                
                                Text(message.content)
                                    .font(.caption)
                                    .padding(.vertical, 2)
                                    .padding(.horizontal, 6)
                                    .background(message.sender == "system" ? Color.orange.opacity(0.1) : Color.blue.opacity(0.1))
                                    .cornerRadius(4)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .frame(height: 300)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal)
        }
    }
    
    private var patientSuggestionsList: some View {
        VStack(spacing: 0) {
            ForEach(patients.prefix(5)) { patient in
                Button(action: {
                    selectPatient(patient)
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(patient.name)
                                .font(.body)
                                .foregroundColor(.primary)
                            Text("ID: \(patient.id)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .buttonStyle(PlainButtonStyle())
                .background(Color.gray.opacity(0.05))
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color.gray.opacity(0.2)),
                    alignment: .bottom
                )
            }
        }
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .padding(.horizontal)
        .padding(.top, 4)
    }
    
    private func handleSearchTextChange(_ newValue: String) {
        if newValue.isEmpty {
            patients = []
            showingSuggestions = false
            isSearching = false
            return
        }
        
        if newValue.count >= 2 {
            searchPatients(newValue)
        } else {
            showingSuggestions = false
        }
    }
    
    private func selectPatient(_ patient: Patient) {
        selectedPatient = patient
        searchText = patient.name
        showingSuggestions = false
        performSearch()
    }
    
    private func searchPatients(_ searchTerm: String) {
        guard !searchTerm.isEmpty else { return }
        
        isSearching = true
        
        guard let encodedSearchTerm = searchTerm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://partialsearchpatientname-uob3euoulq-uc.a.run.app/?name=\(encodedSearchTerm)") else {
            isSearching = false
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                self.isSearching = false
                self.handleAPIResponse(data: data, response: response, error: error)
            }
        }
        
        task.resume()
    }
    
    private func handleAPIResponse(data: Data?, response: URLResponse?, error: Error?) {
        guard let data = data,
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              error == nil else {
            patients = []
            showingSuggestions = false
            return
        }
        
        do {
            let decodedPatients = try JSONDecoder().decode([Patient].self, from: data)
            self.patients = decodedPatients
            self.showingSuggestions = !decodedPatients.isEmpty
        } catch {
            print("Failed to decode patients: \(error)")
            patients = []
            showingSuggestions = false
        }
    }
    
    private func performSearch() {
        guard !searchText.isEmpty else { return }
        let searchMessage = "PingToServer: /search?q=\(searchText)"
        viewModel.sendMessage(searchMessage)
        showingSuggestions = false
    }
    
    private func joinSecureChannel() {
        let secureChannel = "#bitmedic_secure"  // Add # prefix
        let channelPassword = "bitmedicsecure"
        
        print("DEBUG: Attempting to join channel: \(secureChannel)")
        
        if !viewModel.joinedChannels.contains(secureChannel) {
            let success = viewModel.joinChannel(secureChannel, password: channelPassword)
            print("DEBUG: Channel join result: \(success)")
        } else {
            print("DEBUG: Already joined channel: \(secureChannel)")
        }
        
        viewModel.switchToChannel(secureChannel)
        print("DEBUG: Switched to channel: \(secureChannel)")
        print("DEBUG: Current joined channels: \(viewModel.joinedChannels)")
    }
    
    private func getDebugMessages() -> [BitchatMessage] {
        // Get messages from the current secure channel
        let secureChannel = "#bitmedic_secure"
        
        // First try to get channel messages
        if let channelMessages = viewModel.channelMessages[secureChannel] {
            return channelMessages
        }
        
        // Fall back to main messages if no channel messages
        return viewModel.messages.filter { message in
            // Show messages that are system messages or contain our search terms
            message.sender == "system" || 
            message.content.contains("PingToServer:") ||
            message.content.contains("Results:")
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}