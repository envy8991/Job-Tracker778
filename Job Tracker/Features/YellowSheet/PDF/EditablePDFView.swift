//
//  EditablePDFView.swift
//  Job Tracker
//
//  Created by Quinton  Thompson  on 2/8/25.
//


import SwiftUI
import PDFKit

struct EditablePDFView: UIViewRepresentable {
    @Binding var pdfDocument: PDFDocument?
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        // Removed: pdfView.allowsEditingAnnotations = true
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = pdfDocument
    }
}
