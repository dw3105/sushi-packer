# Rulings

Standing operator instructions, one dated row each (session-lifecycle SS-08). Newest last.

| Date | Ruling | Source |
|---|---|---|
| 2026-09-29 | `~/share` holds only files the author asked for or files presented to the author (e.g. one preview PNG). Logs, probe output, renders, fetched zips, helper scripts, tool inputs go to `~/.cache/sushi-packer/` or the session scratchpad; no tool reads from `~/share`. | author: "DO NOT STORE TEMP FILES IN ~/share !!!!", "~/share is only for specific files I asked or you want to present to me!" |
| 2026-09-29 | FND-0031 (bench cost of V10-7) is fixed later, when dev-vm is free; not before. | author: "we fix this later when box is free" |
| 2026-09-29 | Grill sessions ask ONE question per turn (with recommendation), never a numbered batch. | author: "ONE AT A TIME" |
| 2026-09-30 | Bug fix plans: bug reproduced red by headless Factorio (or author in-game error text) before any fix; every plan includes headless Factorio testing. | author: "before fixing the bug must be reproduced by headless factorio", "plan must include headless factorio testing" |
| 2026-10-01 | Arms box (v1.15): no more questions to author until everything is coded and tested. Integrator decides open details and records them in `docs/DECISIONS.md`; report comes after green suites. | author: "NO MORE QUESTIONS UNTIL EVERYTHING IS CODED AND TESTED" |
| 2026-10-02 | Text for author to post somewhere (portal reply, forum, note) is written straight into chat as one plain block, ready to copy. Never a shell box that fetches or prints it. | author: "wtf are you doing?! just output the answer here and I copy-paste it!" |
| 2026-10-04 | Grill questions use full format: `❓ **Qn** - **title**: body` with options, then `➡️` recommendation with reason; explain each question very simply (what happens today, what changes, cost). One question per turn still holds. | author: "FORMAT QUESTIONS PROPERLY!!!!", "explain Q3 very simply" |
