resource "yandex_compute_snapshot_schedule" "daily" {
  name = "daily-snapshot"

  schedule_policy {
    expression = "0 2 * * *"  # каждый день в 02:00
  }

  snapshot_spec {
    description = "daily-auto-snapshot"
  }

  retention_period = "168h"  # 7 дней

  disk_ids = [
    yandex_compute_instance.bastion.boot_disk[0].disk_id,
    yandex_compute_instance.web1.boot_disk[0].disk_id,
    yandex_compute_instance.web2.boot_disk[0].disk_id,
    yandex_compute_instance.zabbix.boot_disk[0].disk_id,
    yandex_compute_instance.elasticsearch.boot_disk[0].disk_id,
    yandex_compute_instance.kibana.boot_disk[0].disk_id,
  ]
}