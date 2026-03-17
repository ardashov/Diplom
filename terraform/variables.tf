variable "cloud_id"  { type = string }
variable "folder_id" { type = string }
variable "token"     { type = string }

variable "ssh_public_key" {
  type    = string
  default = "~/.ssh/id_rsa.pub"
}

variable "pg_password" {
  type        = string
  description = "Password for Zabbix PostgreSQL user"
  sensitive   = true   # не выводится в terraform output

validation {
    condition     = length(var.pg_password) >= 8
    error_message = "pg_password must be at least 8 characters long."
  }
}
