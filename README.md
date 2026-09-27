# ComfyBag

**Version 0.3 – Beta**  
**Target: World of Warcraft: Forever 1.60.1 / Interface 16001**  
Author: **TheRealDoubleG**  
Discord: **the.real.double.g**

Unified inventory window with search for WoW Forever.

A single searchable window for normal character bags 0–4.

ComfyBag is developed specifically for **WoW: Forever**. Retail/Modern WoW, Midnight and WoW Classic are not compatibility targets.

## 0.1 Beta
- Added one combined normal-inventory window.
- Added text search, stack counts and quality borders.
- Uses C_Container when available with legacy fallbacks.
- Direct item use is refused during combat.

## Design notes
Bagnon's history shows how bag edge cases multiply. ComfyBag starts with normal bags only.

The referenced third-party addons were used only to study public feature ideas, long-term bug patterns and architecture lessons. ComfyBag uses original Comfy Suite code and Blizzard UI assets.

## Commands
- /comfybag
- /cbag

## Comfy Suite
UI standard generation 2 with Settings immediately before Info, standalone character/account/custom profiles and the shared Info layout.
