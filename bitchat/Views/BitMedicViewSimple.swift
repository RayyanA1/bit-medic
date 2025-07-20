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
    @Environment(\.colorScheme) var colorScheme
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
    
    // New Patient Form States
    @State private var showingNewPatientForm = false
    @State private var isCreatingPatient = false
    @State private var newPatientId = ""
    @State private var newPatientName = ""
    @State private var newPatientDOB = ""
    @State private var newPatientGender = ""
    @State private var newPatientBloodType = ""
    @State private var newPatientAddress = ""
    @State private var newPatientPhone = ""
    @State private var newPatientAllergies = ""
    @State private var newPatientConditions = ""
    @State private var newPatientNotes = ""
    @State private var showingCreationAlert = false
    @State private var creationAlertMessage = ""
    
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "NetworkMonitor")
    
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
            // Fixed header with debug toggle - always visible
            HStack {
                Text("BitMedic")
                    .font(.largeTitle)
                    .foregroundColor(textColor)
                
                Spacer()
                
                Button("Add Patient") {
                    showingNewPatientForm = true
                }
                .foregroundColor(.green)
                .font(.caption)
                
                Button(action: {
                    debugMode.toggle()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: debugMode ? "eye.slash" : "eye")
                        Text("Debug")
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
                }
            }
            .padding()
            .background(backgroundColor)
            
            // Search section with fixed height
            VStack(spacing: 0) {
                // Search bar - fixed position
                HStack {
                    TextField("Search for patients...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: searchText) { newValue in
                            handleSearchTextChange(newValue)
                        }
                    
                    if isSearching {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(width: 60) // Fixed width for consistent layout
                    } else {
                        Button("Search") {
                            performSearch()
                        }
                        .disabled(searchText.isEmpty)
                        .frame(width: 60) // Fixed width for consistent layout
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                // Suggestions overlay - positioned absolutely to not affect layout
                ZStack(alignment: .top) {
                    // Invisible spacer to maintain layout height
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: debugMode ? 60 : 300) // Reserve space based on debug mode
                    
                    // Suggestions list - overlaid on top
                    if showingSuggestions && !patients.isEmpty {
                        patientSuggestionsList
                            .zIndex(1) // Ensure it appears above other content
                    }
                }
            }
            
            // Debug section - fixed at bottom
            if debugMode {
                debugChatView
                    .transition(.move(edge: .bottom))
            }
            
            Spacer(minLength: 0) // Flexible spacer at bottom
        }
        .background(backgroundColor)
        .animation(.easeInOut(duration: 0.3), value: debugMode)
        .animation(.easeInOut(duration: 0.2), value: showingSuggestions)
        .onTapGesture {
            // Hide suggestions when tapping outside
            if showingSuggestions {
                showingSuggestions = false
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
        .sheet(isPresented: $showingNewPatientForm) {
            VStack(spacing: 20) {
                Text("Add New Patient")
                    .font(.title)
                    .foregroundColor(textColor)
                
                VStack(spacing: 15) {
                    VStack(alignment: .leading) {
                        Text("Patient ID (6 digits)")
                            .foregroundColor(textColor)
                            .font(.caption)
                        TextField("123456", text: $newPatientId)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Patient Name")
                            .foregroundColor(textColor)
                            .font(.caption)
                        TextField("Enter patient name", text: $newPatientName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
                
                HStack(spacing: 20) {
                    Button("Cancel") {
                        resetForm()
                        showingNewPatientForm = false
                    }
                    .foregroundColor(.red)
                    
                    Button("Create Patient") {
                        createNewPatient()
                    }
                    .foregroundColor(.green)
                    .disabled(newPatientId.count != 6 || newPatientName.isEmpty || isCreatingPatient)
                }
                
                if isCreatingPatient {
                    ProgressView("Creating patient...")
                        .foregroundColor(textColor)
                }
            }
            .padding(30)
            .background(backgroundColor)
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
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(patients.prefix(5)) { patient in
                    Button(action: {
                        selectPatient(patient)
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(patient.name)
                                    .font(.body)
                                    .foregroundColor(textColor)
                                    .lineLimit(1)
                                Text("ID: \(patient.id)")
                                    .font(.caption)
                                    .foregroundColor(secondaryTextColor)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(colorScheme == .dark ? Color.gray.opacity(0.2) : Color.gray.opacity(0.05))
                    )
                    .overlay(
                        Rectangle()
                            .frame(height: 0.5)
                            .foregroundColor(colorScheme == .dark ? Color.gray.opacity(0.3) : Color.gray.opacity(0.2)),
                        alignment: .bottom
                    )
                }
            }
        }
        .frame(maxHeight: 250) // Limit maximum height
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColor)
                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        )
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
    
    // MARK: - New Patient Functions
    private func resetForm() {
        newPatientId = ""
        newPatientName = ""
        isCreatingPatient = false
    }
    
    private func createNewPatient() {
        guard newPatientId.count == 6, !newPatientName.isEmpty else { return }
        
        isCreatingPatient = true
        
        let patientData: [String: Any] = [
            "id": Int(newPatientId) ?? 0,
            "name": newPatientName
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: patientData),
              let url = URL(string: "https://addpatient-uob3euoulq-uc.a.run.app/") else {
            isCreatingPatient = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isCreatingPatient = false
                
                if let error = error {
                    print("Error creating patient: \(error)")
                } else if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                        self.resetForm()
                        self.showingNewPatientForm = false
                    } else {
                        print("Server error: \(httpResponse.statusCode)")
                    }
                }
            }
        }.resume()
    }
}