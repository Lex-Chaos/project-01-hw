# Домашняя работа к занятию «Организация сети» - Боровик А.А

### Подготовка к выполнению задания

1. Домашнее задание состоит из обязательной части, которую нужно выполнить на провайдере Yandex Cloud, и дополнительной части в AWS (выполняется по желанию).
2. Все домашние задания в блоке 15 связаны друг с другом и в конце представляют пример законченной инфраструктуры.
3. Все задания нужно выполнить с помощью Terraform. Результатом выполненного домашнего задания будет код в репозитории.
4. Перед началом работы настройте доступ к облачным ресурсам из Terraform, используя материалы прошлых лекций и домашнее задание по теме «Облачные провайдеры и синтаксис Terraform». Заранее выберите регион (в случае AWS) и зону.

---

### Задание 1. Yandex Cloud

**Что нужно сделать**

1. Создать пустую VPC. Выбрать зону.
2. Публичная подсеть.

- Создать в VPC subnet с названием public, сетью 192.168.10.0/24.
- Создать в этой подсети NAT-инстанс, присвоив ему адрес 192.168.10.254. В качестве image_id использовать fd80mrhj8fl2oe87o4e1.
- Создать в этой публичной подсети виртуалку с публичным IP, подключиться к ней и убедиться, что есть доступ к интернету.

3. Приватная подсеть.

- Создать в VPC subnet с названием private, сетью 192.168.20.0/24.
- Создать route table. Добавить статический маршрут, направляющий весь исходящий трафик private сети в NAT-инстанс.
- Создать в этой приватной подсети виртуалку с внутренним IP, подключиться к ней через виртуалку, созданную ранее, и убедиться, что есть доступ к интернету.

Resource Terraform для Yandex Cloud:

- [VPC subnet](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/vpc_subnet).
- [Route table](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/vpc_route_table).
- [Compute Instance](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/compute_instance).

## Ответ

Инфраструктуру создавал с помощью terraform.

<details>

<summary>[Манифест `providers.tf`](https://github.com/Lex-Chaos/project-01-hw/blob/main/files/providers.tf):</summary>

```tf
terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = "~>1.9"
}

provider "yandex" {
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  token     = var.token
  zone      = "ru-central1-a"
}
```

</detail>

<details>

<summary>[Манифест `variables.tf`](https://github.com/Lex-Chaos/project-01-hw/blob/main/files/variables.tf):</summary>

```
variable "ssh_key_path" {
  description = "Path to SSH public key"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "cloud_id" {
  description = "Yandex Cloud ID"
  type        = string
}

variable "folder_id" {
  description = "Yandex Folder ID"
  type        = string
}

variable "token" {
  description = "Yandex OAuth token"
  type        = string
  sensitive   = true
}
```

</details>

<details>

<summary>[Манифест `main.tf`](https://github.com/Lex-Chaos/project-01-hw/blob/main/files/main.tf):</summary>

```
# 1. Создание VPC
resource "yandex_vpc_network" "my-vpc" {
  name = "my-vpc"
}

# 2-1. Публичная подсеть
resource "yandex_vpc_subnet" "public" {
  name           = "public"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.my-vpc.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}

# 2-2. NAT-инстанс
resource "yandex_compute_instance" "nat-instance" {
  name        = "nat-instance"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "fd80mrhj8fl2oe87o4e1"
    }
  }

  network_interface {
    subnet_id  = yandex_vpc_subnet.public.id
    ip_address = "192.168.10.254"
    nat        = true
  }
}

# 2-3. Публичная ВМ

data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2204-lts"
}

resource "yandex_compute_instance" "public-vm" {
  name        = "public-vm"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.public.id
    nat       = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file(var.ssh_key_path)}"
  }
}

# 3-1. Приватная подсеть
resource "yandex_vpc_subnet" "private" {
  name           = "private"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.my-vpc.id
  v4_cidr_blocks = ["192.168.20.0/24"]
  route_table_id = yandex_vpc_route_table.private-rt.id
}

# 3-2. Таблица маршрутизации
resource "yandex_vpc_route_table" "private-rt" {
  network_id = yandex_vpc_network.my-vpc.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    next_hop_address   = "192.168.10.254"
  }
}

# 3-3. Приватная ВМ
resource "yandex_compute_instance" "private-vm" {
  name        = "private-vm"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.private.id
  }

  metadata = {
    ssh-keys = "ubuntu:${file(var.ssh_key_path)}"
  }
}

output "public_vm_ip" {
  value = yandex_compute_instance.public-vm.network_interface.0.nat_ip_address
}

output "private_vm_ip" {
  value = yandex_compute_instance.private-vm.network_interface.0.ip_address
}
```

</details>

<details>

<summary>Переменные среды задал с помощью скрипта [`yasettings.sh`](https://github.com/Lex-Chaos/project-01-hw/blob/main/files/yasettings.sh):</summary>

```bash
#!/bin/bash

# Устанавливаем переменные для Yandex Cloud и Terraform
export TF_VAR_token=$(yc iam create-token)
export TF_VAR_cloud_id=$(yc config get cloud-id)
export TF_VAR_folder_id=$(yc config get folder-id)

# Проверяем, что переменные установлены
echo "Variables set:"
echo "TF_VAR_token:    $TF_VAR_token"
echo "TF_VAR_cloud_id: $TF_VAR_cloud_id"
echo "TF_VAR_folder_id: $TF_VAR_folder_id"
```

</details>

Создание инфраструктуры:

![terraform apply](https://github.com/Lex-Chaos/project-01-hw/blob/main/img/Task1-1.png):

Проверка из публичной ВМ:

![ping public](https://github.com/Lex-Chaos/project-01-hw/blob/main/img/Task1-2.png):

На локалке сделал конфиг для ssh:

![config](https://github.com/Lex-Chaos/project-01-hw/blob/main/img/Task1-3.png)

Зашёл на приватную ВМ через `ssh private-vm` и проверил доступ к интернету:

![ping private](https://github.com/Lex-Chaos/project-01-hw/blob/main/img/Task1-4.png)

Схема инфраструктуры:

![schema](https://github.com/Lex-Chaos/project-01-hw/blob/main/img/Task1-5.png)

---

### Правила приёма работы

Домашняя работа оформляется в своём Git репозитории в файле README.md. Выполненное домашнее задание пришлите ссылкой на .md-файл в вашем репозитории. Файл README.md должен содержать скриншоты вывода необходимых команд, а также скриншоты результатов. Репозиторий должен содержать тексты манифестов или ссылки на них в файле README.md.
