# ToDoAuras

## 1.6.0
- Removed Maelstrom Weapon tracking. Forever hides stacks gained mid-fight from addons,
  and mid-fight is when a Maelstrom reminder matters. The `/tda stacks` command and the
  stack setting are gone with it.
- Lightning Shield's "may be gone" guess from 1.5.x stays. It was confirmed in play.

## 1.5.2
- Lightning Shield charge counting confirmed in play: every "may be gone" in a recorded
  fight matched the moment the shield faded.
- Maelstrom Weapon: removed the Lightning Bolt cast-time check, because Forever doesn't change
  the reported cast time. Stacks gained mid-fight can't be seen. A "ready" row from before
  the fight stays until you spend it.
- Fix: out of combat, a slow Healing Wave or Lightning Bolt no longer clears "ready" for a
  moment. The buff itself decides.

## 1.5.1
- Lightning Shield guess, fixed and tightened: ToDoAuras now counts the shield's charges.
  A hit uses one, at most every 3.5 seconds, which matches how the shield behaved in
  recorded fights. Out of combat it reads the real count. "May be gone" appears when the
  charges run out, or when a buff fades at the very moment of a hit with one charge left.
  This avoids 1.5.0's false alarm on a fresh shield.
- Maelstrom Weapon in combat: Forever sends no spell glow. Instead, ToDoAuras checks whether
  Lightning Bolt has become instant, which happens at full stacks.

## 1.5.0
- In combat, Forever hides all buff information from addons: names, IDs and lookups.
  ToDoAuras now works from what still comes through:
  - **Lightning Shield:** when the game reports that one of your buffs faded right after you
    were hit, and not because of a cast of yours, a yellow "Lightning Shield may be gone" row
    appears. Recasting clears it. After combat, the game's real answer replaces the guess.
  - **Maelstrom Weapon:** a "ready" row no longer disappears when combat starts. At full
    stacks the game makes Lightning Bolt glow on your bars, and ToDoAuras uses that glow to
    show "ready" mid-fight (if Forever sends it).

## 1.4.4
- In combat, ToDoAuras now asks the game about your buff by its ID: the one it saw before the
  fight. If the game answers, a buff lost mid-fight shows as expired at once. If the game
  hides that too, nothing changes. 1.4.2's removed-buff notices turned out to be hidden in
  combat.

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
