# Release notes

## 1.4.0 — Guild watch

- Share guild addon users' positions about every 10 seconds without a lit beacon.
  Sharing defaults to on, with a persistent opt-out in Map & beacon controls.
  Withdraw markers when sharing is disabled or positions are unreadable; stale
  positions expire after 45 seconds. No location history is saved.
- Show locations and beacons on zone, continent and full Azeroth maps using the
  client's map transforms. Distinguish Alliance lion location pins from brazier
  beacon pins. Add tooltips, map waypoints and right-click access to player filters.
- Add local hide-all and individual location filters, independently of sharing.
  Beacon filters offer Normal, Silence (keep calls without horn/popup), and Hide
  (also remove their calls/pins and stop guidance to them).
- Remove the own-beacon popup. Confirm in the card or floating button instead.
  Queue incoming alerts during response celebrations to prevent overlapping text.
- Add a small royal brazier enabled by default: click to light/extinguish,
  Shift-drag to move, right-click for the full card. Settings can hide it; save
  explicit visibility choices and position per character.
- Add `/ltb locations`, `/ltb filters` and `/ltb button`. Preserve existing saves,
  messages, native horn and beacon compatibility with earlier addon versions.
- Validate 276 simulated-client checks, native Lua layout renders and one portable
  Windows/Linux ZIP. Live multiplayer location sharing still needs in-game testing.

## 1.3.0 — Compact Rally card

- Replace the large main window with a 400-pixel-wide Rally card. Keep the caller,
  message, estimated travel and answer action visible; expand Details for the
  route, location, responders and map. Multiple calls gain a compact pager.
- Add a short next-step strip after answering. Expanded details support stopping
  and resuming guidance without sending duplicate responses. Long routes scroll.
- Bundle the original royal blue-and-gold brazier texture for the card, incoming
  alert, minimap button, death prompt and map pins. Keep the Alliance lion crest.
- Move the Whitebeard Tinkerton credit into Options. Settings include sound,
  automatic calls, travel pace, flight refresh, message templates and previews.
- Show your own call with an extinguish action and no self-route or ETA.
- Include the previously local 1.2.0–1.2.1 message templates and native sound fixes.
- Preserve character saves and validate 222 simulated-client checks, native Lua
  layout renders and a portable Windows/Linux ZIP. Live multiplayer and automatic
  PvP attribution still require in-game confirmation.

## 1.2.1 — Own-beacon and sound fixes

- Your own alert opens your beacon details. It never answers the call, adds you
  as a responder, starts rescue navigation or changes your waypoint.
- Guard the answer action itself against self-answering, and stop previous
  rescue guidance when lighting your own beacon.
- Play the native DwarfHorn asset directly (FileDataID 566064, Master channel),
  confirmed audible on the live Forever client. Use the same direct method for
  the Alliance response fanfare (569543); keep sound-kit fallback support.
- Treat missing playback results as failures. Sound tests report the result and
  current audio settings; `/ltb sound` shows diagnostics without playing anything.
- Preserve the three message templates and existing saves. Validate 195 checks
  and the portable Windows/Linux ZIP. Compact UI options remain previews only.

## 1.2.0 — A reason to ride

- Add an Alliance-themed message window for manual calls, the key binding and
  death prompts. Send an optional message of up to 48 characters with your beacon.
- Save, reuse, replace or clear up to three quick-message templates per character.
  Choosing or saving a template does not send a call.
- Show the caller's message in incoming alerts, caller details and map-pin tooltips.
- Preserve templates and the active call's message across reloads. Late-joining
  guildmates receive the message when querying active beacons.
- Keep automatic PvP alerts immediate and free of stale drafts. Handle delayed,
  duplicate and cancelled messages without extra horns or resurrected calls.
- Preserve beacon delivery to older addon versions; update to 1.2.0 to display
  custom messages. All traffic remains on the hidden guild addon channel.
- Validate 177 simulated-client checks and one portable Windows/Linux ZIP.
  Live guild message delivery still needs in-game confirmation.

## 1.1.0 — The Alliance answers

- Ship the approved Alliance design: navy and gold, lion crest, grouped caller
  details, numbered routes with aligned times, current-step highlight and checks.
- Use WoW's native Horn of Cenarius / Dwarf Horn (10843) for beacon calls and the
  Alliance capture fanfare (8173) for the caller's first response. Remove the
  synthesized recording; no external or movie sound files are included.
- Celebrate the first responder with a glowing lion banner, their name and ally
  count. Later allies get a shorter visual update; duplicates and reloads do not
  replay the first-response fanfare. Add `/ltb rally` as a local preview.
- Include the flight-discovery fixes and automatic no-mount/60%/100% riding
  detection from 1.0.2–1.0.3, previously installed locally only.
- Keep guild addon alerts private and include the Whitebeard Tinkerton credit.
- Validate one Windows/Linux (Wine/Proton) ZIP with 129 simulated-client checks.
  Live multiplayer delivery and audio playback still need in-game confirmation.

## 1.0.3

- Automatically plan ground legs using the responding character's trained riding
  tier: none, 60%, or 100%. Read the riding skill rank, with learned riding spells
  as a fallback; never infer training from level or maximum skill rank.
- Replan active guidance when riding training changes. Keep flight and public
  transport times independent of mount speed.
- Replace manual mount-tier selection with Auto and an on-foot override.
  Unreadable training safely uses walking speed and reports that it is unverified.
- Preserve character saves and add regression coverage for training upgrades,
  separate characters, missing/restricted APIs, overrides and active flight travel.
- The Alliance theme and replacement sound candidates remain separate previews.

## 1.0.2

- Fix routes to unvisited destinations such as Gadgetzan: only an open flight
  master can confirm current/reachable flight points. Never trust Forever’s
  world-map `isUndiscovered=false` flag as evidence of discovery.
- Clear the old unverified discovery and node-position caches once, preserving
  settings, active calls, learned connections and measured flight times.
- Learn new node positions from the actual taxi map and replan active routes
  after a scan. Explain when a flight-master visit is needed.
- Add regression coverage for false Gadgetzan discovery, migration, closed or
  partial maps, map-transition pins, restricted states and reload persistence.

## 1.0.1

- Fix `/ltb` failing to register on Forever by replacing the removed
  `NEW_TAXI_PATH` event with `TAXI_NODE_STATUS_CHANGED`.
- Load key bindings through WoW’s dedicated binding loader instead of the TOC.
- Add regression coverage for rejected event names and real login/reload event order.
- One portable addon ZIP for Windows and Linux through Wine/Proton.

## 1.0.0 — initial local build

- Private guild addon alerts, war horn, WoW-style window and compact banner.
- Personal flight discovery, estimated routes, transport links and map guidance.
- Manual distress/death calls and optional confirmed PvP death detection.
