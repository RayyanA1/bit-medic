//
// Patient.swift
// bit-medic
//
// This is free and unencumbered software released into the public domain.
// For more information, see <https://unlicense.org>
//

import Foundation

struct Patient: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var dateOfBirth: Date?
    var phoneNumber: String?
    var email: String?
    var address: String?
    var emergencyContact: String?
    var emergencyContactPhone: String?
    var medicalConditions: [String]
    var medications: [String]
    var allergies: [String]
    var notes: String?
    let createdAt: Date
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        dateOfBirth: Date? = nil,
        phoneNumber: String? = nil,
        email: String? = nil,
        address: String? = nil,
        emergencyContact: String? = nil,
        emergencyContactPhone: String? = nil,
        medicalConditions: [String] = [],
        medications: [String] = [],
        allergies: [String] = [],
        notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.dateOfBirth = dateOfBirth
        self.phoneNumber = phoneNumber
        self.email = email
        self.address = address
        self.emergencyContact = emergencyContact
        self.emergencyContactPhone = emergencyContactPhone
        self.medicalConditions = medicalConditions
        self.medications = medications
        self.allergies = allergies
        self.notes = notes
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    var displayName: String {
        return name.isEmpty ? "Unnamed Patient" : name
    }
    
    var age: Int? {
        guard let dateOfBirth = dateOfBirth else { return nil }
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: dateOfBirth, to: Date())
        return ageComponents.year
    }
    
    mutating func updateLastModified() {
        updatedAt = Date()
    }
}

extension Patient {
    static let samplePatients: [Patient] = [
        Patient(
            name: "John Doe",
            dateOfBirth: Calendar.current.date(byAdding: .year, value: -35, to: Date()),
            phoneNumber: "(555) 123-4567",
            email: "john.doe@email.com",
            medicalConditions: ["Hypertension", "Type 2 Diabetes"],
            medications: ["Metformin", "Lisinopril"],
            allergies: ["Penicillin"]
        ),
        Patient(
            name: "Jane Smith",
            dateOfBirth: Calendar.current.date(byAdding: .year, value: -28, to: Date()),
            phoneNumber: "(555) 987-6543",
            email: "jane.smith@email.com",
            medicalConditions: ["Asthma"],
            medications: ["Albuterol"],
            allergies: ["Shellfish", "Latex"]
        ),
        Patient(
            name: "Robert Johnson",
            dateOfBirth: Calendar.current.date(byAdding: .year, value: -52, to: Date()),
            phoneNumber: "(555) 456-7890",
            medicalConditions: ["High Cholesterol"],
            medications: ["Atorvastatin"],
            allergies: []
        )
    ]
}