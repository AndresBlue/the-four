# The Lurker, more aggressive (24 October 2026)

What the author asked after his first games of floor 2 (in Spanish, his words in quotes), and how it is built. The numbers that are not his are the director's and are tuned by playing.

## What the author asked

1. "Mucha más oscuridad en el piso": the **first stage** (planta 1, the mail) dark by difficulty. Apacible all lit, Equilibrada as today, Desafiante much darker, Pesadilla almost all dark. Plantas 2 and 3 keep their dark: it is their puzzle (the board, the lockdown).
2. "Cuando sea iluminada instantáneamente salga de la luz intentando buscar una forma de escape": no more freezing in the light. Lit (a torch on her, her room's light, looked at with light), she leaves at once for the nearest way into the ceiling.
3. "Que pueda entrar y salir por cualquier placa de techo falso": any full tile of a false ceiling is a way in and out. She opens it with one hand, leaves it half open and comes out; going back in through an open one she closes it after her.
4. "Conforme sube la dificultad, cuando se esconde en el techo que pueda salir por otra parte del techo rápidamente... ojalá por la espalda del jugador": "Me vio, sabe dónde estoy, ¿por dónde irá a salir ahora?".
5. "Que su movimiento cuando no la ves sea MUY rápido."
6. "Un encuentro se compone de varios intentos de la bestia por atacar a un jugador desde las sombras; luego de fallar reiteradas veces se retira y deja tranquilo al jugador por el periodo."
7. The director's package, approved: forced encounters (1), stalking closer (2), not stopped by being looked at without light (3), a shorter window (4), less respite (6), the long leap as her attack (7).

Unchanged: the warning (OFICINAS 1: never a take without a warning at the back), and what saves from it: turning to her with light or the torch on her face, or running away (the author's C3).

## The numbers

| | Apacible | Equilibrada | Desafiante | Pesadilla |
|---|---|---|---|---|
| Stage 1 dark rooms | none | the manifest's | the manifest's + 60 % of the rest | all but 10 % |
| `back_window` (s) | 2.2 | 1.5 (was 1.8) | 1.2 (was 1.5) | 0.9 (was 1.2) |
| `stalk_distance` (m) | 12 | 8 (was 10) | 6 (was 8) | 4 (was 6) |
| `creep_scale` | 0.8 | 0.9 | 1.3 (was 1.0) | 1.5 (was 1.15) |
| Attempts in an encounter | 2 | 3 | 4 | 5 |
| Back out of the ceiling after a failed attempt (s) | 8 to 12 | 4 to 7 | 2 to 4 | 1 to 2 |
| Where she comes out | far from the survivor | another tile 6 to 10 m off | behind the survivor, 3 to 6 m | behind the survivor, 3 to 5 m |
| Rest after the encounter (s, that survivor left alone) | 120 | 90 | 60 | 45 |
| Unseen on a surface (m/s) | 3.0 | 3.5 | 4.0 | 4.5 |
| Unseen in a duct or the plenum (m/s) | 2.0 | 3.0 | 4.0 | 5.0 |
| Forced encounter after (s without contact) | never | 150 | 90 | 60 |

- **Stage 1's dark** is decided in `office_geometry.decide_dark()` on top of the manifest, from the difficulty the floor is built with (`hotel_main.build_floor()` passes it; the manifest does not change), per room with `vary()` (the same on every machine). Rooms that may never be dark (`OFFICE.may_be_dark()`) and the off-limits ones keep their light.
- **Lit**: `p.torch_by` on her, her room `lit()` while she is on its surface, or `p.regarded_by` (looked at with light). Any of them while she is not in a warning: she goes into the ceiling at once (the tile over her, else the nearest way in), at her unseen speed once out of sight. A survivor she was after counts it as a failed attempt.
- **A failed attempt**: a warning saved (turned to with light, the torch, running), or being lit while stalking or closing in on her prey. After it she is in the ceiling; she comes out where the table says, after its time, and tries again. After the last one she goes away (FLEE, far) and leaves that survivor alone for the rest. A take ends the encounter as today (sated).
- **Unseen**: no survivor's eyes have her in view (`creature_sight.watched()`, the shared sight) and she is not in a warning: her moves run at the unseen speed. Seen, her speeds of today.
- **The long leap (7)**: the warning may start from 2 to 5 m (was 2 to 3); at the end of the window, if not saved, she takes from up to 7 m with the leap (was 3.4 m, or 7.4 m only after walking away).
- **Not stopped without light (3)**: `exposed()` holds her only for regard with light or a torch, not for being in somebody's view in the dark.
- **Forced encounters (1)**: the director, after that long without her reaching anybody, leads her into the room of the survivor it picks (its "never where anybody is" rule gives way only here). As built: `creature.forced_after()` (the Lurker's `forced_after` key; nought for every other creature); the director's `last_contact` is the last tick she was noticing somebody or hunting, the wait counts from the end of the last rest too, and in BUILD `forced_due()` leads her (kind "encuentro", 40 s, once) to the middle of the room of `pick_target()` in her wing, never somebody hidden and never the rooms of the hidden nor the ones next to them; one that cannot be given is tried again 5 s later.

## Ways in and out (3, 4)

- Every full tile of a room with a false ceiling is an exit of kind `tile` to the plenum over that room: her duct graph gets one plenum node per such room (over its centre, at the duct's height), linked to the room's cell node and to the plenum nodes of the rooms next to it on the same planta. A route through tiles is a route like any other (`lurker_routes`): in at the tile over her, out at the tile the route asks for.
- **The tile** (as built): coming out, she pushes it down with one hand and it swings on one edge to 60 degrees in a quarter of a second and stays there, half open, hanging over the dark square of its hole (`office_geometry.turn_tile()`; the tile is cut out of its batched run the first time she moves it). Coming back in through an open tile, she pulls it shut after her; going in through a shut one, she lifts it 70 degrees into the plenum (hidden by the dark) and it drops shut after her. On every machine since step 3e (the creature's event "tile", spec_f3_integration 6.5).
- **The tiles she may take**: the ones a grille or a gap may take (`OFFICE.free_tiles()`: no troffer's, clear of the troffers and, but in corridors, of the walls), but the grilles' and the gaps'. The plenum node sits over the free tile nearest the room's middle; the tile she goes through is chosen when the legs are laid (`lurker_routes.tile_way()`): going in, the one nearest her, or one she left open within 2.5 m; coming out, the one nearest where she is going. A closed tile lets no sound through, and she sees nothing from the plenum.
- **Where she comes out**, by difficulty (the table): the tile is chosen by the brain from the survivor's position and facing (behind them, at the distance asked, the room they are in or the next one with a false ceiling), never in a lit room, never in an off-limits one.

## Order of work

1. Stage 1's dark by difficulty.
2. The numbers of the package (2, 4, 6), the long leap (7) and not stopped without light (3).
3. Out of the light at once (2), and fast when unseen (5).
4. The encounter of several attempts and the rest after it (6), coming out elsewhere (4) through the ways in she has today.
5. Any tile a way in and out, with the tile that opens and closes (3), and coming out behind the survivor through them.
6. Forced encounters (1).

Each with its checks (the fairness test keeps holding the warning to its rule with the new numbers) and verify green before its commit.
