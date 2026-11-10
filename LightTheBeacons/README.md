# Light the Beacons 1.3.0

A private guild call for aid for **World of Warcraft: Forever (interface 16001)**.
Sound the horn, rally guildmates who use the addon, and follow a travel route
based on the responding character's discovered flight points.

## Install

Extract the `LightTheBeacons` folder into:

`World of Warcraft/_forever_/Interface/AddOns/`

The final path must be `Interface/AddOns/LightTheBeacons/LightTheBeacons.toc`.
Enable **Light the Beacons** in the AddOns list. Reload when convenient; if a
newly added addon does not appear, restart the client. The same ZIP works on
Windows and Linux through Wine/Proton. There are no required addons or external
programs. Each participating guildmate needs the addon.

**1.0.2 flight discovery fix:** routes now use only flight points confirmed by an
open flight-master map. This update clears the unreliable discovery/position
cache from older versions; your settings, beacon and flight times remain. Open
a flight master on each continent you use to rebuild the confirmed list. Until
then, routes use ground travel and boats instead of guessing at flight access.

**1.0.1 startup fix:** replaces an obsolete flight-path event that stopped
`/ltb` from registering. Key bindings load through WoW's dedicated binding
loader. Existing users can replace the addon folder and `/reload`; keep saves.

## Compact Rally card

Stormwind blue, gold trim, an Alliance lion and the original royal brazier frame
a compact card with the caller, optional message, travel estimate and answer
action. **Details** expands the numbered itinerary, location, responders and map
button. Completed steps show checks; the current step is highlighted. Answering
adds a short next-step strip even when Details is collapsed. Long routes scroll;
hover a step or the responder list for its complete text. **Stop guidance** in
Details pauses navigation; **Resume route** restarts it without another reply.

Options contains settings, local previews and the subtle
**Whitebeard Tinkerton - US PVP** credit. The default card has no credit footer.

## Use

- `/ltb` or the brazier beside the minimap: open the card.
- `/ltb light`: compose a call at your position (or your fallen body).
- `/ltb clear`: extinguish your beacon.
- `/ltb preview`: show a local sample alert and route. Nothing is transmitted.
- `/ltb horn`: test the native Horn of Cenarius / Dwarf Horn without sending a beacon.
- `/ltb sound`: show the last playback result and current audio settings.
- `/ltb rally`: preview the response celebration and Alliance fanfare locally.
- `/ltb options`: sound, automatic alerts, death prompts and travel pace.
- `/ltb scan`: refresh from an open flight-master map, or explain how to scan.
- `/ltb status`: show local discovery and automatic-detection diagnostics.

Bindings are available under **Light the Beacons** in the game's key bindings.

Choose **Light mine**, `/ltb light`, or the call key binding to open the
message window. Add an optional message of up to **48 characters**, then click
**Light the Beacons** to send it. Leaving the field blank still sends a normal
call. Enter finishes editing; it does not send. Cancel or Escape closes the draft.

The same window holds **three quick-message slots**, saved per character. Type a
message and choose **Save current** beside a slot. Click a saved message to use
it, edit and save again to replace it, or choose **Clear** to remove it. Templates
are private until you use one in a call. You can also manage them through
**Options → Quick messages**. Opening a new call starts with an empty draft.

An incoming call shows **“The beacons are lit! <Name> calls for aid!”** in a
compact WoW-style banner. Left-click the banner to answer and start guidance;
right-click to dismiss. Answering acknowledges your response to other addon
users in your guild. The main card has **Answer the Call**; **Show Map** is in Details.
Your own banner opens your beacon details; you cannot answer or start navigation
to your own call.
Use the pager below the actions to switch between simultaneous calls. It appears
only when multiple calls exist. Scroll longer route lists inside Details.
The caller's optional message appears in the alert, caller card and map-pin
tooltip. Both players need **1.2.0 or later** to exchange custom text. Older
versions still receive the beacon, horn and route without the extra message.

The guide displays the next travel step and a direction arrow. World-map brazier
pins identify active beacons. Waypoints change only after you choose to answer
or open a beacon on the map. Travel remains under your control.

Beacons expire after five minutes. New calls have a 60-second cooldown.
Duplicates and acknowledgements never replay the beacon horn. Your first
responder triggers a gold lion flare, their name, an ally count and an Alliance
capture fanfare. Later responders update the count with a shorter visual pulse;
duplicate replies never replay the celebration, including after reload. Sounds
can be muted in Options. Native audio files play on the game's Master channel
and respect master mute/volume; sound kits are a fallback. A failed playback is
reported locally, and `/ltb sound` displays diagnostics without changing settings.
Your beacon stays at the incident
location when you release spirit. Use **Extinguish My Beacon** when aid is no
longer needed.

## Private guild alerts

All network traffic uses `C_ChatInfo.SendAddonMessage`, prefix `LTB1`, on the
hidden `GUILD` addon-data channel. **No message is posted in guild chat**, party
chat, say, yell, ordinary whispers, or any external service. Only other members
of your guild running the addon display the alert. Non-guild senders and packets
received on other channels are ignored. Your identity comes from the game's
sender field, never from an asserted name inside a packet.

Messages contain a beacon ID, timestamp, map position, reason, optional caller
text, and response/cancellation. They contain no flight-discovery list: each responder
plans their own route locally. The game may restrict or throttle addon messages;
a failed send is reported locally and is never displayed as a successful call.

## Travel routes

The seed graph contains **66 flight points, 288 directed flight connections and
10 boat/zeppelin routes** from Forever's client data. The planner compares
ground travel, available flights and faction-appropriate public transports.
It excludes undiscovered flight points, including intermediate stops, and uses
each responder's own confirmed discovery data. Open a flight master's map after
installing to record its current/reachable destinations. Repeat on other
continents you use; confirmations are saved per character. The world-map list
is never accepted as proof of discovery because Forever can mark unvisited
points as known. New node positions and connections are also learned from the
actual flight-master map. Existing rescue routes update after a scan.

Travel pace defaults to **Auto**, using this character's trained riding rank:
no training means on foot (7 yards/second), Apprentice riding means a 60% mount
(11.2 yards/second), and Journeyman or higher means a 100% mount (14 yards/second).
Training upgrades replan the rescue route automatically. The Options button
switches between Auto and an **On foot** override. An old manually chosen mount
speed never unlocks a tier the character has not trained. Unreadable training
falls back to walking, marked unverified in Options and `/ltb status`.

Mounted estimates assume you can use a mount of your trained tier for outdoor
ground legs; select the on-foot override if you intend to walk. They do not
include temporary speed buffs, mount cast time, or combat delays. Training does
not speed up flights or boats. Flight durations start as estimates and improve
when a direct flight is timed and arrival at the expected landing point is verified.

These are **estimated routes**, not terrain-aware GPS paths. Ground segments use
distance with a detour allowance; follow roads around mountains, buildings and
other obstacles. Boat waits are estimates. The addon does not include
hearthstones, class teleports or summons. Unsupported map connections are shown
as unavailable rather than inventing a path across continents. A shared map
position does not move players between layers; group up when needed.

## Optional automatic PvP alerts

Automatic alerts are **off by default**. Enable them in Options to try them.
They only fire after an outdoor death with readable evidence of a hostile
player's killing blow. The detector accepts a public combat-log event, where
available, or a new death recap containing the required player GUID and flags.
It rejects NPCs, environmental damage, friendly players, nonlethal hits, stale
recaps and restricted data. A caster name alone is insufficient evidence.

Forever's published UI exposes restrictions on combat-log access; its public
death-recap schema does not guarantee attacker GUID/flags. Consequently,
automatic attribution may be unavailable on the live client. Hidden attribution
and pet kills can require the manual prompt. The addon never reads secure or
internal combat APIs to work around those restrictions.

The enabled-by-default death prompt provides a fallback: **Call for aid?**
Its button opens the message window; nothing is sent until you choose **Light
the Beacons** there. Automatic calls skip that window and never attach a draft
or saved template. Battlegrounds, arenas and
instances do not create beacons or automatic prompts.

## Saves and verification

`LightTheBeaconsDB` is saved **per character**. It contains options, discovered
flights, learned connections/times, three message templates and your own unexpired
beacon including its message. Remote beacons
are held in memory only. Reloading preserves your ability to extinguish your
own active beacon. Leaving/changing guild clears active guild data. Installing
or updating the addon does not modify the game's `WTF` directory or other saves.

The included workspace tests exercise two simulated clients, protocol filtering,
duplicate/cancel ordering, cooldowns, expiry, discovery isolation, directed
routing, boats/zeppelins, new flight connections, saved settings, death detection
and UI construction. Rendered previews are generated from the real Lua widget
tree with bundled art and a substitute serif font; the game uses Friz Quadrata.
These checks do not substitute for live guild delivery, PvP, map and taint tests.

From the source workspace:

```
luajit tests/light-beacons.lua LightTheBeacons
python3 tools/package_light_beacons.py
```

## Credits and API references

Flight/transport data is adapted from [Lodestar](https://github.com/danielcosta42/lodestar),
Copyright (c) 2026 Daniel Costa, under the included MIT license. Its source is
Blizzard's Forever client DB2 data via wago.tools. Source hash, build and changes
are recorded in `ThirdParty/TravelData-source.txt`. Original UI artwork belongs
to Blizzard Entertainment; pinned sources and hashes are in `Media/sources.json`.
The royal brazier is original artwork created for Light the Beacons with OpenAI
image generation. It ships as a transparent TGA; its source and prompt are in
the repository's `art/` directory. No extra program or download is needed in game.
Sounds are referenced from the WoW client rather than bundled as recordings:
[Horn of Cenarius / Dwarf Horn](https://www.wowhead.com/sound=10843/hornofcenarius)
(FileDataID 566064; sound kit fallback 10843) for a beacon, and
[Alliance flag-capture fanfare](https://www.wowhead.com/tbc/sound=8173/pvpflagcapturedalliance)
(FileDataID 569543; sound kit fallback 8173) for the first responder. Direct horn
playback was confirmed audible on the live Forever client. No external free horn
or movie audio is used.

API definitions: [Forever UI source](https://github.com/Gethe/wow-ui-source/tree/forever),
particularly SkillInfo, SpellBook, ChatInfo, TaxiMap, Map, DeathInfo, DeathRecap and CombatLog.

Forever discovery compatibility: the world-map flag limitation is also documented
in [ForeverPlusPlus API observations](https://github.com/xIGBClutchIx/ForeverPlusPlus/blob/main/docs/forever-api.md).
