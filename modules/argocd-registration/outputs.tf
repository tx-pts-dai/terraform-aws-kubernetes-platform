output "file_path" {
  description = "Path of the cluster Secret file committed to the GitOps repository"
  value       = try(github_repository_file.cluster_secret[0].file, "")
}

output "commit_sha" {
  description = "Git commit SHA of the last file write"
  value       = try(github_repository_file.cluster_secret[0].commit_sha, "")
}
