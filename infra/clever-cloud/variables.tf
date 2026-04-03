variable "organisation" {
  description = "Clever Cloud organisation ID (orga_xxx or user_xxx)"
  type        = string
}

variable "region" {
  description = "Clever Cloud region"
  type        = string
  default     = "par"
}

variable "app_name" {
  description = "Application name on Clever Cloud"
  type        = string
  default     = "aidc-paperclip"
}

variable "postgresql_plan" {
  description = "PostgreSQL add-on plan (dev, xxs_sml, xs_sml, s_sml, m_sml, ...)"
  type        = string
  default     = "dev"
}

variable "instance_flavor" {
  description = "Application instance size (XS, S, M, L, XL)"
  type        = string
  default     = "S"
}

variable "min_instances" {
  description = "Minimum number of instances"
  type        = number
  default     = 1
}

variable "max_instances" {
  description = "Maximum number of instances"
  type        = number
  default     = 1
}

variable "git_repository" {
  description = "Git repository URL to deploy from"
  type        = string
}

variable "better_auth_secret" {
  description = "Random secret for Paperclip session auth (openssl rand -hex 32)"
  type        = string
  sensitive   = true
}

variable "anthropic_api_key" {
  description = "Anthropic API key for Claude agents"
  type        = string
  sensitive   = true
}

variable "openai_api_key" {
  description = "OpenAI API key for Codex agents (optional)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "gh_token" {
  description = "GitHub Personal Access Token for gh CLI (optional)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "gcp_sa_key" {
  description = "Google Cloud service account JSON, base64-encoded (optional)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "gcp_project_id" {
  description = "Google Cloud project ID (required if gcp_sa_key is set)"
  type        = string
  default     = ""
}

variable "custom_domain" {
  description = "Custom domain FQDN (optional, leave empty for cleverapps.io default)"
  type        = string
  default     = ""
}

# ─── Donna messaging tokens (optional) ──────────────────────────────────────

variable "telegram_bot_token" {
  description = "Telegram bot token from @BotFather (optional)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "telegram_allowed_users" {
  description = "Comma-separated Telegram user IDs allowed to talk to Donna (optional)"
  type        = string
  default     = ""
}

variable "slack_bot_token" {
  description = "Slack bot token (xoxb-...) for Donna (optional)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "slack_app_token" {
  description = "Slack app-level token (xapp-...) for Socket Mode (optional)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "slack_allowed_users" {
  description = "Comma-separated Slack member IDs allowed to talk to Donna (optional)"
  type        = string
  default     = ""
}

variable "discord_bot_token" {
  description = "Discord bot token for Donna (optional)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "discord_allowed_users" {
  description = "Comma-separated Discord user IDs allowed to talk to Donna (optional)"
  type        = string
  default     = ""
}
