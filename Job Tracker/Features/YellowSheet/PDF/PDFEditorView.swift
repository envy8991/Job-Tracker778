//
//  PDFEditorView.swift
//  Job Tracker
//
//  Created by Quinton  Thompson  on 2/8/25.
//


import SwiftUI
import PDFKit
import FirebaseStorage

struct PDFEditorView: View {
    let originalURL: URL
    @State private var pdfDocument: PDFDocument? = nil
    @State private var showSaveAlert = false
    @State private var saveAlertMessage = ""
    
    var body: some View {
        VStack {
            if pdfDocument != nil {
                EditablePDFView(pdfDocument: $pdfDocument)
            } else {
                Text("Loading PDF...")
            }
            Button("Save Changes") {
                saveEditedPDF()
            }
            .padding()
        }
        .onAppear {
            pdfDocument = PDFDocument(url: originalURL)
        }
        .navigationTitle("Edit PDF")
        .alert(isPresented: $showSaveAlert) {
            Alert(title: Text("PDF Save"), message: Text(saveAlertMessage), dismissButton: .default(Text("OK")))
        }
    }
    
    private func saveEditedPDF() {
        guard let doc = pdfDocument else {
            saveAlertMessage = "No document to save."
            showSaveAlert = true
            return
        }
        // Write the modified PDF to a temporary file.
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("EditedYellowSheet-\(UUID().uuidString).pdf")
        if doc.write(to: tempURL) {
            // Upload the edited PDF.
            uploadEditedPDF(from: tempURL)
        } else {
            saveAlertMessage = "Failed to write PDF locally."
            showSaveAlert = true
        }
    }
    
    private func uploadEditedPDF(from url: URL) {
        guard let data = try? Data(contentsOf: url) else {
            saveAlertMessage = "Failed to read edited PDF data."
            showSaveAlert = true
            return
        }
        // For this sample, we generate a random document name.
        let storageRef = Storage.storage().reference().child("yellowSheets/edited_\(UUID().uuidString).pdf")
        storageRef.putData(data, metadata: nil) { metadata, error in
            if let error = error {
                saveAlertMessage = "Error uploading edited PDF: \(error.localizedDescription)"
                showSaveAlert = true
                return
            }
            storageRef.downloadURL { url, error in
                if let error = error {
                    saveAlertMessage = "Error fetching download URL: \(error.localizedDescription)"
                    showSaveAlert = true
                } else if let downloadURL = url {
                    // In a full implementation, update your YellowSheet record with downloadURL.
                    saveAlertMessage = "Edited PDF saved and uploaded successfully!\nURL: \(downloadURL.absoluteString)"
                    showSaveAlert = true
                }
            }
        }
    }
}