#!/bin/bash

print_help(){
    echo "Скрипт скачивает бэкапы из указанных директорий сервера в указаную директроию на локальной машине"
    echo ""
    echo "Флаги:"
    echo "  dest          директория для логов на локальной машине"
    echo "  srs           директории с логами на удаленном сервере"
    echo "  username      имя пользователя от чьего имени происходит скачивание логов"
    echo "  server_ip     адрес сервера для скачивания логов"
    echo "  debug         переход в режим дебага"
    echo "  incremental   переход в режим инкрементного бэкапа"
    echo "  help          печатает эту помощь"
    echo ""
    echo "Использование:"
    echo "  $0 [-u username] [-s server_ip] [-d debug] [-i incremental] [-h help] src1...srcN dest"
    exit
}

write_log(){
    [[ $DEBUG == 1 ]] && echo $1
}

while getopts "u:s:dih" flag; do
    case "${flag}" in
        u) USER=$OPTARG;;
        s) SERVER_IP=$OPTARG;;
        d) DEBUG=1;;
        i) INCREMENTAL=1;;
        h) print_help;;
    esac
done
shift $((OPTIND - 1))

# Определяем папки источника и назначения
args=$@
dest_folder="${args##* }"
write_log "Директория для бекапов: $dest_folder"

source_folders="${args% *}"
write_log "Директории источников бекапов: $source_folders"

# Определяем папки куда будем писать бекапы
[[ $INCREMENTAL == 1 ]] && backup_folder="${dest_folder}/Inc" || backup_folder="${dest_folder}/Full"
backup_folder_old="${backup_folder}Old"

# Ротируем папки со старыми бекапами и записываем новые бекапы
for source_folder in $source_folders; do
    source_folder_basename=$(basename $source_folder)
    certain_backup_folder=$backup_folder/$source_folder_basename
    certain_backup_folder_old=$backup_folder_old/$source_folder_basename
    write_log "Директория для новых бекапов: $certain_backup_folder"
    write_log "Директория для старых бекапов: $certain_backup_folder_old"
    
    write_log "Создаем директории для старых и новых бекапов"
    mkdir -p $certain_backup_folder $certain_backup_folder_old

    write_log "Очищаем папку со старыми бекапами и переносим туда новые"
    rm -rf $certain_backup_folder_old/*
    cp -r $certain_backup_folder/* $certain_backup_folder_old/
    
    if [[ $INCREMENTAL != 1 ]]; then
        write_log "Копируем новые бекапы"
        rm -rf $certain_backup_folder/*
        scp -P 22 $USER@$SERVER_IP:$source_folder/*.log.* $certain_backup_folder/
    else
        write_log "Синхронизируем папки логов"
        rsync -azP --delete $USER@$SERVER_IP:$source_folder/*.log.* $certain_backup_folder/
    fi
done