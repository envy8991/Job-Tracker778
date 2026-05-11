# Job Tracker Website

This folder contains a standalone, dependency-free browser version of the Job Tracker iOS app shell. The top-level website now follows the native app's five primary tabs instead of placing every workflow on one long page.

## Files

- `index.html` – semantic tabbed structure for Dashboard, Timesheets, Yellow Sheet, Job Search, and More.
- `styles.css` – dark glassmorphism design system with a fixed bottom tab bar that mirrors the iOS navigation model.
- `script.js` – localStorage-backed demo interactivity for jobs, weekly timesheets, yellow sheets, search, and tab routing.

## Run locally

From the repository root:

```sh
python3 -m http.server 8000 --directory website
```

Then open <http://localhost:8000> in a browser.

## Parity notes

- The primary navigation matches the iOS app: Dashboard, Timesheets, Yellow Sheet, Job Search, and More.
- Dashboard content is limited to the selected day's job workflow.
- Timesheet and Yellow Sheet content are separated into their own tabs.
- Additional native sections such as Profile, Settings, Find a Partner, Recent Crew Jobs, Route Mapper, Splice Assist, and Help Center are grouped under More instead of appearing on the Dashboard.
