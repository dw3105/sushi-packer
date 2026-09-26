# Sushi Packer

Sushi Packer is a 1×1 inline belt box for mixed item belts. It keeps the two belt lanes separate, gathers each item type until it reaches a full item stack, then sends that stack forward. After belt capacity research, the output travels as stacked belt items. The box preserves the lane each item entered on.

## Tiers and recipes

Each tier matches a belt speed. Recipes are crafted in the crafting category, by hand or in an assembler.

| Tier | Ingredients | Craft time | Unlock |
| --- | --- | ---: | --- |
| Yellow | 1 steel chest, 1 splitter, 2 inserters, 5 electronic circuits | 30 s | Sushi packer (yellow) |
| Red | 1 yellow sushi packer, 1 fast splitter, 2 fast inserters, 5 advanced circuits | 45 s | Sushi packer (red) |
| Blue | 1 red sushi packer, 1 express splitter, 2 bulk inserters, 5 processing units | 60 s | Sushi packer (blue) |
| Turbo | 1 blue sushi packer, 1 turbo splitter, 2 stack inserters, 2 quantum processors | 120 s | Sushi packer (turbo) |

Each box tier unlocks from its matching belt technology and the recipe ingredient technologies. The red, blue, and turbo boxes also require the previous box tier's technology.

## Settings

The map setting **Sushi packer flush timeout** sets the default age, in seconds, at which a partial stack is flushed. Set it to `0` to disable the timeout. Each placed box can use the map default or its own timeout. Boxes also support item filters, circuit conditions, and a circuit flush signal.

## Factorio versions

The source supports two builds: Factorio 2.0 uses mod version `0.1.1`; Factorio 2.1 uses mod version `0.2.1`. Both builds require the Space Age expansion for belt stacking and quality support.
