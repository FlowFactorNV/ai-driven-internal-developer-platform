variable "project_id" {
  type        = string
  description = "Service Name Field in OVH Cloud"
}

variable "region" {
  type        = string
  description = "Region where our MKS cluster should be provisioned"
}

variable "team" {
  type        = string
  description = "Name of the team, to be used in resource names"
}
variable "project_name" {
  type        = string
  description = "Identifier/name of the project, to be used in  resource names"
}

#==============================
#Networking
#==============================
variable "private_network_cidr" {
  type    = string
  default = "192.168.168.0/24"
}

variable "dhcp_start_offset" {
  type        = number
  description = "The host number where the DHCP range begins"
  default     = 50
}

variable "dhcp_pool_size" {
  type        = number
  description = "How many IPs to include in the DHCP pool"
  default     = 50

  validation {
    # validation to make sure pool is not too large
    condition     = (var.dhcp_start_offset + var.dhcp_pool_size) < 255
    error_message = "The DHCP pool size is too large for this network prefix."
  }
}
