# Requirement status

Filled by integrator after full suites. One row per requirement ID. Status per version: PASS / FAIL / NOT-TESTED (reason). Proof = test name.

| ID | 2.0 | 2.1 | Proof |
|---|---|---|---|
| T-1 | PASS | PASS | `LOAD-2.0`, `LOAD-2.1`, `FULL-2.0`, `FULL-2.1` — two zips (0.1.8 = 2.0, 0.2.8 = 2.1) load headless; full suites green on both (131 game each, 191 offline, dev-vm 2026-09-28); v10 (dev-vm 2026-09-29): space-age optional — sets `nosa`/`se`/`ab` (builtin_off, harness guard) `modtiers > box releases stacks at research bonus` + load-check 2.0/2.1 nosa/se ok; zips 0.1.11 / 0.2.11; full 139 game each |
| T-2 | NOT-TESTED | NOT-TESTED |  — NOT-TESTED: no save/load or multiplayer desync run; design: all state in `storage` (`core > box is plain data`), no pairs-order logic |
| E-1 | PASS | PASS | `belt_io > works in all four directions`, `lifecycle > placer becomes variant facing its direction` |
| E-2 | PASS | PASS | `data > variants are 48 slot not rotatable containers` |
| E-3 | PASS | PASS | `belt_io > behind finds belt moving into box`, `belt_io > push returns zero without front belt`, `tick > full box flushes oldest partial and loses nothing` |
| E-4 | PASS | PASS | `data > every tier has item placer variants and remnant`, `tick > red tier twice yellow throughput`; v10: `modtiers > box output matches belt rate` always measures blue (FND-0030 fixed, 225/225) + every chain tier every set |
| E-5 | PASS | PASS | `lifecycle > mining returns contents and hold to player`, `lifecycle > mining with full inventory spills rest`, `lifecycle > died box spills contents and hold` |
| E-6 | PASS | PASS | `tick > player removal reconciles next tick`, `tick > opened box reconciles next tick` — GUI shows contents: native container GUI |
| E-7 | PASS | PASS | `lifecycle > swap keeps inventory and settings`, `lifecycle > rotate input turns selected box`, `probe > rotated blueprint turns placer ghost` — Q-8: 4 variants + placer |
| E-8 | PASS | PASS | `tick > decon marked box stops, cancel resumes` (no intake, no output, LED off, resumes); offline `tick > decon *` (4) |
| E-9 | PASS | PASS | `lifecycle > box placed over belt replaces it`, `lifecycle > belt cannot replace box`, `probe > placer over belt replaces belt`, `probe > belt over placed box refused` (FND-0009) |
| C-1 | PASS | PASS | `core > same item on two lanes keeps two buffers`, `core > quality is separate buffer` |
| C-2 | PASS | PASS | `tick > releases at belt stack`, `tick > belt stack 1 passes through`; offline `tick > releases at belt stack`, `tick > item stack size caps release`, `tick > research raise changes next release size` — v6 |
| C-3 | PASS | PASS | `core > full stack becomes ready on its lane`, `tick > sushi in sorted stacks out` |
| C-4 | PASS | PASS | `core > ready stacks leave in ready order` |
| C-5 | PASS | PASS | `core > arrival after ready starts new partial` |
| C-6 | PASS | PASS | v8: `repro > box holds at most one stack per item per lane` (FND-0020, red on e5dfff1), `cap > ore stops at 50 per lane`, `cap > other lane same item unaffected`, `cap > modded stack size 7 honored`, `cap > quality separate`, `tick > sink passes item stack size to core` |
| L-1 | PASS | PASS | `tick > lanes kept end to end`, `belt_io > pull keeps lanes` |
| L-2 | PASS | PASS | v8: `quota > blocked lane never takes 25th slot`, `quota > other lane keeps 24 slots`, `core > counters track partial and ready per lane`, `core > counters rebuilt for old box` |
| L-3 | PASS | PASS | `repro > blocked left lane never starves right lane` (FND-0019, red on e5dfff1), `tick > blocked left lane does not stall right`, `tick > blocked lane does not stall other lane` |
| F-1 | PASS | PASS | v8: `quota > flush picks oldest partial same lane`, `core > oldest partial chosen across lanes`, `tick > full box flushes oldest partial and loses nothing` |
| F-2 | PASS | PASS | `core > full box flushes oldest partial and accepts zero` |
| F-3 | PASS | PASS | `tick > full box flushes oldest partial and loses nothing` |
| F-4 | PASS | PASS | v8: `core > all ready refuses input`, `quota > old box over quota drains` |
| O-1 | PASS | PASS | `belt_io > push inserts stacked item on matching lane` |
| O-2 | PASS | PASS | `tick > sushi in sorted stacks out`, `core > hold waits while stack run started` |
| O-3 | PASS | PASS | `belt_io > belt stack follows research up to engine max`, `belt_io > belt stack size follows research capped at engine max`, `tick > releases at modded belt stack 20` (test env mod max 20); v10 (V10-6): no stacking research → N = 1 unchanged; `modtiers > box releases stacks at research bonus` with and without space-age |
| O-4 | PASS | PASS | `tick > output never faster than tier`, `perf > credits per visit keep tier rate over 800 ticks`, `tick > rate cap holds with early wakes`, `tick > front item never rests at exit` (FND-0013) |
| O-5 | PASS | PASS | `tick > output stacked to research size` (50 ore → 12×4 out, 2 held), `sim > scene makes stacked output`; offline `tick > adopt uses belt stack` — v6 |
| S-1 | PASS | PASS | `tick > custom timeout flushes partial`, `core > timeout flushes old partial only` |
| S-2 | PASS | PASS | `data > timeout setting defaults to off`, `gui > custom timeout written to settings`, `tick > timeout ticks custom and global` |
| S-3 | PASS | PASS | `gui > opening box shows three sections`, `gui > item picked in slot saved as filter`, `gui > clearing slot writes false`, `tick > filtered item passes between stacks`; offline `gui > *` (15) — v6 |
| S-4 | PASS (undo/redo NOT-TESTED) | PASS (undo/redo NOT-TESTED) | `lifecycle > paste settings copies settings`, `lifecycle > blueprint stores placer with tags`, `lifecycle > rotated blueprint builds rotated box with settings`, `lifecycle > clone copies settings and box state` — undo/redo NOT-TESTED (no headless undo driver) |
| P-1 | PASS | PASS | `gui > editor sets comparator and quality on selected slot`; offline `filter > ≥ uncommon matches rare not normal`, `filter > all six comparators`, `tick > filter uses quality rule` — v6; v10: `gui > one quality hides picker`, `one quality filter saves item only`, `quality mod shows picker` |
| P-2 | PASS | PASS | `core > passthrough uses hold not slots` |
| P-3 | PASS | PASS | `core > hold busy refuses second passthrough`, `tick > filtered item passes between stacks` |
| N-1 | PASS | PASS | `circuit > wire connects to box` |
| N-2 | PASS | PASS | `circuit > box outputs contents with quality` |
| N-3 | PASS | PASS | `circuit > condition false disables`, `tick > circuit disable stops both ways and hides led`, `gui > circuit condition and flush written` |
| N-4 | PASS | PASS | `circuit > flush fires once per rising edge`, `gui > circuit condition and flush written` |
| U-1 | PASS | PASS | `data > every ingredient unlocked by prereq closure`, `data > tech cost is belt tech x 1.5`, `data > tech unlocks its recipe`; offline `data > tech prereqs include ingredient unlock techs`, `data > tech ingredients are union over prereqs` |
| U-2 | PASS | PASS | `data > recipes match table` (names, amounts, craft 30/45/60/120 s, crafting category) — Q-1 answered v5; v10: turbo tier only with space-age (`data extra > nosa no turbo tier`) |
| U-3 | PASS | PASS | `lifecycle > upgrade keeps state` (robot upgrade: settings, hold, items, wire, LED), `data > upgrade chain weight and no surface limit`, `probe > upgrade events`; offline `registry > *` (9) |
| U-4 | PASS | PASS | `data > upgrade chain weight and no surface limit` (20 kg, no `surface_conditions`), `data > recycling recipe exists`; v10: `modtiers > box placeable in se space` (SE scaffold, control belt blocked), `data extra > container allowed in se space` |
| U-5 | PASS | PASS | offline `locale > every prototype has name and description`, `locale > recipes and setting described`, `locale > tips entry has locale and prototype`, `locale > mod name and description`; `LOAD-2.0`, `LOAD-2.1` load tips prototype |
| U-6 | PASS | PASS | offline `stage > release info has no test dependency`, `stage > thumbnail is 144 by 144 png`, `stage > changelog format valid`, `stage > release ships thumbnail and changelog`; zip listing: deps `base >= 2.0.0`, `space-age` only |
| U-7 | PASS | PASS | `data > tiers sort yellow red blue turbo in own row`; offline `data > own subgroup row after belts`, `locale > vanilla style names`, `migration > maps every old name to new` — old-save load NOT-TESTED in engine (mapping tested offline) |
| U-8 | PASS (logic), look NOT-TESTED | PASS (logic), look NOT-TESTED | `sim > scene feeds both lanes with four kinds` + `sim > scene never stalls` (v1.4 author layout: box centered, machinery off frame, bottom pair one tile upstream); offline `sim > *` (8) — picture = author eyes |
| R-1 | PASS | NOT-TESTED | `make bench FV=2.0`: `script_ms_avg=4.493` (200 boxes, 3600 ticks, load avg 8.05, 2026-09-28 09:29 UTC, dev-vm, v8); budget ≤ 5 ms (R-1 v4) — 2.1: bench not run |
| R-2 | PASS | PASS | `tick > idle box sleeps 30 ticks`, `perf > yellow box visited every 8 ticks` |
| V-1 | PASS | PASS | `lifecycle > built box gets rec and green led` |
| V-2 | PASS | PASS | `core > new box is idle and green`, `tick > led green then yellow` |
| V-3 | PASS | PASS | `core > led yellow with items and red when full`, `tick > led green then yellow` |
| V-4 | PASS | PASS | v8: `quota > led red when one lane full`, `tick > full box flushes oldest partial and loses nothing` |
| V-5 | PASS | PASS | `perf > led checked every tick` |
| V-6 | PASS | PASS | `lifecycle > led set writes only on change` |
| V-7 | PASS | PASS | `lifecycle > built box gets rec and green led` — light drawn with sprite; night look NOT-TESTED visually |
| V-8 | PASS | PASS | `lifecycle > led destroyed with box`, `lifecycle > ensure recreates missing led` |
| G-1 | PASS (load), look NOT-TESTED | PASS (load), look NOT-TESTED | `LOAD-2.0`, `LOAD-2.1` — files load; visual look NOT-TESTED (author eyes) |
| G-2 | PASS (load), look NOT-TESTED | PASS (load), look NOT-TESTED | `LOAD-2.0`, `LOAD-2.1` — files load; visual look NOT-TESTED (author eyes) |
| G-3 | PASS (load), look NOT-TESTED | PASS (load), look NOT-TESTED | `LOAD-2.0`, `LOAD-2.1` — files load; visual look NOT-TESTED (author eyes) |
| G-4 | PASS (load), look NOT-TESTED | PASS (load), look NOT-TESTED | `LOAD-2.0`, `LOAD-2.1` — files load; visual look NOT-TESTED (author eyes) |
| G-5 | PASS (load), look NOT-TESTED | PASS (load), look NOT-TESTED | `LOAD-2.0`, `LOAD-2.1` — files load; visual look NOT-TESTED (author eyes) |
| G-6 | PASS (load), look NOT-TESTED | PASS (load), look NOT-TESTED | `LOAD-2.0`, `LOAD-2.1` — files load; visual look NOT-TESTED (author eyes) |
| G-7 | PASS (load), look NOT-TESTED | PASS (load), look NOT-TESTED | `LOAD-2.0`, `LOAD-2.1` — files load; visual look NOT-TESTED (author eyes) |
| G-8 | PASS (load), look NOT-TESTED | PASS (load), look NOT-TESTED | `LOAD-2.0`, `LOAD-2.1` — files load; visual look NOT-TESTED (author eyes) |
| G-9 | PASS (load), look NOT-TESTED | PASS (load), look NOT-TESTED | `LOAD-2.0`, `LOAD-2.1` — files load; visual look NOT-TESTED (author eyes) |

Runs 2026-09-26 on `dev-vm`, tree `int/v1` `75de299`: `make test FV=2.0` → `full-2.0-ok`, `make test FV=2.1` → `full-2.1-ok` (each 77 offline + 88 headless game tests). Zips `sushi-packer_0.1.0.zip` (sha256 `5a1852be…`) and `sushi-packer_0.2.0.zip` (sha256 `93f0d49e…`) load headless (`load-check-2.0-ok`, `load-check-2.1-ok`). Author checks in real game: G- look, V-7 night light, S-4 undo/redo, T-2 multiplayer/save-load.

Runs v1.1 2026-09-26 on `dev-vm`, tree `int/v1.1`: `make test FV=2.0` → `full-2.0-ok`, `make test FV=2.1` → `full-2.1-ok` (each 106 offline + 92 headless game tests). Zips `sushi-packer_0.1.1.zip` (sha256 `bff8a50d…`) and `sushi-packer_0.2.1.zip` (sha256 `4fca5d68…`) load headless (`load-check-2.0-ok`, `load-check-2.1-ok`). Author checks in real game still open: G- look, V-7 night light, S-4 undo/redo, T-2 multiplayer/save-load; new: tech tree placement, tips text, upgrade planner by hand.

Runs v1.2 2026-09-26 on `dev-vm`, tree `int/v1.2`: `make test FV=2.0` → `full-2.0-ok`, `make test FV=2.1` → `full-2.1-ok` (96 game tests each + offline). Zips `sushi-packer_0.1.2.zip` (sha256 `2a26543c…`), `sushi-packer_0.2.2.zip` (sha256 `0c12df68…`) load headless. Author checks: Factoriopedia + tip scene look, GUI look, belt swap by hand, old save load.

Runs v1.3 2026-09-26 23:48 on `dev-vm`, tree `int/v1.3`: `full-2.0-ok`, `full-2.1-ok` (101 game tests each + offline). Zips `sushi-packer_0.1.3.zip` (sha256 `0ba405f9…`), `sushi-packer_0.2.3.zip` (sha256 `ae1fa447…`) load headless. Open: author one-lane report (FND-0011) not reproduced in 4 layouts (`tick > north turbo box moves both lanes*`); waiting for author save.

## v9 modded belt tiers (§17), 2026-09-28, dev-vm, `int/v9`

Mod sets (`make test-modsets`): 2.0 arig, hyarion, arig-off, k2so, arig-k2so, bob, ubsa, bb; 2.1 arig, hyarion, k2so, arig-k2so, bob (arig-off 2.0 only, FND-0023). Each set: 5 of 5 `tests/game/test_modtiers.lua` passed. Vanilla full: `full-2.0-ok`, `full-2.1-ok` (137 game each).

| ID | 2.0 | 2.1 | Evidence |
|---|---|---|---|
| M-1 | PASS | PASS | `modtiers > active tiers match installed mods` (every set); arig-off (2.0): no hyper tier, no error; offline `data extra > hidden belt skipped`, `belt tech without unit skipped`, `missing tech skipped`, `k2so hidden advanced belt ignored`; v10: owner gate + splitter check (`data extra > owner missing row skipped`, `ab-sa ub-ultimate not live`, `splitter missing row skipped logged`); sets `se`, `ab`, `ab-sa` green (FND-0027 fixed) |
| M-2 | PASS | PASS | offline `data extra > vanilla prototypes identical to v8` (golden at `lanes-base-v9`); vanilla full suites incl. `data > *`; `modtiers > active tiers match installed mods` vanilla = 4; v10: golden regenerated once (+ `se_allow_in_space` x16 only); no-SA = yellow/red/blue (`data extra > nosa no turbo tier`) |
| M-3 | PASS | PASS | `data-final-fixes.lua` -> `prototypes/extra.lua`; `data extra > info lists belt mods as visible optional deps` (author 2026-09-28: visible, shown on portal) |
| M-4 | PASS | PASS | `modtiers > upgrade chain follows belt speed` (every set; arig-k2so turbo -> hyper -> superior; ubsa 5 tiers); `modtiers > upgrade turbo to next tier keeps state`; offline `data extra > all mods sorted by speed tie by row order`; v10: chain after top vanilla (`data extra > nosa extras chain after blue`, `se deep space after blue`, `speed at or below top vanilla skipped`); `modtiers > upgrade top vanilla to next tier keeps state`; FND-0029 box copy |
| M-5 | PASS | PASS | `modtiers > tech unlocks recipe and every ingredient reachable`; offline `data extra > recipe chains previous tier`, `tech prereqs belt tech previous tier and ingredient unlocks`, `tech cost belt count x 1.5 and pack union`; v10: no-SA recipe (`data extra > nosa extra recipe bulk inserter processing unit`, `sa extra recipe unchanged`); `modtiers > tech unlocks recipe...` 60 s without SA |
| M-6 | PASS | PASS | `modtiers > box output matches belt rate` per lane over 600 ticks: turbo 300/300, hyper 375/375, superior 450/450, bob 375/375, ub 450/675/900/1125/1350 exact, bb 478/480 (2.0); FND-0022, FND-0024; offline `tick extra > *`, `belt_io fast > *` |
| M-7 | PASS | PASS | author approved preview 2026-09-28 ("art ok"): 9 tiers, paint from mod underground icons calibrated to G-2, wear 0.40; files load in `load-check` both builds |
| M-8 | PASS | PASS | offline `locale extra > names mirror belt names`, `descriptions name source mod`; `modtiers > upgrade chain follows belt speed` (item order after turbo); v10: 5 new names (`locale extra > names mirror belt names`) |
| M-9 | PASS (existing rule) | PASS | `lifecycle > configuration changed drops invalid recs` (engine removes entities of missing prototypes); no removed-mod save load run — NOT-TESTED end to end |
| R-1 | over budget under load | NOT-TESTED | v9 A/B same load (avg ~21, 21:53-21:58): v8 10.837 / 7.617 ms, v9 7.798 / 7.257 ms -> no regression; clean rerun pending |

| R-1 | FAIL (v10) | NOT-TESTED | v10 A/B vs v1.10 (dev-vm 2026-09-29, loads 14-28, `make bench FV=2.0`): v10 9.481 / 7.073 / 14.517 ms vs v1.10 8.600 / 5.390 / 6.965 ms -> regression (FND-0031, V10-7 take window on yellow). Shipped by author (V10-8). UNMET Done-when #8 (plan v10): "bench no regression vs v1.10". Deferred by ruling 2026-09-29 until dev-vm free. |
| M-4 (v11) | PASS | PASS | `modtiers > upgrade chain follows belt speed` per chain (set `se`: blue last of main, space -> deep space; every set); offline `data extra > se chain space root then deep space`, `after target inactive skips row`, `se plus k2 two chains`, `own_role keeps slow row` (root); full `full-2.0-ok` / `full-2.1-ok` 140 game each, `test-modsets-2.0-ok` (12 sets), `test-modsets-2.1-ok` (7 sets), dev-vm 2026-09-29 |
| M-5 / U-1 (v11) | PASS | PASS | `modtiers > root tier recipe and tech have no previous box` (set `se`: steel-chest 1, se-space-splitter 1, bulk-inserter 4, processing-unit 10, 60 s; no sushi-packer tech prereq; count = belt tech x 1.5); offline `data extra > se space root recipe`, `se space root tech`, `se deep space recipe needs space box` |
| U-3 (v11) | PASS | PASS | offline `data extra > upgrade chain from top vanilla` (set `se`: blue next_upgrade nil, space -> deep space), `se plus k2 two chains`; `modtiers > upgrade chain follows belt speed` per chain |
| E-4 / M-6 (v11) | PASS | PASS | `modtiers > box output matches belt rate` set `se` 2.0 (SE 0.7.57) + 2.1 (SE 0.7.62): se-space 225/225 per lane (45/s), deep space 450/450, blue 225/225; probe `probe v10 rate` (temp index, SP-10) after FND-0031 fix: yellow 75/75, red 150/150, blue 225/225, turbo 300/300 both builds |
| U-5 (v11) | PASS | PASS | offline `locale de > same keys as en`, `no empty value`, `tier names end with Sushi-Packer`, `names follow table`, `same parameters as en`, `vanilla German terms`; `locale extra > se space name`; load-check 2.0/2.1 vanilla/nosa/se + 2.0 ab zero errors |
| M-7 (v11) | PASS | PASS | author "art ok" 2026-09-29 on `v11-space-preview.png` (se-space 215,215,215 wear 0.40, V11-11); files load in load-check both builds |
| R-1 (v11) | PASS | NOT-TESTED | v1.12 `make bench FV=2.0` 10 runs 3.777-4.165 ms (<= 5 ms, dev-vm 2026-09-29, load 3.9-6.2); vs v1.10 slower 6/6 pairs x1.09..x1.23, no code cause found (FND-0031, V11-12); 2.1 bench not run |
