//
// PatientRepository.swift
// bit-medic
//
// This is free and unencumbered software released into the public domain.
// For more information, see <https://unlicense.org>
//

import Foundation
import Combine

class PatientRepository: ObservableObject {
    @Published private(set) var patients: [Patient] = []
    
    private let userDefaults = UserDefaults.standard
    private let patientsKey = "bit-medic.patients"
    
    static let shared = PatientRepository()
    
    private init() {
        loadPatients()
    }
    
    func loadPatients() {
        if let data = userDefaults.data(forKey: patientsKey),
           let decodedPatients = try? JSONDecoder().decode([Patient].self, from: data) {
            self.patients = decodedPatients
        } else {
            self.patients = Patient.samplePatients
            savePatients()
        }
    }
    
    private func savePatients() {
        if let data = try? JSONEncoder().encode(patients) {
            userDefaults.set(data, forKey: patientsKey)
        }
    }
    
    func addPatient(_ patient: Patient) {
        patients.append(patient)
        savePatients()
    }
    
    func updatePatient(_ patient: Patient) {
        if let index = patients.firstIndex(where: { $0.id == patient.id }) {
            var updatedPatient = patient
            updatedPatient.updateLastModified()
            patients[index] = updatedPatient
            savePatients()
        }
    }
    
    func deletePatient(withId id: UUID) {
        patients.removeAll { $0.id == id }
        savePatients()
    }
    
    func searchPatients(query: String) -> [Patient] {
        guard !query.isEmpty else { return patients }
        
        let lowercaseQuery = query.lowercased()
        return patients.filter { patient in
            patient.name.lowercased().contains(lowercaseQuery) ||
            patient.phoneNumber?.contains(query) == true ||
            patient.email?.lowercased().contains(lowercaseQuery) == true ||
            patient.medicalConditions.contains { $0.lowercased().contains(lowercaseQuery) } ||
            patient.medications.contains { $0.lowercased().contains(lowercaseQuery) } ||
            patient.allergies.contains { $0.lowercased().contains(lowercaseQuery) }
        }
    }
    
    func getPatient(byId id: UUID) -> Patient? {
        return patients.first { $0.id == id }
    }
    
    func clearAllPatients() {
        patients.removeAll()
        savePatients()
    }
}