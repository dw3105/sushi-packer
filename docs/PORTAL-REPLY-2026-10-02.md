# Portal reply — "Belt implementations", UPS (Gamer433), with 0.1.21 / 0.2.21

Thread: https://mods.factorio.com/mod/sushi-packer/discussion/6abb236eee95f227b880c3b2
Post now: 0.1.21 / 0.2.21 are live on portal (2026-10-02 21:10 UTC; portal went 0.1.14 -> 0.1.21). Author posts (portal login). English.
Replaces unposted drafts `PORTAL-REPLY-2026-10-01.md` and `PORTAL-NOTE-2026-10-02.md`.
Numbers: dev-vm (4 vCPU shared cloud VM), 2026-10-02 21:14-21:23 UTC, load1 2.2..5.9, `tools/bench/run.sh 2.0 --tier ab-extreme --modset g433 --flow stacks --boxes 5`, three rounds each of 0.1.21, same scene with plain belts (`--belt-only`), 0.1.14 (`~/.cache/sushi-packer/v21/logs/player-rig.txt`).

---

You were right, and thanks for measuring it. The figure I gave before (about 0.02 ms per packer) was for yellow packers only. The old packer paid script time for every single item, so fast packers cost far more.

0.1.21 (Factorio 2.0) / 0.2.21 (Factorio 2.1) is on the portal now, and the packer works differently inside: hidden inserters pull the items in and put the finished stacks out, one set per belt lane. That is the game engine's work, not script. The script only looks at each packer about twice per second.

I rebuilt your setup (Space Exploration + Advanced Belts 2.0 + Belt Speed Multiplier x2 + SE stacking, 5 extreme packers at full belt) and measured script time per tick on my test machine, a slow shared VM:

- 0.1.14: 0.83 to 1.03 ms
- 0.1.21: 0.13 to 0.15 ms
- the same scene with plain belts instead of packers: 0.11 to 0.13 ms (that is Space Exploration and the other mods)

So the five packers themselves went from about 0.8 ms to about 0.02 ms. Whole update time of the scene with packers was the same as with plain belts, within noise. Your PC should show smaller numbers than these; I would be glad to see them.

It is still not free: the hidden inserters are real entities, so a packer costs a little entity update time instead. On belts above 144 items/s (your extreme belt at x2 is one) a packer carries a few more of them.

What you will notice in game:

- The packer is now a belt piece, not a chest: belts join it like a belt, R rotates it, circuit conditions and "read contents" are the belt's own settings.
- It has its own window. It shows what is stored per lane, 24 kinds per lane, with quality. Stored items can no longer be taken by hand; mine the packer to get them.
- Packers in your save and in blueprints are converted on load. Items, settings and wires are kept.
- Fixed on the way: items piling up inside with many kinds or qualities, and the belt in front of a packer moving in jerks.

One known limit: on belts faster than the turbo belt that carry more than 24 item kinds per lane, the belt in front of a packer can still back up.
