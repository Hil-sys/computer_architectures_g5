# Функция вывода инструкции
print_usage() {
    echo "Usage: $0 <log_directory> <threshold_percent> <files_to_archive>"
    echo "  <log_directory>     - Path to the directory for monitoring (must exist)"
    echo "  <threshold_percent> - Threshold percentage (1-100)"
    echo "  <files_to_archive>  - Number of old files to select (positive integer)"
    exit 1
}

# 1.1. Проверка количества аргументов
if [ $# -ne 3 ]; then
    echo "Error: Exactly 3 arguments required."
    print_usage
fi

# Присвоение аргументов переменным
LOG_DIR="$1"
THRESHOLD_N="$2"
COUNT_M="$3"

# 1.2. Проверка пути
if [ ! -d "$LOG_DIR" ]; then
    echo "Error: Directory '$LOG_DIR' does not exist or is not a directory."
    exit 1
fi

# 1.3. Проверка чисел (N и M)
if ! [[ "$THRESHOLD_N" =~ ^[0-9]+$ ]] || [ "$THRESHOLD_N" -le 0 ] || [ "$THRESHOLD_N" -gt 100 ]; then
    echo "Error: Threshold percentage (N) must be a positive integer between 1 and 100."
    exit 1
fi

if ! [[ "$COUNT_M" =~ ^[0-9]+$ ]] || [ "$COUNT_M" -le 0 ]; then
    echo "Error: Files count (M) must be a positive integer."
    exit 1
fi

echo "--- ARGUMENTS VALIDATION SUCCESSFUL ---"

# 2.2. Настройка бэкапа (создаем, но не используем до 5 задачи)
BACKUP_DIR="/var/log/monitor_backups" # Выбрали место для бэкапов

if [ ! -d "$BACKUP_DIR" ]; then
    echo "Backup directory '$BACKUP_DIR' not found. Creating it..."
    if ! mkdir -p "$BACKUP_DIR"; then
        echo "Fatal Error: Could not create backup directory '$BACKUP_DIR'."
        exit 1
    fi
fi

# 2.3. Создание лог-файла для скрипта
SCRIPT_LOG="/tmp/disk_monitor_$(date +%Y%m%d).log"
echo "$(date +%Y-%m-%d\ %H:%M:%S) - Script started with arguments: $@" >> "$SCRIPT_LOG"

echo "--- ENVIRONMENT SETUP COMPLETE ---"

# 3.1. Вычисление размера папки LOG_DIR
# Используем du для получения размера в мегабайтах (-m)
LOG_SIZE_MB=$(du -sm "$LOG_DIR" | awk '{print $1}')
echo "Monitored Directory Size: ${LOG_SIZE_MB}MB" >> "$SCRIPT_LOG"

# 3.2. Вычисление процента заполнения раздела, на котором находится папка
# $4 - процент использования, $5 - точка монтирования
DISK_INFO=$(df "$LOG_DIR" | awk 'NR==2 {print $5, $1}')
DISK_PERCENT=$(echo "$DISK_INFO" | awk '{print $1}' | sed 's/%//')

if [ -z "$DISK_PERCENT" ]; then
    echo "Error: Could not determine disk usage for '$LOG_DIR'."
    exit 1
fi

echo "Disk Usage for mount point '$(echo "$DISK_INFO" | awk '{print $2}')': ${DISK_PERCENT}%"
echo "Threshold for action: ${THRESHOLD_N}%"

# 3.3. Проверка порога
NEED_ARCHIVE=false
if [ "$DISK_PERCENT" -gt "$THRESHOLD_N" ]; then
    NEED_ARCHIVE=true
    echo "ALERT! Disk usage (${DISK_PERCENT}%) exceeds threshold (${THRESHOLD_N}%)." >> "$SCRIPT_LOG"
    echo "Action required: $COUNT_M oldest files will be selected for archiving."
else
    echo "Disk usage (${DISK_PERCENT}%) is below the threshold. No action required."
fi

echo "--- SIZE CALCULATION COMPLETE ---"

if [ "$NEED_ARCHIVE" = true ]; then

    echo "--- STARTING FILE SELECTION ---"

    # 4.1-4.3. Поиск, сортировка по mtime (старый - первый), выбор M файлов
    # -type f: только файлы
    # -print0: разделение результатов символом null для безопасности (работа с пробелами в именах)
    # | xargs -0 ls -lt: сортировка по времени (lt), -0 для обработки null-разделителей
    # | grep -v ^d: исключаем директории, если ls -l выводит их
    # | tail -n "$COUNT_M": выбираем M самых старых

    # Внимание: find -type f -mtime +0 | sort | head -n M - это надёжный способ
    # сортировки по дате изменения (старые-первые). ls -lt может быть ненадёжным
    # для очень большого количества файлов.

    # Используем более надёжный метод: find с форматированием.
    # %T@ - время модификации в секундах
    # %p - имя файла
    # sort -n: сортировка по числовому значению (времени)
    OLDEST_FILES=$(
        find "$LOG_DIR" -type f -printf '%T@\t%p\n' |
        sort -n |
        head -n "$COUNT_M" |
        cut -f 2-
    )

    if [ -z "$OLDEST_FILES" ]; then
        echo "Warning: No files found in '$LOG_DIR' to select for archiving." >> "$SCRIPT_LOG"
    else
        # 4.4. Вывод списка для проверки
        echo "The following $COUNT_M oldest files have been selected for archiving:"
        echo "$OLDEST_FILES"
    fi
fi

echo "$(date +%Y-%m-%d\ %H:%M:%S) - Script execution finished (Ready for Archiving)." >> "$SCRIPT_LOG"

exit 0
