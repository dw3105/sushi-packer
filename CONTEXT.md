# Sushi Packer — domain glossary

**Tier** — one packer model bound to one belt model. Vanilla tiers: yellow, red, blue, turbo.

**Extra tier** — tier bound to belt from another mod, listed in fixed extra-tier table. Exists only when that named mod is loaded and its belt, splitter, research all present. Belt at or below top vanilla tier speed gets no extra tier.

**Belt stack** — how many items one belt spot holds for a force. Comes only from research, from any mod; packer never raises it. Belt stack 1 = box passes items through, one by one.

**Tier rate** — max items per second box takes and gives per lane. Always equals its own belt's live speed; never set by packer itself.

**Own-role tier** — extra tier kept although its belt is no faster than top vanilla tier, because its belt does job vanilla belts cannot (e.g. Space Exploration space belt, works in space). Rate still = own belt speed.

**Tier chain** — order in which each box recipe needs box before it; upgrade planner follows same order. Main chain = belt speed order. Tier may name its own previous tier instead; that starts separate chain. Space Exploration: main chain yellow → red → blue (→ other mods' tiers by speed), separate chain space → deep space.

**Full flow** — both input lanes of box packed at belt speed with mixed items in belt stacks of 1 to 4, output never blocked.

**Bench row** — one tier, 200 boxes, full flow, belt stack 4. Standing rows: yellow, red, blue, turbo, fastest extra tier live for that game version.

**Root tier** — tier at start of chain; recipe needs no earlier box. Yellow; Space Exploration space tier.

**Packer** (also "box") — whole one-tile thing player places inline on belt. "Box" never means chest kind underneath.

**Lane store** — holding place inside packer, one per lane, for items waiting to become full belt stacks.

**Belt body** — packer that is itself belt piece: belt behind joins it like belt, it turns like belt, wire options are belt's own. Opposite: **chest body** (packer up to v1.16).

**Side-loading in** — belt pointing at packer's flank pushing items into it. **Sideways front** — belt in front of packer running across; packer pushes onto its near lane like belt does.

**Intake share** — what packer line takes in divided by what free belt beside it carries, same feed, same time. Below 1 = belt behind packer stands and goes ("jerks"). **Leftover** — items of one kind in lane store fewer than one belt stack.

**Kind cap** — most of one item kind (item + quality) one lane store may hold: one item stack (item's own stack size, e.g. 100 iron plates). Items already in arms' hands still arrive, so kind may pass cap a little (never more than 2 slots). Kind at cap is not taken from belt until store holds half a stack or less; belt behind waits meanwhile.
