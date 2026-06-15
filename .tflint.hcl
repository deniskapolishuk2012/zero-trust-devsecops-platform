plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

# Catches Azure-specific issues the generic ruleset can't: invalid SKU/location
# combos, deprecated resource arguments, naming convention violations, etc. —
# exactly the class of mistake a Zero Trust review should flag before apply.
plugin "azurerm" {
  enabled = true
  version = "0.28.0"
  source  = "github.com/terraform-linters/tflint-ruleset-azurerm"
}
