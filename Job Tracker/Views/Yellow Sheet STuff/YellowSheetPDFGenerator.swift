import SwiftUI
import PDFKit
import UIKit

class YellowSheetPDFGenerator {
    let weekStart: Date
    let jobs: [Job]
    let user: AppUser

    // Define page dimensions (8.5" x 11" in points)
    private let pageWidth: CGFloat = 612
    private let pageHeight: CGFloat = 792

    init(weekStart: Date, jobs: [Job], user: AppUser) {
        self.weekStart = weekStart
        self.jobs = jobs
        self.user = user
    }

    func generatePDF() -> URL? {
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        
        let data = renderer.pdfData { context in
            context.beginPage()
            let cgContext = context.cgContext
            
            var currentY: CGFloat = 20
            let margin: CGFloat = 20
            
            // 1) Draw the header.
            let headerText = "Yellow Sheet for Week Starting: \(formattedDate(weekStart))"
            drawText(headerText, at: CGPoint(x: margin, y: currentY), fontSize: 16, isBold: true)
            currentY += 30
            
            let userText = "User: \(user.firstName) \(user.lastName)    Position: \(user.position)"
            drawText(userText, at: CGPoint(x: margin, y: currentY), fontSize: 14, isBold: false)
            currentY += 25
            
            // Draw a separator line.
            cgContext.setStrokeColor(UIColor.gray.cgColor)
            cgContext.setLineWidth(1)
            cgContext.move(to: CGPoint(x: margin, y: currentY))
            cgContext.addLine(to: CGPoint(x: pageWidth - margin, y: currentY))
            cgContext.strokePath()
            currentY += 15
            
            // 2) Draw the list of jobs.
            let lineHeight: CGFloat = 16
            for job in jobs {
                var lines: [String] = []
                lines.append("Address: \(job.address)")
                lines.append("Job Number: \(job.jobNumber ?? "N/A")")
                lines.append("Status: \(job.status)")
                
                if let nid = job.nidFootage, !nid.isEmpty {
                    lines.append("NID Footage: \(nid)")
                }
                if let can = job.canFootage, !can.isEmpty {
                    lines.append("CAN Footage: \(can)")
                }
                if (job.nidFootage == nil || job.nidFootage!.isEmpty) &&
                   (job.canFootage == nil || job.canFootage!.isEmpty) {
                    lines.append("Footages: N/A")
                }
                if let materials = job.materialsUsed, !materials.isEmpty {
                    lines.append("Materials: \(materials)")
                }
                
                for line in lines {
                    drawText(line, at: CGPoint(x: margin, y: currentY), fontSize: 10, isBold: false)
                    currentY += lineHeight
                }
                
                currentY += 10  // Spacing between jobs.
                
                if currentY > pageHeight - margin - 50 {
                    context.beginPage()
                    currentY = margin
                }
            }
        }
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("YellowSheet-\(UUID().uuidString).pdf")
        do {
            try data.write(to: tempURL)
            return tempURL
        } catch {
            print("Error writing PDF data: \(error)")
            return nil
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func drawText(_ text: String, at point: CGPoint, fontSize: CGFloat, isBold: Bool) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        let font = isBold ? UIFont.boldSystemFont(ofSize: fontSize) : UIFont.systemFont(ofSize: fontSize)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle
        ]
        let textRect = CGRect(x: point.x, y: point.y, width: pageWidth - 2 * 20, height: 1000)
        (text as NSString).draw(in: textRect, withAttributes: attributes)
    }
}
