//
// PatientSearchHandler.swift
// bit-medic
//
// This is free and unencumbered software released into the public domain.
// For more information, see <https://unlicense.org>
//

import Foundation

class PatientSearchHandler {
    weak var patientViewModel: PatientViewModel?
    private let repository = PatientRepository.shared
    
    // Message prefixes for different operations
    private let searchQueryPrefix = "PatientSearch:"
    private let searchResponsePrefix = "PatientSearchResponse:"
    
    init() {}
    
    // MARK: - Main Message Handler
    func handleIncomingBluetoothMessage(_ message: String) {
        // Handle search queries from other devices
        if message.hasPrefix(searchQueryPrefix) {
            handleSearchQuery(message)
        }
        // Handle search responses from other devices
        else if message.hasPrefix(searchResponsePrefix) {
            handleSearchResponse(message)
        }
    }
    
    // MARK: - Search Query Handling
    private func handleSearchQuery(_ message: String) {
        // Extract the search query after the prefix
        let query = String(message.dropFirst(searchQueryPrefix.count))
        
        print("Received patient search query: '\(query)'")
        
        // Search our local patient database
        let matchingPatients = repository.searchPatients(query: query)
        
        // If we have matching patients, send them back
        if !matchingPatients.isEmpty {
            sendSearchResponse(patients: matchingPatients, originalQuery: query)
        }
    }
    
    // MARK: - Search Response Handling
    private func handleSearchResponse(_ message: String) {
        // Extract the response data after the prefix
        let responseData = String(message.dropFirst(searchResponsePrefix.count))
        
        print("Received patient search response: \(responseData)")
        
        // Parse the JSON response
        guard let jsonData = responseData.data(using: .utf8),
              let response = try? JSONDecoder().decode(PatientSearchResponse.self, from: jsonData) else {
            print("Failed to parse patient search response")
            return
        }
        
        // Update the patient view model with the received patients
        DispatchQueue.main.async { [weak self] in
            self?.patientViewModel?.handleRemotePatients(response.patients, fromPeer: response.senderNickname)
        }
    }
    
    // MARK: - Send Search Response
    private func sendSearchResponse(patients: [Patient], originalQuery: String) {
        // Create response object
        let response = PatientSearchResponse(
            senderNickname: getCurrentDeviceNickname(),
            originalQuery: originalQuery,
            patients: patients,
            timestamp: Date()
        )
        
        // Encode to JSON
        guard let jsonData = try? JSONEncoder().encode(response),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            print("Failed to encode patient search response")
            return
        }
        
        // Send response with prefix
        let fullMessage = searchResponsePrefix + jsonString
        sendBluetoothMessage(fullMessage)
        
        print("Sent patient search response with \(patients.count) patients for query '\(originalQuery)'")
    }
    
    // MARK: - Send Search Query
    func sendSearchQuery(_ query: String) {
        let fullMessage = searchQueryPrefix + query
        sendBluetoothMessage(fullMessage)
        
        print("Broadcast patient search query: '\(query)'")
    }
    
    // MARK: - Helper Methods
    private func sendBluetoothMessage(_ message: String) {
        // This will be called through the PatientViewModel's mesh service
        patientViewModel?.sendBluetoothMessage(message)
    }
    
    private func getCurrentDeviceNickname() -> String {
        // Get the current device nickname from stored preferences
        return UserDefaults.standard.string(forKey: "bitchat.nickname") ?? "Unknown Device"
    }
}

// MARK: - Data Structures
struct PatientSearchResponse: Codable {
    let senderNickname: String
    let originalQuery: String
    let patients: [Patient]
    let timestamp: Date
}

// MARK: - Patient Extension for Network Transfer
extension Patient {
    // Create a lighter version for network transfer (excluding sensitive data if needed)
    var networkSafeVersion: Patient {
        var copy = self
        // You might want to exclude or redact sensitive information here
        // For now, we'll send all data, but you could filter based on privacy requirements
        return copy
    }
}