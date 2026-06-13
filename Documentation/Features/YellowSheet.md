# Yellow Sheet

Yellow sheets capture daily compliance checklists and signatures that complement the timesheet workflow. This module reuses many of the timesheet patterns while tailoring the experience to the yellow sheet document format.

## Responsibilities

- Fetch and display yellow sheet records for the signed-in technician using `UserYellowSheetsViewModel`.
- Provide form-driven entry for daily safety checks, job notes, and material usage via `YellowSheetView`.
- Allow supervisors to review previous submissions through `PastYellowSheetsView`.
- Generate PDFs using `YellowSheetPDFGenerator`, including editable overlays for signatures and corrections.
- Offer in-app PDF viewing and annotation through `EditablePDFView` and `PDFViewer`.

## Key Types

| Type | Role |
| --- | --- |
| `YellowSheet` | Firestore model storing metadata, completion status, and generated PDF URLs. |
| `UserYellowSheetsViewModel` | Coordinates Firestore listeners and exposes the current user's yellow sheets. |
| `YellowSheetView` | Main editing surface for the active day. Integrates photo attachments and checklists. |
| `YellowSheetDetailView` | Expanded view for reviewing submissions, downloading PDFs, or resending to supervisors. |
| `YellowSheetPDFGenerator` | Renders SwiftUI content into PDFs. Shares PDF utilities with the timesheet module. |
| `EditablePDFView` | Hosts PDFKit annotations for signatures or corrections before exporting. |

## Workflow

1. **Loading** – The user view model listens for documents filtered by user ID and date, updating the UI in real time as submissions change.
2. **Editing** – Technicians complete checklist items, add notes, and attach supporting images. Changes are saved back to Firestore via `FirebaseService` helpers.
3. **PDF Export** – Users generate a PDF for supervisor sign-off. The generator saves the file locally and optionally uploads it for sharing.
4. **Review** – Supervisors can open past entries, view the PDF inline, and trigger exports or edits if corrections are needed.

## Integration Notes

- Yellow sheets often link to specific jobs. Keep job metadata handy so forms can pre-populate addresses or partner info.
- Ensure Storage rules allow technicians to upload PDF exports while preventing cross-user access.
- When altering the PDF layout, update both the generator and any tests that verify PDF metadata or file generation.
