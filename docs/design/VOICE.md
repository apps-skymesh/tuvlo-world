# The valley's voice

Tuvlo World has one story: **wake the sleepy valley.** Every sale, order and barge feeds the valley, and each level wakes a piece of it you can see (flowers, lanterns, birds, a kite, a neighbour's lights, a sail). The words exist to name what the player can already see or do. All narrator copy lives in `Godot/scripts/game/story.gd` (`WorldStory`); the waking tiers live in `Godot/scripts/valley_awakening.gd`.

## Who speaks

| Voice | Where | How it sounds |
| --- | --- | --- |
| **The valley** (narrator) | Arrival, return greeting, firsts, a place finishing, level-up lines | Present tense, sensory, warm. No quotes, no exclamation marks. |
| **The neighbours** | Orders and the barge (`FOLK`, `BARGE_THANKS` in `catalogue.gd`) | In quotes, each with a character: Maeve is motherly, Rowan is a cheerful bargeman, Bramble is a wry forager. |
| **The interface** | Buttons, toasts, tooltips | Plain and short. It can be warm ("Busy. Let this one finish"), but clarity comes first. |

## Rules

- **Short.** A narrator line is 44 characters or fewer, and two beats at most ("Sails up. Flour, at last."). A test enforces this.
- **True.** Never promise what the world doesn't show or the rules don't do. Weather lines say what the spell really speeds up. The breeze line only mentions the mill once there is one. A tier line names scenery that really appears.
- **Shown first.** The world change comes first and the line names it. Don't add a line for something invisible.
- **Once.** Peaks (the first harvest, the first sale, a place finishing) read from the save, so they can only happen once. Opening the game records where things stand and replays nothing.
- **Never over a neighbour.** A narrator line waits until a neighbour's words have cleared.
- **Clarity beats flavour** for errors and buttons. "Couldn't save. Try again." stays plain.

## Lexicon

- The valley *sleeps* and *wakes*, and a level is the valley waking a little more ("The valley wakes").
- Places *breathe* when finished. Write their line about the life they bring, not the building.
- The daily gift is *a basket on the step*.
- Avoid: "Level complete", "Error", "Invalid", "Success", "Congratulations".
