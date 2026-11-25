# ToDoAuras

## 1.4.3
- Fix: recasting a buff that can go on others (Thorns, Mark of the Wild, Fortitude, Arcane
  Intellect...) on yourself during combat now clears its "expired" row at once. Before, it
  stayed until combat ended. ToDoAuras checks who the spell went on. With no target, yourself
  or an enemy targeted, it went on you. Group versions (Gift of the Wild, Prayer of
  Fortitude, Arcane Brilliance...) always count.

## 1.4.2
- Fix: 1.4.1's combat-text check never fired on Forever. The game sends the messages under
  another name and hides which buff faded. ToDoAuras now remembers each tracked buff's
  ID and notices at once when the game removes that buff, even in combat. A recast that
  replaces the buff is not counted as a loss.
- `/tda log` also records buffs being added and removed, by ID.

## 1.4.1
- Faster in combat: ToDoAuras now listens to the game's floating combat text
  ("Lightning Shield fades", "+Lightning Shield"). A buff lost mid-fight shows as expired
  at once, and a regained one clears straight away, even while Forever hides buffs from
  addons in combat. Needs floating combat text for auras turned on (the default).

## 1.4.0
- Alignment: rows can be left-aligned, centred or right-aligned (icon on the right).
  Settings window or `/tda align left|center|right`.
- Fading: "expired" and "ready" rows can fade out after a set time (default: never).
  They come back when the item expires or gets ready again. Settings window or
  `/tda fade <seconds>` (0 = never).

## 1.3.1
- Fix: Maelstrom Weapon (and other procs not in the spellbook) showed no icon. Icons now come
  from the buff itself and are remembered per character.

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
