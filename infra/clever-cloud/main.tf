provider "clevercloud" {
  organisation = var.organisation
}

# ─── DATABASE ───────────────────────────────────────────────────────────────

resource "clevercloud_postgresql" "db" {
  name   = "${var.app_name}-pg"
  plan   = var.postgresql_plan
  region = var.region
}

# ─── PERSISTENT STORAGE ────────────────────────────────────────────────────

resource "clevercloud_fsbucket" "paperclip_home" {
  name   = "${var.app_name}-home"
  region = var.region
}

# ─── APPLICATION ────────────────────────────────────────────────────────────

locals {
  public_url = var.custom_domain != "" ? "https://${var.custom_domain}" : "https://${var.app_name}.cleverapps.io"

  environment = merge(
    {
      # Runtime
      HOST             = "0.0.0.0"
      SERVE_UI         = "true"
      CC_NODE_VERSION  = "20"
      CC_PRE_RUN_HOOK  = "bash scripts/init-db.sh"

      # Database
      DATABASE_URL = clevercloud_postgresql.db.uri

      # Persistent storage — mount FS Bucket to /app/paperclip
      CC_FS_BUCKET   = "/app/paperclip:${clevercloud_fsbucket.paperclip_home.host}"
      PAPERCLIP_HOME = "/app/paperclip"

      # Auth
      PAPERCLIP_DEPLOYMENT_MODE     = "authenticated"
      PAPERCLIP_DEPLOYMENT_EXPOSURE = "public"
      PAPERCLIP_PUBLIC_URL          = local.public_url
      BETTER_AUTH_SECRET            = var.better_auth_secret

      # AI providers
      ANTHROPIC_API_KEY = var.anthropic_api_key
    },
    var.openai_api_key != "" ? { OPENAI_API_KEY = var.openai_api_key } : {},
  )
}

resource "clevercloud_nodejs" "paperclip" {
  name               = var.app_name
  region             = var.region
  min_instance_count = var.min_instances
  max_instance_count = var.max_instances
  smallest_flavor    = var.instance_flavor
  biggest_flavor     = var.instance_flavor

  redirect_https = true

  dependencies = [
    clevercloud_postgresql.db.id,
    clevercloud_fsbucket.paperclip_home.id,
  ]

  environment = local.environment

  vhosts = var.custom_domain != "" ? [{ fqdn = var.custom_domain, path_begin = null }] : null

  deployment {
    repository = var.git_repository
  }
}
