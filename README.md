# Valheim Server Update Bash Script  
Bash-скрипт для обновления сервера Valheim через SteamCMD.  

Предусмотрено три триггера для запуска процесса обновления:  
 1. Запускает процесс обновления в заданное время. Если текущее время совпадает с указанным в настройках скрипта, то запускается процесс обновления;  
 2. Проверяет лог сервера Valheim на наличие сообщений о конфликте версий клиента и сервера - если версия сервера старее, чем версия клиента, то запускается процесс обновления;  
 3. Проверка параметра принудительного запуска обновления.  

В целом все параметры и этапы скрипта описаны в комментариях в самом скрипте.

Скачайте файл скрипта с именем `valheim-update-script.sh` в удобное для вас расположение, например в папку сервера Valheim. Сделайте его исполняемым с помощью команды `chmod +x valheim-update-script.sh`.  
  
# Измените переменные  
Обязательно необходимо изменить переменные на свои. В скрипте указаны лишь для примера:  
`LOG_DIR="/opt/valheim/valheim_updates_log"`                 Полный путь к папке сохранения лога данного скрипта
`STEAM_DIR="/opt/Steam"`                                     Полный путь к папке установки Steam  
`STEAM_USER="steam_username"`                                Имя пользователя Steam  
`SERVER_LOG="/opt/valheim/logs/valheim.log"`                 Файл лога сервера Valheim  
`SERVER_DIR="/opt/valheim"`                                  Полный путь к серверу Valheim без косой черты в конце пути  
`WORLD_DIR="/home/steam/.config/unity3d/IronGate/Valheim"`   Полный путь к папке сохранений миров. Обычно это */<домашняя папка пользователя>/.config/unity3d/IronGate/Valheim*  
`BACKUP_DIR="/backup"`                                       Полный путь к папке хранения резервных копий  
`LOCK_FILE="/tmp/valheim_update.lock"`                       Файл блокировки для предотвращения конфликтов. Можно его не трогать.  
`TIME_FOR_UPDATE="06:00"`                                    Время для запуска обновления сервера по расписанию  

# Запуск  
Запустите удобным для вас способом. Рекомендую использовать Systemd:  
 1. Создайте файл сервиса Systemd  
`nano /etc/systemd/system/valheim-update.service`  
 2. Заполните файл следующим содержимым:  
```
[Unit]
Description=Valheim update Service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/opt/valheim/valheim-update-script.sh
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
```

В строке `ExecStart=/opt/valheim/valheim-update-script.sh` укажите полный путь к файлу скрипта, а в строке `User=root` укажите имя пользователя, который будет запускать скрипт.

## Что требуется учесть для работы скрипта:
 1. Пользователь, который будет запускать скрипт, должен обладать правами для работы с сервисами Systemd;
 2. У вас уже установлен сервер Valheim с помощью SteamCMD, так как скрипт запускает именно SteamCMD для обновления сервера;
 3. Сервер Valheim запускается, как сервис Systemd;
 4. Для проверки файла лога требуется запускать сервер Valheim с ключом `-logfile`.
