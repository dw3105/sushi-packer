# Portal reply — "Bug: Crash when selecting new contents for blueprint saved in blueprint library" (Gammel2012)

Thread: https://mods.factorio.com/mod/sushi-packer/discussion/6abcbd58f00bbe9ee51d2831
Post after 0.1.13 / 0.2.13 is live on portal. Author posts (portal login). English.

---

Thanks for the report, reproduced and fixed in 0.1.13 (Factorio 2.0) / 0.2.13 (Factorio 2.1).

Cause: for a blueprint in the library the game hands the mod a library record instead of an item stack, and the mod asked it a question only item stacks answer. Now the mod checks which one it got first. Library blueprints get the same treatment as inventory ones: packers are stored with their settings.

If it still crashes for you, please post the error text here.
