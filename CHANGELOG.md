# Changelog — hotel8

## Unreleased

### Added
- **Settlement vertical: bank8 → bill8 (H8-BILL-1..5)** — all three
  settlement call sites (pms cashiering integration, pos card capture,
  upsell acceptance) now route through **Bill8:Payments** and
  **Bill8:Ledger** instead of Bank8. Payments become immutable charges
  (`POST /v1/charges`) with single-use token consumption
  (`POST /v1/tokens/{v}/consume`); settlement postings become double-entry
  balance-transactions (`POST /v1/balance-transactions` over balance ids).
  New M2M workloads `pms-payments`/`pms-ledger`/`pos-payments`/
  `upsell-payments` carry `bill8:*` scopes (registered via m2m_grants);
  env vars are now `BILL8_PAYMENTS_URL`/`BILL8_LEDGER_URL`. 293 tests
  pass; build is zero-warning.
- **Rust test suite (H8T-1..7)** — hotel8 went from 0 Rust tests to 122
  (0 failures, 0 warnings), closing the gap with every other vertical.
  Three layers per `design/sentin8-hotel8-rust-test-strategy.md`:
  contracts serde round-trips (pms/pos/loyalty/upsell/meta/distrib),
  extracted DB-free state machines (`pms/src/state_machine.rs`:
  Reservation/Folio/Block/Event; `pos/src/check_state.rs`: Check/Order +
  void-authorization policy + payment-outcome mirror), and per-service
  integration tests (`services/{pms,pos}/tests/integration_test.rs`).
  Availability math (`available_rooms`, `restrictions_allow`) extracted as
  pure functions and wired into the handler filter.

### Changed
- `PUT blocks/{id}/status` now validates the transition against the
  block state matrix server-side (409 on illegal transitions) instead of
  accepting any status string.

## v0.2.0 — 2026-08-13

- **Module-prefixed scopes**: All OAuth scopes renamed from `pms:*`, `pos:*`, `dist:*`, `loyal:*`, `meta:*`, `ups:*` to `hotel8:pms:*`, `hotel8:pos:*`, `hotel8:dist:*`, `hotel8:loyal:*`, `hotel8:meta:*`, `hotel8:ups:*` to prevent clashes across modules.
- **Dynamic admin scopes**: Vertical admin scopes declared in `vertical-registry.json` under `admin_scopes`, stored in `sentin8_vertical_admin_scopes` table during enrollment — platform never hardcodes hotel8 scopes.

## v0.1.0 — 2026-08-10

- Initial domain split from the monolithic sentin8 workspace.
- Contains: pms, pos, upsell, meta, loyalty.
- Contains contracts + clients for all hospitality services.
- Contains Flutter apps: ecorpbooking, ebooking, ekiosk, epms, epos.
- Depends on sentin8 via relative path dependencies.