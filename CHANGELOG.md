# Release notes

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
