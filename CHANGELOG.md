# Release notes

## 1.6.3 — One death window, selectable attackers

- Combine the beacon and grudge prompts in one themed death window with the
  royal brazier, dark ledger section, individual checkboxes and Select all.
- List up to 32 detected hostile players who damaged you within 30 seconds of
  death. Deduplicate hits, mark the confirmed killing blow and page longer lists.
  Restricted identities, pets without owners and nearby names are not guessed.
- Inscribe only selected attackers, once per incident, with explicit guild
  sharing. Preserve the existing protocol; other contributors use manual evidence
  and a note that they attacked before the death. Auto-save still applies only
  to the confirmed killer, leaving other names for confirmation.
- Preserve choices while composing a beacon or reviewing/adding a name. Show
  Beacon lit and recorded-entry confirmations in the same window. Keep the
  two actions, their settings and saved records independent.
- Clear temporary attacker data on resurrection, guild changes or disabling
  death recording. Keep missing-attribution manual entry and global alert mute.
- Explicitly exclude battlegrounds, arenas and uncertain instance states. Cancel
  pending death actions and close the window when entering an instance.
- Validate 599 simulated-client checks, native Lua previews and the portable ZIP.
  Live combat attribution still requires an in-game check.

## 1.6.2 — Prompt for a grudge after death

- Add the missing post-death grudge prompt. Prefill confirmed killers and let
  players review the grievance before sharing it with the guild.
- Offer a manual fallback after about three seconds when the client cannot
  identify the killer. Never invent a name or label a manual account verified.
  Suppress prompts for readable lethal NPC/environmental damage and instances.
- Add Ask first (default), Auto-save, and Off to the book's Settings. Preserve
  an existing disabled death option; move previously enabled recording to Ask first.
- Deduplicate death events, cancel pending prompts on resurrection/guild changes,
  respect global alert mute, preserve unfinished entries and retain the death zone.
- Validate 539 simulated-client checks, native UI renders, Lua syntax and the
  extracted portable ZIP. Live PvP attribution still needs an in-game check.

## 1.6.1 — Clearer Grudges controls

- Title the tome **Grudges**, retaining the aged parchment and fantasy lettering.
- Give editable fields outlines, typing hints and focus highlights. Frame buttons
  and tabs so actions are visibly clickable; use direct labels for adding, saving
  and marking a grudge avenged.
- Remove decorative slogans from the main pages and use concise default notices.
  Optional themed phrases remain available in Phrases; saved choices are kept.
- Add public gallery previews with synthetic sample names.
- Preserve guild-ledger compatibility, saved grievances, flight data and settings.
- Validate 493 simulated-client checks and the extracted Windows/Linux ZIP.


## 1.6.0 — The guild Book of Grudges

- Integrate an aged, iron-bound ledger into Light the Beacons. Open it from the
  Rally card or `/ltb grudges`; browse names and turn individual grievance pages.
  Keep the approved dark tome, clear title, signed notes, scratched tallies and
  cracked wax seals. Bundle original materials and OFL fonts for Windows/Linux.
- Share inscriptions, vengeance and author withdrawals through a separate guild
  addon protocol. Preserve the original grievance when a debt is avenged. Show
  who wrote and who answered each wrong, with date, zone and evidence type.
- Recover missed history from online guildmates in bounded batches. Validate
  live sender identity, scope every event to its guild, bound fragment buffers,
  retry delayed sends, deduplicate records and cap retained history at 90 days
  and 1,200 events. Relayed historical attribution trusts the supplying guildmate.
- Record confirmed outdoor PvP deaths and your own readable killing blows when
  supported; retain manual inscription and witnessed-vengeance confirmation.
  One confirmed kill settles at most one oldest unpaid debt. Never infer an
  enemy from a name alone or read restricted combat data.
- Add local target/mouseover warnings, personal hidden names, phrase choices and
  independent book settings. Sightings are not transmitted or saved. Turning
  book sharing off pauses its network and automatic recording.
- Keep notices in one separate bottom slot; retain beacon alert behavior, known
  flights, riding detection, Friends, map sharing and existing saved settings.
- Validate 493 simulated-client checks, native Lua book renders, bundled assets
  and the extracted Windows/Linux ZIP. Live guild sync and PvP attribution
  still require in-game verification.

## 1.5.0 — Friends and quiet alerts

- Add a global beacon-alert mute that suppresses live horns, popups, response
  celebrations and death prompts while preserving location sharing, call lists,
  responder counts and manual calls. Dismiss queued alerts and stop addon sounds
  immediately. Explicit test/preview actions remain available.
- Add private per-character Friend marks in Friends & filters. Preserve existing
  beacon and location filters when toggling Friend status, and retain all choices
  through reloads.
- Add Friends-only map filtering for shared positions and beacon pins, retaining
  your own beacon. Keep sharing, call lists and alert choices independent.
- Use WoW's native Alliance shield for Friends, keeping the existing Alliance
  lion for regular guildmates and royal brazier for active beacons. Refresh icons
  immediately on Friend/filter changes and when reusing a map pin.

- Add All Rights Reserved with Free Player Use terms to the source and addon ZIP;
  preserve the separate Lodestar MIT license and third-party notices.
- Add player privacy information covering default-on guild position broadcasts,
  message/response visibility, local saves, opt-out controls and retention limits.
- Clear expired or invalid saved beacons at login, including stale incident
  coordinates, message text and responder names. Preserve settings and templates.
- Reference Blizzard textures from the installed WoW client instead of bundling
  copies; keep the original royal brazier and native horn/sound references.
- Keep WoW Forever 1.60.1 / interface 16001 support in one Windows/Linux ZIP.
- Validate 309 simulated-client checks, native Lua settings renders and the
  extracted portable ZIP. Live texture rendering awaits the user's reload.

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
