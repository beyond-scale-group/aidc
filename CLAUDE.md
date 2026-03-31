# CLAUDE.md — AIDC: The AI Driven Company

Instructions for Claude Code when working in this repository.

## Project Purpose

This repo bootstraps a new AI-driven company. The goal is to set up all tooling, agents, and processes so the company runs on AI from day one.

## Key Dependencies

- **Paperclip** (`https://github.com/paperclipai/paperclip`): The primary AI agent framework. Install before anything else.

## Setup Order

1. Install Paperclip
2. Configure agent workflows in `agents/`
3. Provision infrastructure via `infra/`
4. Run operational automations from `ops/`

## Conventions

- Agent definitions live in `agents/` as YAML or JSON files
- All automation scripts must be idempotent
- Prefer declarative config over imperative scripts
- Document every agent's purpose, inputs, and outputs

## Working with Claude Code

- Use this repo as the source of truth for company setup steps
- When adding new tooling, update both README.md and the relevant `agents/` or `ops/` directory
- Keep CLAUDE.md updated as the project evolves
