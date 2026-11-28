<p align="center"><img src="media/logo.jpg" alt="ToDoAuras" width="180"></p>

# ToDoAuras

**A tiny to-do list for your own buffs. It only appears when something is about to run out or
already has.**

No bars, no big frames, nothing on screen while everything is fine. When a buff, weapon imbue,
poison or totem has less than 5 seconds left (you can change this), a row appears:

> Rockbiter Weapon expires in 4s

When it runs out, the row turns red and stays until you reapply it:

> Rockbiter Weapon expired

The list builds from the bottom up, like a stack of reminders.

Made for **WoW: Forever**.

## What it tracks

| Class | Tracked (ticked by default) | Optional |
|---|---|---|
| Shaman | Weapon imbue (main hand and off-hand), Lightning Shield, Fire / Earth / Water / Air totems, Maelstrom Weapon x5 alert | |
| Warrior | Battle Shout | |
| Paladin | Blessing, Paladin aura | Righteous Fury |
| Hunter | Aspect | Trueshot Aura |
| Rogue | Poison (main hand and off-hand) | Slice and Dice |
| Priest | Fortitude, Inner Fire | Divine Spirit, Shadow Protection, Shadowform |
| Mage | Arcane Intellect, Mage armor | Dampen / Amplify Magic |
| Warlock | Demon Armor / Demon Skin | Unending Breath |
| Druid | Mark of the Wild, Thorns, Omen of Clarity | |

- **Group buffs count:** a buff from another player counts too, for example Prayer of Fortitude
  or Greater Blessing of Kings.
- **Only spells you know:** spells your character hasn't learned are skipped.
- **Weapon imbues and poisons:** these appear only once you've used one on that character. The
  name comes from your last cast.
- **Totems:** an expired totem shows only during combat, and clears when combat ends or you drop
  a new one.
- **Hidden** while you're dead or on a flight path.
- **Maelstrom Weapon x5 (shaman):** a gold, pulsing "Maelstrom Weapon x5" above your cast bar,
  separate from the list, shown only at 5 stacks. The game draws it itself, so it works in
  combat too.
- **In combat**, Forever hides your buffs from addons. ToDoAuras follows what still comes
  through: your own casts, weapon enchants, totems, and the game's anonymous "a buff faded"
  text. A Lightning Shield lost mid-fight shows as expired, worked out by counting its charges
  as you get hit, and the game confirms it when combat ends.

## Settings

Type `/tda` to open the settings window (or Options → AddOns → ToDoAuras → *Open ToDoAuras settings*):

- **What to track:** tick or untick each item, saved per character.
- **Warn when less than:** how many seconds before something expires the row appears (1 to 30).
- **List size.**
- **Fade expired rows after:** let them fade out after some seconds (default: never).
- **Alignment:** Left, Center or Right. With Right, the icon sits on the right of the text.
- **Move list:** shows sample rows on a blue bar. Drag it, then click *Lock list*.
- **Move bar (shaman):** moves the Maelstrom Weapon x5 alert on its own. Drag it, then click *Lock bar*.

## Commands

| Command | What it does |
|---|---|
| `/tda` | Open or close the settings window |
| `/tda unlock` / `/tda lock` | Move the list |
| `/tda bar` | Move the Maelstrom Weapon x5 alert (type it again to lock) |
| `/tda warn 8` | Warn 8 seconds before something expires |
| `/tda scale 1.2` | List size (0.5 to 2) |
| `/tda align right` | Align rows left, center or right |
| `/tda fade 10` | Fade expired rows after 10 seconds (0 = never) |
| `/tda reset` | Reset position and size (the Maelstrom alert goes back above your cast bar) |
| `/tda list` | Show what's tracked |
| `/tda on <item>` / `/tda off <item>` | Track or stop tracking an item |

## Light by design

- **Event-driven:** it does nothing until the game reports a change, like a buff, totem, weapon
  enchant or combat starting.
- **One timer:** a single timer wakes it when the next item reaches the warning time.
- **Brief countdown:** a countdown updates five times a second, and only while a row is on screen.
- **Combat-safe:** when Forever hides combat data from addons, ToDoAuras keeps the last known time
  instead of throwing errors.

## Issues and source

Bug reports, missing spells and ideas: [GitHub issues](https://github.com/DrVonMiau/ToDoAuras/issues).
MIT licensed.
