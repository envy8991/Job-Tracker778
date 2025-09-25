# Authentication

The authentication feature contains the sign-in, sign-up, and password recovery flows along with the shared `AuthViewModel` that coordinates Firebase session state. Once a user is authenticated, the `AppShellView` in the Shared module reads the view model to present the main tab navigation.

## Responsibilities

- Register new technicians with first name, last name, position, email, and password fields via `FirebaseService.signUpUser`.
- Authenticate returning users with email/password credentials and fetch their corresponding `AppUser` profile from Firestore.
- Refresh the current session when the app launches or returns to the foreground by calling `checkAuthState()`.
- Handle password reset requests through `FirebaseService.sendPasswordReset`.
- Support account deletion through `deleteAccount(preserveJobs:)`, which removes the Firebase Auth user while retaining job history.
- Expose convenience flags (`isAdmin`, `isSupervisor`) derived from the current user's profile to gate admin-only functionality.

## Key Types

| Type | Role |
| --- | --- |
| `AuthViewModel` | Observable object published to the environment. Stores the current `AppUser`, `isSignedIn` flag, and role information. |
| `LoginView` | Email/password entry surface with links to sign-up and password reset flows. |
| `SignUpView` | Registration form that validates the input payload before invoking `signUp`. |
| `AuthFlowView` | Wrapper that switches between login and registration flows and presents success/error toasts. |

## Flow Summary

1. **Startup** – `AuthViewModel` instantiates `checkAuthState()` to detect an existing Firebase user. If one exists, `FirebaseService.fetchCurrentUser` populates the view model and transitions to the authenticated shell.
2. **Sign-In** – After credentials are submitted, the view model signs in, fetches the profile, updates `currentUser`, and clears any loading UI.
3. **Sign-Up** – Valid input triggers a call to `signUpUser`. On success the newly created `AppUser` is stored, the session is considered signed in, and the shell is presented.
4. **Password Reset** – The email address is passed to `sendPasswordReset` and the user receives a confirmation toast on success or an error on failure.
5. **Sign-Out / Delete** – `signOut()` clears the current session and returns the app to the login flow. `deleteAccount` deletes the auth record and optionally the profile document while leaving job data intact for auditing.

## Integration Notes

- Wrap `AuthViewModel` in an `@StateObject` at the app entry point (`Job_TrackerApp.swift`) so views see consistent updates.
- Downstream features should observe the view model through `@EnvironmentObject` to react to sign-in state and role changes.
- Ensure Firebase rules restrict access based on the user ID and custom claims that `AuthViewModel` surfaces.
