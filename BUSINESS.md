# hotel8 — Business Requirements & Functionality

> Audience: product owners, business analysts, and anyone evaluating what the
> hotel8 vertical **does for the business**. For architecture read
> `README.md`; for wire-level detail read `DESIGN.md`. Per-service and
> per-app functionality detail lives in `services/{svc}/BUSINESS.md` and
> `apps/{app}/BUSINESS.md`.

## 1. Business Purpose

- Run a hotel end-to-end on one software vertical: from the moment a guest
  shops rates on a metasearch platform or books directly, through front-desk
  arrival, restaurant meals charged to the room, upsell offers, loyalty
  points, channel distribution, to the nightly close.
- Eliminate integration tax: reservations, folios, menus, offers, rewards,
  and channel availability live in one tenant-isolated model with one
  identity plane and one event stream, not five vendor systems stitched
  nightly.
- Give the operator an admin console (Dash-rendered RFW pages) and staff/guest
  apps that share the same authorized domain model — no per-app copies of
  business rules.

## 2. Business Scope (What the Vertical Provides)

| Capability | Provided by | Description |
|---|---|---|
| Property system of record | hotel8:PMS | Properties, rooms/types, rate plans, packages, items, reservations (create/edit/cancel/split), front desk, folios, housekeeping, groups & banquet events, night audit, digital keys, reporting |
| Direct booking channel | eBooking (app) | Commission-free guest booking funnel under the hotel's brand with metasearch attribution, multi-property search, loyalty join and voucher redemption |
| Corporate booking channel | eCorpBooking (app) | Negotiated-rate portal with policy-guarded search, traveler rosters, credit methods (post-pay / bill-to-company), multi-company switcher, SSO or first-admin provisioning |
| In-stay guest services | eGuest (app) | Pre-registration, mobile check-in, room service ordering, upsell accepts, digital key, stay feedback, rewards + saved payment methods |
| Self-service lobby | eKiosk (app) | Check-in/out with add-on sales and payment, express walk-in booking, staff unlock; entirely config-driven from the PMS kiosk-config |
| Staff console | ePMS (app) | Reservations, front desk, housekeeping, cashiering, rates, blocks, events, end-of-day — with property switching and re-auth on sensitive operations |
| Restaurant & room service | hotel8:POS + ePOS (app) | Table service, menus with modifiers, splitting/merging transfers, manager approvals, room charges into the PMS folio, offline queue, guest room-service for eGuest |
| Revenue growth | hotel8:Upsell | Rules-as-data offers (upgrades, early check-in, amenities) generated on booking events, A/B tested, guest one-tap accept with bill8 payment |
| Channel distribution | hotel8:Distrib | OTA/GDS/wholesaler onboarding, mappings, per-channel markup, ARI push, reservation intake from channels |
| Metasearch presence | hotel8:Meta | Partner channels (Google Hotel Ads et al.), rate ads derived from live availability, click attribution feeding eBooking |
| Loyalty program | hotel8:Loyalty | Programs, tiers, points earning on stays, redemptions at hotel and restaurant touchpoints, catalog management |
| Corporate credit | hotel8:PMS corporate surfaces | Approved payment methods per company (approved on the PMS Corporate admin page), traveler bindings, first-admin provisioning |

**What the vertical does NOT own (business boundary)**

| Concern | Owning service |
|---|---|
| Identity, sign-in, consent | Sentin8:Auth |
| Client token custody & proxying | Sentin8:BFF |
| Card capture, payment settlement, ledger | Bill8:Payments / Bill8:Ledger |
| Durable event transport & audit store | Sentin8:Bus / Sentin8:Sys |
| Email transport | Sentin8:Post |
| Scheduled & workflow execution | Sentin8:Cron / Sentin8:Flow / Sentin8:Func |
| Admin page rendering, ingress TLS | Sentin8:Dash / Sentin8:Proxy |

## 3. Business Capabilities (per area)

| Area | Capability | Business rule |
|---|---|---|
| Booking | Reservation creation | Availability-gated per room type; the system generates the confirmation number; channel/walk-in origins carry source codes |
| Booking | Walk-in / express | Kiosk express booking never oversells — refuses when the window's availability is below the request |
| Stay | Check-in/out | State machine only (CONFIRMED→CHECKED_IN→CHECKED_OUT); reversal is a logged staff op; folio settles at check-out |
| Money | Folio | Charges and payments post to the same folio; room charges move through bill8 as immutable charges + ledger postings; disputes are tracked, never edited |
| Dining | Room charge | POST's into the guest's folio — no manual reconciliation between restaurant and front desk |
| Dining | Offline resilience | Terminal queues operations with client idempotency keys and replays; revenue is never lost to a network blip |
| Revenue | Upsell | One live offer per booking+rule; declines remembered per stay; payment state only reflects actual bill8 results |
| Retention | Loyalty | Points earn on checked-out stays; redemption possible at POS (restaurant) not just the hotel; catalog is tenant-authored |
| Reach | Channels | Live ARI reaches channels within seconds of a PMS change (event-driven); per-channel commercial terms as data |
| Reach | Metasearch | Ads derived from live availability; clicks attributed into the booking funnel (UTM) to close the loop |
| Compliance | Corporate policy | Rate caps, advance-booking limits and approved properties enforced at search time; company credit methods surface only when approved (post-pay / bill-to-company) |
| Security | Sensitive operations | Void/discount/EOD/check-out style operations re-authenticate (fresh password) before executing |
| Operations | Night audit | One atomic EOD: folio roll-up, housekeeping reset, inventory roll, no-show processing |
| Admin | Console | 14 PMS RFW pages (live data + submit), plus per-service admin pages incl. policy studio (Shield sets, relations, attributes) |

## 4. Business Events

**PMS emits** the vertical's core facts — reservation lifecycle
(created/updated/cancelled/checked_in/checked_out/split), folio postings and
generation, inventory updates, housekeeping status, keys issued, kiosk-config
and corporate changes (`company:method_updated`, `company:user_bound`,
`company:admin_provisioned`) — consumed directly by the services that care:

| Consumer | On PMS event | Business reaction |
|---|---|---|
| POS | reservation:checked_in | Open table prep for the arriving party |
| Upsell | reservation:created | Generate offers from the booking snapshot |
| Loyalty | reservation:checked_out | Award points for the stay |
| Distrib | inventory:updated | Push ARI deltas to subscribed channels |
| Meta | inventory:updated | Re-derive rate ads |

Counter-flows close the loop: distrib reservations received → PMS reservation
via owner API; POS redeem loyalty reward; ebooking metasearch clicks → meta
rate identity → booking payload; all services emit their own
`hotel8:{svc}:{resource}:{operation}` events for auditability and platform
consumers.

## 5. Business Rules & Invariants

1. A reservation, check, offer, or member record is created exactly once per
   request (idempotency keys on every event-triggered path).
2. Money moves only through bill8 (charges + balance transactions); no
   vertical service computes or stores balances.
3. Guest-facing operations never see staff data: guest routes are
   session-scope-gated and holder-scoped (their reservation id, their folio).
4. Corporate credit only surfaces when approved — a pending/rejected method
   never appears in checkout.
5. Availability math is shared: the same sell-limit formula decides what a
   channel, the website, the kiosk, and the front desk can sell.
6. Every guest-visible amount is the property currency; conversions are not
   computed in the vertical.
7. Nothing is deleted that money or audit touched — voids, cancels and
   reversals are state transitions with journal entries.

## 6. Target-User Roles & Use Cases

| Persona | Uses | Typical flow |
|---|---|---|
| Leisure guest | eBooking, eGuest, eKiosk | Search → book → pre-register → key → room service → rate stay |
| Business traveler | eCorpBooking, eGuest | Company-code sign-in → policy-compliant book → in-stay services |
| Travel manager | eCorpBooking | Roster, credit methods, booking oversight across the company |
| Front-desk agent | ePMS, eKiosk | Check-in walk-ups, room moves, folio settlement, EOD |
| F&B staff | ePOS | Open tables, routes orders to stations, settle incl. room charge |
| Revenue manager | Dash (RFW admin) | Rates, package/upsell rules, channel mappings, loyalty catalog |
| Hotel sales | Dash — PMS Corporate admin page | Approve credit methods, bind company users, link negotiated rates |
| IT operator | Sentin8 platform tools | Enroll vertical, monitor captain fleet, replay DLQ |

## 7. KPIs / Success Criteria

- **Direct revenue share**: bookings through eBooking/eCorpBooking vs OTA
  (commission savings).
- **Front-desk throughput**: kiosk check-in share; average desk time per
  arrival.
- **Ancillary revenue**: upsell accept rate, add-on sales per check-in,
  room-service covers.
- **Repeat rate**: loyalty membership growth and redemption frequency.
- **Channel freshness**: seconds from a PMS inventory change to channel ARI
  (event pipeline latency).
- **Reliability**: offline-queue replay success; zero double postings
  (idempotency); audit completeness (every mutation journaled).

## 8. Dependencies & Reliance on Other Services

| Relies on | For |
|---|---|
| Sentin8:Auth | all sign-in, tokens, M2M DCR, enterprise SSO |
| Sentin8:BFF | every app→service call, token custody, CSRF |
| Sentin8:Bus | the event backbone linking all six services |
| Sentin8:DB | the database engine + RLS helper functions |
| Bill8:Payments/Ledger | card capture and settlement postings |
| Sentin8:Post/Storage | guest emails, property images |
| Sentin8:Cron/Flow/Func | scheduled generation, booking workflows, hooks |
| Sentin8:Dash/Proxy | admin rendering, PQ-TLS ingress |

## 9. Acceptance Criteria

1. A guest can book, check in via kiosk or phone, charge a restaurant meal to
   the room, earn and redeem loyalty points, and check out — without a staff
   member touching the same data twice.
2. A change to availability at the desk is reflected on channels and
   metasearch without a human export step.
3. Every corporate booking adheres to the company's policy rules or is
   explicitly flagged with the violation reason.
4. Night audit completes atomically or not at all; a failed component leaves
   data in its prior consistent state.
5. Any terminal can lose its network mid-service and still settle the shift.
6. The admin console renders live data and accepts edits for every domain
   page it shows (no static placeholders).
7. All authorization is policy-based (Shield) with live role resolution —
   a role change takes effect on the next request, not the next login.

## 10. Open Business Questions

- The auto-link between an anonymous eBooking reservation and an eGuest
  sign-in (which journey owns the "claim your booking" moment) —
  `BACKLOG.md` APP-EGS-1.
- Corporate-rate display priority when both public and negotiated rates fit
  the stay (revenue-management decision) — recorded in `DESIGN.md` §10 of
  eCorpBooking.
- Whether loyalty earning should also trigger on folio settlement amounts
  (currently stay-completion based) — pending program-economics decision.

---

**Design attribution:** hotel8 and its underlying concepts were designed by Hamid Jahanzad <Hamid@Jahanzad.com>.
