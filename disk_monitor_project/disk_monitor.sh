#!/bin/bash
# disk_monitor.sh

# Настройка и валидация аргументов

# Функция вывода инструкции
print_usage() {
    echo "Usage: $0 <log_directory> <threshold_mb> <files_to_archive>"
    echo "  <log_directory>      - Путь к папке для мониторинга (должна существовать)"
    echo "  <threshold_mb>       - Порог размера папки в МБ (например, 10)"
    echo "  <files_to_archive>   - Количество старых файлов для архивации"
    exit 1
}

# Проверка количества аргументов
if [ $# -ne 3 ]; then
    echo "Ошибка: Требуется ровно 3 аргумента."
    print_usage
fi

# Присвоение аргументов переменным
LOG_DIR="$1"
THRESHOLD_MB="$2"
COUNT_M="$3"

# Проверка, что путь является папкой
if [ ! -d "$LOG_DIR" ]; then
    echo "Ошибка: Папка '$LOG_DIR' не существует."
    exit 1
fi

# Проверка, что порог и количество файлов - положительные числа
if ! [[ "$THRESHOLD_MB" =~ ^[0-9]+$ ]]; then
    echo "Ошибка: Порог размера (в МБ) должен быть положительным числом."
    exit 1
fi

if ! [[ "$COUNT_M" =~ ^[0-9]+$ ]] || [ "$COUNT_M" -le 0 ]; then
    echo "Ошибка: Количество файлов для архивации (M) должно быть положительным числом."
    exit 1
fi

echo "--- Succesful Validation ---"

# Подготовка окружения
BACKUP_DIR="$(dirname "$LOG_DIR")/backup_dir"

if [ ! -d "$BACKUP_DIR" ]; then
    echo "Папка для бэкапов '$BACKUP_DIR' не найдена. Создаю..."
    if ! mkdir -p "$BACKUP_DIR"; then
        echo "Критическая ошибка: Не удалось создать папку '$BACKUP_DIR'."
        exit 1
    fi
fi

# Создание лог-файла для самого скрипта
SCRIPT_LOG="/tmp/disk_monitor_$(date +%Y%m%d).log"
echo "$(date +%Y-%m-%d\ %H:%M:%S) - Скрипт запущен с аргументами: $@" >> "$SCRIPT_LOG"

# Расчёт размера и проверка порога

# Вычисление размера папки LOG_DIR в мегабайтах
LOG_SIZE_MB=$(du -sm "$LOG_DIR" | awk '{print $1}')
echo "Размер папки '$LOG_DIR': ${LOG_SIZE_MB}МБ"
echo "Установленный порог: ${THRESHOLD_MB}МБ"

# Проверка порога
NEED_ARCHIVE=false
if [ "$LOG_SIZE_MB" -gt "$THRESHOLD_MB" ]; then
    NEED_ARCHIVE=true
    echo "ВНИМАНИЕ! Размер папки (${LOG_SIZE_MB}МБ) превышает порог (${THRESHOLD_MB}МБ)."
    echo "Требуется действие: будет заархивировано $COUNT_M старых файлов."
    echo "ВНИМАНИЕ! Размер папки (${LOG_SIZE_MB}МБ) превышает порог (${THRESHOLD_MB}МБ)." >> "$SCRIPT_LOG"
else
    echo "Размер папки в пределах нормы. Никаких действий не требуется."
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
        echo "Предупреждение: В папке '$LOG_DIR' нет файлов для архивации." >> "$SCRIPT_LOG"
    else
        echo "Следующие $COUNT_M файлов выбраны для архивации:"
        echo "$OLDEST_FILES"

        # АРХИВАЦИЯ -
        
        # Уникальное имя для архива
        TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        ARCHIVE_NAME="archive_${TIMESTAMP}.tar.gz"
        ARCHIVE_PATH="${BACKUP_DIR}/${ARCHIVE_NAME}"
        
        # Создаем временный файл со списком файлов для tar
        TEMP_FILE_LIST=$(mktemp)
        echo "$OLDEST_FILES" > "$TEMP_FILE_LIST"
        
        echo "Создается архив: $ARCHIVE_NAME в папке $BACKUP_DIR..."
        echo "Создается архив: $ARCHIVE_NAME" >> "$SCRIPT_LOG"

        # Создание архива
        if tar -czf "$ARCHIVE_PATH" -T "$TEMP_FILE_LIST"; then
            echo "Архив '$ARCHIVE_NAME' успешно создан."
            echo "Архив '$ARCHIVE_NAME' успешно создан." >> "$SCRIPT_LOG"

            # -ОЧИСТКА 

            echo "Начинается удаление $COUNT_M оригинальных файлов из $LOG_DIR..."
            
            # Удаляем оригинальные файлы, используя список из временного файла
            if xargs -a "$TEMP_FILE_LIST" rm -f; then
                 echo "Оригинальные файлы успешно удалены."
                 echo "Оригинальные $COUNT_M файлов успешно удалены." >> "$SCRIPT_LOG"
            else
                 echo "Ошибка: Не удалось удалить оригинальные файлы. Может потребоваться ручная очистка." >> "$SCRIPT_LOG"
            fi
            
        else
            echo "Критическая ошибка: Не удалось создать архив. Проверьте лог: $SCRIPT_LOG"
            rm -f "$ARCHIVE_PATH" # Удаляем неудачный архив
            echo "Ошибка: команда tar завершилась с ошибкой." >> "$SCRIPT_LOG"
            rm -f "$TEMP_FILE_LIST"
            exit 1
        fi
        
        # Очистка временного файла
        rm -f "$TEMP_FILE_LIST"
    fi
fi


# Финал

echo "$(date +%Y-%m-%d\ %H:%M:%S) - Выполнение скрипта завершено." >> "$SCRIPT_LOG"
echo "Скрипт завершил работу. Детали в логе: $SCRIPT_LOG"

exit 0
