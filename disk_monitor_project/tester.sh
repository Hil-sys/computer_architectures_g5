#!/bin/bash

# Конфигурация
MAIN_SCRIPT="./disk_monitor.sh"
TEST_DIR="simple_test_env"
LOG_DIR="${TEST_DIR}/log"
BACKUP_DIR="${TEST_DIR}/backup_dir"
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Очистка тестовой среды
cleanup() {
    rm -rf "$TEST_DIR"
    echo -e "\n${YELLOW}[CLEANUP]${NC} Temporary directory '${TEST_DIR}' has been deleted."
}

# Подготовка тестовых файлов
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

    echo -e "${GREEN}[SETUP]${NC} Created $num_files test files in ${LOG_DIR}."
}

# Вывод результата теста
check_result() {
    local test_name="$1"
    local expected_code="$2"
    local actual_code="$3"

    if [ "$actual_code" -eq "$expected_code" ]; then
        echo -e "${GREEN}[SUCCESS]${NC} $test_name. Exit code: $actual_code."
    else
        echo -e "${RED}[FAIL]${NC} $test_name. Expected exit code $expected_code, but got $actual_code."
    fi
}

# Проверка состояния файловой системы
check_fs() {
    local test_name="$1"
    local expected_log_count="$2"
    local expected_archive_count="$3"
    
    sleep 0.1 

    local log_count=$(find "$LOG_DIR" -type f 2>/dev/null | wc -l)
    local archive_count=$(find "$BACKUP_DIR" -type f -name "*.tar.gz" 2>/dev/null | wc -l)

    echo -e "  Checking filesystem state for '$test_name':"
    if [ "$log_count" -eq "$expected_log_count" ] && [ "$archive_count" -eq "$expected_archive_count" ]; then
        echo -e "${GREEN}  [SUCCESS]${NC} Found logs: $log_count, archives: $archive_count. (OK)"
    else
        echo -e "${RED}  [FAIL]${NC} Logs: Expected $expected_log_count, found $log_count."
        echo -e "${RED}  [FAIL]${NC} Archives: Expected $expected_archive_count, found $archive_count."
    fi
}


echo "Tests"

# Тест 1: Некорректное число аргументов (EXIT 1)
echo -e "\n${YELLOW}--- Test 1: Incorrect number of arguments ---${NC}"
$MAIN_SCRIPT "$LOG_DIR" 10 > /dev/null 2>&1
check_result "T1: Validation check (2 of 3 arguments)" 1 $?

# Тест 2: Без действия (EXIT 0)
setup_files 5
echo -e "\n${YELLOW}--- Test 2: High threshold in MB (No action) ---${NC}"
$MAIN_SCRIPT "$LOG_DIR" 10 2 > /dev/null
check_result "T2: No action mode" 0 $?
check_fs "T2" 5 0


# Тест 3: С действием (EXIT 0)
setup_files 5
echo -e "\n${YELLOW}--- Test 3: Low threshold in MB (Archiving M=2) ---${NC}"
$MAIN_SCRIPT "$LOG_DIR" 0 2 > /dev/null
check_result "T3: Archiving mode" 0 $?
check_fs "T3" 3 1

# Тест 4: Неверный аргумент порога (не число)
setup_files 5
echo -e "\n${YELLOW}--- Test 4: Threshold is not a number ---${NC}"
$MAIN_SCRIPT "$LOG_DIR" "abc" 2 > /dev/null 2>&1
check_result "T4: Threshold validation (not a number)" 1 $?
check_fs "T4" 5 0 # Ничего не должно было измениться

# Тест 5: Неверный аргумент количества файлов (не число)
setup_files 5
echo -e "\n${YELLOW}--- Test 5: File count is not a number ---${NC}"
$MAIN_SCRIPT "$LOG_DIR" 0 "xyz" > /dev/null 2>&1
check_result "T5: File count validation (not a number)" 1 $?
check_fs "T5" 5 0 # Ничего не должно было измениться

# Тест 6: Несуществующая папка логов
echo -e "\n${YELLOW}--- Test 6: Non-existent log directory ---${NC}"
cleanup
$MAIN_SCRIPT "/tmp/non_existent_dir_12345" 0 2 > /dev/null 2>&1
check_result "T6: Log directory path validation" 1 $?

# Тест 7: Архивация большего количества файлов, чем есть
setup_files 3 # Создаем только 3 файла
echo -e "\n${YELLOW}--- Test 7: Request to archive more files than exist (M=5, found 3) ---${NC}"
$MAIN_SCRIPT "$LOG_DIR" 0 5 > /dev/null # Просим заархивировать 5
check_result "T7: Archiving all available files" 0 $?
# Скрипт должен заархивировать все 3 файла, которые нашел
check_fs "T7" 0 1 # В логах 0 файлов, 1 новый архив

# Тест 8: Папка пуста, но порог превышен (например, для другой папки)
setup_files 0 # Создаем 0 файлов
echo -e "\n${YELLOW}--- Test 8: Threshold exceeded, but archive directory is empty ---${NC}"
# Порог 0 МБ, но файлов нет
$MAIN_SCRIPT "$LOG_DIR" 0 5 > /dev/null
check_result "T8: Handling an empty directory" 0 $?
# Скрипт должен завершиться успешно, ничего не сделав
check_fs "T8" 0 0

# the end
cleanup

exit 0
