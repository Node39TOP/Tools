#!/bin/bash

# =========================================================================
# Các biến cấu hình - Vui lòng điều chỉnh nếu cần
# =========================================================================

# Thư mục gốc của Pactus, nơi chứa pactus-daemon, pactus-wallet và thư mục data.
# Đảm bảo pactus-daemon và pactus-wallet có thể được thực thi từ đây.
PAC_HOME="$HOME/node_pactus"
PAC_DAEMON="$PAC_HOME/pactus-daemon"
PAC_WALLET="$PAC_HOME/pactus-wallet"
REWARD_ADDRESS=""

# =========================================================================
# Các hàm trợ giúp
# =========================================================================

# Hàm lấy tất cả các địa chỉ ví và gán cho biến toàn cục ADDRESSES_LIVE
# cũng như xác định REWARD_ADDRESS
get_all_addresses() {
    echo "Đang tải danh sách ví từ Pactus Wallet..."
    local raw_output=$("$PAC_WALLET" address all 2>&1) # Chuyển cả stdout và stderr vào biến để kiểm tra lỗi
    local exit_code=$?
    
    # Kiểm tra xem lệnh có chạy thành công không
    if [ $exit_code -ne 0 ]; then
        echo "⚠️ Lỗi khi chạy lệnh '$PAC_WALLET address all'."
        echo ""
        echo "Chi tiết lỗi: $raw_output"
        echo ""
        echo "Vui lòng kiểm tra: "
        echo "  - Đường dẫn đến pactus-wallet ($PAC_WALLET) có đúng không?"
        echo "  - pactus-wallet có quyền thực thi không? (chmod +x $PAC_WALLET)"
        echo "  - Ví Pactus của bạn đã được tạo và có đang hoạt động/mở khóa không?"
        ADDRESSES_LIVE=()
        REWARD_ADDRESS=""
        return 1
    fi

    # Xóa mảng ADDRESSES_LIVE cũ
    unset ADDRESSES_LIVE
    declare -g -a ADDRESSES_LIVE=() # Khai báo lại là mảng toàn cục
    
    REWARD_ADDRESS="" # Reset reward address
    local temp_reward_address="" # Biến tạm để lưu reward address đầu tiên tìm thấy
    
    # Đọc từng dòng đầu ra và phân tích bằng awk
    # Awk sẽ tự động xử lý các khoảng trắng, bao gồm cả non-breaking spaces và tabs.
    # Nó cũng bỏ qua các dòng không bắt đầu bằng "pc1"
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Loại bỏ các ký tự điều khiển/không in được và ký tự số thứ tự (ví dụ "1- ")
        local processed_line=$(echo "$line" | tr -d '\r' | sed 's/[^[:print:]\t]//g' | sed -E 's/^[0-9]+-\s*//')
        
        # Sử dụng awk để tách địa chỉ và phần mô tả còn lại
        local address_part=$(echo "$processed_line" | awk '/^pc1/ {print $1}')
        local description_part=$(echo "$processed_line" | awk '/^pc1/ {for(i=2;i<=NF;i++) printf "%s ", $i; print ""}' | sed 's/ $//')

        if [[ -z "$address_part" ]]; then
            continue # Bỏ qua nếu không tìm thấy địa chỉ Pactus hợp lệ
        fi

        local type_display=""
        if [[ "$description_part" =~ "Reward address" ]]; then
            type_display="Reward address"
            if [[ -z "$temp_reward_address" ]]; then
                temp_reward_address="$address_part"
            fi
        elif [[ "$description_part" =~ "Validator address" ]]; then
            # Trích xuất số validator từ mô tả
            local validator_number=$(echo "$description_part" | grep -oP 'Validator address \K[0-9]+' | head -n 1)
            if [[ -n "$validator_number" ]]; then
                type_display="Validator address $validator_number"
            else
                type_display="Validator address (số không xác định)" # Fallback
            fi
        else
            type_display="Unknown type"
        fi
        
        ADDRESSES_LIVE+=("$address_part:$type_display")

    done <<< "$raw_output"
    
    REWARD_ADDRESS="$temp_reward_address"

    if [ ${#ADDRESSES_LIVE[@]} -eq 0 ]; then
        echo "Lưu ý: Script không tìm thấy địa chỉ ví hợp lệ nào trong đầu ra của Pactus Wallet."
        return 1
    fi
    return 0
}

# Hàm hiển thị danh sách tất cả các địa chỉ ví đã lấy được
display_live_addresses() {
    if ! get_all_addresses; then
        echo "Không thể hiển thị danh sách ví do lỗi tải dữ liệu."
        return 1
    fi

    if [ ${#ADDRESSES_LIVE[@]} -eq 0 ]; then
        echo "Không tìm thấy địa chỉ ví nào. Hãy đảm bảo ví của bạn đã được tạo và Pactus Wallet đang hoạt động."
        return 1
    fi

    echo "---"
    echo "## Danh sách ví Pactus của bạn"
    echo "---"
    for i in "${!ADDRESSES_LIVE[@]}"; do
        local entry="${ADDRESSES_LIVE[$i]}"
        local address=$(echo "$entry" | cut -d':' -f1)
        local type_info=$(echo "$entry" | cut -d':' -f2)

        # Sử dụng thông tin loại đã được phân tích chính xác
        # Hiển thị số thứ tự cho Validator address theo số đã được trích xuất
        if [[ "$type_info" =~ "Validator address " ]]; then
            echo "$((i+1))- ${address} (${type_info})"
        else
            echo "$((i+1))- ${address} (${type_info})"
        fi
    done
    echo ""
    return 0
}

# Hàm kiểm tra xem địa chỉ có phải là validator không
is_validator_address() {
    local address_to_check=$1
    for entry in "${ADDRESSES_LIVE[@]}"; do
        local address=$(echo "$entry" | cut -d':' -f1)
        local type_info=$(echo "$entry" | cut -d':' -f2)
        if [[ "$address" == "$address_to_check" && "$type_info" =~ "Validator address" ]]; then
            return 0 # Là validator
        fi
    done
    return 1 # Không phải validator
}


# Hàm hiển thị danh sách tất cả các địa chỉ ví đã lấy được
display_live_addresses() {
    if ! get_all_addresses; then
        echo "Không thể hiển thị danh sách ví do lỗi tải dữ liệu."
        return 1
    fi

    if [ ${#ADDRESSES_LIVE[@]} -eq 0 ]; then
        echo "Không tìm thấy địa chỉ ví nào. Hãy đảm bảo ví của bạn đã được tạo và Pactus Wallet đang hoạt động."
        return 1
    fi

    echo "---"
    echo "## Danh sách ví Pactus của bạn"
    echo "---"
    for i in "${!ADDRESSES_LIVE[@]}"; do
        local entry="${ADDRESSES_LIVE[$i]}"
        local address=$(echo "$entry" | cut -d':' -f1)
        local type_info=$(echo "$entry" | cut -d':' -f2)

        # Sử dụng thông tin loại đã được phân tích chính xác
        echo "$((i+1))- ${address} (${type_info})"
    done
    echo ""
    return 0
}

# Hàm kiểm tra xem địa chỉ có phải là validator không
# Hàm này cần được cập nhật để sử dụng thông tin type_info chính xác từ ADDRESSES_LIVE
is_validator_address() {
    local address_to_check=$1
    for entry in "${ADDRESSES_LIVE[@]}"; do
        local address=$(echo "$entry" | cut -d':' -f1)
        local type_info=$(echo "$entry" | cut -d':' -f2)
        if [[ "$address" == "$address_to_check" && "$type_info" =~ "Validator address" ]]; then
            return 0 # Là validator
        fi
    done
    return 1 # Không phải validator
}

# Hàm hiển thị danh sách tất cả các địa chỉ ví đã lấy được
display_live_addresses() {
    if ! get_all_addresses; then
        echo "Không thể hiển thị danh sách ví do lỗi tải dữ liệu."
        return 1
    fi

    if [ ${#ADDRESSES_LIVE[@]} -eq 0 ]; then
        echo "Không tìm thấy địa chỉ ví nào. Hãy đảm bảo ví của bạn đã được tạo và Pactus Wallet đang hoạt động."
        return 1
    fi

    echo "---"
    echo "## Danh sách ví Pactus của bạn"
    echo "---"
    local validator_count=0
    for i in "${!ADDRESSES_LIVE[@]}"; do
        local entry="${ADDRESSES_LIVE[$i]}"
        local address=$(echo "$entry" | cut -d':' -f1)
        local type_info=$(echo "$entry" | cut -d':' -f2)

        if [[ "$type_info" == "Reward address" ]]; then
            echo "$((i+1))- ${address} (Reward address)"
        elif [[ "$type_info" == "Validator address $((i))" ]]; then
            validator_count=$((validator_count+1))
            echo "$((i+1))- ${address} (Validator address ${validator_count})"
        else
            echo "$((i+1))- ${address} (${type_info})"
        fi
    done
    echo ""
    return 0
}

# Hàm lấy địa chỉ ví dựa trên số thứ tự (1-indexed) mà người dùng nhập
# Trả về địa chỉ (chỉ địa chỉ, không có loại)
get_address_by_live_index() {
    local index=$1
    if (( index > 0 && index <= ${#ADDRESSES_LIVE[@]} )); then
        echo "${ADDRESSES_LIVE[index-1]}" | cut -d':' -f1
    else
        echo ""
    fi
}

# Hàm kiểm tra xem địa chỉ có phải là validator không
is_validator_address() {
    local address_to_check=$1
    for entry in "${ADDRESSES_LIVE[@]}"; do
        local address=$(echo "$entry" | cut -d':' -f1)
        local type_info=$(echo "$entry" | cut -d':' -f2)
        if [[ "$address" == "$address_to_check" && "$type_info" == *"Validator address"* ]]; then
            return 0 # Là validator
        fi
    done
    return 1 # Không phải validator
}

# =========================================================================
# Các chức năng chính của menu
# =========================================================================

# Hiển thị menu chính
show_menu() {
    clear
    echo "---------------------------------------------"
    echo "           🧭 MENU CHÍNH - PACTUS TOOL"
    echo "         ⚠️ Dành riêng cho Node39.TOP Guide"
    echo "🔗 Hướng dẫn: https://node39.top/docs/Mainnet/Pactus-Blockchain/"
    echo "---------------------------------------------"
    echo " 1  - 📋 Danh sách ví của bạn"
    echo " 2  - 💰 Kiểm tra số dư"
    echo " 3  - 🔁 Chuyển Token"
    echo " 4  - ⚙️  Bond vào Validator"
    echo " 5  - 🧩 Unbond Validator"
    echo " 6  - 🎁 Rút phần thưởng (sau khi unbond)"
    echo " 7  - ♻️  Khôi phục ví reward (phiên bản cũ)"
    echo " 8  - 🔐 Xem 12 ký tự bí mật (Seed)"
    echo " 9  - 📦 Tải Snapshot"
    echo " 0  - 🚪 Thoát"
    echo "---------------------------------------------"
    echo -n "🔽 Nhập số thứ tự trong menu: "
}

# 0 - Tải Snapshot
download_snapshot() {
    echo "---"
    echo "## Tải Snapshot"
    echo "---"
    echo "Lưu ý: Sau khi tải lại snapshot, các dữ liệu sẽ cập nhật lại theo ngày bạn tải snapshot."
    echo "Vui lòng dừng Validator trước khi tải snapshot."
    echo ""
    read -p "Nhấn 'y' để tải snapshot, hoặc bất kỳ phím nào khác để quay lại menu chính: " -n 1 -r
    echo "" # Thêm dòng mới sau khi đọc input
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Đang xóa dữ liệu cũ và tải snapshot..."
        rm -rf "$PAC_HOME/.pactus.lock"
        rm -rf "$PAC_HOME/data"
        "$PAC_DAEMON" import
        echo "✅ Tải snapshot hoàn tất."
    else
        echo "❌ Hủy tải snapshot."
    fi
    read -p "Nhấn Enter để quay lại menu chính."
}

# 1 - Danh sách ví
list_addresses_option() {
    echo "---"
    echo "## Danh sách ví của bạn"
    echo "---"
    display_live_addresses
    read -p "Nhấn Enter để quay lại menu chính."
}

# 2 - Xem 12 ký tự bí mật (Seed)
show_mnemonic() {
    echo "---"
    echo "## Xem 12 ký tự bí mật (Seed)"
    echo "---"
    echo "⚠️ Đây là 12 từ đặc biệt bí mật của ví bạn."
    echo "🚷 Bất cứ trang web nào yêu cầu bạn cung cấp thì đó là lừa đảo."
    echo "🚫 Nếu bạn cung cấp cho bất cứ ai, bạn có thể mất toàn bộ số tiền trong ví."
    echo ""
    read -p "Nhấn 'y' nếu bạn đã hiểu rõ và muốn tiếp tục xem, hoặc 'Enter' để quay lại menu chính: " -n 1 -r
    echo "" # Thêm dòng mới sau khi đọc input
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        "$PAC_WALLET" seed
    else
        echo "Hủy xem 12 ký tự bí mật."
    fi
    read -p "Nhấn Enter để quay lại menu chính."
}

# 3 - Kiểm tra số dư
check_balance() {
    echo "---"
    echo "## Kiểm tra số dư"
    echo "---"
    while true; do
        if ! display_live_addresses; then
            read -p "Nhấn Enter để quay lại menu chính."
            return
        fi

        echo "Nhập 'a' để kiểm tra tất cả các ví."
        echo "Nhập 'q' để thoát (Về menu chính)."
        read -p "Nhập số thứ tự ví cần kiểm tra: " choice

        if [[ "$choice" == "q" ]]; then
            break
        elif [[ "$choice" == "a" ]]; then
            echo "Đang kiểm tra số dư cho tất cả các ví..."
            for entry in "${ADDRESSES_LIVE[@]}"; do
                local addr=$(echo "$entry" | cut -d':' -f1)
                echo "---"
                echo "Số dư của $addr:"
                "$PAC_WALLET" address balance "$addr"
            done
            echo "---"
        elif [[ "$choice" =~ ^[0-9]+$ ]]; then
            selected_address=$(get_address_by_live_index "$choice")
            if [[ -n "$selected_address" ]]; then
                echo "Số dư của $selected_address:"
                "$PAC_WALLET" address balance "$selected_address"
            else
                echo "⚠️ Lựa chọn không hợp lệ. Vui lòng nhập số thứ tự hợp lệ."
            fi
        else 
            echo "⚠️ Lựa chọn không hợp lệ."
            echo ""
            echo "Nhập 'a' để kiểm tra tất cả ví"
            echo ""
            echo "Nhập 'q' để thoát"
            echo ""
            echo "Hoặc nhập số thứ tự ví cần kiểm tra"
        fi
        echo ""
        read -p "Nhấn Enter để tiếp tục kiểm tra số dư, hoặc 'q' để thoát về menu chính." next_action
        if [[ "$next_action" == "q" ]]; then
            break
        fi
    done
}

# =========================================================================
# Các chức năng chính của menu (Thực thi lệnh thủ công)
# =========================================================================

# 4 - Chuyển Token
transfer_token() {
    echo "---"
    echo "## Chuyển Token"
    echo "---"
    if ! get_all_addresses; then
        read -p "Nhấn Enter để quay lại menu chính."
        return
    fi
    
    if [[ -z "$REWARD_ADDRESS" ]]; then
        echo "⚠️ Không tìm thấy địa chỉ ví Reward. Vui lòng đảm bảo ví của bạn đã được tạo và có một địa chỉ Reward."
        read -p "Nhấn Enter để quay lại menu chính."
        return
    fi

    local continue_transfer="y"
    while [[ "$continue_transfer" =~ ^[Yy]$ ]]; do
        local sender_address="$REWARD_ADDRESS"
        echo ""
        echo "Ví nguồn - Reward address: ${sender_address}"
        echo ""
        echo "Nhập 'q' để thoát"
        echo ""
        read -p "Nhập địa chỉ ví người nhận: " receiver_address
        if [[ "$receiver_address" == "q" ]]; then
            echo "Hủy chuyển token."
            break # Thoát khỏi vòng lặp chuyển token
        fi

        read -p "Nhập số lượng PAC muốn chuyển: " amount
        if [[ "$amount" == "q" ]]; then # Cũng cho phép thoát nếu nhập 'q' ở số lượng
            echo "Hủy chuyển token."
            break # Thoát khỏi vòng lặp chuyển token
        fi

        if [[ -z "$receiver_address" || -z "$amount" ]]; then
            echo "⚠️ Địa chỉ ví người nhận hoặc số lượng không được để trống."
            read -p "Nhấn Enter để quay lại menu chính."
            return
        fi

        echo ""
        echo "--- THÔNG TIN GIAO DỊCH CHUYỂN TOKEN ---"
        echo "Bạn sẽ được yêu cầu nhập mật khẩu ví và xác nhận sau khi lệnh chạy."
        echo "----------------------------------------"
        echo ""
        
        "$PAC_WALLET" tx transfer "$sender_address" "$receiver_address" "$amount"
        
        echo ""
        echo "✅ Lệnh chuyển token đã được thực thi."
        echo "Vui lòng kiểm tra đầu ra phía trên để biết trạng thái."
        
        read -p "Nhấn Enter để tiếp tục chuyển hoặc quay về menu chính." next_action_transfer
        if [[ "$next_action_transfer" =~ ^[Nn]$ ]]; then
             break
        fi

        read -p "Nhập 'y' để tiếp tục hoặc Enter để quay về menu chính): " -n 1 -r continue_transfer
        echo ""
        if [[ ! "$continue_transfer" =~ ^[Yy]$ ]]; then
            break
        fi
    done
}

# 5 - Bond to Validator
bond_to_validator() {
    echo "---"
    echo "## Bond to Validator"
    echo "---"
    if ! get_all_addresses; then
        read -p "Nhấn Enter để quay lại menu chính."
        return
    fi

    if [[ -z "$REWARD_ADDRESS" ]]; then
        echo "⚠️ Không tìm thấy địa chỉ ví Reward để thực hiện Bond. Vui lòng đảm bảo ví của bạn đã được tạo và có một địa chỉ Reward."
        read -p "Nhấn Enter để quay lại menu chính."
        return
    fi

    local continue_bond="y"
    while [[ "$continue_bond" =~ ^[Yy]$ ]]; do
        if ! display_live_addresses; then
            read -p "Nhấn Enter để quay lại menu chính."
            return
        fi
        local reward_addr="$REWARD_ADDRESS" # Ví mặc định (nguồn) là ví reward
        echo "Ví nguồn - Reward address: ${reward_addr}"

        read -p "Nhập số thứ tự validator cần bond: " validator_num
        local validator_address=$(get_address_by_live_index "$validator_num")

        if [[ -z "$validator_address" ]]; then
            echo "Lựa chọn validator không hợp lệ."
            read -p "Nhấn Enter để quay lại menu chính."
            return
        fi
        if ! is_validator_address "$validator_address"; then
            echo "⚠️ Địa chỉ đã chọn không phải là địa chỉ Validator."
            read -p "Nhấn Enter để quay lại menu chính."
            return
        fi

        read -p "Nhập số lượng PAC muốn bond: " amount

        if [[ -z "$amount" ]]; then
            echo "⚠️ Số lượng không được để trống."
            read -p "Nhấn Enter để quay lại menu chính."
            return
        fi

        echo ""
        echo "--- THÔNG TIN GIAO DỊCH BOND ---"
        echo "Bạn sẽ được yêu cầu nhập mật khẩu ví và xác nhận sau khi lệnh chạy."
        echo "--------------------------------"
        echo ""
        
        # Thực thi lệnh pactus-wallet trực tiếp. Người dùng sẽ nhập mật khẩu và 'y' thủ công.
        "$PAC_WALLET" tx bond "$reward_addr" "$validator_address" "$amount"
        
        echo ""
        echo "✅ Lệnh bond đã được thực thi."
        echo "Vui lòng kiểm tra đầu ra phía trên để biết trạng thái."

        read -p "Nhấn Enter để tiếp tục bond hoặc quay về menu chính." next_action_bond
        if [[ "$next_action_bond" =~ ^[Nn]$ ]]; then
             break
        fi

        read -p "nhập 'y' để tiếp tục hoặc Enter để quay về menu chính): " -n 1 -r continue_bond
        echo ""
        if [[ ! "$continue_bond" =~ ^[Yy]$ ]]; then
            break
        fi
    done
}

# 6 - Unbond
unbond_validator() {
    echo "---"
    echo "## Unbond Validator"
    echo "---"
    if ! get_all_addresses; then
        read -p "Nhấn Enter để quay lại menu chính."
        return
    fi

    local continue_unbond="y"
    while [[ "$continue_unbond" =~ ^[Yy]$ ]]; do
        if ! display_live_addresses; then
            read -p "Nhấn Enter để quay lại menu chính."
            return
        fi
        echo "⚠️ Lưu ý:"
        echo ""
        echo "- Unbond cần đợi 181440 blocks tương đương 21 ngày."
        echo "- Sau thời gian trên, vui lòng chạy lệnh **Rút phần thưởng** trên menu số 7."

        read -p "Nhập số thứ tự validator cần unbond: " validator_num
        local validator_address=$(get_address_by_live_index "$validator_num")

        if [[ -z "$validator_address" ]]; then
            echo "Lựa chọn validator không hợp lệ."
            read -p "Nhấn Enter để quay lại menu chính."
            return
        fi
        if ! is_validator_address "$validator_address"; then
            echo "❌ Địa chỉ đã chọn không phải là địa chỉ Validator."
            read -p "Nhấn Enter để quay lại menu chính."
            return
        fi

        echo ""
        echo "--- THÔNG TIN GIAO DỊCH UNBOND ---"
        echo "Bạn sẽ được yêu cầu nhập mật khẩu ví và xác nhận sau khi lệnh chạy."
        echo "----------------------------------"
        echo ""
        
        # Thực thi lệnh pactus-wallet trực tiếp. Người dùng sẽ nhập mật khẩu và 'y' thủ công.
        "$PAC_WALLET" tx unbond "$validator_address"
        
        echo ""
        echo "✅ Lệnh unbond đã được thực thi."
        echo "Vui lòng kiểm tra đầu ra phía trên để biết trạng thái."

        read -p "Nhấn Enter để tiếp tục unbond hoặc quay về menu chính." next_action_unbond
        if [[ "$next_action_unbond" =~ ^[Nn]$ ]]; then
             break
        fi

        read -p "👉 Nhập 'y' để tiếp tục hoặc Enter để quay về menu chính): " -n 1 -r continue_unbond
        echo ""
        if [[ ! "$continue_unbond" =~ ^[Aa]$ ]]; then
            break
        fi
    done
}

# 7 - Rút phần thưởng (Sau khi unbond xong)
withdraw_token() {
    echo "---"
    echo "## Rút phần thưởng (Sau khi unbond xong)"
    echo "---"
    if ! get_all_addresses; then
        read -p "Nhấn Enter để quay lại menu chính."
        return
    fi

    if [[ -z "$REWARD_ADDRESS" ]]; then
        echo "❌ Không tìm thấy địa chỉ ví Reward để nhận phần thưởng. Vui lòng đảm bảo ví của bạn đã được tạo và có một địa chỉ Reward."
        read -p "Nhấn Enter để quay lại menu chính."
        return
    fi

    if ! display_live_addresses; then
        read -p "Nhấn Enter để quay lại menu chính."
        return
    fi
    echo "⚠️Lưu ý:"
    echo ""
    echo "Để rút được PAC, vui lòng đợi 181440 blocks tương đương 21 ngày sau khi unbond."
    local reward_dest_address="$REWARD_ADDRESS"
    echo "Ví đích mặc định (Reward address): ${reward_dest_address}"

    read -p "Nhập số thứ tự validator cần withdraw: " validator_num
    local validator_address=$(get_address_by_live_index "$validator_num")

    if [[ -z "$validator_address" ]]; then
        echo "❌ Lựa chọn validator không hợp lệ."
        read -p "Nhấn Enter để quay lại menu chính."
        return
    fi
    if ! is_validator_address "$validator_address"; then
        echo "❌ Địa chỉ đã chọn không phải là địa chỉ Validator."
        read -p "Nhấn Enter để quay lại menu chính."
        return
    fi

    read -p "👉 Nhập số lượng PAC muốn rút: " amount

    if [[ -z "$amount" ]]; then
        echo "⚠️ Số lượng không được để trống."
        read -p "Nhấn Enter để quay lại menu chính."
        return
    fi

    echo ""
    echo "--- THÔNG TIN GIAO DỊCH RÚT PHẦN THƯỞNG ---"
    echo "Bạn sẽ được yêu cầu nhập mật khẩu ví và xác nhận sau khi lệnh chạy."
    echo "------------------------------------------"
    echo ""
    
    "$PAC_WALLET" tx withdraw "$validator_address" "$reward_dest_address" "$amount"
    
    echo ""
    echo "✅ Lệnh rút phần thưởng đã được thực thi."
    echo "Vui lòng kiểm tra đầu ra phía trên để biết trạng thái."

    read -p "Nhấn Enter để quay lại menu chính."
}

# 8 - Khôi phục ví reward (Phiên bản cũ)
recover_old_reward_wallet() {
    echo "---"
    echo "## Khôi phục ví reward (Phiên bản cũ)"
    echo "---"
    echo "Lưu ý: Đây là phiên bản cũ loại mỗi validator 1 ví reward."
    echo "Nếu từ đầu bạn đã chạy phiên bản mới (1 ví reward chung cho tất cả validator) thì không nên làm bước này."
    echo ""
    read -p "Nhập 'y' để đồng ý, hoặc Enter để quay về menu chính: " -n 1 -r
    echo "" # Thêm dòng mới sau khi đọc input
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        "$PAC_WALLET" --path "$PAC_HOME/wallets/default_wallet" address new --type bls_account
        echo "✅ Lệnh khôi phục ví reward đã được thực thi."
    else
        echo "❌ Hủy khôi phục ví reward."
    fi
    read -p "Nhấn Enter để quay về menu chính."
}

# =========================================================================
# Vòng lặp chính của script
# =========================================================================
while true; do
    show_menu
    read choice
    case "$choice" in
        1) list_addresses_option ;;
        2) check_balance ;;
        3) transfer_token ;;
        4) bond_to_validator ;;
        5) unbond_validator ;;
        6) withdraw_token ;;
        7) recover_old_reward_wallet ;;
        8) show_mnemonic ;;
        9) download_snapshot ;;
        0) echo "Thoát khỏi script. Tạm biệt!" ; exit 0 ;;
        *) echo "Lựa chọn không hợp lệ." ; read -p "Nhấn Enter để tiếp tục." ;;
    esac
done
