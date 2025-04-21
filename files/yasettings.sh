#!/bin/bash

# Устанавливаем переменные для Yandex Cloud и Terraform
export TF_VAR_token=$(yc iam create-token)
export TF_VAR_cloud_id=$(yc config get cloud-id)
export TF_VAR_folder_id=$(yc config get folder-id)

# Проверяем, что переменные установлены
echo "Variables set:"
echo "TF_VAR_token:    [скрыто]"
echo "TF_VAR_cloud_id: $TF_VAR_cloud_id"
echo "TF_VAR_folder_id: $TF_VAR_folder_id"