# Portal reply — "Belt implementations", UPS (Gamer433)

Thread: https://mods.factorio.com/mod/sushi-packer/discussion/6abb236eee95f227b880c3b2
Post after 0.1.15 / 0.2.15 is live on portal. Author posts (portal login). English.

---

You were right, and thanks for measuring it. The figure I gave before (about 0.02 ms per packer) was for yellow packers only. Fast packers move many more items, and the old packer paid script time for every single item, so fast tiers cost far more.

0.1.15 (Factorio 2.0) / 0.2.15 (Factorio 2.1) changes how the packer works inside: hidden inserters now pull the items in (the game engine does that, no script), one set per belt lane, and the script only pushes finished stacks out. Lanes stay separate as before.

Measured on my test machine (a slow shared VM), packers at full belt, script time before → after:

- your setup (Space Exploration + Advanced Belts 2.0 + Belt Speed Multiplier ×2 + SE stacking), 5 extreme packers: about 1.0 ms → 0.4 ms in total, of which the packers themselves about 0.85 ms → 0.25 ms
- 200 yellow packers: 5.1 ms → 1.7 ms
- 200 turbo packers: 20 ms → 5.6 ms
- 200 packers on a 270 items/s belt: 61 ms → 13.5 ms

So roughly 3 to 4 times less script time, on every tier. Your PC should show smaller numbers than these.

What you will notice in game:

- the packer window now shows two rows, left lane and right lane; click a slot to take the items
- each lane holds 12 slots (was 24)
- packers in existing saves keep all their items; those leave first
- everything else (stacking, filters, flush timer, circuit, upgrade planner) works as before

It is still a scripted box, so it is not free: a packer costs script time for every stack it sends out. If you build a big setup, I would be glad to see your numbers again.
