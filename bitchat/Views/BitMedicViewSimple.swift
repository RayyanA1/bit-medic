//
// BitMedicViewSimple.swift
// bitchat - BitMedic Custom UI (Simple Version)
//

import SwiftUI
import Network

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
    @State private var isConnectedToInternet = false
    @State private var connectivityTimer: Timer?
    @State private var activeAPITask: URLSessionDataTask?
    @State private var currentSearchTerm: String?
    
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "NetworkMonitor")
    
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
            startNetworkMonitoring()
            setupNotificationObserver()
            startPeriodicConnectivityCheck()
        }
        .onDisappear {
            networkMonitor.cancel()
            connectivityTimer?.invalidate()
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
                    Circle()
                        .fill(isConnectedToInternet ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    
                    Text("Internet: \(isConnectedToInternet ? "Connected" : "Offline")")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text("Search Mode: \(isConnectedToInternet ? "Direct API" : "Via Mesh")")
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
        
        // Cancel any previous request
        cancelPreviousSearch()
        
        currentSearchTerm = searchTerm.lowercased()
        isSearching = true
        
        // Test connectivity immediately before search to ensure current status
        testInternetConnectivity()
        
        // Add a small delay to allow connectivity test to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Only proceed if this is still the current search term
            guard self.currentSearchTerm == searchTerm.lowercased() else { return }
            
            if self.isConnectedToInternet {
                // Direct API call when online
                self.searchPatientsDirectly(searchTerm)
            } else {
                // Use mesh network when offline
                self.searchPatientsViaMesh(searchTerm)
            }
        }
    }
    
    private func cancelPreviousSearch() {
        // Cancel any active API task
        activeAPITask?.cancel()
        activeAPITask = nil
        
        // Clear current search term
        currentSearchTerm = nil
        
        // Reset search state
        isSearching = false
        patients = []
        showingSuggestions = false
    }
    
    private func searchPatientsDirectly(_ searchTerm: String) {
        guard let encodedSearchTerm = searchTerm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://partialsearchusingpatientname-uob3euoulq-uc.a.run.app/?name=\(encodedSearchTerm)") else {
            isSearching = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        activeAPITask = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                // Only process if this is still the current search term
                guard self.currentSearchTerm == searchTerm.lowercased() else { return }
                
                self.isSearching = false
                self.activeAPITask = nil
                self.handleAPIResponse(data: data, response: response, error: error)
            }
        }
        
        activeAPITask?.resume()
    }
    
    private func searchPatientsViaMesh(_ searchTerm: String) {
        // Send search request via mesh network
        let searchMessage = "PingToServer: /search?q=\(searchTerm)"
        
        // Notify PingToServerHandler that we're making this request so it can track it
        NotificationCenter.default.post(
            name: NSNotification.Name("BitMedicSearchRequestMade"),
            object: searchTerm.lowercased()
        )
        
        viewModel.sendMessage(searchMessage)
        
        // Set a timeout for mesh search
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
            if self.isSearching {
                self.isSearching = false
                self.patients = []
                self.showingSuggestions = false
            }
        }
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
        return viewModel.messages
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
    
    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [self] path in
            DispatchQueue.main.async {
                // First check if any network interface is available
                let hasNetworkInterface = path.status == .satisfied
                
                if hasNetworkInterface {
                    // Test actual internet connectivity
                    self.testInternetConnectivity()
                } else {
                    self.isConnectedToInternet = false
                }
            }
        }
        networkMonitor.start(queue: networkQueue)
        
        // Initial connectivity test
        testInternetConnectivity()
    }
    
    private func testInternetConnectivity() {
        // Use a lightweight endpoint to test connectivity
        guard let url = URL(string: "https://www.google.com") else {
            isConnectedToInternet = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5.0
        
        let task = URLSession.shared.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                if let httpResponse = response as? HTTPURLResponse {
                    self.isConnectedToInternet = httpResponse.statusCode == 200
                } else {
                    self.isConnectedToInternet = false
                }
            }
        }
        
        task.resume()
    }
    
    private func startPeriodicConnectivityCheck() {
        // Check connectivity every 10 seconds
        connectivityTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            self.testInternetConnectivity()
        }
    }
    
    private func setupNotificationObserver() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("BitMedicSearchResponse"),
            object: nil,
            queue: .main
        ) { notification in
            if let message = notification.object as? BitchatMessage {
                self.handleMeshSearchResponse(message.content)
            }
        }
    }
    
    private func handleMeshSearchResponse(_ content: String) {
        // Check if this is a patient search response
        if content.hasPrefix("Results: ") {
            let responseContent = String(content.dropFirst("Results: ".count))
            
            // Try to parse as JSON if it looks like structured data
            if responseContent.hasPrefix("[") && responseContent.hasSuffix("]") {
                // This looks like JSON array
                if let data = responseContent.data(using: .utf8) {
                    do {
                        let decodedPatients = try JSONDecoder().decode([Patient].self, from: data)
                        self.patients = decodedPatients
                        self.showingSuggestions = !decodedPatients.isEmpty
                        return
                    } catch {
                        print("Failed to decode mesh response as patients: \(error)")
                    }
                }
            }
            
            // Fallback: treat as simple text response
            // Try to extract patient info from text format
            let patientStrings = responseContent.components(separatedBy: " | ")
            var extractedPatients: [Patient] = []
            
            for (index, patientString) in patientStrings.enumerated() {
                // Create a simple patient from the string
                let patient = Patient(
                    id: 999900 + index, // Temporary ID for mesh responses
                    name: patientString,
                    DOB: nil,
                    address: nil,
                    phone_number: nil,
                    number_of_previous_visits: nil,
                    number_of_previous_admissions: nil,
                    date_of_last_admission: nil,
                    patient_notes: nil,
                    last_record_update: nil
                )
                extractedPatients.append(patient)
            }
            
            self.patients = extractedPatients
            self.showingSuggestions = !extractedPatients.isEmpty
        }
        
        // Stop searching indicator after processing
        isSearching = false
    }
}