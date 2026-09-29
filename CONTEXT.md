# Sushi Packer — domain glossary

**Tier** — one packer model bound to one belt model. Vanilla tiers: yellow, red, blue, turbo.

**Extra tier** — tier bound to belt from another mod, listed in fixed extra-tier table. Exists only when that named mod is loaded and its belt, splitter, research all present. Belt at or below top vanilla tier speed gets no extra tier.

**Belt stack** — how many items one belt spot holds for a force. Comes only from research, from any mod; packer never raises it. Belt stack 1 = box passes items through, one by one.

**Tier rate** — max items per second box takes and gives per lane. Always equals its own belt's live speed; never set by packer itself.

**Own-role tier** — extra tier kept although its belt is no faster than top vanilla tier, because its belt does job vanilla belts cannot (e.g. Space Exploration space belt, works in space). Rate still = own belt speed.

**Tier chain** — order in which each box recipe needs box before it; upgrade planner follows same order. Main chain = belt speed order. Tier may name its own previous tier instead; that starts separate chain. Space Exploration: main chain yellow → red → blue (→ other mods' tiers by speed), separate chain space → deep space.

**Root tier** — tier at start of chain; recipe needs no earlier box. Yellow; Space Exploration space tier.
