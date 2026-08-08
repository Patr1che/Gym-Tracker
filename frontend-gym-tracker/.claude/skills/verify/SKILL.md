---
name: verify
description: Run the full GymTracker verification suite (analyze, tests, release web build). Use after completing any feature or refactor, and before declaring work done.
---

# Verify GymTracker

Run all three, in order, from `/c/github/gym_tracker/frontend-gym-tracker` (Flutter is not on PATH):

```bash
/c/src/flutter/bin/flutter analyze                 # must be 0 issues
/c/src/flutter/bin/flutter test                    # all tests green, headless
/c/src/flutter/bin/flutter build web --release     # proves the whole app compiles for the real target
```

- `flutter analyze` warnings count as failures — fix them, don't suppress with `// ignore:` unless there is a documented reason.
- A single test file: `/c/src/flutter/bin/flutter test test/core/domain/pr_detector_test.dart`
- If tests fail with Hive errors, check the test used `Hive.init(<temp dir>)` in `setUp` and closed/deleted boxes in `tearDown` — box state leaks between tests.
- The web build emits to `build/web/`; occasional font tree-shaking notes are normal, real errors are not.
- For visual confirmation after all three pass, use the `run` skill.
