# Portal note — 0.1.16 / 0.2.16 (follow-up in Gamer433 thread)

Thread: https://mods.factorio.com/mod/sushi-packer/discussion/6abb236eee95f227b880c3b2
Post after 0.1.16 / 0.2.16 is live on portal. Author posts. English.

---

Follow-up: 0.1.16 (Factorio 2.0) / 0.2.16 (Factorio 2.1) goes one step further. Hidden inserters now also put the finished stacks onto the belt in front, so the script no longer touches items in normal flow; it only checks each packer about twice per second.

Measured on my test machine (slow shared VM), 200 packers at full belt, script time per tick:

- yellow: 4.7 ms (0.1.14) → 1.5 ms (0.1.15) → 0.3 ms
- turbo: 17 ms → 4.6 ms → 0.3 ms
- 270 items/s belt: 53 ms → 11 ms → 0.4 ms
- your setup, 5 extreme packers: the packers' share is now too small to tell apart from the same scene with plain belts

What changes in game:

- items below one full stack wait in a hidden inserter hand; the packer window does not show them, the light does (it may lag a few seconds)
- a lane no longer limits itself to one stack per item, and stacks leave in no fixed order
- a packer passes up to about 1.6 times its own belt tier
- inserters next to a packer can take items from it again
- packers with pass-through filters, and games without the belt stacking feature, work as in 0.1.15
- fix: items held by the hidden inserters are no longer lost when a packer is mined or rotated
