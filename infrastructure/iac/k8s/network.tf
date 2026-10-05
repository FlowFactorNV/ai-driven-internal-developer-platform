locals {
  dhcp_start = cidrhost(var.private_network_cidr, var.dhcp_start_offset)

  # Logic: Start + Size - 1 
  # (e.g., Start at 50 + 50 IPs = reaches host 99)
  dhcp_end = cidrhost(var.private_network_cidr, var.dhcp_start_offset + var.dhcp_pool_size - 1)
}

resource "ovh_cloud_project_network_private" "mks-private-network" {
  service_name = var.project_id
  name         = "${var.team}-${var.project_name}-pn"
  regions      = [var.region]
  vlan_id      = 10           #set VLAN_ID to 10 to isolate trafic
}


resource "ovh_cloud_project_network_private_subnet" "mks-subnet" {
  service_name = var.project_id
  network_id   = ovh_cloud_project_network_private.mks-private-network.id
  region       = var.region

  network = var.private_network_cidr
  start   = local.dhcp_start
  end     = local.dhcp_end

  dhcp       = true
  no_gateway = false
}

resource "ovh_cloud_project_gateway" "name" {
  service_name = var.project_id
  name         = "${var.team}-${var.project_name}-gateway"
  region       = var.region
  model        = "s" #small
  network_id   = ovh_cloud_project_network_private.mks-private-network.regions_openstack_ids[var.region]
  subnet_id    = ovh_cloud_project_network_private_subnet.mks-subnet.id
}
