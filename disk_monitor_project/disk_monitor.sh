#!/bin/bash
# disk_monitor.sh

# Функция вывода инструкции
print_usage() {
    echo "Usage: $0 <log_directory> <threshold_mb> <files_to_archive>"
    echo "  <log_directory>      - Path to the directory to monitor (must exist)"
    echo "  <threshold_mb>       - Size threshold in MB (e.g., 10)"
    echo "  <files_to_archive>   - Number of old files to archive"
    exit 1
}

# Проверка количества аргументов
if [ $# -ne 3 ]; then
    echo "Error: Exactly 3 arguments are required."
    print_usage
fi

# Присвоение аргументов переменным
LOG_DIR="$1"
THRESHOLD_MB="$2"
COUNT_M="$3"

# Проверка, что путь является папкой
if [ ! -d "$LOG_DIR" ]; then
    echo "Error: Directory '$LOG_DIR' does not exist."
    exit 1
fi

# Проверка, что порог и количество файлов - положительные числа
if ! [[ "$THRESHOLD_MB" =~ ^[0-9]+$ ]]; then
    echo "Error: The size threshold (in MB) must be a positive integer."
    exit 1
fi

if ! [[ "$COUNT_M" =~ ^[0-9]+$ ]] || [ "$COUNT_M" -le 0 ]; then
    echo "Error: The number of files to archive (M) must be a positive integer."
    exit 1
fi

echo "Validation successful."

# Подготовка окружения
BACKUP_DIR="$(dirname "$LOG_DIR")/backup_dir"

if [ ! -d "$BACKUP_DIR" ]; then
    echo "Backup directory '$BACKUP_DIR' not found. Creating it..."
    if ! mkdir -p "$BACKUP_DIR"; then
        echo "Fatal Error: Could not create backup directory '$BACKUP_DIR'."
        exit 1
    fi
fi

# Создание лог-файла для самого скрипта
SCRIPT_LOG="/tmp/disk_monitor_$(date +%Y%m%d).log"
echo "$(date +%Y-%m-%d\ %H:%M:%S) - Script started with arguments: $@" >> "$SCRIPT_LOG"

# Расчёт размера и проверка порога

# Вычисление размера папки LOG_DIR в мегабайтах
LOG_SIZE_MB=$(du -sm "$LOG_DIR" | awk '{print $1}')
echo "Directory size for '$LOG_DIR': ${LOG_SIZE_MB}MB"
echo "Threshold set to: ${THRESHOLD_MB}MB"

# Проверка порога
NEED_ARCHIVE=false
if [ "$LOG_SIZE_MB" -gt "$THRESHOLD_MB" ]; then
    NEED_ARCHIVE=true
    echo "Directory size (${LOG_SIZE_MB}MB) exceeds the threshold (${THRESHOLD_MB}MB)."
    echo "Action required: $COUNT_M oldest files will be archived."
    echo "Directory size (${LOG_SIZE_MB}MB) exceeds the threshold (${THRESHOLD_MB}MB)." >> "$SCRIPT_LOG"
else
    echo "Directory size is within the normal range. No action required."
fi

if [ "$NEED_ARCHIVE" = true ]; then

    # Находим M самых старых файлов
    OLDEST_FILES=$(
        find "$LOG_DIR" -type f -printf '%T@\t%p\n' | # %T@ - время модификации в секундах
        sort -n |                                    # Сортируем по времени (старые вверху)
        head -n "$COUNT_M" |                         # Выбираем M самых старых
        cut -f 2-                                    # Оставляем только пути к файлам
    )

    if [ -z "$OLDEST_FILES" ]; then
        echo "No files found in directory '$LOG_DIR' to archive." >> "$SCRIPT_LOG"
    else
        echo "The following $COUNT_M files have been selected for archiving:"
        echo "$OLDEST_FILES"

        # Архивация
        
        # Уникальное имя для архива
        TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        ARCHIVE_NAME="archive_${TIMESTAMP}.tar.gz"
        ARCHIVE_PATH="${BACKUP_DIR}/${ARCHIVE_NAME}"
        
        # Создаем временный файл со списком файлов для tar
        TEMP_FILE_LIST=$(mktemp)
        echo "$OLDEST_FILES" > "$TEMP_FILE_LIST"
        
        echo "Creating archive: $ARCHIVE_NAME in directory $BACKUP_DIR"
        echo "Creating archive: $ARCHIVE_NAME" >> "$SCRIPT_LOG"

        # Создание архива
        if tar -czf "$ARCHIVE_PATH" -T "$TEMP_FILE_LIST"; then
            echo "Archive '$ARCHIVE_NAME' created successfully."
            echo "Archive '$ARCHIVE_NAME' created successfully." >> "$SCRIPT_LOG"

            # Очистка

            echo "Deleting $COUNT_M original files from $LOG_DIR"
            
            # Удаляем оригинальные файлы, используя список из временного файла
            if xargs -a "$TEMP_FILE_LIST" rm -f; then
                 echo "Original files deleted successfully."
                 echo "Original $COUNT_M files deleted successfully." >> "$SCRIPT_LOG"
            else
                 echo "Error: Failed to delete original files. Manual cleanup may be required." >> "$SCRIPT_LOG"
            fi
            
        else
            echo "Fatal Error: Failed to create archive. Check log: $SCRIPT_LOG"
            rm -f "$ARCHIVE_PATH" # Удаляем неудачный архив
            echo "Error: command tar ended with a wrong." >> "$SCRIPT_LOG"
            rm -f "$TEMP_FILE_LIST"
            exit 1
        fi
        
        # Очистка временного файла
        rm -f "$TEMP_FILE_LIST"
    fi
fi


# Финал

echo "$(date +%Y-%m-%d\ %H:%M:%S) - Script finished." >> "$SCRIPT_LOG"
echo "Script finished. Check log for details: $SCRIPT_LOG"

exit 0
