output "deployment_summary" {
  description = "Counts of managed Anti-Malware File Hash objects."
  value = {
    sections = length(cato_anti_malware_file_hash_section.sections)
    rules    = length(cato_anti_malware_file_hash_rule.rules)
  }
}

output "section_ids" {
  description = "Map of section name to section id."
  value       = { for name, s in cato_anti_malware_file_hash_section.sections : name => s.id }
}

output "rule_ids" {
  description = "Map of rule name to rule id."
  value       = { for name, r in cato_anti_malware_file_hash_rule.rules : name => r.id }
}

# Ordering rows the move resource cannot address (section_name "" - rules at
# the policy root). Their order is creation order. Informational only.
output "unordered_rules" {
  description = "rules_in_sections rows excluded from cato_bulk_amfh_move_rule (no managed section to order within)."
  value       = local.unordered_rules_data
}
