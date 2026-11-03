variable "amfh_rules_json_file_path" {
  description = "Path to the Anti-Malware File Hash JSON export produced by `catocli export amfh_rules` (data.policy.antiMalwareFileHash.policy root)."
  type        = string
}

variable "policy_enabled" {
  description = "Manage the account-level Anti-Malware File Hash policy toggle. null leaves the toggle unmanaged; true/false manages it via cato_anti_malware_file_hash_policy."
  type        = bool
  default     = null
}
