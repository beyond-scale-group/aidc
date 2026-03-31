# AIDC — The AI Driven Company

A repository for bootstrapping a new AI-driven company. This repo automates the setup of infrastructure, tooling, and processes needed to run a company powered by AI agents.

## Overview

AIDC provides a structured approach to launching a company where AI agents handle operations, workflows, and decision support. It integrates best-in-class AI tooling from day one.

## Prerequisites

- [Paperclip](https://github.com/paperclipai/paperclip) — AI agent framework (installed first)
- Node.js >= 18
- Git

## Getting Started

### 1. Install Paperclip

```bash
npm install -g @paperclipai/paperclip
```

### 2. Clone this repo

```bash
git clone <this-repo>
cd create-aidc-the-ai-driven-company
```

### 3. Bootstrap the company

```bash
paperclip run setup
```

## Structure

```
.
├── CLAUDE.md          # Claude Code instructions for this project
├── README.md          # This file
├── agents/            # AI agent definitions and workflows
├── infra/             # Infrastructure as code
├── ops/               # Operational playbooks and automations
└── setup/             # Bootstrap scripts
```

## Philosophy

An AI Driven Company runs on agents for routine operations, uses AI for decision support, and keeps humans focused on strategy and creativity. AIDC gives you the scaffolding to build that from day one.
