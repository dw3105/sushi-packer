# Portal note — 0.1.17 / 0.2.17

Post after 0.1.17 / 0.2.17 is live on portal. Author posts. English. Numbers: dev-vm (4 vCPU cloud VM), 2026-10-02, headless bench, 200 packers at full flow; see `docs/FINDINGS.md` FND-0049.

---

0.1.17 (Factorio 2.0) / 0.2.17 (Factorio 2.1): the sushi packer is now a belt piece instead of a chest.

- Belts join it like a belt, and R rotates it like a belt.
- Circuit network works as on a belt: enable condition and "read contents" are the belt's own settings, so copy-paste, blueprints and the upgrade planner carry them. Read contents shows everything stored inside and is on by default.
- A belt running across in front of the packer gets the stacks on its near lane. A belt pointing at the packer's side puts nothing in.
- Inserters next to it behave as with a belt: what they drop gets packed; they can take only what lies on the belt piece, not stored items.
- It has its own window (click it). Items shown there can not be taken by hand any more; mine the packer to get them.
- Packers in existing saves and blueprints are converted on load: items, settings and wires are kept.
- Fixed: a packer rotated or upgraded with nothing in front could drop a few stored items on the ground.

Speed is the same as 0.1.16 on vanilla belts. On one very fast modded belt (270 items/s) script time per 200 packers went from 0.38 ms to 0.45 ms.

0.1.18 / 0.2.18 (same day): fixes one case of 0.1.17 - with a belt running across in front of the packer, a few leftover items could stay inside for good.
