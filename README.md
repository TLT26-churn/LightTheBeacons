# Light the Beacons

A guild rescue addon for **World of Warcraft: Forever (interface 16001)**.
Sound a war horn and call your guildmates to your aid, with estimated routes
based on each responding character’s discovered flight points.

**[Download the latest addon ZIP](https://github.com/TLT26-churn/LightTheBeacons/releases/latest)** ·
[Full guide](LightTheBeacons/README.md) · [Release notes](CHANGELOG.md)

## Install on Windows or Linux

Use the same `LightTheBeacons-<version>.zip` on **Windows** and **Linux with
Wine/Proton**. Extract its `LightTheBeacons` folder into your WoW installation’s
`_forever_/Interface/AddOns/` directory. The final file must be:

```
_forever_/Interface/AddOns/LightTheBeacons/LightTheBeacons.toc
```

Enable Light the Beacons in the game’s AddOns list. Restart WoW if a newly
installed addon is absent; use `/reload` when updating an existing installation.
Open with **`/ltb`** or the minimap torch. Open a flight master's map to confirm
your available flight points; repeat on other continents you use. Every
participating guildmate needs the addon. Keep your SavedVariables when updating.

## What it does

- Sends alerts only through the hidden guild addon channel. **No guild chat posts.**
- Shows “The beacons are lit! <Name> calls for aid!” with an original war horn.
- Provides a WoW-themed window, compact alert, map pins and a direction guide.
- Compares ground travel, flight-master-confirmed flights, boats and zeppelins for each responder.
- Supports private responses, extinguishing calls and five-minute beacon expiry.
- Offers optional automatic PvP death alerts when the client exposes readable
  evidence of a hostile player’s killing blow. Automatic alerts default to off;
  a manual death prompt is available when attribution is restricted.

**1.0.2:** fixes routes to undiscovered flight points such as Gadgetzan. The old
unreliable discovery cache is reset once; settings and flight timings are kept.
Visit a flight master after updating to rebuild the confirmed list.

Routes are estimates rather than terrain-aware GPS. The addon does not account
for hearthstones, teleports or summons, and never moves your character for you.
Automatic PvP attribution and guild delivery still require live multiplayer
verification; simulated-client checks cannot establish those live behaviors.

## Development

The runtime is ordinary WoW Lua/XML with bundled TGA and OGG assets. Players do
not need Python, LuaJIT, FFmpeg or any other external program.

To run the headless tests, install LuaJIT. Packaging also requires a Lua compiler
(`luac`), Python 3 and Pillow:

```sh
luajit tests/light-beacons.lua LightTheBeacons
python3 tools/package_light_beacons.py
```

The packager validates Lua syntax, media hashes, bindings, archive paths and an
extracted copy with simulated clients, then creates one portable ZIP. The tests
cover private delivery, malformed messages, cooldowns, discovery isolation,
routes, death attribution, reload/login startup and UI construction.

Optional `tools/build_light_beacons_media.py` rebuilds the original horn using
FFmpeg and restores missing artwork from pinned sources. The preview renderer
accepts `LTB_PREVIEW_FONT` if its default serif fonts are unavailable.

## Credits

By **Whitebeard Tinkerton — US PVP**. Flight data is adapted from Daniel Costa’s
[Lodestar](https://github.com/danielcosta42/lodestar); its MIT license and source
record are included under `LightTheBeacons/ThirdParty/`. Original Blizzard UI
artwork remains Blizzard Entertainment’s property; pinned source URLs and
hashes are in `LightTheBeacons/Media/sources.json`. The horn is synthesized,
with no sampled recording. This project is not affiliated with Blizzard.
