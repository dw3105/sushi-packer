# Requirement status

Filled by integrator after full suites. One row per requirement ID. Status per version: PASS / FAIL / NOT-TESTED (reason). Proof = test name.

| ID | 2.0 | 2.1 | Proof |
|---|---|---|---|
| T-1 | PASS | PASS | `LOAD-2.0`, `LOAD-2.1`, `FULL-2.0`, `FULL-2.1` — two zips (0.1.3 = 2.0, 0.2.3 = 2.1) load headless; full suites green on both |
| T-2 | NOT-TESTED | NOT-TESTED |  — NOT-TESTED: no save/load or multiplayer desync run; design: all state in `storage` (`core > box is plain data`), no pairs-order logic |
| E-1 | PASS | PASS | `belt_io > works in all four directions`, `lifecycle > placer becomes variant facing its direction` |
| E-2 | PASS | PASS | `data > variants are 48 slot not rotatable containers` |
| E-3 | PASS | PASS | `belt_io > behind finds belt moving into box`, `belt_io > push returns zero without front belt`, `tick > full box flushes oldest partial and loses nothing` |
| E-4 | PASS | PASS | `data > every tier has item placer variants and remnant`, `tick > red tier twice yellow throughput` |
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
| L-1 | PASS | PASS | `tick > lanes kept end to end`, `belt_io > pull keeps lanes` |
| L-2 | PASS | PASS | `core > used slots counts ready and partials` |
| L-3 | PASS | PASS | `tick > blocked left lane does not stall right`, `tick > blocked lane does not stall other lane` |
| F-1 | PASS | PASS | `core > oldest partial chosen across lanes`, `tick > full box flushes oldest partial and loses nothing` |
| F-2 | PASS | PASS | `core > full box flushes oldest partial and accepts zero` |
| F-3 | PASS | PASS | `tick > full box flushes oldest partial and loses nothing` |
| F-4 | PASS | PASS | `core > all ready refuses input` |
| O-1 | PASS | PASS | `belt_io > push inserts stacked item on matching lane` |
| O-2 | PASS | PASS | `tick > sushi in sorted stacks out`, `core > hold waits while stack run started` |
| O-3 | PASS | PASS | `tick > output stacked to research size`, `belt_io > belt stack size follows research capped at 4`, `tick > on research caches belt stack size` |
| O-4 | PASS | PASS | `tick > output never faster than tier`, `perf > credits per visit keep tier rate over 800 ticks` |
| O-5 | PASS | PASS | `tick > output stacked to research size` (50 ore → 12×4 out, 2 held), `sim > scene makes stacked output`; offline `tick > adopt uses belt stack` — v6 |
| S-1 | PASS | PASS | `tick > custom timeout flushes partial`, `core > timeout flushes old partial only` |
| S-2 | PASS | PASS | `data > timeout setting defaults to off`, `gui > custom timeout written to settings`, `tick > timeout ticks custom and global` |
| S-3 | PASS | PASS | `gui > opening box shows three sections`, `gui > item picked in slot saved as filter`, `gui > clearing slot writes false`, `tick > filtered item passes between stacks`; offline `gui > *` (15) — v6 |
| S-4 | PASS (undo/redo NOT-TESTED) | PASS (undo/redo NOT-TESTED) | `lifecycle > paste settings copies settings`, `lifecycle > blueprint stores placer with tags`, `lifecycle > rotated blueprint builds rotated box with settings`, `lifecycle > clone copies settings and box state` — undo/redo NOT-TESTED (no headless undo driver) |
| P-1 | PASS | PASS | `gui > editor sets comparator and quality on selected slot`; offline `filter > ≥ uncommon matches rare not normal`, `filter > all six comparators`, `tick > filter uses quality rule` — v6 |
| P-2 | PASS | PASS | `core > passthrough uses hold not slots` |
| P-3 | PASS | PASS | `core > hold busy refuses second passthrough`, `tick > filtered item passes between stacks` |
| N-1 | PASS | PASS | `circuit > wire connects to box` |
| N-2 | PASS | PASS | `circuit > box outputs contents with quality` |
| N-3 | PASS | PASS | `circuit > condition false disables`, `tick > circuit disable stops both ways and hides led`, `gui > circuit condition and flush written` |
| N-4 | PASS | PASS | `circuit > flush fires once per rising edge`, `gui > circuit condition and flush written` |
| U-1 | PASS | PASS | `data > every ingredient unlocked by prereq closure`, `data > tech cost is belt tech x 1.5`, `data > tech unlocks its recipe`; offline `data > tech prereqs include ingredient unlock techs`, `data > tech ingredients are union over prereqs` |
| U-2 | PASS | PASS | `data > recipes match table` (names, amounts, craft 30/45/60/120 s, crafting category) — Q-1 answered v5 |
| U-3 | PASS | PASS | `lifecycle > upgrade keeps state` (robot upgrade: settings, hold, items, wire, LED), `data > upgrade chain weight and no surface limit`, `probe > upgrade events`; offline `registry > *` (9) |
| U-4 | PASS | PASS | `data > upgrade chain weight and no surface limit` (20 kg, no `surface_conditions`), `data > recycling recipe exists` |
| U-5 | PASS | PASS | offline `locale > every prototype has name and description`, `locale > recipes and setting described`, `locale > tips entry has locale and prototype`, `locale > mod name and description`; `LOAD-2.0`, `LOAD-2.1` load tips prototype |
| U-6 | PASS | PASS | offline `stage > release info has no test dependency`, `stage > thumbnail is 144 by 144 png`, `stage > changelog format valid`, `stage > release ships thumbnail and changelog`; zip listing: deps `base >= 2.0.0`, `space-age` only |
| U-7 | PASS | PASS | `data > tiers sort yellow red blue turbo in own row`; offline `data > own subgroup row after belts`, `locale > vanilla style names`, `migration > maps every old name to new` — old-save load NOT-TESTED in engine (mapping tested offline) |
| U-8 | PASS (logic), look NOT-TESTED | PASS (logic), look NOT-TESTED | `sim > scene feeds both lanes with four kinds` (v1.3 author layout: left lane coal + circuit, right lane iron + copper, 4-stacks out both lanes); offline `sim > *` (7) — picture = author eyes |
| R-1 | PASS | NOT-TESTED | `make bench FV=2.0`: `script_ms_avg=2.407` (200 boxes, 3600 ticks, load avg 1.85, 2026-09-26 23:48, `legalcopilot-dev`, v1.3); v1.2 4.071 at load 8.84; budget ≤ 5 ms (R-1 v4) — 2.1: bench not run |
| R-2 | PASS | PASS | `tick > idle box sleeps 30 ticks`, `perf > yellow box visited every 8 ticks` |
| V-1 | PASS | PASS | `lifecycle > built box gets rec and green led` |
| V-2 | PASS | PASS | `core > new box is idle and green`, `tick > led green then yellow` |
| V-3 | PASS | PASS | `core > led yellow with items and red when full`, `tick > led green then yellow` |
| V-4 | PASS | PASS | `tick > full box flushes oldest partial and loses nothing` |
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

Runs 2026-09-26 on `legalcopilot-dev`, tree `int/v1` `75de299`: `make test FV=2.0` → `full-2.0-ok`, `make test FV=2.1` → `full-2.1-ok` (each 77 offline + 88 headless game tests). Zips `sushi-packer_0.1.0.zip` (sha256 `5a1852be…`) and `sushi-packer_0.2.0.zip` (sha256 `93f0d49e…`) load headless (`load-check-2.0-ok`, `load-check-2.1-ok`). Author checks in real game: G- look, V-7 night light, S-4 undo/redo, T-2 multiplayer/save-load.

Runs v1.1 2026-09-26 on `legalcopilot-dev`, tree `int/v1.1`: `make test FV=2.0` → `full-2.0-ok`, `make test FV=2.1` → `full-2.1-ok` (each 106 offline + 92 headless game tests). Zips `sushi-packer_0.1.1.zip` (sha256 `bff8a50d…`) and `sushi-packer_0.2.1.zip` (sha256 `4fca5d68…`) load headless (`load-check-2.0-ok`, `load-check-2.1-ok`). Author checks in real game still open: G- look, V-7 night light, S-4 undo/redo, T-2 multiplayer/save-load; new: tech tree placement, tips text, upgrade planner by hand.

Runs v1.2 2026-09-26 on `legalcopilot-dev`, tree `int/v1.2`: `make test FV=2.0` → `full-2.0-ok`, `make test FV=2.1` → `full-2.1-ok` (96 game tests each + offline). Zips `sushi-packer_0.1.2.zip` (sha256 `2a26543c…`), `sushi-packer_0.2.2.zip` (sha256 `0c12df68…`) load headless. Author checks: Factoriopedia + tip scene look, GUI look, belt swap by hand, old save load.

Runs v1.3 2026-09-26 23:48 on `legalcopilot-dev`, tree `int/v1.3`: `full-2.0-ok`, `full-2.1-ok` (101 game tests each + offline). Zips `sushi-packer_0.1.3.zip` (sha256 `0ba405f9…`), `sushi-packer_0.2.3.zip` (sha256 `ae1fa447…`) load headless. Open: author one-lane report (FND-0011) not reproduced in 4 layouts (`tick > north turbo box moves both lanes*`); waiting for author save.
