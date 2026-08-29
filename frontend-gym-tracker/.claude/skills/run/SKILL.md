---
name: run
description: Launch the GymTracker app in Chrome for manual verification or screenshots. Use whenever asked to run, start, demo, or visually verify the app.
---

# Run GymTracker

Flutter is not on PATH; the Windows desktop target is unavailable (no Visual Studio). Run on Chrome:

```bash
cd /c/github/gym_tracker/frontend-gym-tracker
/c/src/flutter/bin/flutter run -d chrome --web-port 5555
```

- Always pin `--web-port 5555`: IndexedDB (Hive) data is per-origin, so a different port looks like a wiped database.
- This is long-running — launch it in the background and watch output for "Flutter run key commands" to know it's up. Hot reload: send `r` to the process; hot restart: `R`; quit: `q`.
- Headless compile check (no browser, good for CI-style verification): `/c/src/flutter/bin/flutter build web --release`.
- If the app starts on the login screen with no data: that's expected on a fresh origin — register a throwaway account (any non-empty password will do - there are no length or composition rules) and complete onboarding to reach the shell.

Manual smoke route: register → onboarding → Workouts tab (programs + exercise library) → start a program day → complete 2–3 sets and let the rest timer tick → Finish → check History, Progress, Home dashboard → hard-refresh the tab → confirm still signed in and data persisted.
