variable "region" {
  description = "The region of the HCP HVN and Vault cluster."
  type        = string
  default     = "eu-west-1"
}

variable "tfc_organization_name" {
  type = string
}
variable "hvn_id" {
  type = string
}