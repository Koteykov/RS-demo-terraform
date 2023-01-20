# RS-demo-terraform
Это Terraform-проект, с помощью которого разворачивается инфраструктура на AWS, 5 EC2-серверов и S3-хранилище. 
Один из серверов выступает в роли Ansible-контроллера, он настраивается с помощью cloud-init.

## main.tf
Под сервера разворачивается отдельный VPC со своей подсетью, IGW, security-group и т. д. 

В качестве AMI под EC2-сервера берётся самая свежая CentOS 9.

Для control-сервера и apache-серверов назначаются статические приватные ip-адреса из пула. У haproxy-сервера динамический приватный ip.

Конфиг cloud-init передаётся на control-сервер через user_data.

Также, разворачивается S3-хранилище и на него загружается архив с Ansible-конфигурацией для control-сервера.

## cloud-init.yaml
В первой половине конфига есть комментарии, во второй половине нет - это потому что при добавлении комментариев во вторую часть возникали ошибки с синтаксисом YAML, которые я не смогла исправить.
Также, я могла бы с самого начала отделить блок с командами знаком |, но нет, это тоже приводило к ошибкам с синтаксисом. Поэтому конфиг выглядит так и никак иначе.

Действия в конфиге:
- Устанавливается пакет python3-pip
- Создаётся пользователь ansible-user с sudo правами. Важно, что имя пользователя не должно совпадать с устанавливаемым в дальнейшем пакетом ansible, так как всё ломается
- Создаётся директория .ssh и файл с приватным ключом для подключения к другим EC2-серверам
- Через pip устанавливаются пакеты ansible, awscli, boto3. Последние два нужны для подключения к S3
- Создаётся директория .aws и файл с аутентификационными данными для AWS для подключения к S3
- Из S3-хранилища скачивается архив с Ansible-конфигурацией и распаковывается
- Запускается плейбук с динамическим инвентарём
