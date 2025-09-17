import UIKit
import PDFKit

private let kHeaderGreen = UIColor(red: 198/255, green: 224/255, blue: 180/255, alpha: 1)   // Excel-style green

class WeeklyTimesheetPDFGenerator {
    let startOfWeek: Date
    let endOfWeek: Date
    let jobs: [Job]
    let currentUserID: String
    let partnerUserID: String?

    let supervisor: String
    let name1: String
    let name2: String

    // Row 1 (user 1)
    let gibsonHours: String
    let cableSouthHours: String
    let totalHours: String

    // Row 2 (user 2) — NEW
    let gibsonHours2: String
    let cableSouthHours2: String
    let totalHours2: String

    // Dictionary of per-day total hours keyed by the day’s start.
    let dailyTotalHours: [Date: String]

    // Define the page size (8.5" x 11")
    private let pageWidth: CGFloat = 612
    private let pageHeight: CGFloat = 792

    init(
        startOfWeek: Date,
        endOfWeek: Date,
        jobs: [Job],
        currentUserID: String,
        partnerUserID: String?,
        supervisor: String,
        name1: String,
        name2: String,
        gibsonHours: String,
        cableSouthHours: String,
        totalHours: String,
        gibsonHours2: String,
        cableSouthHours2: String,
        totalHours2: String,
        dailyTotalHours: [Date: String]
    ) {
        self.startOfWeek = startOfWeek
        self.endOfWeek = endOfWeek
        self.jobs = jobs
        self.currentUserID = currentUserID
        self.partnerUserID = partnerUserID
        self.supervisor = supervisor
        self.name1 = name1
        self.name2 = name2

        self.gibsonHours = gibsonHours
        self.cableSouthHours = cableSouthHours
        self.totalHours = totalHours

        self.gibsonHours2 = gibsonHours2
        self.cableSouthHours2 = cableSouthHours2
        self.totalHours2 = totalHours2

        self.dailyTotalHours = dailyTotalHours
    }

    func generatePDF() -> URL? {
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let data = renderer.pdfData { context in
            context.beginPage()
            let cgContext = context.cgContext

            var currentY: CGFloat = 40
            let margin: CGFloat = 40

            // 1) Draw the header.
            currentY = drawHeader(atY: currentY, margin: margin)

            // 2) Always render a single page in a fixed two-column grid.
            let days = (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: startOfWeek) }
            let colGap: CGFloat = 20
            let colW: CGFloat = (pageWidth - margin * 2 - colGap) / 2
            let boxH: CGFloat = 140  // fixed height so everything fits one page

            var rowY = currentY
            var i = 0
            while i < 7 {
                let leftDate = days[i]
                let leftRect  = CGRect(x: margin, y: rowY, width: colW, height: boxH)
                drawDayBox(leftDate, in: leftRect, context: cgContext)

                if i + 1 < 7 {
                    let rightDate = days[i + 1]
                    let rightRect = CGRect(x: margin + colW + colGap, y: rowY, width: colW, height: boxH)
                    drawDayBox(rightDate, in: rightRect, context: cgContext)
                } else {
                    // Optional: draw an empty box so Saturday lines up with the grid
                    let emptyRect = CGRect(x: margin + colW + colGap, y: rowY, width: colW, height: boxH)
                    cgContext.setStrokeColor(UIColor.darkGray.cgColor)
                    cgContext.setLineWidth(1)
                    cgContext.stroke(emptyRect)
                }

                rowY += (boxH + colGap)
                i += 2
            }
        }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("Timesheet-\(UUID().uuidString).pdf")
        do {
            try data.write(to: tempURL)
            return tempURL
        } catch {
            print("PDF write error:", error)
            return nil
        }
    }
}

extension WeeklyTimesheetPDFGenerator {
    /// Draws the supervisor, names, and Gibson/CS/Total fields for **two users**; returns next Y-offset.
    private func drawHeader(atY startY: CGFloat, margin: CGFloat) -> CGFloat {
        var currentY = startY
        let lineHeight: CGFloat = 18

        // Positions
        let leftX = margin
        let rightX = pageWidth - margin - 240   // right block start
        let colGap: CGFloat = 80

        // Helper to draw a value with an underline-sized box (to mimic Excel blanks)
        func drawLabelValue(_ label: String, value: String, labelWidth: CGFloat = 90, valueWidth: CGFloat = 200) {
            // Label
            drawText(label, at: CGPoint(x: leftX, y: currentY), fontSize: 12, isBold: false)
            // Value text
            drawText(value, at: CGPoint(x: leftX + labelWidth, y: currentY), fontSize: 12, isBold: false)
            // Underline for value area
            if let ctx = UIGraphicsGetCurrentContext() {
                ctx.setStrokeColor(UIColor.black.withAlphaComponent(0.6).cgColor)
                ctx.setLineWidth(0.6)
                let underlineY = currentY + lineHeight - 4
                ctx.move(to: CGPoint(x: leftX + labelWidth, y: underlineY))
                ctx.addLine(to: CGPoint(x: leftX + labelWidth + valueWidth, y: underlineY))
                ctx.strokePath()
            }
            currentY += lineHeight
        }

        // Right-side column headers
        drawText("Gibson",     at: CGPoint(x: rightX,               y: currentY), fontSize: 12, isBold: true)
        drawText("CS Hours",   at: CGPoint(x: rightX + colGap,      y: currentY), fontSize: 12, isBold: true)
        drawText("Total",      at: CGPoint(x: rightX + colGap * 2,  y: currentY), fontSize: 12, isBold: true)
        currentY += lineHeight

        // Left: Supervisor + Names
        drawLabelValue("Supervisor:", value: supervisor)

        // Row 1 (first user)
        drawLabelValue("Name:", value: name1)
        drawText(gibsonHours,     at: CGPoint(x: rightX,              y: currentY - lineHeight), fontSize: 12, isBold: false)
        drawText(cableSouthHours, at: CGPoint(x: rightX + colGap,     y: currentY - lineHeight), fontSize: 12, isBold: false)
        drawText(totalHours,      at: CGPoint(x: rightX + colGap * 2, y: currentY - lineHeight), fontSize: 12, isBold: false)

        // Row 2 (second user) — now filled
        drawLabelValue("Name:", value: name2)
        drawText(gibsonHours2,     at: CGPoint(x: rightX,              y: currentY - lineHeight), fontSize: 12, isBold: false)
        drawText(cableSouthHours2, at: CGPoint(x: rightX + colGap,     y: currentY - lineHeight), fontSize: 12, isBold: false)
        drawText(totalHours2,      at: CGPoint(x: rightX + colGap * 2, y: currentY - lineHeight), fontSize: 12, isBold: false)

        // Row 3 (blank) to mirror the template
        drawLabelValue("Name:", value: "")
        if let ctx = UIGraphicsGetCurrentContext() {
            ctx.setStrokeColor(UIColor.black.withAlphaComponent(0.3).cgColor)
            ctx.setLineWidth(0.5)
            let underlineY = currentY - 4
            ctx.move(to: CGPoint(x: rightX, y: underlineY))
            ctx.addLine(to: CGPoint(x: rightX + 60, y: underlineY))
            ctx.move(to: CGPoint(x: rightX + colGap, y: underlineY))
            ctx.addLine(to: CGPoint(x: rightX + colGap + 60, y: underlineY))
            ctx.move(to: CGPoint(x: rightX + colGap * 2, y: underlineY))
            ctx.addLine(to: CGPoint(x: rightX + colGap * 2 + 60, y: underlineY))
            ctx.strokePath()
        }

        // Small spacer + title
        currentY += 6
        let title = "Gibson Connect Weekly"
        let titleFont = UIFont.boldSystemFont(ofSize: 16)
        let titleWidth = (title as NSString).size(withAttributes: [.font: titleFont]).width
        let titleX = (pageWidth - titleWidth) / 2
        drawText(title, at: CGPoint(x: titleX, y: currentY), fontSize: 16, isBold: true)
        currentY += lineHeight + 12

        return currentY
    }

    /// Draws a single day block exactly like the Excel template.
    private func drawDayBox(_ date: Date, in rect: CGRect, context: CGContext) {
        // Outer border
        context.setStrokeColor(UIColor.darkGray.cgColor)
        context.setLineWidth(1)
        context.stroke(rect)

        // Header (date label)
        let headerHeight: CGFloat = 14
        drawText("\(dayLabelText(date)) Date",
                 in: CGRect(x: rect.minX + 2, y: rect.minY + 1, width: rect.width - 4, height: headerHeight),
                 fontSize: 10, isBold: true)

        // Column header background
        let tableY = rect.minY + headerHeight + 2
        let colHeaderRect = CGRect(x: rect.minX, y: tableY, width: rect.width, height: headerHeight)
        context.setFillColor(kHeaderGreen.cgColor)
        context.fill(colHeaderRect)

        // Column header titles
        let col1W: CGFloat = 50
        let col2W: CGFloat = 40
        drawText("Job #",
                 in: CGRect(x: colHeaderRect.minX + 2, y: colHeaderRect.minY, width: col1W - 4, height: headerHeight),
                 fontSize: 10, isBold: true)
        drawText("Hours",
                 in: CGRect(x: colHeaderRect.minX + col1W + 2, y: colHeaderRect.minY, width: col2W - 4, height: headerHeight),
                 fontSize: 10, isBold: true)
        drawText("Address/Description",
                 in: CGRect(x: colHeaderRect.minX + col1W + col2W + 4, y: colHeaderRect.minY, width: rect.width - col1W - col2W - 8, height: headerHeight),
                 fontSize: 10, isBold: true)

        // Horizontal line under column header
        context.setStrokeColor(UIColor.black.cgColor)
        context.setLineWidth(0.8)
        context.move(to: CGPoint(x: rect.minX, y: colHeaderRect.maxY))
        context.addLine(to: CGPoint(x: rect.maxX, y: colHeaderRect.maxY))
        context.strokePath()

        // Rows: always fit inside the fixed box height by shrinking row height/font if needed.
        var currentY = colHeaderRect.maxY
        let rowsAreaHeight = rect.height - (colHeaderRect.maxY - rect.minY) - 28  // 28 reserved for totals
        let dayJobs = filterJobs(for: date)
        let jobCount = max(1, dayJobs.count)
        let dynamicRowHeight = rowsAreaHeight / CGFloat(jobCount)
        let fontSize = max(6, min(10, dynamicRowHeight - 2))

        // Draw rows
        for job in dayJobs {
            let rowRect = CGRect(x: rect.minX, y: currentY, width: rect.width, height: dynamicRowHeight)
            drawJobRow(job, in: rowRect, fontSize: fontSize)
            currentY += dynamicRowHeight
        }

        // Totals footer
        let totalsStartY = rect.maxY - 28
        let labelWidth: CGFloat = 72
        let valueWidth: CGFloat = 36
        let lineHeight: CGFloat = 14
        let labelRect1 = CGRect(x: rect.minX + 2, y: totalsStartY, width: labelWidth, height: lineHeight)
        let valueRect1 = CGRect(x: labelRect1.maxX + 2, y: totalsStartY, width: valueWidth, height: lineHeight)
        let labelRect2 = CGRect(x: rect.minX + 2, y: totalsStartY + lineHeight, width: labelWidth, height: lineHeight)
        let valueRect2 = CGRect(x: labelRect2.maxX + 2, y: totalsStartY + lineHeight, width: valueWidth, height: lineHeight)

        drawText("Total Hours", in: labelRect1, fontSize: 8, isBold: false)
        let dayKey = Calendar.current.startOfDay(for: date)
        let totalH = dailyTotalHours[dayKey] ?? String(format: "%.1f", filterJobs(for: date).reduce(0.0) { $0 + $1.hours })
        drawText(totalH, in: valueRect1, fontSize: 8, isBold: false)

        drawText("Total Drops", in: labelRect2, fontSize: 8, isBold: false)
        let dropsCount = filterJobs(for: date).count
        drawText("\(dropsCount)", in: valueRect2, fontSize: 8, isBold: false)

        // Box internal vertical lines
        context.setLineWidth(0.8)
        let lineBottom = totalsStartY - 2
        context.move(to: CGPoint(x: rect.minX + 50, y: tableY))
        context.addLine(to: CGPoint(x: rect.minX + 50, y: lineBottom))
        context.move(to: CGPoint(x: rect.minX + 90, y: tableY))
        context.addLine(to: CGPoint(x: rect.minX + 90, y: lineBottom))
        context.strokePath()
    }

    private func drawJobRow(_ job: Job, in rowRect: CGRect, fontSize: CGFloat = 10) {
        let col1Width: CGFloat = 50
        let col2Width: CGFloat = 40

        let jobNum = job.jobNumber ?? ""
        drawText(jobNum,
                 in: CGRect(x: rowRect.minX + 4, y: rowRect.minY, width: col1Width, height: rowRect.height),
                 fontSize: fontSize,
                 isBold: false)

        let hoursX = rowRect.minX + 4 + col1Width + 5
        drawText(String(format: "%.1f", job.hours),
                 in: CGRect(x: hoursX, y: rowRect.minY, width: col2Width, height: rowRect.height),
                 fontSize: fontSize,
                 isBold: false)

        let addrX = hoursX + col2Width + 5
        let addrWidth = rowRect.maxX - addrX - 4
        drawText(job.shortAddress,
                 in: CGRect(x: addrX, y: rowRect.minY, width: addrWidth, height: rowRect.height),
                 fontSize: fontSize,
                 isBold: false)

        // Subtle row separator
        if let ctx = UIGraphicsGetCurrentContext() {
            ctx.setStrokeColor(UIColor.lightGray.cgColor)
            ctx.setLineWidth(0.25)
            ctx.move(to: CGPoint(x: rowRect.minX, y: rowRect.maxY - 0.25))
            ctx.addLine(to: CGPoint(x: rowRect.maxX, y: rowRect.maxY - 0.25))
            ctx.strokePath()
        }
    }

    private func dayLabelText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE MMM d"
        return formatter.string(from: date)
    }

    private func filterJobs(for date: Date) -> [Job] {
        let allowedUserIDs: Set<String> = {
            var ids: Set<String> = []
            if !currentUserID.isEmpty {
                ids.insert(currentUserID)
            }
            if let partner = partnerUserID, !partner.isEmpty {
                ids.insert(partner)
            }
            return ids
        }()

        return jobs.filter { job in
            guard job.status.lowercased() != "pending" else { return false }

            let createdByAllowed = job.createdBy.flatMap { allowedUserIDs.contains($0) } ?? false
            let assignedToAllowed = job.assignedTo.flatMap { allowedUserIDs.contains($0) } ?? false
            guard createdByAllowed || assignedToAllowed else { return false }

            return Calendar.current.isDate(job.date, inSameDayAs: date)
        }
    }

    // Basic text drawing helpers.
    private func drawText(_ text: String, at point: CGPoint, fontSize: CGFloat, isBold: Bool) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byTruncatingTail
        let attributes: [NSAttributedString.Key: Any] = [
            .font: isBold ? UIFont.boldSystemFont(ofSize: fontSize) : UIFont.systemFont(ofSize: fontSize),
            .paragraphStyle: paragraphStyle
        ]
        let textRect = CGRect(origin: point, size: CGSize(width: 500, height: 16))
        (text as NSString).draw(in: textRect, withAttributes: attributes)
    }

    private func drawText(_ text: String, in rect: CGRect, fontSize: CGFloat, isBold: Bool) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byTruncatingTail
        let attributes: [NSAttributedString.Key: Any] = [
            .font: isBold ? UIFont.boldSystemFont(ofSize: fontSize) : UIFont.systemFont(ofSize: fontSize),
            .paragraphStyle: paragraphStyle
        ]
        (text as NSString).draw(in: rect, withAttributes: attributes)
    }
}


// MARK: - Dictionary Key Mapper
extension Dictionary where Key == Date {
    func mapKeys<T>(_ transform: (Date) -> T) -> [T: Value] {
        var dict: [T: Value] = [:]
        for (k, v) in self { dict[transform(k)] = v }
        return dict
    }
}
