output "bastion_public_ip"       { value = yandex_compute_instance.bastion.network_interface[0].nat_ip_address }
output "zabbix_public_ip"        { value = yandex_compute_instance.zabbix.network_interface[0].nat_ip_address }
output "kibana_public_ip"        { value = yandex_compute_instance.kibana.network_interface[0].nat_ip_address }
output "alb_public_ip"           { value = yandex_alb_load_balancer.web_alb.listener[0].endpoint[0].address[0].external_ipv4_address[0].address }
output "elasticsearch_private_ip"{ value = yandex_compute_instance.elasticsearch.network_interface[0].ip_address }
output "postgresql_fqdn" {
  # FQDN master-ноды — YC автоматически переключает его при failover
  value = yandex_mdb_postgresql_cluster.zabbix_pg.host[0].fqdn
}