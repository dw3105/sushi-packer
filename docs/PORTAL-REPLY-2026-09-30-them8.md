# Portal reply — "Error while loading" (them8)

Thread: https://mods.factorio.com/mod/sushi-packer/discussion/6abd72a34c791f3fbc708afc
Post after 0.1.14 / 0.2.14 is live on portal. Author posts (portal login). English.

---

Thanks for the screenshot, that made it easy to reproduce. Fixed in 0.1.14 (Factorio 2.0) / 0.2.14 (Factorio 2.1).

It was not Arig alone: Mining Drones Remastered adds its own collision layer to existing containers, including the sushi packers. The Arig hyper packer is created later, so it missed that layer, and Factorio refuses an upgrade (turbo → hyper packer) between boxes with different collision masks. Extra packer tiers now copy the collision mask from the top vanilla packer.

Your mod set (Arig + Mining Drones Remastered + aai-containers + Panglia) is now part of our load tests on both 2.0 and 2.1.
