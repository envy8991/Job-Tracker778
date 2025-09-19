import SwiftUI
import PDFKit
import Foundation   // for CharacterSet

// MARK: - Address Helper
/// Returns house number + street name (up to the first street-type word or comma).
private func houseNumberAndStreet(from fullAddress: String) -> String {
    // 1. If there is a comma, everything before it is already just street.
    if let comma = fullAddress.firstIndex(of: ",") {
        return String(fullAddress[..<comma]).trimmingCharacters(in: .whitespaces)
    }
    
    // 2. Otherwise, keep tokens until we hit a known street suffix or run out.
    let suffixes: Set<String> = [
        "st", "street", "rd", "road", "ave", "avenue",
        "blvd", "circle", "cir", "ln", "lane", "dr", "drive",
        "ct", "court", "pkwy", "pl", "place", "ter", "terrace"
    ]
    
    var resultTokens: [Substring] = []
    for token in fullAddress.split(separator: " ") {
        resultTokens.append(token)
        let cleaned = token.trimmingCharacters(in: CharacterSet(charactersIn: ",.")).lowercased()
        if suffixes.contains(cleaned) {
            break   // stop once we've captured the full street name
        }
    }
    return resultTokens.joined(separator: " ")
}

// MARK: - PDFKitView
struct PDFKitView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> PDFView {
        PDFView()
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {
        if let document = PDFDocument(url: url) {
            uiView.document = document
            uiView.autoScales = true   // scale after document is set
        }
    }
}

// MARK: - PDFViewer (wrapper for navigation)
struct PDFViewer: View {
    let url: URL
    
    var body: some View {
        PDFKitView(url: url)
            .navigationTitle("PDF Viewer")
            .navigationBarTitleDisplayMode(.inline)
    }
}
