# Дипломная работа по профессии «Системный администратор» SYS-46 Ардашов Владимир

---

## Описание

 Проект реализует отказоустойчивую инфраструктуру для веб-сайта в Yandex Cloud, включающую:

  - Два веб-сервера nginx в разных зонах доступности за Application Load Balancer
  - Мониторинг через Zabbix с базой данных на Managed PostgreSQL
  - Централизованный сбор логов через Filebeat → Elasticsearch → Kibana
  - Бастион-хост для безопасного доступа к приватной сети
  - Ежедневное резервное копирование дисков всех ВМ

**Инструменты:** Terraform, Ansible, Docker, Yandex Cloud

---

## Архитектура

```
Internet
    │
    ▼
Application Load Balancer (публичный IP)
    │
    ├──── web1.ru-central1.internal (zone-a, приватная сеть)
    │         nginx + filebeat + zabbix-agent
    │
    └──── web2.ru-central1.internal (zone-b, приватная сеть)
              nginx + filebeat + zabbix-agent

Публичная подсеть (192.168.10.0/24):
    ├── bastion     — SSH jump host (порт 22)
    ├── zabbix      — Zabbix Server + Frontend
    └── kibana      — Kibana (Docker)

Приватная подсеть A (192.168.20.0/24):
    ├── web1        — nginx
    └── elasticsearch — Elasticsearch (Docker)

Приватная подсеть B (192.168.30.0/24):
    └── web2        — nginx

Managed подсети:
    ├── 192.168.40.0/24 (zone-a) — PostgreSQL нода 1
    └── 192.168.50.0/24 (zone-b) — PostgreSQL нода 2

NAT Gateway — исходящий интернет для приватных подсетей
```

### Схема сети

| Компонент | Подсеть | Внешний IP | Зона |
|---|---|---|---|
| bastion | public (10.0/24) | да | ru-central1-a |
| zabbix | public (10.0/24) | да | ru-central1-a |
| kibana | public (10.0/24) | да | ru-central1-a |
| web1 | private-a (20.0/24) | нет | ru-central1-a |
| web2 | private-b (30.0/24) | нет | ru-central1-b |
| elasticsearch | private-a (20.0/24) | нет | ru-central1-a |
| PostgreSQL (x2) | managed (40-50.0/24) | нет | a + b |

---

## Структура репозитория

```
diplom/
├── terraform/
│   ├── main.tf                  # провайдер Yandex Cloud
│   ├── variables.tf             # переменные
│   ├── outputs.tf               # выходные значения (IP-адреса)
│   ├── network.tf               # VPC, подсети, NAT-шлюз
│   ├── security_groups.tf       # правила Security Groups
│   ├── vms.tf                   # виртуальные машины
│   ├── load_balancer.tf         # ALB, target group, backend group
│   ├── postgresql.tf            # Managed PostgreSQL кластер
│   ├── snapshots.tf             # расписание снапшотов
│   └── terraform.tfvars         # ← в .gitignore, не коммитить!
│
├── ansible/
│   ├── ansible.cfg              # конфигурация Ansible
│   ├── inventory.ini            # FQDN-имена хостов
│   ├── group_vars/
│   │   └── all.yml              # общие переменные
│   ├── playbook-site.yml        # деплой nginx
│   ├── playbook-monitoring.yml  # деплой Zabbix
│   ├── playbook-logs.yml        # деплой ELK
│   └── roles/
│       ├── nginx/               # установка nginx + статический сайт
│       ├── docker/              # установка Docker
│       ├── elasticsearch/       # Elasticsearch в Docker
│       ├── kibana/              # Kibana в Docker
│       ├── filebeat/            # Filebeat в Docker
│       ├── zabbix-server/       # Zabbix Server + Frontend
│       └── zabbix-agent/        # Zabbix Agent 2
│
└── .gitignore
```

---

## Инфраструктура (Terraform)

### Развёртывание инфраструктуры

```bash
cd terraform

# Инициализация провайдера
terraform init

# Проверка плана
terraform plan

# Применение (создание всех ресурсов ~10-15 минут)
terraform apply

# Получение IP-адресов
terraform output
```

### Выходные значения

| Output | Описание |
|---|---|
| `bastion_public_ip` | IP бастион-хоста для SSH |
| `zabbix_public_ip` | IP Zabbix веб-интерфейса |
| `kibana_public_ip` | IP Kibana веб-интерфейса |
| `alb_public_ip` | IP Application Load Balancer |
| `postgresql_fqdn` | FQDN кластера PostgreSQL |
| `elasticsearch_private_ip` | Приватный IP Elasticsearch |


![Название скриншота 1](https://github.com/ardashov/Diplom/blob/main/scr/scr_1.png)`


![Название скриншота 2](https://github.com/ardashov/Diplom/blob/main/scr/scr_2.png)`


### Managed PostgreSQL

 Кластер из двух нод с автоматическим failover:
  - **Нода 1** (primary): `ru-central1-a`
  - **Нода 2** (replica): `ru-central1-b` — при падении primary автоматически становится новым primary
  - Подключение через FQDN кластера — при failover адрес не меняется
  - Порт: `6432` (pgbouncer)

![Название скриншота 4](https://github.com/ardashov/Diplom/blob/main/scr/scr_4.png)`

### Снапшоты дисков

 Расписание создаётся автоматически через `snapshots.tf`:
  - Запуск: ежедневно в 02:00
  - Хранение: 7 дней
  - Охват: все 6 ВМ (bastion, web1, web2, zabbix, elasticsearch, kibana)

![Название скриншота 5](https://github.com/ardashov/Diplom/blob/main/scr/scr_5.png)`

---

## Конфигурация (Ansible)

### Запуск плейбуков

```bash
# 1. Логирование (ELK)
ansible-playbook playbook-logs.yml

# 2. Мониторинг (Zabbix)
ansible-playbook playbook-monitoring.yml

# 3. Сайт (nginx)
ansible-playbook playbook-site.yml
```

> **Важно:** Elasticsearch и Kibana разворачиваются в Docker-контейнерах, так как apt-репозиторий Elastic недоступен с российских IP-адресов.

---

## Сайт и балансировщик

### Проверка сайта

```bash
# Получаем IP балансировщика
ALB_IP=$(cd terraform && terraform output -raw alb_public_ip)

# Проверяем доступность
curl -v http://158.160.193.128:80

```

![Название скриншота 8](https://github.com/ardashov/Diplom/blob/main/scr/scr_8.png)`

### Схема балансировщика

![Название скриншота 3](https://github.com/ardashov/Diplom/blob/main/scr/scr_3.png)`

```
Application Load Balancer
    └── HTTP Router (путь /)
        └── Backend Group
            └── Target Group
                ├── web1 (192.168.20.x:80)
                └── web2 (192.168.30.x:80)

Healthcheck: GET / HTTP, порт 80, таймаут 10s, интервал 2s
```

---

## Мониторинг (Zabbix)

### Доступ к веб-интерфейсу

```
URL:      http://89.169.135.18/zabbix/
Логин:    Admin
Пароль:   zabbix
```

![Название скриншота 6](https://github.com/ardashov/Diplom/blob/main/scr/scr_6.png)`


![Название скриншота 6_1](https://github.com/ardashov/Diplom/blob/main/scr/scr_6_1.png)`


### Подключённые хосты

| Хост | Шаблоны | Назначение |
|---|---|---|
| web1 | Linux by Zabbix agent, Nginx by Zabbix agent | Веб-сервер 1 |
| web2 | Linux by Zabbix agent, Nginx by Zabbix agent | Веб-сервер 2 |
| elasticsearch | Linux by Zabbix agent | Сервер логов |

### Дашборд USE Monitoring

Дашборд создан по принципу USE (Utilization, Saturation, Errors):

---

## Логирование (ELK Stack)

### Схема сбора логов

```
web1 nginx access.log ──┐
web1 nginx error.log  ──┤
                        ├── Filebeat (Docker) ──→ Elasticsearch (Docker) ──→ Kibana (Docker)
web2 nginx access.log ──┤
web2 nginx error.log  ──┘

Индекс: nginx-logs-YYYY.MM.DD
```

### Компоненты

| Компонент | Хост | Порт | Запуск |
|---|---|---|---|
| Elasticsearch | elasticsearch.ru-central1.internal | 9200 | Docker |
| Kibana | kibana.ru-central1.internal | 5601 | Docker |
| Filebeat | web1, web2 | — | Docker |

### Доступ к Kibana

```
URL: http://93.77.182.245:5601
```

![Название скриншота 7](https://github.com/ardashov/Diplom/blob/main/scr/scr_7.png)`


### Настройка Data View в Kibana

```
☰ → Management → Kibana → Data Views → Create data view

Name:            nginx-logs
Index pattern:   nginx-logs-*
Timestamp field: @timestamp

→ Save data view to Kibana
```

### Просмотр логов

```
☰ → Analytics → Discover → выбрать nginx-logs
```

---

## Сеть и безопасность

### VPC и подсети

| Подсеть | CIDR | Назначение |
|---|---|---|
| public | 192.168.10.0/24 | Bastion, Zabbix, Kibana |
| private-a | 192.168.20.0/24 | web1, Elasticsearch |
| private-b | 192.168.30.0/24 | web2 |
| managed | 192.168.40.0/24 | PostgreSQL нода 1 |
| managed-b | 192.168.50.0/24 | PostgreSQL нода 2 |

### Security Groups

| SG | Входящие порты | Источник |
|---|---|---|
| sg-bastion | 22 | 0.0.0.0/0 |
| sg-alb | 80 | 0.0.0.0/0 + 198.18.235.0/24, 198.18.248.0/24 (healthcheck) |
| sg-web | 80, 22, 10050 | 192.168.10.0/24 + healthcheck диапазоны |
| sg-zabbix | 80, 10051, 22 | 0.0.0.0/0 / 192.168.0.0/16 |
| sg-kibana | 5601, 22 | 0.0.0.0/0 |
| sg-elasticsearch | 9200, 10050, 22 | 192.168.0.0/16 |
| sg-postgresql | 6432 | 192.168.0.0/16 |

> Диапазоны `198.18.235.0/24` и `198.18.248.0/24` — служебные адреса Yandex Cloud для healthcheck ALB.

### Бастион-хост

Единственная ВМ с публичным IP. Открыт только порт 22.
Все остальные ВМ доступны только через бастион:

```bash
# Прямое подключение к любой ВМ
ssh -J ubuntu@93.77.177.183 ubuntu@web1.ru-central1.internal

```

### NAT Gateway

Все ВМ в приватных подсетях имеют исходящий доступ в интернет через NAT Gateway.
Входящий трафик из интернета к ним заблокирован.

---

### Безопасность

 - `terraform/terraform.tfvars` добавлен в `.gitignore` — токен и пароли не попадают в git
 - Zabbix-агенты принимают подключения только из подсети `192.168.10.0/24`
 - Elasticsearch доступен только из внутренней сети `192.168.0.0/16`
 - Единственная точка входа из интернета — бастион-хост (порт 22)

---
