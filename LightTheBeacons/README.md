# Light the Beacons 1.6.4-test.1

Guild death actions dock beneath Blizzard's original
death controls, which retain their normal behavior and existing skin. Readable
death-recap contributors are offered for review; nothing is shared in Ask first
mode until you confirm. Both death prompts require positive hostile-player
evidence. Mob-only deaths and unknown attribution stay quiet. Battlegrounds,
arenas and other instances are excluded.
Use `/ltb deathstatus` for local diagnostics and `/ltb deathdock` to toggle docking.

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

Options contains settings and the subtle
**Whitebeard Tinkerton - US PVP** credit. The default card has no credit footer.

## Use

- `/ltb grudges` or **Grudges** on the Rally card: open the shared ledger.
- `/ltb` or the brazier beside the minimap: open the card.
- `/ltb light`: compose a call at your position (or your fallen body).
- `/ltb clear`: extinguish your beacon.
- `/ltb sound`: show the last playback result and current audio settings.
- `/ltb options`: sound, automatic alerts, death prompts and travel pace.
- `/ltb settings`: combining, merge distance, horn cooldown, popups and marker size.
- `/ltb locations`: sharing, map visibility and floating beacon button settings.
- `/ltb filters`: Friends and individual beacon/location filters.
- `/ltb button`: show or hide the movable beacon button.
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
Your own call confirms with **Beacon lit** in the card instead of another popup;
you cannot answer or start navigation to your own call. Incoming alerts wait
until the response celebration finishes, so the two banners never overlap.
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

## Movable beacon button and player filters

The movable beacon button is **on by default**. Hide it with **Show movable
beacon button** under **Options → Map & beacon controls**, or toggle it with
`/ltb button`. The small royal brazier shows whether your beacon is lit.
Left-click to ignite immediately without a message, or extinguish an active call.
Right-click opens the full card. **Shift-drag** moves the icon; its position and
visibility are saved per character. Reset its position from the same settings page.
The normal message composer remains available through the card and `/ltb light`.

Under **Options → Friends & filters**, add a player's full character name including
surname. Click their beacon mode to cycle **Normal → Silence → Hide**. Silence
removes their beacon horn and popup while keeping their call in the list and on
the map. Hide also removes their calls and beacon pins, and stops guidance to
their beacon. **Hide location** independently hides their background position.
Remove the filter to restore normal behavior. These choices apply locally and
are never sent to the guild.

## Nearby calls and notification settings

Open **Options → Beacon settings** or `/ltb settings`. Preferences are saved per
character; changing them never sends a guild message.

- **Combine nearby beacons: on.** Default range **100 yards**, adjustable from
  **25–250 yards**. All members must be within the range of every other member;
  a long chain cannot connect separate fights. Turn combining off for individual calls.
- The first call can sound and notify. **Joining an active group is always quiet**:
  no new horn or popup, and no restart of an existing popup. The card and marker
  update their caller count. Details shows every caller and their optional message.
- The oldest active call anchors the route and shared map pin. Every caller keeps
  their own expiry and extinguish action; leaving never cancels anyone else's call.
  Answering acknowledges the active callers with paced, individual replies. Each
  responder is counted once. You cannot answer a group containing your own call.
- **Shared horn cooldown: 30 seconds**, adjustable **0–120 seconds**. This is a
  local cooldown across all callers, measured from the last successfully started
  beacon horn. Other beacons still appear immediately. Silent calls do not extend
  it. **0** removes the cooldown for separate calls; joins remain quiet. The first
  responder's fanfare is independent and retains its own short repeat guard.
- **Show beacon and response popups: on.** Turn off to keep calls in the card
  without popups. Sound and the existing global mute are separate controls.
- **Map marker size: 75%** of the prior size, adjustable **50–150%**. Applies to
  guildmate lions, Friend shields and beacon braziers. Icons keep a consistent
  displayed size while the map canvas zooms.
- **Disable beacons in dungeons and raids: on.** Blocks new calls, horns, popups,
  beacon map pins and guidance there. Calls remain available in the card and an
  existing own beacon can still be extinguished. Turn off to allow manual beacon
  activity in party/raid instances. Battlegrounds and arenas always stay excluded.
  Automatic death actions still require outdoor PvP evidence. Background location
  sharing and manual ledger use retain their independent settings.

Combining happens locally using the client's readable world positions. Unknown
positions and dungeon floors are never guessed or combined across instance
copies. Different preferences or older addon versions can display separate
calls; every client still receives the original, compatible caller records.
Map projection now supports both directions through the client's map hierarchy,
so a position sent on a broader map can remain visible in its matching zone.
Missing transforms fail quietly rather than displaying an invented location.

## Quiet alerts and Friends

Enable **Options → Mute all beacon alerts** to use guild location sharing without
beacon interruptions. This suppresses incoming and own-call horns, response
fanfare/celebrations, activity chat notices, and death prompts. It also dismisses visible/queued alerts
and stops recently started addon sounds. Calls stay in the card and on the map,
and response counts still update. Manual calls, your existing automatic-PvP
choice, sharing preferences and per-player filters are unchanged. Unmuting does
not replay missed alerts. Sound-test and sample-preview controls have been removed.
The global mute is off by default and is saved per character.

## Local chat notices

Open **Options → Chat notices** or **`/ltb chat`**. These notices appear only in
your own chat window; they never post to guild chat or send additional addon
messages. Preferences are saved per character.

- **Beacon activity: on.** Names who lights a beacon and where, who extinguishes
  a previously announced call, and who answers your call. Answering a shared
  beacon gives you one confirmation for the whole group.
- **Nearby beacon joins: off.** Optionally add a chat line for a new caller
  joining an existing beacon. Requires Beacon activity. Joins still do not play
  a new horn or create a new popup.
- **Grudge activity: on.** Names who records, avenges or withdraws a grudge.
  Your own entries say they are queued for guild sharing; bulk death selections
  produce one summary. Manual vengeance is distinguished from a detected kill.
- **Enemy sightings: off.** Optionally show target/mouseover sightings in chat,
  at most once per minute per enemy. Also requires sighting warnings in Grudges
  settings. Hidden enemies remain quiet.

The horn cooldown and popup switches do not suppress chat notices. Global alert
mute suppresses all four categories. Individual beacon Silence/Hide filters and
instance restrictions suppress beacon chat; hidden grudge enemies suppress
grudge chat. History syncing, duplicate packets, older beacon query replies and
delayed grudge announcements stay quiet. Turning a switch on does not replay
events that were suppressed while it was off.

In **Friends & filters**, tick **Friend** beside a player's name. Friend marks
are private to this character and are not sent to the guild or linked to Battle.net
friendship. Changing a Friend mark preserves that player's other filters. Remove
deletes the entire row, including its Friend mark and filters.

Enable **Show only Friends on the map** under **Map & beacon controls** to filter
both shared locations and guild beacon pins. Your own lit beacon remains visible.
Individual Hide location and Hide beacon filters still apply; a Friend mark does
not override them. With no Friends selected, other guildmates' markers are hidden.
This map-only filter leaves the call list, alerts and outbound sharing unchanged.
It defaults to off. Neither setting restricts which guildmates receive your
location. Friends use WoW's native Alliance shield on the map; regular guildmates
keep the existing Alliance lion. Active beacon pins remain royal braziers. Changing
a Friend mark refreshes the icon immediately on zone, continent and world maps.

## Guild location sharing

**Sharing is on by default.** Guildmates running 1.4.0 or later share their current
map position about every **10 seconds**, even without lighting a beacon. The
data travels only through the guild addon channel. Locations use Alliance lion
markers; active beacons use royal braziers. Both appear on **zone, continent and
the full Azeroth world map**, using the client's map transforms. The addon does
not guess positions when a transform or player position is unavailable.

Open **Options → Map & beacon controls** or `/ltb locations` to turn off **Share
my location with guildmates**. Turning it off stops background position sends
and withdraws your marker. A lit beacon still shares the incident location you
called from. If the game delays a withdrawal, old markers expire within **45
seconds**. Unreadable positions also withdraw the old marker rather than reuse
stale coordinates. Offline or disconnected players disappear when their last
update expires. Sharing preferences persist through reloads.

Turn off **Show guildmates on my map** to hide all background position markers
locally, or use **Hide location** in Friends & filters for particular people. Map
display choices do not change whether you share your own location. Hover a
marker for name, zone, coordinates and update age. Left-click to open its source
map and set a waypoint; right-click to open the player's filter setup.

Background sharing makes no horns, popups or calls for aid. Remote locations
remain in memory only, with no saved location history. Updates are approximate
and can be delayed by game messaging restrictions. A marker does not establish
that another player is on your layer. Earlier addon versions continue to
exchange beacons normally but do not share background positions.

## The guild Book of Grudges

**1.6.0:** the book is integrated into Light the Beacons; no separate grudge addon
is required. Every participating guildmate needs 1.6.0 or later. Older clients
continue to exchange beacons normally and ignore the separate ledger protocol.

The **Grudges** ledger has a dark leather binding, stained parchment, legible fantasy titles,
a name index and one grievance per facing leaf. **Add grudge** accepts the enemy's
full name and up to 160 characters. **Use hostile target** fills a readable player
name. Outlined fields include typing hints and a focus highlight; framed buttons
identify actions clearly. Every entry is signed with its author, date and zone and is shared with
guild addon users. **Previous/Next entry** traverses a debtor's history; the name
index is paged and searchable. Hover a page for the complete written record.

Any guildmate can **Mark avenged** after witnessing the enemy's defeat.
The confirmation records one victory against one selected debt, preserves the
original words, and adds an attributed wax seal. Manual records are identified
as manually witnessed victories. Only the original scribe can **Withdraw my
entry**; a withdrawal is a shared tombstone that hides the entry, not a way to
forcibly erase copies another player has already received.

Book **Settings → After an outdoor PvP death** offers **Ask first** (default),
**Auto-save**, and **Off**. Ask first opens one **You have fallen** window with
the beacon call and grudge actions. **Detected attackers** lists up to 32 hostile
players whose readable damage reached you in the 30 seconds before death, with
the confirmed **Killing blow** listed first. This is not a complete roster of
everyone involved: restricted data, unidentifiable pet owners, healers and
crowd-control-only participants cannot be inferred. Repeated hits are deduplicated.

Use the checkboxes and **Select all / Clear selection**, then **Inscribe selected**
to save and share one grudge per selected player. Longer lists have page controls;
the button counts selections across all pages. Other attackers are explicitly
recorded as manually confirmed damage before the death, not as killing blows.
Recorded names are disabled for this incident. **Review / edit entry** reviews a
single remaining attacker; **Add missing name** lets you enter an additional name.
The form preserves the other selections and returns to the death window when
saved. Its **Save to guild ledger** button shares only that reviewed entry.

**Light the Beacons** opens the existing optional-message editor without saving
any grudges. Sending or cancelling returns to the same selections; a successful
call shows **Beacon lit**. Saving grudges never lights a beacon. The captured
death zone stays with entries even if you move before saving. **Dismiss** skips
the remaining death actions without cancelling an already lit beacon.

Both death prompts require positive evidence of hostile-player damage in the
death encounter. Mob-only deaths, environmental deaths and unknown/restricted
attribution stay quiet. When PvP involvement is confirmed but the player's name
is unavailable, the prompt can offer manual name entry after about three seconds.
Enter the name and review the note; this is saved as a manual account. Late recap
data is checked for up to 5.5 seconds. A player who actually damaged you can still
be offered for review if a mob landed the final hit. No player killing blow is
claimed in that case. Manual calls and `/ltb grudges` remain available at any time.
Auto-save shares only confirmed killers automatically; other detected attackers
still require selection and confirmation. It stays quiet without positive PvP
evidence. Confirmed automatic recording requires readable hostile-player
GUID, flags, lethal evidence and name. Changing the prefilled enemy name makes
the entry manual. Battlegrounds/instances are excluded. Global alert mute hides
these prompts. Previously disabled death recording stays off after updating;
previously enabled recording moves to Ask first.

Book settings also default to guild sharing, automatic recording of your own
confirmed killing blows, target/mouseover warnings and grudge notices. These
are independent of the beacon's automatic-call setting (which defaults to off).
Automatic vengeance needs your own readable `PARTY_KILL` event against a known
enemy; party participation is not treated as your kill. One kill settles the
oldest unpaid debt, and repeated evidence is deduplicated. If the game restricts
attribution, use manual inscription/vengeance. No secure/internal combat API is used.

Sightings are local observations of a hostile player you target or mouse over;
they are not shared or saved as enemy tracking. **Hide this name** suppresses a
debtor in your index and sightings locally. Restore hidden names in Settings.
Turning off **Use the guild-shared book** pauses receiving, sending and automatic
recording and makes saved pages read-only. **Phrases** offers optional themed wording; concise notifications are the default.
“All grudges avenged” appears only when a debtor has no unpaid entries. Notices use one bottom-screen slot;
the existing beacon alert mute also suppresses them.

The ledger uses `LTBGR1` on the hidden `GUILD` addon-data channel. It sends no
ordinary chat. Records include a guild identifier, author, event ID/time, enemy
name, optional readable player GUID, zone, written grievance and evidence type;
seals/withdrawals reference the original entry. Packets are bounded, assembled
without evaluating code and sent at most twice per second. Live authors must
match the game's sender identity. Missed history is copied from current online
guildmates, **trusting those peers' cached attribution**; historical records are
not cryptographically signed or independently verified combat evidence.

Records and unsent local changes persist per character. The current guild's
cache retains at most 1,200 records for 90 days. Switching guild discards the
previous guild's ledger cache and pending packets. Login and periodic inventory
checks recover missing pages in bounded batches from online peers; this can
take time and needs overlapping online sessions. There is no central server.
Sharing is suspended while guild identity is unavailable, and records are also
bound to the guild in their payload to reject delayed old-guild traffic.

## Private guild alerts

All network traffic uses `C_ChatInfo.SendAddonMessage`, prefixes `LTB1` for
beacons/locations and `LTBGR1` for the book, on the
hidden `GUILD` addon-data channel. **No message is posted in guild chat**, party
chat, say, yell, ordinary whispers, or any external service. Only other members
of your guild running the addon display the alert. Non-guild senders and packets
received on other channels are ignored. Your identity comes from the game's
sender field for live events. Relayed book history has the separate trust model
described above.

Beacon messages contain a beacon ID, timestamp, map position, reason, optional
caller text, and response/cancellation. Background location messages contain a
timestamp, map and coordinates, or a withdrawal. They contain no flight-discovery list: each responder
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
and pets without a readable owner can require opening the ledger manually. The addon never reads secure or
internal combat APIs to work around those restrictions.

The enabled-by-default death prompt offers **Call for aid** only after detected
hostile-player involvement. Mob-only deaths and unknown attribution stay quiet.
Its button opens the message window; nothing is sent until you choose **Light
the Beacons** there. Automatic calls skip that window and never attach a draft
or saved template. Battlegrounds, arenas and
instances do not create beacons or automatic prompts.

## Saves and verification

`LightTheBeaconsDB` is saved **per character**. It contains options, discovered
flights, learned connections/times, three message templates, sharing/display
preferences, global alert mute, Friend marks, player filters, floating-button position and your own unexpired
beacon including its message and responder names.
Guild grudge events, unsent ledger changes and local book settings are also
saved; ledger history expires after 90 days and is cleared on a guild change.
Expired or invalid saved beacons are cleared at login; WoW writes the cleanup at
its next normal save. Remote beacons and shared locations
are held in memory only. Reloading preserves your ability to extinguish your
own active beacon. Leaving/changing guild clears active guild data. Installing
or updating the addon does not modify the game's `WTF` directory or other saves.

The included workspace tests exercise two simulated clients, protocol filtering,
duplicate/cancel ordering, cooldowns, expiry, discovery isolation, directed
routing, boats/zeppelins, new flight connections, saved settings, death detection
and UI construction, plus popup arbitration, movable controls, per-player
filters, location opt-out/expiry and zone-to-continent-to-world map projection.
Rendered previews are generated from the real Lua widget
tree with local native-texture preview fixtures. The book renderer uses the same
bundled fonts as the client; other panels use a substitute serif for Friz Quadrata.
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
are recorded in `ThirdParty/TravelData-source.txt`. Native UI artwork belongs
to Blizzard Entertainment and is referenced from the installed client, not bundled;
references and local preview source records are in `Media/sources.json`.
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

## License and privacy

All Rights Reserved with Free Player Use: players may download, install, run and
make personal backups at no cost. Redistribution, resale and publication of
modified original code require separate permission. See [LICENSE.txt](LICENSE.txt).
Third-party materials retain their own rights, including Lodestar’s MIT license.

**Location sharing is on by default.** Guild members can receive and record addon
packets, including beacon messages and responses. Local player filters are not
recipient blocks. Read [PRIVACY.txt](PRIVACY.txt) for transmitted fields,
local saves, retention and instructions to stop sharing.
