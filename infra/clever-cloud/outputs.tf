output "app_id" {
  description = "Clever Cloud application ID"
  value       = clevercloud_nodejs.paperclip.id
}

output "deploy_url" {
  description = "Git remote URL — push here to deploy"
  value       = clevercloud_nodejs.paperclip.deploy_url
}

output "public_url" {
  description = "Public URL of the running Paperclip instance"
  value       = local.public_url
}

output "database_host" {
  description = "PostgreSQL hostname"
  value       = clevercloud_postgresql.db.host
}

output "fsbucket_host" {
  description = "FS Bucket FTP endpoint"
  value       = clevercloud_fsbucket.paperclip_home.host
}
