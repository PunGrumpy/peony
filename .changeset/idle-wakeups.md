---
"@peony/macos": patch
---

Peony uses less CPU and battery. It hears about network changes from macOS instead of checking every two seconds, stops waking for reachability checks that already finished, and no longer freezes the menu bar while it checks the helper. The log window keeps following new output after its first 500 lines.
