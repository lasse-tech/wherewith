# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-11-06

### Added
- `make uninstall-forever` removes the addon from the Forever client
- World of Warcraft: Forever: `Wherewith_Camelot.toc` (interface 16001);
  `make install-forever`

### Changed
- Retail interface 120105 (12.1.5)
- Shift-click links through `ChatFrameUtil.InsertLink` (`ChatEdit_InsertLink` is deprecated)
- `Makefile.bat` no longer asks before replacing or deleting

## [0.1.1] - 2026-10-31

### Changed
- Licence: MIT (was AGPL-3.0-or-later)

### Added
- Donate link in the addon list (`X-Donate`)

## [0.1.0] - 2026-10-31

### Added
- Vendor scan: offers that cost currencies or items, with vendor position, account-wide
- Window grouped by currency or by vendor, with search and filters (affordable, collected, owned)
- Affordability from bags and currencies, purchases possible, prices in red when short
- Currencies without a known vendor
- Currency mounts from the mount journal
- Collected check for mounts, pets, toys, appearances and recipes
- Category dropdown: Blizzard's item classes, plus mounts and companion pets
- Currency and token tooltips with known vendors
- Waypoints via TomTom or the game's map pin
- Minimap button, addon compartment, key binding, `/ww`, English and German
- Licence: AGPL-3.0-or-later
