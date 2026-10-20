# Metapanda Implementation Plan

> **For agentic workers:** Use executing-plans and test-driven-development. User explicitly waived further design confirmations.

**Goal:** Support same-model Metapanda wired/wireless devices, real state, per-application DPI/rate rules, preserving existing functions.
**Architecture:** Separate MetapandaProtocol codec and MetapandaDeviceHelper transport; endpoint-specific identity; MainForm routes selected Metapanda only; independent foreground application profile service and editor.
**Tech Stack:** C# 5 / .NET 4 / Win32 HID, UTF-8 BOM, no external runtime dependencies.
**Spec:** docs/superpowers/specs/2026-10-20-metapanda-design.md

## Global Constraints
Work in D:\data\github\mose. No 4K, firmware or official app changes. No guessed successful state. No VID-only device targeting. Keep upstream functionality.

## Review Focus
Multiple identical endpoints; unexpected/late/malformed reports; unknown settings; disconnection and reconnect; profile release and competing game scheduler.

### Task 1: Codec and transport
- [x] Add failing behavior tests using captured 17-byte reports, checksum, wrong responses, invalid stage/rate.
- [x] Implement MetapandaProtocol and MetapandaDeviceHelper. Public contract: QueryDevices(): List<MouseBatteryInfo>; IsMetapanda(MouseBatteryInfo): bool; SetDpiStage(string deviceId,int oneBasedStage): bool; SetPollingRate(string deviceId,int hz): bool; QueryDevice(string deviceId): MouseBatteryInfo. IDs start Metapanda:, exact endpoint matching, no global fallback.
- [x] Decode actual stage table/current stage/rate using capture and read-only query; if unknown retain unknown and disable controls requiring it.
- [x] Validate tests, csc build, read-only local hardware; readback after settings.

### Task 2: UI and application integration
- [x] Add tests for exact executable path matching, per-device persistence, release to desktop, duplicate suppression and invalid/unknown targets.
- [x] Route device discovery without duplicate VGN/generic entries; manual DPI/rate and existing game/desktop hooks support Metapanda.
- [x] Add editable application rule model/store/manager and scheduler, exact full path matching, profile precedence over game scheduler, no-match restore, disconnect handling.
- [x] Build and run focused tests.

### Task 3: Integration and delivery
- [x] Review combined diff; run baseline appropriate tests and fix regressions.
- [x] Validate local hardware within captured 800/1600 and125/1000, restore original values; report wireless/multi-device limits honestly.
- [x] Document supported capabilities, build local deliverable, verify git status; no push or publish.

## Execution ledger
Implementation starts after user's explicit instruction to skip further design approvals. Skills requiring confirmation are overridden by that instruction. Existing checkout retained per user work directory.


## Verification outcome
Native csc C#5 build succeeded. Four new focused tests plus seven relevant upstream regressions pass (including runtime UI fixture). Current actual wireless endpoint F5A9 read battery85%, stage1/[800,1600],125Hz. Actual stage2->1 and1000->125 hardware writes/readbacks passed, original settings restored. Profile service exercised with actual hardware: application rule1600/1000, duplicate suppression, desktop800/125 restore. Official Mouse Drive Beta was closed after one concurrent communication failure; independent operation then passed. Wired F5AB has captured protocol fixtures but was not available for the final write/readback run. Multiple physical identical units were not available; endpoint isolation verified in tests. Unknown PIDs and DPI extensions are not guessed.

Review fixes: application ownership and setting writes serialized; queued game/manual callbacks recheck ownership; fresh hardware snapshots supply desktop baseline; profile cache reconciles observed values; game state capture runs off UI thread; tray reconstruction preserves entry; rendered dialog layout checked. No upstream push or publish.

Delegation model audit: hardware(pig), profiles(pig), UI(dog), documentation(cat), review(pig) each requested gpt-6.1-sol; actual model metadata unavailable, model compliance unverified. Lead inspected code, compiled and ran tests independently.
