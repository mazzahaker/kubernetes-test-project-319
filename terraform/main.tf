resource "yandex_vpc_network" "net" {
  name = "project-devops-deploy-net"
}

resource "yandex_vpc_gateway" "nat" {
  name = "project-devops-deploy-nat"
  shared_egress_gateway {}
}

resource "yandex_vpc_route_table" "rt" {
  name       = "project-devops-deploy-rt"
  network_id = yandex_vpc_network.net.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.nat.id
  }
}

resource "yandex_vpc_subnet" "subnet" {
  name           = "project-devops-deploy-subnet"
  zone           = var.zone
  network_id     = yandex_vpc_network.net.id
  v4_cidr_blocks = [var.subnet_cidr]
  route_table_id = yandex_vpc_route_table.rt.id
}

resource "yandex_iam_service_account" "k8s_sa" {
  name = "project-devops-deploy-k8s-sa"
}

resource "yandex_iam_service_account" "nodes_sa" {
  name = "project-devops-deploy-nodes-sa"
}

resource "yandex_resourcemanager_folder_iam_member" "k8s_sa_editor" {
  folder_id = var.folder_id
  role      = "editor"
  member    = "serviceAccount:${yandex_iam_service_account.k8s_sa.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "nodes_sa_editor" {
  folder_id = var.folder_id
  role      = "editor"
  member    = "serviceAccount:${yandex_iam_service_account.nodes_sa.id}"
}

resource "yandex_vpc_security_group" "k8s_sg" {
  name       = "project-devops-deploy-k8s-sg"
  network_id = yandex_vpc_network.net.id

  ingress {
    protocol          = "TCP"
    from_port         = 0
    to_port           = 65535
    predefined_target = "loadbalancer_healthchecks"
  }

  ingress {
    protocol          = "ANY"
    from_port         = 0
    to_port           = 65535
    predefined_target = "self_security_group"
  }

  ingress {
    protocol       = "ICMP"
    v4_cidr_blocks = [var.network_cidr]
  }

  ingress {
    protocol       = "TCP"
    port           = 6443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol       = "ANY"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "db_sg" {
  name       = "project-devops-deploy-db-sg"
  network_id = yandex_vpc_network.net.id

  ingress {
    protocol          = "TCP"
    port              = 6432
    security_group_id = yandex_vpc_security_group.k8s_sg.id
  }

  egress {
    protocol       = "ANY"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_kubernetes_cluster" "k8s" {
  name       = "project-devops-deploy-k8s"
  network_id = yandex_vpc_network.net.id

  master {
    version = var.k8s_version

    zonal {
      zone      = var.zone
      subnet_id = yandex_vpc_subnet.subnet.id
    }

    public_ip          = true
    security_group_ids = [yandex_vpc_security_group.k8s_sg.id]
  }

  service_account_id      = yandex_iam_service_account.k8s_sa.id
  node_service_account_id = yandex_iam_service_account.nodes_sa.id

  depends_on = [
    yandex_resourcemanager_folder_iam_member.k8s_sa_editor,
    yandex_resourcemanager_folder_iam_member.nodes_sa_editor
  ]
}

resource "yandex_kubernetes_node_group" "nodes" {
  cluster_id = yandex_kubernetes_cluster.k8s.id
  name       = "project-devops-deploy-ng"
  version    = var.k8s_version

  scale_policy {
    fixed_scale {
      size = var.node_count
    }
  }

  allocation_policy {
    location {
      zone = var.zone
    }
  }

  instance_template {
    platform_id = "standard-v3"

    network_interface {
      subnet_ids         = [yandex_vpc_subnet.subnet.id]
      nat                = true
      security_group_ids = [yandex_vpc_security_group.k8s_sg.id]
    }

    resources {
      cores  = var.node_cores
      memory = var.node_memory
    }

    boot_disk {
      type = "network-hdd"
      size = var.node_disk_gb
    }

    scheduling_policy {
      preemptible = false
    }
  }
}

resource "random_password" "db_password" {
  length  = 24
  special = true
}

resource "yandex_mdb_postgresql_cluster" "db" {
  name               = "project-devops-deploy-db"
  environment        = "PRODUCTION"
  network_id         = yandex_vpc_network.net.id
  security_group_ids = [yandex_vpc_security_group.db_sg.id]

  config {
    version = var.db_version
    resources {
      resource_preset_id = "s2.micro"
      disk_type_id       = "network-ssd"
      disk_size          = var.db_disk_gb
    }
  }

  host {
    zone      = var.zone
    subnet_id = yandex_vpc_subnet.subnet.id
  }
}

resource "yandex_mdb_postgresql_database" "appdb" {
  cluster_id = yandex_mdb_postgresql_cluster.db.id
  name       = var.db_name
  owner      = yandex_mdb_postgresql_user.appuser.name
}

resource "yandex_mdb_postgresql_user" "appuser" {
  cluster_id = yandex_mdb_postgresql_cluster.db.id
  name       = var.db_user
  password   = random_password.db_password.result
}
