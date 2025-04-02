#!/bin/bash

##### Настройки логирования данного скрипта
export TERM=dumb # необходимо для корректного отображения логов 
# введите полный путь в папку для хранения логов обновления
LOG_DIR="/opt/valheim/valheim_updates_log"
# Создаёт директорию, если её нет
mkdir -p "$LOG_DIR"
# Задаём имя лог-файлов с учётом директории, указаной выше, и текущей даты
LOG_FILE="$LOG_DIR/valheim_update_$(date +%Y-%m-%d).log"
## Перенаправляем весь вывод (stdout и stderr) в лог-файл с временной меткой
exec > >(while IFS= read -r line; do echo "$(date '+[%Y-%m-%d %H:%M:%S]') $line"; done | tee -a "$LOG_FILE") 2>&1

## Переменные
STEAM_DIR="/opt/Steam"                                      # полный путь к папке установки Steam
STEAM_USER="steam_username"                                 # имя пользователя Steam
SERVER_LOG="/opt/valheim/logs/valheim.log"                  # файл лога сервера Valheim
SERVER_DIR="/opt/valheim"                                   # полный путь к серверу Valheim без косой черты в конце пути
WORLD_DIR="/home/steam/.config/unity3d/IronGate/Valheim"    # полный путь к папке сохранений миров. Обычно это /<домашняя папка пользователя>/.config/unity3d/IronGate/Valheim
BACKUP_DIR="/backup"                                        # полный путь к папке хранения резервных копий
LOCK_FILE="/tmp/valheim_update.lock"                        # Файл блокировки для предотвращения конфликтов
TIME_FOR_UPDATE="06:00"                                     # Время для запуска обновления сервера по расписанию


# Получаем путь к текущему скрипту. Необходимо для проверки FORCE_UPDATE
SCRIPT_PATH="$(realpath "$0")"

##### Параметры принудительного обновления
# FORCE_UPDATE=1 является триггером для запуска процесса обновления сервера.
# По умолчанию принудительное обновление отключено.
# Если необходимо принудительно запустить процесс обновления сервера Valheim,
# просто укажите FORCE_UPDATE=1 и сохраните скрипт. В течение 10 секунд после сохранения
# автоматически запустится скрипт обновления, а параметр FORCE_UPDATE=1автоматически
# изменится на FORCE_UPDATE=0, чтобы функция обновления не попала в цикл.
FORCE_UPDATE=0



##### Функция для выполнения обновления сервера
perform_update() {
    DATE=$(date +%Y-%m-%d_%H-%M-%S)
    echo "Starting server update process..."

    # Создаём файл блокировки
    touch "$LOCK_FILE"

    # Останавливаем сервер Valheim. Проверьте, чтобы название сервиса было valheim.service
    echo "Stopping Valheim service..."
    if ! systemctl stop valheim.service; then
        echo "Failed to stop Valheim service. Attempting to kill the process..."
        pkill -f "valheim_server.x86_64" || true
    fi

    # Удаляем резервные копии старше 14 дней
    echo "Removing old backups..."
    find "$BACKUP_DIR"/* -type d -mtime +14 -exec rm -rf {} +

    # Создаём резервную копию текущего сервера
    echo "Copying server folder to backups..."
    cp -r "$SERVER_DIR" "$BACKUP_DIR/server_$DATE"

    # Создаём резервную копию миров
    echo "Copying world folder to backups..."
    cp -r "$WORLD_DIR" "$BACKUP_DIR/world_$DATE"

    # Запускаем обновление через SteamCMD
    echo "Updating Valheim server with SteamCMD..."
    "$STEAM_DIR/steamcmd.sh" +force_install_dir "$SERVER_DIR" +login "$STEAM_USER" +app_update 896660 validate +quit

    # Запускаем сервер Valheim
    echo "Starting Valheim service..."
    systemctl start valheim.service

    # Удаляем файл блокировки
    rm -f "$LOCK_FILE"

    echo "Update completed successfully."
}

##### Функция проверки принудительного обновления
check_force_update() {
    # Читаем значение FORCE_UPDATE из этого скрипта
    FORCE_UPDATE_VALUE=$(grep -oP '^FORCE_UPDATE=\K[0-9]+' "$SCRIPT_PATH")

    if [[ "$FORCE_UPDATE_VALUE" -eq 1 ]]; then
        echo "Force update requested. Starting update process..."
        # Обновляем значение FORCE_UPDATE в самом скрипте
        sed -i 's/^FORCE_UPDATE=.*/FORCE_UPDATE=0/' "$SCRIPT_PATH"
        return 0
    fi
    return 1
}

##### Функция проверки времени
check_time_for_update() {
    # Получаем текущее время в формате HH:MM
    CURRENT_TIME=$(date +"%H:%M")
    # сравниваем время с указанным в параметрах
    if [[ "$CURRENT_TIME" == "$TIME_FOR_UPDATE" ]]; then
        return 0 # Время совпало
    else
        return 1 # Время не совпало
    fi
}

##### Функция мониторинга лога
monitor_log() {
    tail -n 0 -F "$SERVER_LOG" | while read -r line; do
        # Проверяем, содержится ли в строке информация о несовместимости версий
        if echo "$line" | grep -q "Peer .* has incompatible version"; then
            # Извлекаем версии сервера и клиента из строки
            server_version=$(echo "$line" | grep -oP 'mine:\K[0-9]+\.[0-9]+\.[0-9]+')
            client_version=$(echo "$line" | grep -oP 'remote \K[0-9]+\.[0-9]+\.[0-9]+')

            # Проверяем, что версии успешно извлечены
            if [[ -n "$server_version" && -n "$client_version" ]]; then
                # Сравниваем версии
                if [[ "$(printf '%s\n' "$server_version" "$client_version" | sort -V | head -n1)" == "$server_version" ]]; then
                    # Сервер старее клиента — запускаем обновление
                    return 0
                else
                    # Сервер новее или равен клиенту — обновление не требуется
                    echo "Server version ($server_version) is newer or equal to client version ($client_version). No update needed."
                    continue
                fi
            else
                echo "Failed to extract versions from log line: $line"
            fi
        fi
    done
}

##### Основной цикл мониторинга
while true; do
    # Проверяем, запущено ли уже обновление
    if [[ -f "$LOCK_FILE" ]]; then
        echo "Update process is already running. Skipping checks..."
        sleep 60 # Ждём минуту перед следующей проверкой
        continue
    fi

    # Проверяем время для обновления
    if check_time_for_update; then
        echo "Scheduled update time reached. Starting update..."
        perform_update
    fi

    # Мониторим лог на наличие сообщений о несовместимости версий
    if monitor_log; then
        echo "Incompatible version detected in log. Starting update..."
        perform_update
    fi

    # Проверяем принудительное обновление
    if check_force_update; then
        echo "Performing force update..."
        perform_update
    fi

    # Ждём перед следующей итерацией
    sleep 10
done
