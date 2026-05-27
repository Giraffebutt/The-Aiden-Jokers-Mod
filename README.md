# The Aiden Jokers Mod

A chaotic Balatro mod by **BindyCot** that adds the OG Aiden plus five color-coded Aiden Jokers, each with its own gimmick, custom sounds, sprites, shaders, and card modifiers.

Requires [Steamodded](https://github.com/Steamodded/smods).

## Joker Lineup

| Joker | Rarity | What it does |
| --- | --- | --- |
| **Regular Aiden** | Common | Turns scored cards into **Autistic Cards**, which give **X2 Mult** when scored. |
| **Blue Aiden** | Uncommon | Rewards bad hands with **Pity**, giving **X2 Mult** and cash before sadness takes him out. |
| **Green Aiden** | Uncommon | Gives other owned Jokers the **Poop Seal**, a temporary scaling Mult buff. |
| **Purple Aiden** | Uncommon | Applies the dangerous **Evil Edition** to playing cards. Big upside, increasingly purple consequences. |
| **Red Aiden** | Uncommon | A comeback Joker for desperate last hands, with retriggers, money, and a fire overlay. |
| **Yellow Aiden** | Rare | Mutates cards into the **Corruption** suit, giving each corrupted card a random bonus effect. |

## Regular Aiden

Regular Aiden is the main Aiden Joker.

- Scored cards have a **1 in 6** chance to become **Autistic Cards**.
- **Royal Flush**, **Straight Flush**, **Four of a Kind**, and **Full House** guarantee the transformation.
- Autistic Cards give **X2 Mult** when scored.
- The `ohmygod.ogg` sound replaces the normal Mult sound when an Autistic Card scores.
- Rare-hand transformations play `holy.ogg`.
- Scoring Flush-style hands increases the chance that Regular Aiden appears in the shop if you do not already own him. A forced shop appearance plays `appear.ogg`.
- Regular Aiden is limited to one copy while owned or sitting in the shop.

## Blue Aiden

Blue Aiden rewards the player when things are going badly.

- **High Card** hands, or hands scoring below **15%** of the blind requirement, trigger **Pity**.
- Pity gives **X2 Mult** and **$3**.
- Each Pity trigger adds to the **Sadness** meter.
- At **5 Sadness**, Blue Aiden destroys himself and gives **$10**.
- Pity plays `crying.ogg`.

## Green Aiden

Green Aiden buffs your other Jokers instead of your playing cards.

- At the start of each blind, Green Aiden has a **2 in 3** chance to give a random other owned Joker a **Poop Seal**.
- Green Aiden cannot give the seal to himself.
- A Joker cannot receive a second Poop Seal while it already has one.
- Poop Seal gains **+3 Mult** at the start of each blind.
- The seal caps at **+20 Mult**, then disappears after scoring.
- Applying the seal uses `perfect-fart.ogg`.

## Purple Aiden

Purple Aiden is the evilest Aiden.

- Each scoring card has a **1 in 10** chance to gain **Evil Edition**.
- Evil Edition also turns the card into a **Wild Card**.
- Evil Edition gives **+20 Mult**.
- Evil Edition has a **1 in 8** chance to retrigger the card.
- Every time an Evil card scores, it becomes more purple.
- After **4 scored turns**, the card is fully purple and has a **1 in 2** chance to destroy itself.
- Applying Evil Edition plays `laugh.mp3`, and the laugh pitch drops lower each time another card becomes evil.

## Red Aiden

Red Aiden is built for clutch comeback hands.

- If you are on the **last hand** of a blind and below **50%** of the required score, Red Aiden activates.
- While active, scoring cards retrigger once.
- Activation plays `raaah.ogg`.
- Red Aiden shows a semi-transparent fire shader while active.
- If the hand triggers Balatro's score-flame moment, Red Aiden rewards **$5**.
- The fire effect fades out after the blind ends.

## Yellow Aiden

Yellow Aiden mutates your deck.

- When a blind is selected, Yellow Aiden has a **1 in 2** chance to mutate a random playing card into the **Corruption** suit.
- If it misses, the mutation is guaranteed within **2 blinds**.
- Mutating a card plays `static.mp3`.
- Yellow Aiden blinks with a custom TV static shader while the static sound is active.
- Corruption cards roll one stored effect when mutated. A corrupted card can give:
  - Chips
  - Mult
  - XMult
  - Money
  - A Seal
  - An Edition
- Numeric Corruption rolls can reach **100**, but high rolls are intentionally rare.

## Install

1. Install [Steamodded](https://github.com/Steamodded/smods).
2. Download or clone this repository.
3. Place the mod folder in:

```text
%AppData%\Balatro\Mods\BalatroAidenMod
```

4. Launch Balatro and enable the mod through Steamodded.

## Thunderstore Notes

Thunderstore package basics expect a package to include `manifest.json`, `README.md`, and `icon.png`, with `CHANGELOG.md` strongly recommended. This README is written in standard Markdown so it can display cleanly on GitHub and Thunderstore.

Reference: [Thunderstore Package Setup Basics](https://hytalemodding.dev/ru-RU/docs/publishing/thunderstore/package-basics)

## Credits

- **BindyCot**: Mod creator, Joker concepts, sprites, sounds, and integration.
- **Sjeiti**: Fire shader effect, sourced from [Shadertoy](https://www.shadertoy.com/).
- **arthurstammet**: TV static shader effect, sourced from [Shadertoy](https://www.shadertoy.com/).
- **Steamodded team**: Balatro modding framework.

## Disclaimer

This is an unofficial Balatro mod and is not affiliated with LocalThunk, Playstack, or the Balatro team.
