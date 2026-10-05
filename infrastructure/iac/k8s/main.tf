

resource "ovh_cloud_project_kube" "mks_cluster" {
  service_name = var.project_id
  name         = "${var.team}-${var.project_name}-mks-cluster"
  region       = var.region

  private_network_id = ovh_cloud_project_network_private.mks-private-network.regions_openstack_ids[var.region]
  nodes_subnet_id    = ovh_cloud_project_network_private_subnet.mks-subnet.id

  private_network_configuration {
    default_vrack_gateway              = ""
    private_network_routing_as_default = false
  }
}

resource "ovh_cloud_project_kube_nodepool" "node_pool_1" {
  service_name = ovh_cloud_project_kube.mks_cluster.service_name
  kube_id      = ovh_cloud_project_kube.mks_cluster.id

  name           = "${var.team}-${var.project_name}-node-pool"
  flavor_name    = "b2-7" #smallest size in GRA9
  monthly_billed = false  #set hourly billing

  #Scaling
  autoscale     = true
  min_nodes     = 1
  max_nodes     = 3
  desired_nodes = 2
}

resource "ovh_cloud_project_kube_nodepool" "runner_node_pool" {
  service_name = ovh_cloud_project_kube.mks_cluster.service_name
  kube_id      = ovh_cloud_project_kube.mks_cluster.id

  name           = "${var.team}-${var.project_name}-runner-node-pool"
  flavor_name    = "b2-7"
  monthly_billed = false #set hourly billing

  #Scaling: dont use any nodes if no runners are working
  autoscale     = true
  min_nodes     = 1
  max_nodes     = 5
  desired_nodes = 1
  template {
    metadata {
      annotations = {}
      labels = {
        nodepool = "ci_pool"
        role     = "worker-ci"
      }
      finalizers = []
    }
    spec {
      unschedulable = false
      taints = [
        { key    = "workload"
          value  = "ci"
          effect = "NoSchedule"
      }]
    }
  }
}
resource "ovh_cloud_project_kube_nodepool" "harbor_node_pool" {
  service_name = ovh_cloud_project_kube.mks_cluster.service_name
  kube_id      = ovh_cloud_project_kube.mks_cluster.id

  name           = "${var.team}-${var.project_name}-harbor-node-pool"
  flavor_name    = "b2-7"
  monthly_billed = false #set hourly billing

  #Scaling: dont use any nodes if no runners are working
  autoscale     = true
  min_nodes     = 1
  max_nodes     = 3
  desired_nodes = 1
  template {
    metadata {
      annotations = {}
      labels = {
        nodepool = "harbor_pool"
        role     = "worker-harbor"
      }
      finalizers = []
    }
    spec {
      unschedulable = false
      taints = [
        { key    = "workload"
          value  = "harbor"
          effect = "NoSchedule"
      }]
    }
  }
}
resource "ovh_cloud_project_kube_nodepool" "sonar_node_pool" {
  service_name = ovh_cloud_project_kube.mks_cluster.service_name
  kube_id      = ovh_cloud_project_kube.mks_cluster.id

  name           = "${var.team}-${var.project_name}-sonar-node-pool"
  flavor_name    = "b2-7"
  monthly_billed = false #set hourly billing

  #Scaling: dont use any nodes if no runners are working
  autoscale     = true
  min_nodes     = 1
  max_nodes     = 3
  desired_nodes = 1
  template {
    metadata {
      annotations = {}
      labels = {
        nodepool = "sonar_pool"
        role     = "worker-sonar"
      }
      finalizers = []
    }
    spec {
      unschedulable = false
      taints = [
        { key    = "workload"
          value  = "sonar"
          effect = "NoSchedule"
      }]
    }
  }
}



resource "local_file" "kubeconfig" {
  content  = ovh_cloud_project_kube.mks_cluster.kubeconfig
  filename = "${path.module}/kubeconfig.yaml"
}
