output "k8s_cluster_id" {
  value = yandex_kubernetes_cluster.k8s.id
}

output "k8s_node_group_id" {
  value = yandex_kubernetes_node_group.nodes.id
}

output "db_host" {
  value = yandex_mdb_postgresql_cluster.db.host[0].fqdn
}

output "db_port" {
  value = 6432
}

output "db_name" {
  value = yandex_mdb_postgresql_database.appdb.name
}

output "db_user" {
  value = yandex_mdb_postgresql_user.appuser.name
}

output "db_password" {
  value     = random_password.db_password.result
  sensitive = true
}

output "db_url" {
  value = "jdbc:postgresql://${yandex_mdb_postgresql_cluster.db.host[0].fqdn}:6432/${yandex_mdb_postgresql_database.appdb.name}"
}

output "get_kubeconfig" {
  value = "yc managed-kubernetes cluster get-credentials --id ${yandex_kubernetes_cluster.k8s.id} --external --force"
}
