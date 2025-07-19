//
// PatientViewModel.swift
// bit-medic
//
// This is free and unencumbered software released into the public domain.
// For more information, see <https://unlicense.org>
//

import Foundation
import SwiftUI
import Combine

class PatientViewModel: ObservableObject {
    @Published var searchQuery: String = "" {
        didSet {
            searchPatients()
        }
    }
    @Published var searchResults: [Patient] = []
    @Published var selectedPatient: Patient? = nil
    @Published var isLoading: Bool = false
    @Published var showAddPatientForm: Bool = false
    @Published var remoteSearchResults: [RemotePatientResult] = []
    @Published var connectedPeers: [String] = []
    @Published var isConnected = false
    
    private let repository = PatientRepository.shared
    private let patientSearchHandler = PatientSearchHandler()
    let meshService = BluetoothMeshService()
    private var cancellables = Set<AnyCancellable>()
    private var searchDelayTimer: Timer?
    
    init() {
        setupBindings()
        setupMeshService()
        loadInitialData()
    }
    
    private func setupBindings() {
        repository.$patients
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.searchPatients()
            }
            .store(in: &cancellables)
    }
    
    private func setupMeshService() {
        // Set up patient search handler with reference to this view model
        patientSearchHandler.patientViewModel = self
        
        // Set up mesh service delegate
        meshService.delegate = self
        
        // Start mesh service
        meshService.startServices()
    }
    
    private func loadInitialData() {
        searchPatients()
    }
    
    private func searchPatients() {
        isLoading = true
        
        // Cancel any existing timer
        searchDelayTimer?.invalidate()
        
        // Local search (immediate)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let results = self.repository.searchPatients(query: self.searchQuery)
            
            DispatchQueue.main.async {
                self.searchResults = results
                self.isLoading = false
            }
        }
        
        // Remote search (with delay to avoid spam)
        if !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            searchDelayTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
                self?.broadcastSearchQuery()
            }
        } else {
            // Clear remote results when search is empty
            remoteSearchResults.removeAll()
        }
    }
    
    private func broadcastSearchQuery() {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        
        print("Broadcasting patient search query: '\(query)'")
        patientSearchHandler.sendSearchQuery(query)
    }
    
    func selectPatient(_ patient: Patient) {
        selectedPatient = patient
    }
    
    func clearSelection() {
        selectedPatient = nil
    }
    
    func addPatient(_ patient: Patient) {
        repository.addPatient(patient)
    }
    
    func updatePatient(_ patient: Patient) {
        repository.updatePatient(patient)
        if selectedPatient?.id == patient.id {
            selectedPatient = patient
        }
    }
    
    func deletePatient(_ patient: Patient) {
        repository.deletePatient(withId: patient.id)
        if selectedPatient?.id == patient.id {
            selectedPatient = nil
        }
    }
    
    func clearSearch() {
        searchQuery = ""
    }
    
    var hasSearchQuery: Bool {
        !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var searchResultsCount: Int {
        searchResults.count
    }
    
    var displayMessage: String {
        let localCount = searchResults.count
        let remoteCount = remoteSearchResults.reduce(0) { $0 + $1.patients.count }
        let totalCount = localCount + remoteCount
        
        if hasSearchQuery {
            if totalCount == 0 {
                return "No patients found for '\(searchQuery)'"
            } else {
                var message = "\(localCount) local patient\(localCount == 1 ? "" : "s")"
                if remoteCount > 0 {
                    message += ", \(remoteCount) from \(remoteSearchResults.count) peer\(remoteSearchResults.count == 1 ? "" : "s")"
                }
                return message
            }
        } else {
            if localCount == 0 {
                return "No patients in local database"
            } else {
                return "\(localCount) patient\(localCount == 1 ? "" : "s") in local database"
            }
        }
    }
    
    // MARK: - Mesh Service Integration
    
    func sendBluetoothMessage(_ message: String) {
        meshService.sendMessage(message)
    }
    
    func handleRemotePatients(_ patients: [Patient], fromPeer peerNickname: String) {
        // Update or add remote search results
        if let existingIndex = remoteSearchResults.firstIndex(where: { $0.peerNickname == peerNickname }) {
            remoteSearchResults[existingIndex] = RemotePatientResult(
                peerNickname: peerNickname,
                patients: patients,
                timestamp: Date()
            )
        } else {
            remoteSearchResults.append(RemotePatientResult(
                peerNickname: peerNickname,
                patients: patients,
                timestamp: Date()
            ))
        }
        
        print("Received \(patients.count) patients from peer '\(peerNickname)'")
    }
    
    func clearRemoteResults() {
        remoteSearchResults.removeAll()
    }
    
    var allSearchResults: [PatientSearchResultSection] {
        var sections: [PatientSearchResultSection] = []
        
        // Local results section
        if !searchResults.isEmpty {
            sections.append(PatientSearchResultSection(
                title: "Local Database",
                patients: searchResults,
                isLocal: true
            ))
        }
        
        // Remote results sections
        for remoteResult in remoteSearchResults.sorted(by: { $0.timestamp > $1.timestamp }) {
            if !remoteResult.patients.isEmpty {
                sections.append(PatientSearchResultSection(
                    title: "From \(remoteResult.peerNickname)",
                    patients: remoteResult.patients,
                    isLocal: false
                ))
            }
        }
        
        return sections
    }
}

// MARK: - BluetoothMeshService Delegate
extension PatientViewModel: BitchatDelegate {
    func didReceiveMessage(_ message: BitchatMessage) {
        // Pass all messages to the patient search handler
        patientSearchHandler.handleIncomingBluetoothMessage(message.content)
    }
    
    func didConnectToPeer(_ peerID: String) {
        // Handle peer connection
        print("Connected to peer: \(peerID)")
    }
    
    func didDisconnectFromPeer(_ peerID: String) {
        // Handle peer disconnection
        print("Disconnected from peer: \(peerID)")
    }
    
    func didUpdatePeerList(_ peers: [String]) {
        DispatchQueue.main.async {
            self.connectedPeers = peers
            self.isConnected = !peers.isEmpty
        }
    }
}

// MARK: - Data Structures
struct RemotePatientResult {
    let peerNickname: String
    let patients: [Patient]
    let timestamp: Date
}

struct PatientSearchResultSection {
    let title: String
    let patients: [Patient]
    let isLocal: Bool
}