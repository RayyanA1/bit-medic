import Foundation
import Network

class PingToServerHandler {
    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")
    private var isConnectedToInternet = false
    private let serverURL: String = "https://jsonplaceholder.typicode.com/posts"
    private var activeSearchRequests: Set<String> = []  // Track search requests this device made
    private var currentSearchTerm: String?  // Track the most recent search term
    private var activeAPITask: URLSessionDataTask?  // Track active API request for cancellation
    
    weak var chatViewModel: ChatViewModel?
    
    init() {
        startNetworkMonitoring()
        setupNotificationObservers()
    }
    
    deinit {
        networkMonitor.cancel()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Notification Observers
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSearchRequestMade(_:)),
            name: NSNotification.Name("BitMedicSearchRequestMade"),
            object: nil
        )
    }
    
    @objc private func handleSearchRequestMade(_ notification: Notification) {
        if let searchTerm = notification.object as? String {
            // Cancel any previous search requests
            cancelPreviousSearchRequests()
            
            // Set this as the current search term
            currentSearchTerm = searchTerm
            activeSearchRequests.insert(searchTerm)
        }
    }
    
    private func cancelPreviousSearchRequests() {
        // Cancel any active API request
        activeAPITask?.cancel()
        activeAPITask = nil
        
        // Clear previous search requests except the current one
        if let current = currentSearchTerm {
            activeSearchRequests.removeAll()
            activeSearchRequests.insert(current)
        } else {
            activeSearchRequests.removeAll()
        }
    }
    
    // MARK: - Network Monitoring
    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            self?.isConnectedToInternet = path.status == .satisfied
            print("Internet connection status: \(path.status == .satisfied ? "Available" : "Unavailable")")
        }
        networkMonitor.start(queue: monitorQueue)
    }
    
    // MARK: - Main Message Handler
    func handleIncomingBluetoothMessage(_ message: String) {
        let prefix = "PingToServer:"
        
        // Check if message starts with the required prefix
        guard message.hasPrefix(prefix) else {
            // Check if this is a search response (Results: prefix)
            if message.hasPrefix("Results: ") {
                // Extract the original search term from the response to check if we made this request
                let responseContent = String(message.dropFirst("Results: ".count))
                
                // Try to determine if this response is for a search this device initiated
                var isMyRequest = false
                
                // Only process if this response is for the current search term
                if let currentTerm = currentSearchTerm {
                    if responseContent.contains("\"name\"") || responseContent.lowercased().contains(currentTerm) {
                        // This response matches our current search term
                        isMyRequest = true
                        activeSearchRequests.remove(currentTerm)
                        currentSearchTerm = nil  // Clear current search term after processing
                    }
                }
                
                // Only process the response if this device made the original request
                if isMyRequest {
                    // This is a search response received via mesh network for a request we made
                    // Notify the BitMedic UI directly
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("BitMedicSearchResponse"),
                            object: BitchatMessage(
                                sender: "system",
                                content: message,
                                timestamp: Date(),
                                isRelay: false,
                                isPrivate: false
                            )
                        )
                    }
                }
            }
            return // Not a ping-to-server message, ignore
        }
        
        // Extract the actual message after the prefix
        let extractedMessage = String(message.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("Received PingToServer message: \(extractedMessage)")
        
        // Handle BitMedic search queries specially
        if extractedMessage.hasPrefix("/search?q=") {
            // Extract search term to track this request
            let queryPrefix = "/search?q="
            let searchTerm = String(extractedMessage.dropFirst(queryPrefix.count))
                .removingPercentEncoding ?? ""
            
            // Cancel any previous search requests
            cancelPreviousSearchRequests()
            
            // Set this as the current search term and add to active requests
            currentSearchTerm = searchTerm.lowercased()
            activeSearchRequests.insert(searchTerm.lowercased())
            
            handleBitMedicSearch(extractedMessage)
            return
        }
        
        // Check internet connectivity for other requests
        guard isConnectedToInternet else {
            print("No internet connection available. Cannot forward message to server.")
            return
        }
        
        // Send to server
        sendMessageToServer(extractedMessage)
    }
    
    // MARK: - HTTP Request
    private func sendMessageToServer(_ message: String) {
        guard let url = URL(string: serverURL) else {
            print("Invalid server URL")
            showFeedbackMessage("Invalid server URL: \(serverURL)")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Validate that the message is valid JSON
        guard let jsonData = message.data(using: .utf8) else {
            print("Failed to convert message to data")
            showFeedbackMessage("Failed to convert message to data")
            return
        }
        
        // Validate JSON format
        do {
            _ = try JSONSerialization.jsonObject(with: jsonData, options: [])
        } catch {
            print("Invalid JSON format: \(error.localizedDescription)")
            showFeedbackMessage("Invalid JSON format: \(error.localizedDescription)")
            return
        }
        
        // Send the raw JSON directly
        request.httpBody = jsonData
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.handleServerResponse(data: data, response: response, error: error, originalMessage: message)
            }
        }
        
        task.resume()
        print("Sending JSON to server: \(message)")
    }
    
    // MARK: - User Feedback
    private func showFeedbackMessage(_ message: String) {
        guard let chatViewModel = chatViewModel else { return }
        
        DispatchQueue.main.async {
            // Add to local messages for visibility
            let systemMessage = BitchatMessage(
                sender: "system",
                content: message,
                timestamp: Date(),
                isRelay: false,
                isPrivate: false
            )
            chatViewModel.messages.append(systemMessage)
            
            // Send response back through the mesh network
            chatViewModel.sendMessage(message)
        }
    }
    
    // MARK: - Response Handling
    private func handleServerResponse(data: Data?, response: URLResponse?, error: Error?, originalMessage: String) {
        if let error = error {
            print("Network error while sending message '\(originalMessage)': \(error.localizedDescription)")
            showFeedbackMessage("Failed to send message to server: \(error.localizedDescription)")
            return
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("Invalid response type for message '\(originalMessage)'")
            showFeedbackMessage("Invalid server response for message '\(originalMessage)'")
            return
        }
        
        let statusCode = httpResponse.statusCode
        
        if 200...299 ~= statusCode {
            print("Successfully sent JSON to server. Status code: \(statusCode)")
            
            // Show the raw JSON that was sent
            showFeedbackMessage("Server sent message to URL \(serverURL) with payload \(originalMessage)")
            
            // Optionally log response data
            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                print("Server response: \(responseString)")
                showFeedbackMessage("Server response: \(responseString)")
            }
        } else {
            print("Server returned error status \(statusCode) for message '\(originalMessage)'")
            showFeedbackMessage("Server error \(statusCode) for message '\(originalMessage)'")
            
            if let data = data, let errorString = String(data: data, encoding: .utf8) {
                print("Error response: \(errorString)")
            }
        }
    }
    
    // MARK: - BitMedic Search Handler
    private func handleBitMedicSearch(_ searchQuery: String) {
        // Extract search term from "/search?q=term" format
        let queryPrefix = "/search?q="
        guard searchQuery.hasPrefix(queryPrefix) else { return }
        
        let searchTerm = String(searchQuery.dropFirst(queryPrefix.count))
            .removingPercentEncoding ?? ""
        
        print("BitMedic search query: \(searchTerm)")
        
        // Call real API
        searchPatients(searchTerm: searchTerm)
    }
    
    private func searchPatients(searchTerm: String) {
        guard !searchTerm.isEmpty else {
            showSearchResponse("Results: Please enter a patient name to search")
            return
        }
        
        // URL encode the search term for query parameter
        guard let encodedSearchTerm = searchTerm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://partialsearchusingpatientname-uob3euoulq-uc.a.run.app/?name=\(encodedSearchTerm)") else {
            showSearchResponse("Results: Invalid search term")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        print("Calling patient search API with GET: \(url)")
        showFeedbackMessage("API Call: GET \(url)")
        
        // Cancel any previous API request
        activeAPITask?.cancel()
        
        activeAPITask = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let strongSelf = self else { return }
                
                // Only process if this is still the current search term
                if strongSelf.currentSearchTerm == searchTerm.lowercased() {
                    strongSelf.handlePatientSearchResponse(data: data, response: response, error: error, searchTerm: searchTerm)
                }
                // Clear the task reference
                strongSelf.activeAPITask = nil
            }
        }
        
        activeAPITask?.resume()
    }
    
    private func handlePatientSearchResponse(data: Data?, response: URLResponse?, error: Error?, searchTerm: String) {
        if let error = error {
            print("Patient search API error: \(error.localizedDescription)")
            showFeedbackMessage("API Error: \(error.localizedDescription)")
            showSearchResponse("Results: Search failed - \(error.localizedDescription)")
            return
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            showFeedbackMessage("API Response: Invalid response type")
            showSearchResponse("Results: Invalid server response")
            return
        }
        
        showFeedbackMessage("API Response: HTTP \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            showSearchResponse("Results: Server error (\(httpResponse.statusCode))")
            return
        }
        
        guard let data = data else {
            showSearchResponse("Results: No data received from server")
            return
        }
        
        do {
            // Try to parse as JSON array first
            if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                showFeedbackMessage("API Success: Found \(jsonArray.count) patients")
                handlePatientJSONResponse(jsonArray, searchTerm: searchTerm)
            } else {
                // Fall back to plain text response
                let responseText = String(data: data, encoding: .utf8) ?? "Unable to decode response"
                showFeedbackMessage("API Response: Non-JSON data received")
                showSearchResponse("Results: \(responseText)")
            }
        } catch {
            // If JSON parsing fails, treat as plain text
            let responseText = String(data: data, encoding: .utf8) ?? "Unable to decode response"
            showFeedbackMessage("API Response: JSON parse failed - \(error.localizedDescription)")
            showSearchResponse("Results: \(responseText)")
        }
    }
    
    private func handlePatientJSONResponse(_ patients: [[String: Any]], searchTerm: String) {
        if patients.isEmpty {
            showSearchResponse("Results: No patients found for '\(searchTerm)'")
            return
        }
        
        // Return the raw JSON for typeahead functionality
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: Array(patients.prefix(5)))
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                showSearchResponse("Results: \(jsonString)")
            } else {
                // Fallback to text format
                let patientList = patients.prefix(5).compactMap { patient in
                    patient["name"] as? String
                }
                let responseMessage = "Results: " + patientList.joined(separator: " | ")
                showSearchResponse(responseMessage)
            }
        } catch {
            // Fallback to text format
            let patientList = patients.prefix(5).compactMap { patient in
                patient["name"] as? String
            }
            let responseMessage = "Results: " + patientList.joined(separator: " | ")
            showSearchResponse(responseMessage)
        }
    }
    
    private func showSearchResponse(_ message: String) {
        // Send response back through the mesh network
        showFeedbackMessage(message)
        
        // Also notify the BitMedic UI
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name("BitMedicSearchResponse"),
                object: BitchatMessage(
                    sender: "system",
                    content: message,
                    timestamp: Date(),
                    isRelay: false,
                    isPrivate: false
                )
            )
        }
    }
}