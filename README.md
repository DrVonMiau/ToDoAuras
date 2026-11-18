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
| Shaman | Weapon imbue (main hand and off-hand), Lightning Shield, Fire / Earth / Water / Air totems | |
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

## Settings

Type `/tda`, or open Options → AddOns → ToDoAuras:

- **What to track:** tick or untick each item, saved per character.
- **Warn when less than:** how many seconds before something expires the row appears (1 to 30).
- **List size.**
- **Move list:** shows sample rows on a blue bar. Drag it, then click *Lock list*.

## Commands

| Command | What it does |
|---|---|
| `/tda` | Open settings |
| `/tda unlock` / `/tda lock` | Move the list |
| `/tda warn 8` | Warn 8 seconds before something expires |
| `/tda scale 1.2` | List size (0.5 to 2) |
| `/tda reset` | Reset position and size |
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
