# Meta Glasses Pilot

The Meta Glasses Pilot screen is a planning and prototype surface for evaluating how Meta's Wearables Device Access Toolkit could improve Job Tracker field workflows before the production SDK is enabled for technicians.

## User Benefits

- **Less phone handling** – Technicians can keep gloves on and keep working while capturing pole tags, splice trays, and before/after proof.
- **Cleaner job records** – Point-of-view photos or clips can be linked to the active job immediately instead of being found and uploaded later.
- **Faster assist requests** – A glasses capture can become context for Splice Assist or supervisor review without asking the technician to re-frame the issue on a phone.
- **Safer audio prompts** – Route updates, safety reminders, and checklist steps can be played through glasses speakers while the phone stays pocketed.

## Implemented App Surface

`MetaGlassesPilotView` now includes three practical pilot areas:

1. **Benefits review** – Summarizes the user-facing value of using camera, microphone, and speaker features in Job Tracker.
2. **Prototype workflow picker** – Lets stakeholders compare the first workflows worth piloting: job photo capture, Live Splice Assist, voice timesheet notes, and audio prompts.
3. **Readiness checklist** – Tracks whether glasses are paired, an active job is linked, and camera/microphone consent is confirmed before running a controlled field pilot.

## Rollout Notes

- Keep the feature behind an internal pilot or release-channel flag until the Meta developer project and field policy are approved.
- Require explicit consent before any camera, microphone, or speaker use.
- Start with job photo capture because it has a high user benefit and can reuse the existing job attachment workflow.
- Treat streaming into Splice Assist as the second milestone after still-image capture is reliable.
