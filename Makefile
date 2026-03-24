########################
### Makefile Helpers ###
########################

BOLD := \033[1m
CYAN := \033[36m
RESET := \033[0m

REPO_SKILLS := $(CURDIR)/skills
ALL_TARGETS := $(HOME)/.claude/skills $(HOME)/.gemini/antigravity/skills $(HOME)/.codex/skills

.PHONY: help
.DEFAULT_GOAL := help
help: ## List all targets
	@echo ""
	@echo "$(BOLD)$(CYAN)gstack$(RESET)"
	@echo ""
	@grep -h -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "$(CYAN)%-20s$(RESET) %s\n", $$1, $$2}'
	@echo ""

########################
### Install          ###
########################

.PHONY: install
install: ## Full install: build binary + Chromium + link skills
	@./setup

.PHONY: build
build: ## Build binary + regenerate SKILL.md docs
	@bun run build

########################
### Skills           ###
########################

.PHONY: link-skills
link-skills: ## Symlink skills into Claude, Gemini, and Codex (no build)
	@for target_dir in $(ALL_TARGETS); do \
		mkdir -p "$$target_dir"; \
		echo "=== $$target_dir ==="; \
		for skill in $(REPO_SKILLS)/*/; do \
			name=$$(basename "$$skill"); \
			link="$$target_dir/$$name"; \
			if [ -L "$$link" ]; then \
				current=$$(readlink "$$link"); \
				if [ "$$current" != "$$skill" ]; then \
					rm "$$link"; \
					ln -s "$$skill" "$$link"; \
					echo "  ~ $$name (repointed)"; \
				fi; \
			elif [ -d "$$link" ]; then \
				rm -rf "$$link"; \
				ln -s "$$skill" "$$link"; \
				echo "  ~ $$name (replaced real dir)"; \
			else \
				ln -s "$$skill" "$$link"; \
				echo "  + $$name"; \
			fi; \
		done; \
		for link in "$$target_dir"/*; do \
			[ -L "$$link" ] || continue; \
			readlink "$$link" | grep -q "$(REPO_SKILLS)" || continue; \
			[ -e "$$link" ] || { echo "  - $$(basename $$link) (stale)"; rm -f "$$link"; }; \
		done; \
	done
	@echo "Done"

.PHONY: unlink-skills
unlink-skills: ## Remove all gstack symlinks from tool directories
	@for target_dir in $(ALL_TARGETS); do \
		echo "=== $$target_dir ==="; \
		for link in "$$target_dir"/*; do \
			[ -L "$$link" ] || continue; \
			readlink "$$link" | grep -q "$(REPO_SKILLS)" || continue; \
			echo "  - $$(basename $$link)"; \
			rm -f "$$link"; \
		done; \
	done
	@echo "Done"

.PHONY: list-skills
list-skills: ## List all skills with descriptions
	@echo ""
	@echo "$(BOLD)$(CYAN)Skills$(RESET)"
	@echo ""
	@for skill in $(REPO_SKILLS)/*/SKILL.md; do \
		name=$$(grep "^name:" "$$skill" | sed 's/name: *//'); \
		desc=$$(grep "^description:" "$$skill" | head -1 | sed 's/description: *//; s/^"//; s/"$$//; s/|//'); \
		printf "  $(CYAN)%-30s$(RESET) %s\n" "$$name" "$$desc"; \
	done
	@echo ""

########################
### Testing          ###
########################

.PHONY: test
test: ## Validate skill frontmatter (name matches dir, description present)
	@echo "Running checks..."
	@errors=0; \
	for skill in $(REPO_SKILLS)/*/SKILL.md; do \
		name=$$(grep "^name:" "$$skill" | sed 's/name: *//'); \
		desc=$$(grep "^description:" "$$skill" | sed 's/description: *//'); \
		dir_name=$$(basename $$(dirname "$$skill")); \
		if [ -z "$$name" ]; then \
			echo "  FAIL $$dir_name: missing 'name' in frontmatter"; errors=$$((errors+1)); \
		elif [ "$$name" != "$$dir_name" ]; then \
			echo "  FAIL $$dir_name: name '$$name' doesn't match directory"; errors=$$((errors+1)); \
		fi; \
		if [ -z "$$desc" ]; then \
			echo "  FAIL $$dir_name: missing 'description' in frontmatter"; errors=$$((errors+1)); \
		fi; \
	done; \
	skill_count=$$(find $(REPO_SKILLS) -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' '); \
	skillmd_count=$$(find $(REPO_SKILLS) -name SKILL.md | wc -l | tr -d ' '); \
	if [ "$$skill_count" != "$$skillmd_count" ]; then \
		echo "  FAIL skill dir count ($$skill_count) != SKILL.md count ($$skillmd_count)"; errors=$$((errors+1)); \
	fi; \
	echo "  $$skill_count skills checked"; \
	if [ $$errors -gt 0 ]; then \
		echo "FAILED: $$errors error(s)"; exit 1; \
	else \
		echo "All checks passed"; \
	fi

########################
### Info             ###
########################

.PHONY: status
status: ## Show install state (binary, linked skills, Chromium)
	@echo ""
	@echo "$(BOLD)gstack status$(RESET)"
	@echo ""
	@echo "  Binary:    $$([ -x browse/dist/browse ] && echo "OK ($$(cat browse/dist/.version 2>/dev/null | head -c 8))" || echo "MISSING")"
	@echo "  Version:   $$(cat VERSION 2>/dev/null || echo "unknown")"
	@echo "  Skills:    $$(find $(REPO_SKILLS) -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ') skills"
	@echo ""
	@echo "  Symlinks:"
	@for target_dir in $(ALL_TARGETS); do \
		count=0; \
		if [ -d "$$target_dir" ]; then \
			for link in "$$target_dir"/*; do \
				[ -L "$$link" ] || continue; \
				readlink "$$link" | grep -q "$(REPO_SKILLS)" && count=$$((count+1)); \
			done; \
		fi; \
		printf "    %-45s %d linked\n" "$$target_dir" "$$count"; \
	done
	@echo ""
