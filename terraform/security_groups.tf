# Bastion: только SSH снаружи
resource "yandex_vpc_security_group" "bastion" {
  name       = "sg-bastion"
  network_id = yandex_vpc_network.main.id

  ingress {
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# Web серверы: HTTP от ALB, SSH от bastion, Zabbix от zabbix-server
resource "yandex_vpc_security_group" "web" {
  name       = "sg-web"
  network_id = yandex_vpc_network.main.id

  ingress {
    protocol       = "TCP"
    port           = 80
    v4_cidr_blocks = ["192.168.10.0/24"]  # от ALB
  }
  ingress {
    protocol       = "TCP"
    port           = 80
    v4_cidr_blocks = ["198.18.235.0/24", "198.18.248.0/24"]  # Healthcheck от служебных диапазонов Yandex Cloud
  }
  ingress {
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = ["192.168.10.0/24"]  # от bastion
  }
  ingress {
    protocol       = "TCP"
    port           = 10050
    v4_cidr_blocks = ["192.168.10.0/24"]  # от Zabbix server
  }
  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# PostgreSQL: доступ только от Zabbix-server (приватная подсеть)
resource "yandex_vpc_security_group" "postgresql" {
  name       = "sg-postgresql"
  network_id = yandex_vpc_network.main.id

  ingress {
    protocol       = "TCP"
    port           = 6432   # pgbouncer (порт managed PostgreSQL в YC)
    v4_cidr_blocks = ["192.168.10.0/24"]  # публичная подсеть (Zabbix)
  }
  ingress {
    protocol       = "TCP"
    port           = 6432
    v4_cidr_blocks = ["192.168.20.0/24"]  # приватная подсеть-a
  }
  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# Zabbix: HTTP(S) снаружи, zabbix-port внутри
resource "yandex_vpc_security_group" "zabbix" {
  name       = "sg-zabbix"
  network_id = yandex_vpc_network.main.id

  ingress {
    protocol       = "TCP"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol       = "TCP"
    port           = 10051
    v4_cidr_blocks = ["192.168.0.0/16"]
  }
  ingress {
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = ["192.168.10.0/24"]
  }
  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# Elasticsearch: только от web и Kibana
resource "yandex_vpc_security_group" "elasticsearch" {
  name       = "sg-elasticsearch"
  network_id = yandex_vpc_network.main.id

  ingress {
    protocol       = "TCP"
    port           = 9200
    v4_cidr_blocks = ["192.168.0.0/16"]
  }
  ingress {
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = ["192.168.10.0/24"]
  }
  ingress {
    protocol       = "TCP"
    port           = 10050
    v4_cidr_blocks = ["192.168.10.0/24"]  # подсеть где живёт zabbix
  }
  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# Kibana: HTTP снаружи
resource "yandex_vpc_security_group" "kibana" {
  name       = "sg-kibana"
  network_id = yandex_vpc_network.main.id

  ingress {
    protocol       = "TCP"
    port           = 5601
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = ["192.168.10.0/24"]
  }
  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# Отдельная SG для ALB (не переиспользуем sg-zabbix!)
resource "yandex_vpc_security_group" "alb" {
  name       = "sg-alb"
  network_id = yandex_vpc_network.main.id

  # Входящий HTTP от пользователей
  ingress {
    protocol       = "TCP"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  # ОБЯЗАТЕЛЬНО: healthcheck от служебных диапазонов Yandex Cloud
  ingress {
    protocol       = "TCP"
    port           = 80
    v4_cidr_blocks = ["198.18.235.0/24", "198.18.248.0/24"]
  }

  # ОБЯЗАТЕЛЬНО: второй диапазон healthcheck (любые порты)
  ingress {
    protocol       = "ANY"
    v4_cidr_blocks = ["198.18.235.0/24", "198.18.248.0/24"]
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}