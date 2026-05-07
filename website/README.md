# Job Tracker Website

This folder contains a standalone browser version of the Job Tracker workspace. It is intentionally dependency-free so the website can be opened directly from `index.html`, served by any static host, or used as a prototype before wiring it to the same Firebase services as the iOS app.

## Files

- `index.html` – semantic page structure for the responsive dashboard, job board, team coordination, compliance checklist, and splice assist prototype.
- `styles.css` – dark glassmorphism design system inspired by the native app's field-operations interface.
- `script.js` – localStorage-backed interactivity for demo job creation, deletion, daily progress metrics, and splice troubleshooting checklist generation.

## Run locally

From the repository root:

```sh
python3 -m http.server 8000 --directory website
```

Then open <http://localhost:8000> in a browser.

## Next integration steps

1. Replace the demo `localStorage` job data in `script.js` with Firestore reads and writes that mirror `FirebaseService` in the iOS target.
2. Add authentication so technicians, supervisors, and admins see role-appropriate sections.
3. Connect document exports to the existing timesheet and yellow sheet PDF generation workflows.
4. Route the splice assist form to the same AI-backed troubleshooting service used by the native app.
