# Metapanda feedback and polling label fix

User request: use D:\github\mouse as primary; display every polling rate as full numeric Hz and remove delayed UI feedback after DPI clicks.

Bounded fixes in existing flows; use systematic-debugging, TDD and verification-before-completion.

Evidence: passive capture confirms write ACK in about72ms. Existing manual callbacks mutate captured device objects and selected fields instead of publishing the full readback; ApplyDeviceStatus can later replace them with older scans. ReadState unnecessarily reads44 bytes for a two-stage20-byte table.

- [x] Add failing runtime regression for complete UI publication, stale scan isolation, fresh physical changes and consistent full-numeric rate button text.
- [x] Return the confirmed state from setting overloads; publish it once on UI thread and reconcile older scan results by timestamps. Preserve custom names, primary status, endpoint identity and application ownership.
- [x] Read only the required actual DPI table bytes and remove redundant online probe before write; retain ACK matching and readback.
- [x] Use numeric Hz labels and widen the existing main form to fit all six complete labels; unify profile and tray display spacing.
- [x] Build, run focused and relevant regressions, render main form, measure real click-to-confirmation; restore mouse settings.
- [x] Update docs and retain D:\github\mouse\FerrisPulse.exe as the primary program. Retain local branch, no publish.
Verification: native build and13 relevant regressions pass. Main window rendered at606x856 and editor at980x460; full numericHz labels fit. Hardware benchmark four writes/readbacks502/503/503/503ms; UI publication49ms. Baseline restored1600/125. Older scans and late write callbacks cannot undo newer state, and newer physical observations remain accepted. Existing autostart targets primary D:\github\mouse\FerrisPulse.exe. User exited the old outputs process. Started the primary D:\github\mouse\FerrisPulse.exe and verified process path and live accessibility text: all six numeric Hz labels, current1600 DPI/125 Hz. Computer Use click measurement was unavailable (coordinate input geometry unavailable); no GUI-click timing is claimed.

## First-click follow-up correction
- [x] Reproduced the conservative ownership guard returning true for an empty profile service when the scheduler gate is held. The successful manual callback then returned without publishing; earlier publisher-only tests missed this boundary.
- [x] Keep/coalesce confirmed manual callbacks per endpoint; retry on a50ms UI timer while the gate is busy and check actual ownership before publication. Dispose pending timer on form disposal.
- [x] Added test_metapanda_feedback_contention: first click survives lock contention, latest callback wins, actually owned endpoints still yield.
- [x] Native build and14 related tests passed. User exited old primary process; rebuilt and launched D:\github\mouse\FerrisPulse.exe.
- [x] User clicked800 exactly once and confirmed immediate UI update. Accessibility monitoring changed1600->800; capture has one corresponding write/ACK. ACK-to-observed-label814ms includes readback and sampling. Capture stopped; local evidence kept in tools/scratch/capture/first-click-fixed*. No second-click requirement observed in final verification.

## Manual software DPI OSD follow-up
- [x] Root cause: Metapanda manual confirmation published state but never called OnDpiChanged, unlike other brands.
- [x] Add accepted-confirmation-only manual OSD routing, preserving disabled preference and rejecting stale feedback. Reuse existing XY-aware, non-activating OSD.
- [x] Expose ModernSegmentButton standard accessibility Click and Pressed state; disabled actions do nothing.
- [x] Added failing-then-passing OSD and real-button-action regressions; native build and16 related tests passed.
- [x] Restarted primary app after confirming no application profile file. User clarified software stage buttons as scope.
- [x] Automatic input still returned coordinate input geometry unavailable. User clicked800 once and confirmed OSD appeared and button switched; accessibility monitoring observed the corresponding1600->800 label change. No automated desktop-click success is claimed.