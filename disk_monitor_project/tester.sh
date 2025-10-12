#!/bin/bash

# --- КОНФИГУРАЦИЯ ---
MAIN_SCRIPT="./disk_monitor.sh"
TEST_DIR="simple_test_env"
LOG_DIR="${TEST_DIR}/log"
BACKUP_DIR="${TEST_DIR}/backup_dir"
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

# 1. Очистка тестовой среды
cleanup() {
    rm -rf "$TEST_DIR"
    echo -e "\n${YELLOW}[ОЧИСТКА]${NC} Временная папка '${TEST_DIR}' удалена."
}

# 2. Подготовка тестовых файлов
setup_files() {
    local num_files=${1:-5} # По умолчанию создаем 5 файлов
    cleanup
    mkdir -p "$LOG_DIR" "$BACKUP_DIR"

    for i in $(seq 1 $num_files); do
        local content="Log entry $i"
        local file_name="file_$i.log"
        # Создаем файлы с разной датой модификации
        touch -d "$((10-i)) days ago" "${LOG_DIR}/${file_name}"
        echo "$content" > "${LOG_DIR}/${file_name}"
    done

    echo -e "${GREEN}[SETUP]${NC} Создано $num_files тестовых файлов в ${LOG_DIR}."
}

# 3. Вывод результата теста
check_result() {
    local test_name="$1"
    local expected_code="$2"
    local actual_code="$3"

    if [ "$actual_code" -eq "$expected_code" ]; then
        echo -e "${GREEN}[УСПЕХ]${NC} $test_name. Код выхода $actual_code."
    else
        echo -e "${RED}[ПРОВАЛ]${NC} $test_name. Ожидался код выхода $expected_code, получен $actual_code."
    fi
}

# 4. Проверка состояния файловой системы
check_fs() {
    local test_name="$1"
    local expected_log_count="$2"
    local expected_archive_count="$3"
    
    sleep 0.1 

    local log_count=$(find "$LOG_DIR" -type f 2>/dev/null | wc -l)
    local archive_count=$(find "$BACKUP_DIR" -type f -name "*.tar.gz" 2>/dev/null | wc -l)

    echo -e "  Проверка состояния для '$test_name':"
    if [ "$log_count" -eq "$expected_log_count" ] && [ "$archive_count" -eq "$expected_archive_count" ]; then
        echo -e "${GREEN}  [ФС УСПЕХ]${NC} Найдено логов: $log_count, архивов: $archive_count. (ОК)"
    else
        echo -e "${RED}  [ФС ПРОВАЛ]${NC} Логов: Ожидалось $expected_log_count, найдено $log_count."
        echo -e "${RED}  [ФС ПРОВАЛ]${NC} Архивов: Ожидалось $expected_archive_count, найдено $archive_count."
    fi
}


echo "===== Start ====="

# ТЕСТ 1: Некорректное число аргументов (EXIT 1)
echo -e "\n${YELLOW}--- test1: Некорректное число аргументов ---${NC}"
$MAIN_SCRIPT "$LOG_DIR" 10 > /dev/null 2>&1
check_result "Т1: Проверка валидации (2 из 3 аргументов)" 1 $?

# ТЕСТ 2: Без действия (EXIT 0)
setup_files 5
echo -e "\n${YELLOW}--- test2: Высокий порог в МБ (Нет действия) ---${NC}"
$MAIN_SCRIPT "$LOG_DIR" 10 2 > /dev/null
check_result "Т2: Режим бездействия" 0 $?
check_fs "Т2" 5 0


# ТЕСТ 3: С действием (EXIT 0)
setup_files 5
echo -e "\n${YELLOW}--- test3: Низкий порог в МБ (Архивация M=2) ---${NC}"
$MAIN_SCRIPT "$LOG_DIR" 0 2 > /dev/null
check_result "Т3: Режим архивации" 0 $?
check_fs "Т3" 3 1

# ТЕСТ 4: Неверный аргумент порога (не число)
setup_files 5
echo -e "\n${YELLOW}--- test4: Порог не является числом ---${NC}"
$MAIN_SCRIPT "$LOG_DIR" "abc" 2 > /dev/null 2>&1
check_result "Т4: Валидация порога (не число)" 1 $?
check_fs "Т4" 5 0 # Ничего не должно было измениться

# ТЕСТ 5: Неверный аргумент количества файлов (не число)
setup_files 5
echo -e "\n${YELLOW}--- test5: Количество файлов не является числом ---${NC}"
$MAIN_SCRIPT "$LOG_DIR" 0 "xyz" > /dev/null 2>&1
check_result "Т5: Валидация количества файлов (не число)" 1 $?
check_fs "Т5" 5 0 # Ничего не должно было измениться

# ТЕСТ 6: Несуществующая папка логов
echo -e "\n${YELLOW}--- test6: Несуществующая папка логов ---${NC}"
cleanup
$MAIN_SCRIPT "/tmp/non_existent_dir_12345" 0 2 > /dev/null 2>&1
check_result "Т6: Валидация пути к папке логов" 1 $?

# ТЕСТ 7: Архивация большего количества файлов, чем есть
setup_files 3 # Создаем только 3 файла
echo -e "\n${YELLOW}---test7: Запрошено архивировать больше файлов, чем существует (M=5, есть 3) ---${NC}"
$MAIN_SCRIPT "$LOG_DIR" 0 5 > /dev/null # Просим заархивировать 5
check_result "Т7: Архивация всех доступных файлов" 0 $?
# Скрипт должен заархивировать все 3 файла, которые нашел
check_fs "Т7" 0 1 # В логах 0 файлов, 1 новый архив

# ТЕСТ 8: Папка пуста, но порог превышен (например, для другой папки)
setup_files 0 # Создаем 0 файлов
echo -e "\n${YELLOW}--- test8: Порог превышен, но папка для архивации пуста ---${NC}"
# Порог 0 МБ, но файлов нет
$MAIN_SCRIPT "$LOG_DIR" 0 5 > /dev/null
check_result "Т8: Работа с пустой папкой" 0 $?
# Скрипт должен завершиться успешно, ничего не сделав
check_fs "Т8" 0 0

# the end
cleanup

exit 0
