# Wherewith

World of Warcraft addon (Midnight, retail, and World of Warcraft: Forever): what your currencies
and tokens buy, and where.

## Features
- **Learns vendors**: open a vendor once and every offer that costs a currency or an item is
  stored with the vendor's name and position, account-wide
- **By currency**: each currency you own with its offers, cheapest first, affordable ones on top;
  a green tick marks what you can buy right now, prices you cannot pay are red
- **By vendor**: the same offers grouped by vendor and zone
- **No vendor known yet**: currencies you own whose vendors you have not opened yet
- **Mount journal**: currency mounts the game's mount journal lists, before you visit their vendor
- **Collected**: mounts, pets, toys, appearances and known recipes can be hidden
- **Category**: Blizzard's item classes (armor, weapons, recipes, ...), mounts and companion pets
- **Currency tooltips**: known vendors and offers in the tooltip of a currency or token
- Click sets a waypoint (TomTom if loaded, the game's map pin otherwise), Shift-click links,
  Ctrl-click tries on
- Search over items, vendors, zones and currencies
- English and German

## Limits
- Only vendors you have opened since installing are known; the game has no vendor list
- A vendor's class filter hides items; with the filter on "All" the scan is complete, otherwise
  new entries are added and old ones kept
- Vendors inside instances have no map position

## Installation
The zip from [GitHub releases](https://github.com/lasse-tech/wherewith/releases) unpacked into
`World of Warcraft/_retail_/Interface/AddOns` or `World of Warcraft/_forever_/Interface/AddOns`.
The folder carries `Wherewith.toc` (retail) and `Wherewith_Camelot.toc` (Forever, interface
16001); `make install-forever` installs into Forever.

## Usage
- `/ww` toggles the window, `/ww <text>` opens it with a search
- `/ww stats`, `/ww forget` (asks first), `/ww config`, `/ww debug` (at an open vendor: raw scan data)
- Minimap icon: click toggles the window, right-click opens the options
- Vendor view: right-click a vendor header to forget that vendor (asks first)

## Support

[Buy me a coffee](https://buymeacoffee.com/gossardla)

## Licence
© 2026 lasse tech, Lars Gossard — <lars@lasse-tech.de>

[MIT](LICENSE). The embedded libraries
(LibStub, CallbackHandler-1.0, LibDataBroker-1.1, LibDBIcon-1.0) keep their own licences.
