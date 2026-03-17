locals {
  pg_db_name  = "zabbix"
  pg_user     = "zabbix"
  pg_password = var.pg_password
}

resource "yandex_mdb_postgresql_cluster" "zabbix_pg" {
  name        = "zabbix-postgres"
  environment = "PRODUCTION"
  network_id  = yandex_vpc_network.main.id

  config {
    version = "15"

    resources {
      resource_preset_id = "s2.micro"
      disk_type_id       = "network-ssd"
      disk_size          = 10
    }

    postgresql_config = {
      max_connections            = 100
      log_min_duration_statement = 5000
    }
  }

  host {
    zone             = "ru-central1-a"
    subnet_id        = yandex_vpc_subnet.managed.id
    assign_public_ip = false
    name             = "pg-host-a"
  }

  host {
    zone             = "ru-central1-b"
    subnet_id        = yandex_vpc_subnet.managed_b.id
    assign_public_ip = false
    name             = "pg-host-b"
  }

  security_group_ids = [yandex_vpc_security_group.postgresql.id]

  maintenance_window {
    type = "ANYTIME"
  }
}

# Шаг 1: пользователь БЕЗ permission — база ещё не существует
resource "yandex_mdb_postgresql_user" "zabbix_user" {
  cluster_id = yandex_mdb_postgresql_cluster.zabbix_pg.id
  name       = local.pg_user
  password   = local.pg_password

  # permission убран намеренно — YC требует существующую БД
  # права будут выданы автоматически через поле owner в database-ресурсе
}

# Шаг 2: база данных — пользователь уже есть
resource "yandex_mdb_postgresql_database" "zabbix_db" {
  cluster_id = yandex_mdb_postgresql_cluster.zabbix_pg.id
  name       = local.pg_db_name
  owner      = local.pg_user   # ← пользователь получает полные права как владелец

  extension {
    name = "uuid-ossp"
  }

  depends_on = [yandex_mdb_postgresql_user.zabbix_user]
}