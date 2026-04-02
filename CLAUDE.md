# CLAUDE.md — AIDC: The AI Driven Company

Instructions for Claude Code when working in this repository.

## Project Purpose

This repo bootstraps a new AI-driven company. The goal is to set up all tooling, agents, and processes so the company runs on AI from day one.

## Key Dependencies

- **Paperclip** (`https://github.com/paperclipai/paperclip`): The primary AI agent framework. Install before anything else.
- **Hermes** (`https://hermes-agent.nousresearch.com`): Nous Research autonomous agent runtime. Powers Donna (chief of staff). Installed via `scripts/install-tools.sh` and started as a background gateway in `scripts/startup.sh`.

## Setup Order

1. Install Paperclip
2. Install Hermes (done automatically at build time via `CC_PRE_BUILD_HOOK`)
3. Configure agent workflows in `agents/`
4. Provision infrastructure via `infra/`
5. Run operational automations from `ops/`

## Donna — Chief of Staff Agent

Donna is the company's chief of staff, running on Hermes. She:
- Coordinates across Paperclip workflows and Claude Code tasks
- Tracks company priorities, OKRs, and initiatives
- Is the primary human-facing interface for company operations

Her identity lives in `agents/donna/SOUL.md`, her Hermes config in `agents/donna/config.yaml`.
On Clever Cloud, her data persists at `DONNA_HOME=/app/paperclip/donna` (on the FS bucket).

**To reach Donna**: connect a messaging platform (Slack, Telegram, Discord) via `hermes gateway`.

## Git Conventions

- Always use `git pull --rebase` — keeps history linear, no merge commits

## Conventions

- Agent definitions live in `agents/` as YAML or JSON files
- All automation scripts must be idempotent
- Prefer declarative config over imperative scripts
- Document every agent's purpose, inputs, and outputs

## Working with Claude Code

- Use this repo as the source of truth for company setup steps
- When adding new tooling, update both README.md and the relevant `agents/` or `ops/` directory
- Keep CLAUDE.md updated as the project evolves
