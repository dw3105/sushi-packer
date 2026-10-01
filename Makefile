# sushi-packer - build and gate. `make help` lists targets.
SHELL := /bin/bash
.DEFAULT_GOAL := help
FV ?= 2.0
# Exact label only (gateslot looks weights up by exact label). Lane checks call tools/run_tests.sh direct.
GATE := $(if $(shell command -v gateslot),gateslot --label sushi-packer/heavy --,)

.PHONY: help factorio test test-one test-modsets ci-collect skill-lint skill-check skill-install zip load-check bench verify

help: ## List targets
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "%-14s %s\n", $$1, $$2}'

factorio: ## Download headless Factorio FV=2.0 (2.0.77) or FV=2.1 (2.1.20) into ~/factorio-$(FV)
	tools/fetch_factorio.sh $(FV)

test: ## FULL suite on FV (queues in gateslot). Integrator only; lanes never run this
	$(GATE) tools/run_tests.sh $(FV) --full

test-one: ## One test only: make test-one FV=2.0 T='tests/game/test_probe.lua::probe > placer keeps direction'
	@test -n "$(T)" || { echo "usage: make test-one FV=<2.0|2.1> T='<file>::<describe> > <it>'" >&2; exit 2; }
	$(if $(MODSET),tools/fetch_mods.py fetch $(FV) $(MODSET) &&) MODSET=$(MODSET) $(GATE) tools/run_tests.sh $(FV) '$(T)'

ci-collect: ## List offline test names, runs nothing
	@for f in tests/offline/test_*.lua; do grep -oE '(describe|it)\("[^"]+"' $$f | sed "s|^|$$f: |"; done

skill-lint: ## Estate skill lint on skills/
	/usr/local/bin/lint_skill.py --all skills --budget 10000 --register --citations --token-gate=measure

skill-check: ## Fail if live ~/.claude/skills/sushi-packer-code drifted from repo copy
	python3 ~/skills/tools/skill_install.py --src skills/sushi-packer-code --live ~/.claude/skills/sushi-packer-code --check --allow-missing-live

skill-install: ## Copy repo skill live; refuses unless on main with clean skills/
	@test "$$(git rev-parse --abbrev-ref HEAD)" = main || { echo "skill-install: refuse, branch not main"; exit 1; }
	@test -z "$$(git status --porcelain -- skills/sushi-packer-code)" || { echo "skill-install: refuse, uncommitted skill changes"; exit 1; }
	python3 ~/skills/tools/skill_install.py --src skills/sushi-packer-code --live ~/.claude/skills/sushi-packer-code --force
	$(MAKE) skill-check

zip: ## Build both release zips into build/
	tools/make_zip.sh 2.0 && tools/make_zip.sh 2.1

load-check: ## Headless load of release files on FV, zero errors. MODSET=<set> adds belt mods (tools/modsets.json)
	$(if $(MODSET),tools/fetch_mods.py fetch $(FV) $(MODSET) &&) MODSET=$(MODSET) tools/load_check.sh $(FV)

test-modsets: ## v9: tests/game/test_modtiers.lua once per mod set of FV (fetch + run). Integrator only
	@set -e; for s in $$(python3 -c "import json,sys; d=json.load(open('tools/modsets.json')); print(' '.join(k for k,v in d.items() if not k.startswith('_') and '$(FV)' in v['fv'] and not v.get('bench_only')))"); do \
	  tools/fetch_mods.py fetch $(FV) $$s; echo "== modset $$s"; MODSET=$$s $(GATE) tools/run_tests.sh $(FV) --modtiers || fail="$$fail $$s"; done; \
	  test -z "$$fail" || { echo "test-modsets-$(FV) FAIL:$$fail"; exit 1; }; echo "test-modsets-$(FV)-ok"

bench: ## R-1: 200 boxes, script ms/tick on FV (lane H fills tools/bench/)
	$(GATE) tools/bench/run.sh $(FV)

verify: ## Gate before merge to main: skill lint + both full suites + skill drift
	$(MAKE) skill-lint
	$(MAKE) test FV=2.0
	$(MAKE) test FV=2.1
	$(MAKE) skill-check
