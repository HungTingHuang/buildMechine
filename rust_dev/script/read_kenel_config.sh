

read_kconfig_value() {
    key=$1
    awk -F= -v key="$key" '
        $1 == key {
            value = $2
            gsub(/^"/, "", value)
            gsub(/"$/, "", value)
            print value
        }
    ' "$KENEL_CONFIG"
}