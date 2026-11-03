# terraform-cato-bulk-amfh-rules
#
# Bulk-manages the Cato Anti-Malware File Hash (antiMalwareFileHash) policy from one JSON
# export produced by `catocli export amfh_rules`:
#   sections[] / rules[] / rules_in_sections[] - flat policy, no sub-policies.
# cato_bulk_amfh_move_rule applies ordering and republishes.
# Rule fields: action (BLOCK|BYPASS), expirationDate, fileName, sha256.

locals {
  amfh_json = jsondecode(file("${var.amfh_rules_json_file_path}"))
  amfh      = local.amfh_json.data.policy.antiMalwareFileHash.policy

  sections_data_raw      = try(local.amfh.sections, [])
  rules_data_raw         = try(local.amfh.rules, [])
  rules_in_sections_data = try(local.amfh.rules_in_sections, [])

  sections_data = {
    for s in local.sections_data_raw : s.section_name => s
  }

  rules_by_name = {
    for rw in local.rules_data_raw : rw.rule.name => rw
  }

  move_section_data = {
    for name, s in local.sections_data : name => {
      section_index = s.section_index
    }
  }

  move_rule_data = {
    for row in local.rules_in_sections_data :
    row.rule_name => {
      index_in_section = row.index_in_section
      section_name     = row.section_name
    }
    if row.section_name != "" && contains(keys(local.sections_data), row.section_name)
  }

  unordered_rules_data = [
    for row in local.rules_in_sections_data : row
    if !contains(keys(local.move_rule_data), try(row.rule_name, ""))
  ]

  rule_bodies = {
    for name, rw in local.rules_by_name : name => merge(
      {
        name            = rw.rule.name
        enabled         = try(rw.rule.enabled, true)
        action          = try(rw.rule.action, "BLOCK")
        expiration_date = rw.rule.expirationDate
        file_name       = rw.rule.fileName
        sha256          = rw.rule.sha256
      },
      try(rw.rule.description, "") != "" ? { description = rw.rule.description } : {}
    )
  }
}

# Optional account-level policy toggle (Anti-Malware File Hash ships disabled on new
# tenants - without enabling it, published rules have no effect).
resource "cato_anti_malware_file_hash_policy" "policy" {
  count   = var.policy_enabled == null ? 0 : 1
  enabled = var.policy_enabled
}

resource "cato_anti_malware_file_hash_section" "sections" {
  for_each = local.sections_data
  at = {
    position = "LAST_IN_POLICY"
  }
  section = {
    name = each.value.section_name
  }
}

resource "cato_anti_malware_file_hash_rule" "rules" {
  depends_on = [cato_anti_malware_file_hash_section.sections]
  for_each   = local.rules_by_name

  at = contains(keys(local.sections_data), each.value.rule.section.name) ? {
    position = "LAST_IN_SECTION"
    ref      = cato_anti_malware_file_hash_section.sections[each.value.rule.section.name].id
    } : {
    position = "LAST_IN_POLICY"
  }

  rule = local.rule_bodies[each.key]
}

# Ordering + republish on changes.
resource "cato_bulk_amfh_move_rule" "all_amfh_rules" {
  depends_on = [cato_anti_malware_file_hash_section.sections, cato_anti_malware_file_hash_rule.rules]

  section_data = local.move_section_data
  rule_data    = local.move_rule_data
}
