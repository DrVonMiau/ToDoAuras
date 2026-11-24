# ToDoAuras

## 1.3.0
- Settings window: `/tda` opens a movable window with everything to tick and tune
  (Escape closes it). Options → AddOns → ToDoAuras has a button to it.
- Fix: re-applying a weapon imbue or poison during combat clears its "expired" row right
  away, even when the game hides weapon enchants in combat. A second imbue cast fills a
  missing off-hand.
- `/tda log` records casts, what the game reports and row changes into the saved
  variables, to help hunt down bugs.

## 1.2.0
- Shaman: Maelstrom Weapon. A green row ("Maelstrom Weapon x5") when the stacks are ready,
  with "fades in Xs" when they're about to drop. Clears when you cast Lightning Bolt,
  Chain Lightning or a heal. Set the stack count in `/tda` or with `/tda stacks <n>`.
- `/tda debug` also shows stack counts.

## 1.1.1
- Fix: a buff could stay on the list as "expired" while it was active, mostly when
  recast during combat. Buffs are now also looked up by spell ID and recognised from
  your own casts, and an unconfirmed "not found" during combat is no longer trusted.
- `/tda debug` shows what the game reports for each tracked buff.

## 1.1.0
- Settings page (`/tda`): tick what to track per character, warning time, list size, move and reset.
- Modules for all classes: Warrior, Paladin, Hunter, Rogue, Priest, Mage, Warlock and Druid,
  next to Shaman.
- Group buffs count, for example Prayer of Fortitude or Greater Blessings.
- Rogue poisons tracked like shaman imbues, on both weapons.
- `/tda warn <seconds>` to change when rows appear.

## 1.0.0
- First release with the Shaman module: weapon imbue, Lightning Shield and totems.
