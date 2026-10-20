# Metapanda 4K and Flexible DPI Implementation Plan

> For agentic workers: execute inline with superpowers:executing-plans. Steps use checkboxes.

**Goal:** Support the captured F5AC 4K receiver, six polling rates, and per-application DPI-value or stage selection.
**Architecture:** Keep the existing HID transport and serialized scheduler. Decode captured report values centrally, validate endpoint capabilities before writing, resolve DPI values against fresh X/Y stage tables, and preserve existing stage-based XML rules.
**Tech Stack:** C# 5 / .NET Framework 4, Win32 P/Invoke, Windows csc, BOM source files.
**Spec:** User-approved chat design (2026-10-20): choose DPI value matching or direct stage number. Editable game preset 800/4000 and office preset 1600/125. No editing onboard DPI values.

## Global Constraints
- Work directory explicitly selected by user: D:\github\mouse; retain MetapandaMouse05 branch.
- C# 5 / .NET Framework 4.0; no external runtime dependencies; UTF-8 BOM.
- Six-rate capture: 125=08,250=04,500=02,1000=01,2000=10,4000=20. Exact echo ACKs captured for all six.
- DPI-value mode matches both axes. Missing match causes no guessed stage write. Old stage rules remain loadable.
- F5AC advertises six rates; previously verified F5A9/F5AB retain 125/1000 capability.
- Source only in Git; capture, diagnostics and binaries remain ignored. Do not publish upstream.

## Task 1: Captured codec and receiver capability
Files: src/Hardware/MetapandaProtocol.cs, src/Hardware/MetapandaDeviceHelper.cs, tests/test_metapanda_protocol.ps1.
Interface: BuildPollingRate(int hz), DecodeSettings(byte[] memory, MouseBatteryInfo state), QueryDevices(), SetPollingRate(string deviceId,int hz).
- [x] Add literal capture fixtures for all six commands and decode 20/35 as 4000,10/45 as 2000. Replace rejected F5AC fixture with a different unknown PID. Verify test fails before implementation.
  `Check(Hex(MetapandaProtocol.BuildPollingRate(4000))=="08070000000220350000000000000000ef","captured 4000Hz");`
- [x] Implement explicit rate map; include F5AC in discovery; endpoint capability gate before sending unsupported rates.
- [x] Run powershell -File tests/test_metapanda_protocol.ps1 and build.bat.
- [x] Read actual F5AC state with official app closed; record exact DPI table, battery and rate.

## Task 2: Flexible application rules
Files: src/Models/ApplicationMouseProfile.cs, src/Services/ApplicationMouseProfileService.cs, src/UI/Forms/ApplicationMouseProfilesDialog.cs, src/UI/Forms/MainForm.Metapanda.cs, tests/test_application_mouse_profiles.ps1, tests/test_metapanda_flexible_profiles.ps1.
Interfaces: add int DpiValue (0 means stage mode), ResolveDpiStage(MouseBatteryInfo device); stage rules use DpiValue=0, value rules use DpiStage=0. Persist optional dpi XML attribute.
- [x] Add failing real-service tests: 1600 resolves to stage3 in [800,1200,1600]; reorder to [1600,800,1200] resolves stage1; missing match sends nothing; XY mismatch excluded; old XML roundtrip; 4000 snapshot restored; endpoint rate gate rejects 4000 on 1K.
  `service.Update(game,devices,apply); Check(lastStage==3 && lastRate==4000,"value-based 4K profile");`
- [x] Implement model validation and resolution, XML load/save optional dpi, rate capability checks, shared stage resolution for UI and service.
- [x] Add UI selection column (stage/value), numeric target, six-rate dropdown, live resolved-stage/status column, and game/office preset buttons applying to selected row. Presets are editable rule values, not forced global settings.
- [x] Run focused profile tests and runtime UI save/reload test.

## Task 3: Integration, hardware and delivery
Files: src/UI/Forms/MainForm.PollingRate.cs and existing Metapanda/game routing as needed, ARCHITECTURE.md, docs/metapanda-guide.md.
- [x] Remove Metapanda-only 125/1000 assumptions while preserving other brands; run upstream related regressions.
- [x] On real hardware apply all six rates with readback, then game800/4000 and office1600/125 via value rules. Restore initial captured settings after tests.
- [x] Rebuild, render and inspect rule editor; verify git diff --check and clean artifact exclusion; document capture evidence and limits.
- [x] Save portable program and source package under this chat outputs; retain local branch for review.
## Verification outcome
Native C#5 build and 12 relevant tests pass. F5AC six-rate writes and independent readbacks pass, value rules 800/4000 and1600/125 pass, baseline restored to stage2/1600/125. Editor rendered and checked at1220x600 and980x460. New restore regression reproduced and fixed by tracking baseline X/Y DPI through stage-table reorder. Source BOM and git diff whitespace checks pass. No upstream push. Artifacts exported to this chat outputs; capture and scratch remain Git ignored.
