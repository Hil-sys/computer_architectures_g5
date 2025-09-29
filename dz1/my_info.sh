check_name() {
    if [[ -z "$1" ]]; then
        echo "Input cannot be empty. Please try again."
        return 1
    fi

    if [[ "$1" =~ [^a-zA-Zа-яА-Я\ ] ]]; then
        echo "Input must contain only letters and spaces. Please try again."
        return 1
    fi
    return 0
}

check_age() {
    if [[ -z "$1" ]]; then
        echo "Input cannot be empty. Please try again."
        return 1
    fi

    if ! [[ "$1" =~ ^[0-9]+$ ]]; then
        echo "Age must be a number. Please try again."
        return 1
    fi

    if (( "$1" < 0 || "$1" > 110 )); then
        echo "Age must be between 0 and 110. Please try again."
        return 1
    fi
    return 0
}

while true; do
    read -p "Enter your FIO (e.g., Ivanov Ivan Ivanovich): " full_name
    if check_name "$full_name"; then
        break
    fi
done

read -r family_name first_name middle_name <<< $(echo "$full_name" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr -s ' ')

while true; do
    read -p "Enter your Age: " age
    if check_age "$age"; then
        break
    fi
done

echo "Hello, my name is $family_name $first_name $middle_name, and I am $age years old."