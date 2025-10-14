rm -rf test_logs backup_dir
# first
./disk_monitor.sh ./test_logs

# s
./disk_monitor.sh ./non_existent_folder 10 5

# tr
mkdir -p test_logs
echo "file 1" > test_logs/file1.log
echo "file 2" > test_logs/file2.log
echo "file 3" > test_logs/file3.log

./disk_monitor.sh ./test_logs 10 2

# 4
mkdir -p test_logs
# Создаем 3 файла по 1МБ каждый
dd if=/dev/zero of=test_logs/file_C.log bs=1M count=1
dd if=/dev/zero of=test_logs/file_B.log bs=1M count=1
dd if=/dev/zero of=test_logs/file_A.log bs=1M count=1

touch -d "3 days ago" test_logs/file_C.log # Самый новый
touch -d "5 days ago" test_logs/file_B.log # Средний
touch -d "10 days ago" test_logs/file_A.log # the oldest

./disk_monitor.sh ./test_logs 2 2

