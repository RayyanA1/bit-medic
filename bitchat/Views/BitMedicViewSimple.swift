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
    let chronic_conditions: String?
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
    
    // Patient View States
    @State private var showingPatientView = false
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
    @State private var creationErrorMessage = ""
    @State private var creationSuccessMessage = ""
    
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
        .sheet(isPresented: $showingPatientView) {
            patientViewSheet
        }
        .sheet(isPresented: $showingNewPatientForm) {
            VStack(spacing: 20) {
                Text("Add New Patient")
                    .font(.title)
                    .foregroundColor(textColor)
                
                ScrollView {
                    VStack(spacing: 15) {
                        VStack(alignment: .leading) {
                            HStack {
                                Text("Patient ID")
                                    .foregroundColor(textColor)
                                    .font(.caption)
                                Text("*")
                                    .foregroundColor(.red)
                                    .font(.caption)
                                    .fontWeight(.bold)
                            }
                            TextField("Enter patient ID", text: $newPatientId)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                )
                        }
                        
                        VStack(alignment: .leading) {
                            HStack {
                                Text("Patient Name")
                                    .foregroundColor(textColor)
                                    .font(.caption)
                                Text("*")
                                    .foregroundColor(.red)
                                    .font(.caption)
                                    .fontWeight(.bold)
                            }
                            TextField("Enter patient name", text: $newPatientName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                )
                        }
                        
                        VStack(alignment: .leading) {
                            HStack {
                                Text("Date of Birth")
                                    .foregroundColor(textColor)
                                    .font(.caption)
                                Text("*")
                                    .foregroundColor(.red)
                                    .font(.caption)
                                    .fontWeight(.bold)
                            }
                            TextField("YYYY-MM-DD", text: $newPatientDOB)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                )
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Gender")
                                .foregroundColor(secondaryTextColor)
                                .font(.caption)
                            Picker("", selection: $newPatientGender) {
                                Text("Select Gender").tag("")
                                Text("Male").tag("Male")
                                Text("Female").tag("Female")
                            }
                            .pickerStyle(MenuPickerStyle())
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Blood Type")
                                .foregroundColor(secondaryTextColor)
                                .font(.caption)
                            TextField("A+, B-, O+, etc.", text: $newPatientBloodType)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Address")
                                .foregroundColor(secondaryTextColor)
                                .font(.caption)
                            TextField("Enter address", text: $newPatientAddress)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Phone Number")
                                .foregroundColor(secondaryTextColor)
                                .font(.caption)
                            TextField("Enter phone number", text: $newPatientPhone)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Allergies")
                                .foregroundColor(secondaryTextColor)
                                .font(.caption)
                            TextEditor(text: $newPatientAllergies)
                                .frame(minHeight: 60, maxHeight: 120)
                                .padding(4)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Chronic Conditions")
                                .foregroundColor(secondaryTextColor)
                                .font(.caption)
                            TextEditor(text: $newPatientConditions)
                                .frame(minHeight: 60, maxHeight: 120)
                                .padding(4)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Notes")
                                .foregroundColor(secondaryTextColor)
                                .font(.caption)
                            TextEditor(text: $newPatientNotes)
                                .frame(minHeight: 80, maxHeight: 150)
                                .padding(4)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                        }
                    }
                    .padding(.horizontal)
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
                    .disabled(newPatientId.isEmpty || newPatientName.isEmpty || newPatientDOB.isEmpty || isCreatingPatient || !isValidDOB())
                }
                
                if isCreatingPatient {
                    ProgressView("Creating patient...")
                        .foregroundColor(textColor)
                }
                
                if !creationErrorMessage.isEmpty {
                    Text(creationErrorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.top, 10)
                }
                
                if !creationSuccessMessage.isEmpty {
                    Text(creationSuccessMessage)
                        .foregroundColor(.green)
                        .font(.caption)
                        .padding(.top, 10)
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
                    Button("Clear") {
                        clearDebugMessages()
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(6)
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
                VStack(alignment: .leading, spacing: 4) {
                    let messages = getDebugMessages()
                    
                    if messages.isEmpty {
                        Text("No messages yet. Try searching to see mesh network activity.")
                            .foregroundColor(.gray)
                            .italic()
                            .padding()
                    } else {
                        // Create one big selectable text block with all messages
                        Text(messages.map { message in
                            "\(message.sender) [\(formatTime(message.timestamp))]\n\(message.content)"
                        }.joined(separator: "\n\n"))
                            .font(.caption)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                }
            }
            .frame(height: 300)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal)
        }
    }
    
    private var patientViewSheet: some View {
        VStack(spacing: 20) {
            Text("Patient Details")
                .font(.title)
                .foregroundColor(textColor)
            
            if let patient = selectedPatient {
                ScrollView {
                    VStack(spacing: 15) {
                        VStack(alignment: .leading) {
                            HStack {
                                Text("Patient ID")
                                    .foregroundColor(textColor)
                                    .font(.caption)
                                Text("*")
                                    .foregroundColor(.red)
                                    .font(.caption)
                                    .fontWeight(.bold)
                            }
                            Text("\(patient.id)")
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(6)
                        }
                        
                        VStack(alignment: .leading) {
                            HStack {
                                Text("Patient Name")
                                    .foregroundColor(textColor)
                                    .font(.caption)
                                Text("*")
                                    .foregroundColor(.red)
                                    .font(.caption)
                                    .fontWeight(.bold)
                            }
                            Text(patient.name)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(6)
                        }
                        
                        VStack(alignment: .leading) {
                            HStack {
                                Text("Date of Birth")
                                    .foregroundColor(textColor)
                                    .font(.caption)
                                Text("*")
                                    .foregroundColor(.red)
                                    .font(.caption)
                                    .fontWeight(.bold)
                            }
                            Text(patient.DOB ?? "Not provided")
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(6)
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Address")
                                .foregroundColor(secondaryTextColor)
                                .font(.caption)
                            Text(patient.address ?? "Not provided")
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(6)
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Phone Number")
                                .foregroundColor(secondaryTextColor)
                                .font(.caption)
                            Text(patient.phone_number ?? "Not provided")
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(6)
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Previous Visits")
                                .foregroundColor(secondaryTextColor)
                                .font(.caption)
                            Text("\(patient.number_of_previous_visits ?? 0)")
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(6)
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Previous Admissions")
                                .foregroundColor(secondaryTextColor)
                                .font(.caption)
                            Text("\(patient.number_of_previous_admissions ?? 0)")
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(6)
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Last Admission Date")
                                .foregroundColor(secondaryTextColor)
                                .font(.caption)
                            Text(patient.date_of_last_admission ?? "Never admitted")
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(6)
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Chronic Conditions")
                                .foregroundColor(secondaryTextColor)
                                .font(.caption)
                            ScrollView {
                                Text(patient.chronic_conditions ?? "No chronic conditions recorded")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(minHeight: 60, maxHeight: 120)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(6)
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Patient Notes")
                                .foregroundColor(secondaryTextColor)
                                .font(.caption)
                            ScrollView {
                                Text(patient.patient_notes ?? "No notes available")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(minHeight: 80, maxHeight: 150)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(6)
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Last Record Update")
                                .foregroundColor(secondaryTextColor)
                                .font(.caption)
                            Text(patient.last_record_update ?? "Unknown")
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(6)
                        }
                    }
                    .padding(.horizontal)
                }
                
                Button("Close") {
                    showingPatientView = false
                }
                .foregroundColor(.blue)
                .font(.body)
                .padding()
            } else {
                Text("No patient selected")
                    .foregroundColor(.gray)
            }
        }
        .padding(30)
        .background(backgroundColor)
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
        showingPatientView = true
    }
    
    private func searchPatients(_ searchTerm: String) {
        guard !searchTerm.isEmpty else { return }
        
        // Cancel any previous request
        cancelPreviousSearch()
        
        currentSearchTerm = searchTerm  // Keep original case for API and tracking
        isSearching = true
        
        // Test connectivity immediately before search to ensure current status
        testInternetConnectivity()
        
        // Add a small delay to allow connectivity test to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Only proceed if this is still the current search term
            guard self.currentSearchTerm == searchTerm else { return }
            
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
                guard self.currentSearchTerm == searchTerm else { return }
                
                self.isSearching = false
                self.activeAPITask = nil
                self.handleAPIResponse(data: data, response: response, error: error)
            }
        }
        
        activeAPITask?.resume()
    }
    
    private func searchPatientsViaMesh(_ searchTerm: String) {
        // Notify PingToServerHandler that we're making this request so it can track it BEFORE sending
        NotificationCenter.default.post(
            name: NSNotification.Name("BitMedicSearchRequestMade"),
            object: searchTerm  // Keep original case for tracking
        )
        
        // Send search request via mesh network
        let searchMessage = "PingToServer: /search?q=\(searchTerm)"
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
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("BitMedicCreatePatientResponse"),
            object: nil,
            queue: .main
        ) { notification in
            if let message = notification.object as? BitchatMessage {
                self.handleMeshCreatePatientResponse(message.content)
            }
        }
    }
    
    private func clearDebugMessages() {
        let secureChannel = "#bitmedic_secure"
        viewModel.channelMessages[secureChannel] = []
        viewModel.messages = []
    }
    
    private func handleMeshSearchResponse(_ content: String) {
        // Stop searching indicator after processing (like create patient does)
        isSearching = false
        
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
                        // JSON parsing failed, fall through to text parsing
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
                    chronic_conditions: nil,
                    patient_notes: nil,
                    last_record_update: nil
                )
                extractedPatients.append(patient)
            }
            
            self.patients = extractedPatients
            self.showingSuggestions = !extractedPatients.isEmpty
        }
    }
    
    private func handleMeshCreatePatientResponse(_ content: String) {
        // Check if this is a patient creation response
        if content.hasPrefix("CreatePatientResult: ") {
            let responseContent = String(content.dropFirst("CreatePatientResult: ".count))
            
            isCreatingPatient = false
            
            if responseContent.contains("success") || responseContent.contains("created") {
                print("Patient created successfully via mesh")
                creationSuccessMessage = "Patient created successfully via mesh!"
                
                // Show success message for 2 seconds then close form
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    resetForm()
                    showingNewPatientForm = false
                }
            } else if responseContent.contains("error") {
                // Extract error message from "error - message" format
                let errorMsg: String
                if responseContent.hasPrefix("error - ") {
                    errorMsg = String(responseContent.dropFirst("error - ".count))
                } else {
                    errorMsg = responseContent
                }
                print("Patient creation failed via mesh: \(errorMsg)")
                creationErrorMessage = "Failed via mesh: \(errorMsg)"
            } else {
                let errorMsg = "Unknown response from mesh: \(responseContent)"
                print(errorMsg)
                creationErrorMessage = errorMsg
            }
        }
    }
    
    // MARK: - New Patient Functions
    private func resetForm() {
        newPatientId = ""
        newPatientName = ""
        newPatientDOB = ""
        newPatientGender = ""
        newPatientBloodType = ""
        newPatientAddress = ""
        newPatientPhone = ""
        newPatientAllergies = ""
        newPatientConditions = ""
        newPatientNotes = ""
        isCreatingPatient = false
        creationErrorMessage = ""
        creationSuccessMessage = ""
    }
    
    private func isValidDOB() -> Bool {
        // DOB is now required, so empty is invalid
        if newPatientDOB.isEmpty {
            return false
        }
        
        // Check format YYYY-MM-DD
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.isLenient = false
        
        return dateFormatter.date(from: newPatientDOB) != nil
    }
    
    private func createNewPatient() {
        guard !newPatientId.isEmpty, !newPatientName.isEmpty, !newPatientDOB.isEmpty, isValidDOB() else { return }
        
        isCreatingPatient = true
        creationErrorMessage = ""
        creationSuccessMessage = ""
        
        var patientData: [String: Any] = [
            "id": Int(newPatientId) ?? 0,
            "name": newPatientName,
            "DOB": newPatientDOB
        ]
        
        // Add optional fields if provided
        if !newPatientGender.isEmpty {
            patientData["gender"] = newPatientGender
        }
        if !newPatientBloodType.isEmpty {
            patientData["blood_type"] = newPatientBloodType
        }
        if !newPatientAddress.isEmpty {
            patientData["address"] = newPatientAddress
        }
        if !newPatientPhone.isEmpty {
            patientData["phone_number"] = newPatientPhone
        }
        if !newPatientAllergies.isEmpty {
            patientData["allergies"] = newPatientAllergies
        }
        if !newPatientConditions.isEmpty {
            patientData["chronic_conditions"] = newPatientConditions
        }
        if !newPatientNotes.isEmpty {
            patientData["patient_notes"] = newPatientNotes
        }
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: patientData),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            isCreatingPatient = false
            creationErrorMessage = "Failed to prepare request data"
            return
        }
        
        print("Creating patient with data: \(jsonString)")
        
        // Test connectivity to determine how to send the request
        testInternetConnectivity()
        
        // Add a small delay to allow connectivity test to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if self.isConnectedToInternet {
                // Direct API call when online
                self.createPatientDirectly(jsonData: jsonData)
            } else {
                // Use mesh network when offline
                self.createPatientViaMesh(jsonString: jsonString)
            }
        }
    }
    
    private func createPatientDirectly(jsonData: Data) {
        guard let url = URL(string: "https://addpatient-uob3euoulq-uc.a.run.app/") else {
            isCreatingPatient = false
            creationErrorMessage = "Invalid server URL"
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
                    let errorMsg = "Network error: \(error.localizedDescription)"
                    print("Error creating patient: \(errorMsg)")
                    self.creationErrorMessage = errorMsg
                } else if let httpResponse = response as? HTTPURLResponse {
                    print("Server response code: \(httpResponse.statusCode)")
                    
                    if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                        print("Patient created successfully")
                        self.creationSuccessMessage = "Patient created successfully!"
                        
                        // Show success message for 2 seconds then close form
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            self.resetForm()
                            self.showingNewPatientForm = false
                        }
                    } else {
                        let errorMsg: String
                        if let data = data, let responseBody = String(data: data, encoding: .utf8) {
                            errorMsg = "Server error \(httpResponse.statusCode): \(responseBody)"
                            print("Server error response: \(responseBody)")
                        } else {
                            errorMsg = "Server error: HTTP \(httpResponse.statusCode)"
                        }
                        print("Server error: \(httpResponse.statusCode)")
                        self.creationErrorMessage = errorMsg
                    }
                } else {
                    let errorMsg = "Invalid response from server"
                    print(errorMsg)
                    self.creationErrorMessage = errorMsg
                }
            }
        }.resume()
    }
    
    private func createPatientViaMesh(jsonString: String) {
        // Check if we have mesh connectivity before sending
        if !viewModel.isConnected || viewModel.connectedPeers.count == 0 {
            isCreatingPatient = false
            creationErrorMessage = "No mesh network connectivity. Unable to create patient offline."
            return
        }
        
        // Send patient creation request via mesh network
        let createMessage = "PingToServer: /createpatient \(jsonString)"
        
        // Notify PingToServerHandler that we're making this request so it can track it
        NotificationCenter.default.post(
            name: NSNotification.Name("BitMedicCreatePatientRequestMade"),
            object: jsonString
        )
        
        viewModel.sendMessage(createMessage)
        
        // Set a timeout for mesh patient creation
        DispatchQueue.main.asyncAfter(deadline: .now() + 15.0) {
            if self.isCreatingPatient {
                self.isCreatingPatient = false
                self.creationErrorMessage = "Patient creation timed out. No response from mesh network."
            }
        }
    }
}