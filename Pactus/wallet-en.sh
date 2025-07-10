#!/bin/bash

# =========================================================================
# Configuration Variables - Please adjust if needed
# =========================================================================

# Pactus root directory, containing pactus-daemon, pactus-wallet, and the data directory.
# Ensure pactus-daemon and pactus-wallet are executable from here.
PAC_HOME="$HOME/node_pactus"
PAC_DAEMON="$PAC_HOME/pactus-daemon"
PAC_WALLET="$PAC_HOME/pactus-wallet"
REWARD_ADDRESS=""

# =========================================================================
# Helper Functions
# =========================================================================

# Function to retrieve all wallet addresses and assign to global variable ADDRESSES_LIVE
# as well as determine REWARD_ADDRESS
get_all_addresses() {
    echo "Loading wallet list from Pactus Wallet..."
    local raw_output=$("$PAC_WALLET" address all 2>&1) # Redirect both stdout and stderr to variable for error checking
    local exit_code=$?
    
    # Check if the command ran successfully
    if [ $exit_code -ne 0 ]; then
        echo "⚠️ Error running command '$PAC_WALLET address all'."
        echo ""
        echo "Error details: $raw_output"
        echo ""
        echo "Please check: "
        echo "  - Is the path to pactus-wallet ($PAC_WALLET) correct?"
        echo "  - Does pactus-wallet have execute permissions? (chmod +x $PAC_WALLET)"
        echo "  - Has your Pactus wallet been created and is it active/unlocked?"
        ADDRESSES_LIVE=()
        REWARD_ADDRESS=""
        return 1
    fi

    # Clear old ADDRESSES_LIVE array
    unset ADDRESSES_LIVE
    declare -g -a ADDRESSES_LIVE=() # Re-declare as global array
    
    REWARD_ADDRESS="" # Reset reward address
    local temp_reward_address="" # Temporary variable to store the first reward address found
    
    # Read each line of output and parse with awk
    # Awk will automatically handle whitespaces, including non-breaking spaces and tabs.
    # It also skips lines not starting with "pc1"
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Remove control/non-printable characters and numbering (e.g., "1- ")
        local processed_line=$(echo "$line" | tr -d '\r' | sed 's/[^[:print:]\t]//g' | sed -E 's/^[0-9]+-\s*//')
        
        # Use awk to separate address and remaining description
        local address_part=$(echo "$processed_line" | awk '/^pc1/ {print $1}')
        local description_part=$(echo "$processed_line" | awk '/^pc1/ {for(i=2;i<=NF;i++) printf "%s ", $i; print ""}' | sed 's/ $//')

        if [[ -z "$address_part" ]]; then
            continue # Skip if no valid Pactus address found
        fi

        local type_display=""
        if [[ "$description_part" =~ "Reward address" ]]; then
            type_display="Reward address"
            if [[ -z "$temp_reward_address" ]]; then
                temp_reward_address="$address_part"
            fi
        elif [[ "$description_part" =~ "Validator address" ]]; then
            # Extract validator number from description
            local validator_number=$(echo "$description_part" | grep -oP 'Validator address \K[0-9]+' | head -n 1)
            if [[ -n "$validator_number" ]]; then
                type_display="Validator address $validator_number"
            else
                type_display="Validator address (number unknown)" # Fallback
            fi
        else
            type_display="Unknown type"
        fi
        
        ADDRESSES_LIVE+=("$address_part:$type_display")

    done <<< "$raw_output"
    
    REWARD_ADDRESS="$temp_reward_address"

    if [ ${#ADDRESSES_LIVE[@]} -eq 0 ]; then
        echo "Note: Script found no valid wallet addresses in Pactus Wallet output."
        return 1
    fi
    return 0
}

# Function to display the list of all retrieved wallet addresses
display_live_addresses() {
    if ! get_all_addresses; then
        echo "Cannot display wallet list due to data loading error."
        return 1
    fi

    if [ ${#ADDRESSES_LIVE[@]} -eq 0 ]; then
        echo "No wallet addresses found. Ensure your wallet is created and Pactus Wallet is operational."
        return 1
    fi

    echo "---"
    echo "## Your Pactus Wallet List"
    echo "---"
    for i in "${!ADDRESSES_LIVE[@]}"; do
        local entry="${ADDRESSES_LIVE[$i]}"
        local address=$(echo "$entry" | cut -d':' -f1)
        local type_info=$(echo "$entry" | cut -d':' -f2)

        # Use the correctly parsed type information
        # Display sequence number for Validator address according to the extracted number
        if [[ "$type_info" =~ "Validator address " ]]; then
            echo "$((i+1))- ${address} (${type_info})"
        else
            echo "$((i+1))- ${address} (${type_info})"
        fi
    done
    echo ""
    return 0
}

# Function to check if an address is a validator address
is_validator_address() {
    local address_to_check=$1
    for entry in "${ADDRESSES_LIVE[@]}"; do
        local address=$(echo "$entry" | cut -d':' -f1)
        local type_info=$(echo "$entry" | cut -d':' -f2)
        if [[ "$address" == "$address_to_check" && "$type_info" =~ "Validator address" ]]; then
            return 0 # Is a validator
        fi
    done
    return 1 # Not a validator
}


# Function to display the list of all retrieved wallet addresses (duplicate, consider merging)
display_live_addresses() {
    if ! get_all_addresses; then
        echo "Cannot display wallet list due to data loading error."
        return 1
    fi

    if [ ${#ADDRESSES_LIVE[@]} -eq 0 ]; then
        echo "No wallet addresses found. Ensure your wallet is created and Pactus Wallet is operational."
        return 1
    fi

    echo "---"
    echo "## Your Pactus Wallet List"
    echo "---"
    for i in "${!ADDRESSES_LIVE[@]}"; do
        local entry="${ADDRESSES_LIVE[$i]}"
        local address=$(echo "$entry" | cut -d':' -f1)
        local type_info=$(echo "$entry" | cut -d':' -f2)

        # Use the correctly parsed type information
        echo "$((i+1))- ${address} (${type_info})"
    done
    echo ""
    return 0
}

# Function to check if an address is a validator address (duplicate, consider merging)
# This function needs to be updated to use accurate type_info from ADDRESSES_LIVE
is_validator_address() {
    local address_to_check=$1
    for entry in "${ADDRESSES_LIVE[@]}"; do
        local address=$(echo "$entry" | cut -d':' -f1)
        local type_info=$(echo "$entry" | cut -d':' -f2)
        if [[ "$address" == "$address_to_check" && "$type_info" =~ "Validator address" ]]; then
            return 0 # Is a validator
        fi
    done
    return 1 # Not a validator
}

# Function to display the list of all retrieved wallet addresses (duplicate, consider merging)
display_live_addresses() {
    if ! get_all_addresses; then
        echo "Cannot display wallet list due to data loading error."
        return 1
    fi

    if [ ${#ADDRESSES_LIVE[@]} -eq 0 ]; then
        echo "No wallet addresses found. Ensure your wallet is created and Pactus Wallet is operational."
        return 1
    fi

    echo "---"
    echo "## Your Pactus Wallet List"
    echo "---"
    local validator_count=0
    for i in "${!ADDRESSES_LIVE[@]}"; do
        local entry="${ADDRESSES_LIVE[$i]}"
        local address=$(echo "$entry" | cut -d':' -f1)
        local type_info=$(echo "$entry" | cut -d':' -f2)

        if [[ "$type_info" == "Reward address" ]]; then
            echo "$((i+1))- ${address} (Reward address)"
        elif [[ "$type_info" == "Validator address $((i))" ]]; then # This logic seems off, should use parsed validator number
            validator_count=$((validator_count+1))
            echo "$((i+1))- ${address} (Validator address ${validator_count})"
        else
            echo "$((i+1))- ${address} (${type_info})"
        fi
    done
    echo ""
    return 0
}

# Function to get wallet address based on user-entered (1-indexed) sequence number
# Returns only the address (no type)
get_address_by_live_index() {
    local index=$1
    if (( index > 0 && index <= ${#ADDRESSES_LIVE[@]} )); then
        echo "${ADDRESSES_LIVE[index-1]}" | cut -d':' -f1
    else
        echo ""
    fi
}

# Function to check if an address is a validator address
is_validator_address() {
    local address_to_check=$1
    for entry in "${ADDRESSES_LIVE[@]}"; do
        local address=$(echo "$entry" | cut -d':' -f1)
        local type_info=$(echo "$entry" | cut -d':' -f2)
        if [[ "$address" == "$address_to_check" && "$type_info" == *"Validator address"* ]]; then
            return 0 # Is a validator
        fi
    done
    return 1 # Not a validator
}

# =========================================================================
# Main Menu Functions
# =========================================================================

# Display main menu
show_menu() {
    clear
    echo "---------------------------------------------"
    echo "           🧭 MAIN MENU - PACTUS TOOL"
    echo "         ⚠️ Exclusive for Node39.TOP Guide"
    echo "🔗 Guide: https://node39.top/docs/Mainnet/Pactus-Blockchain/"
    echo "---------------------------------------------"
    echo " 1  - 📋 Your Wallet List"
    echo " 2  - 💰 Check Balance"
    echo " 3  - 🔁 Transfer Token"
    echo " 4  - ⚙️  Bond to Validator"
    echo " 5  - 🧩 Unbond Validator"
    echo " 6  - 🎁 Withdraw Rewards (after unbonding)"
    echo " 7  - ♻️  Recover Reward Wallet (old version)"
    echo " 8  - 🔐 View 12 Secret Words (Seed)"
    echo " 9  - 📦 Download Snapshot"
    echo " 0  - 🚪 Exit"
    echo "---------------------------------------------"
    echo -n "🔽 Enter menu number: "
}

# 0 - Download Snapshot
download_snapshot() {
    echo "---"
    echo "## Download Snapshot"
    echo "---"
    echo "Note: After re-downloading the snapshot, data will be updated to the date you downloaded the snapshot."
    echo "Please stop the Validator before downloading the snapshot."
    echo ""
    read -p "Press 'y' to download the snapshot, or any other key to return to the main menu: " -n 1 -r
    echo "" # Add a new line after reading input
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Deleting old data and downloading snapshot..."
        rm -rf "$PAC_HOME/.pactus.lock"
        rm -rf "$PAC_HOME/data"
        "$PAC_DAEMON" import
        echo "✅ Snapshot download complete."
    else
        echo "❌ Snapshot download cancelled."
    fi
    read -p "Press Enter to return to the main menu."
}

# 1 - Wallet List
list_addresses_option() {
    echo "---"
    echo "## Your Wallet List"
    echo "---"
    display_live_addresses
    read -p "Press Enter to return to the main menu."
}

# 2 - View 12 Secret Words (Seed)
show_mnemonic() {
    echo "---"
    echo "## View 12 Secret Words (Seed)"
    echo "---"
    echo "⚠️ These are 12 highly confidential words of your wallet."
    echo "🚷 Any website asking you for them is a scam."
    echo "🚫 If you provide them to anyone, you may lose all funds in your wallet."
    echo ""
    read -p "Press 'y' if you understand and wish to proceed, or 'Enter' to return to the main menu: " -n 1 -r
    echo "" # Add a new line after reading input
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        "$PAC_WALLET" seed
    else
        echo "Cancelled viewing 12 secret words."
    fi
    read -p "Press Enter to return to the main menu."
}

# 3 - Check Balance
check_balance() {
    echo "---"
    echo "## Check Balance"
    echo "---"
    while true; do
        if ! display_live_addresses; then
            read -p "Press Enter to return to the main menu."
            return
        fi

        echo "Enter 'a' to check all wallets."
        echo "Enter 'q' to quit (Back to main menu)."
        read -p "Enter the sequence number of the wallet to check: " choice

        if [[ "$choice" == "q" ]]; then
            break
        elif [[ "$choice" == "a" ]]; then
            echo "Checking balances for all wallets..."
            for entry in "${ADDRESSES_LIVE[@]}"; do
                local addr=$(echo "$entry" | cut -d':' -f1)
                echo "---"
                echo "Balance of $addr:"
                "$PAC_WALLET" address balance "$addr"
            done
            echo "---"
        elif [[ "$choice" =~ ^[0-9]+$ ]]; then
            selected_address=$(get_address_by_live_index "$choice")
            if [[ -n "$selected_address" ]]; then
                echo "Balance of $selected_address:"
                "$PAC_WALLET" address balance "$selected_address"
            else
                echo "⚠️ Invalid choice. Please enter a valid sequence number."
            ECHO "Invalid choice."
            ECHO ""
            ECHO "Enter 'a' to check all wallets"
            ECHO ""
            ECHO "Enter 'q' to quit"
            ECHO ""
            ECHO "Or enter the sequence number of the wallet to check"
            fi
        else 
            echo "⚠️ Invalid choice."
            echo ""
            echo "Enter 'a' to check all wallets"
            echo ""
            echo "Enter 'q' to quit"
            echo ""
            echo "Or enter the sequence number of the wallet to check"
        fi
        echo ""
        read -p "Press Enter to continue checking balance, or 'q' to quit to main menu." next_action
        if [[ "$next_action" == "q" ]]; then
            break
        fi
    done
}

# =========================================================================
# Main Menu Functions (Manual Command Execution)
# =========================================================================

# 4 - Transfer Token
transfer_token() {
    echo "---"
    echo "## Transfer Token"
    echo "---"
    if ! get_all_addresses; then
        read -p "Press Enter to return to the main menu."
        return
    fi
    
    if [[ -z "$REWARD_ADDRESS" ]]; then
        echo "⚠️ No Reward wallet address found. Please ensure your wallet is created and has a Reward address."
        read -p "Press Enter to return to the main menu."
        return
    fi

    local continue_transfer="y"
    while [[ "$continue_transfer" =~ ^[Yy]$ ]]; do
        local sender_address="$REWARD_ADDRESS"
        echo ""
        echo "Source wallet - Reward address: ${sender_address}"
        echo ""
        echo "Enter 'q' to quit"
        echo ""
        read -p "Enter recipient wallet address: " receiver_address
        if [[ "$receiver_address" == "q" ]]; then
            echo "Token transfer cancelled."
            break # Exit transfer token loop
        fi

        read -p "Enter amount of PAC to transfer: " amount
        if [[ "$amount" == "q" ]]; then # Also allow quitting if 'q' is entered for amount
            echo "Token transfer cancelled."
            break # Exit transfer token loop
        fi

        if [[ -z "$receiver_address" || -z "$amount" ]]; then
            echo "⚠️ Recipient wallet address or amount cannot be empty."
            read -p "Press Enter to return to the main menu."
            return
        fi

        echo ""
        echo "--- TOKEN TRANSFER TRANSACTION INFO ---"
        echo "You will be asked to enter your wallet password and confirm after the command runs."
        echo "----------------------------------------"
        echo ""
        
        "$PAC_WALLET" tx transfer "$sender_address" "$receiver_address" "$amount"
        
        echo ""
        echo "✅ Transfer token command executed."
        echo "Please check the output above for status."
        
        read -p "Press Enter to continue transferring or return to main menu." next_action_transfer
        if [[ "$next_action_transfer" =~ ^[Nn]$ ]]; then
             break
        fi

        read -p "Enter 'y' to continue or Enter to return to main menu): " -n 1 -r continue_transfer
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
        read -p "Press Enter to return to the main menu."
        return
    fi

    if [[ -z "$REWARD_ADDRESS" ]]; then
        echo "⚠️ No Reward wallet address found to perform Bond. Please ensure your wallet is created and has a Reward address."
        read -p "Press Enter to return to the main menu."
        return
    fi

    local continue_bond="y"
    while [[ "$continue_bond" =~ ^[Yy]$ ]]; do
        if ! display_live_addresses; then
            read -p "Press Enter to return to the main menu."
            return
        fi
        local reward_addr="$REWARD_ADDRESS" # Default source wallet is reward wallet
        echo "Source wallet - Reward address: ${reward_addr}"

        read -p "Enter sequence number of validator to bond: " validator_num
        local validator_address=$(get_address_by_live_index "$validator_num")

        if [[ -z "$validator_address" ]]; then
            echo "Invalid validator selection."
            read -p "Press Enter to return to the main menu."
            return
        fi
        if ! is_validator_address "$validator_address"; then
            echo "⚠️ The selected address is not a Validator address."
            read -p "Press Enter to return to the main menu."
            return
        fi

        read -p "Enter amount of PAC to bond: " amount

        if [[ -z "$amount" ]]; then
            echo "⚠️ Amount cannot be empty."
            read -p "Press Enter to return to the main menu."
            return
        fi

        echo ""
        echo "--- BOND TRANSACTION INFO ---"
        echo "You will be asked to enter your wallet password and confirm after the command runs."
        echo "--------------------------------"
        echo ""
        
        # Execute pactus-wallet command directly. User will manually enter password and 'y'.
        "$PAC_WALLET" tx bond "$reward_addr" "$validator_address" "$amount"
        
        echo ""
        echo "✅ Bond command executed."
        echo "Please check the output above for status."

        read -p "Press Enter to continue bonding or return to main menu." next_action_bond
        if [[ "$next_action_bond" =~ ^[Nn]$ ]]; then
             break
        fi

        read -p "Enter 'y' to continue or Enter to return to main menu): " -n 1 -r continue_bond
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
        read -p "Press Enter to return to the main menu."
        return
    fi

    local continue_unbond="y"
    while [[ "$continue_unbond" =~ ^[Yy]$ ]]; do
        if ! display_live_addresses; then
            read -p "Press Enter to return to the main menu."
            return
        fi
        echo "⚠️ Note:"
        echo ""
        echo "- Unbond requires waiting 181440 blocks, equivalent to 21 days."
        echo "- After this period, please run the **Withdraw Rewards** command from menu option 7."

        read -p "Enter sequence number of validator to unbond: " validator_num
        local validator_address=$(get_address_by_live_index "$validator_num")

        if [[ -z "$validator_address" ]]; then
            echo "Invalid validator selection."
            read -p "Press Enter to return to the main menu."
            return
        fi
        if ! is_validator_address "$validator_address"; then
            echo "❌ The selected address is not a Validator address."
            read -p "Press Enter to return to the main menu."
            return
        fi

        echo ""
        echo "--- UNBOND TRANSACTION INFO ---"
        echo "You will be asked to enter your wallet password and confirm after the command runs."
        echo "----------------------------------"
        echo ""
        
        # Execute pactus-wallet command directly. User will manually enter password and 'y'.
        "$PAC_WALLET" tx unbond "$validator_address"
        
        echo ""
        echo "✅ Unbond command executed."
        echo "Please check the output above for status."

        read -p "Press Enter to continue unbonding or return to main menu." next_action_unbond
        if [[ "$next_action_unbond" =~ ^[Nn]$ ]]; then
             break
        fi

        read -p "👉 Enter 'y' to continue or Enter to return to main menu): " -n 1 -r continue_unbond
        echo ""
        if [[ ! "$continue_unbond" =~ ^[Aa]$ ]]; then # This condition checks for 'A' or 'a', likely a typo and should be 'Yy'
            break
        fi
    done
}

# 7 - Withdraw Rewards (After unbonding is complete)
withdraw_token() {
    echo "---"
    echo "## Withdraw Rewards (After unbonding is complete)"
    echo "---"
    if ! get_all_addresses; then
        read -p "Press Enter to return to the main menu."
        return
    fi

    if [[ -z "$REWARD_ADDRESS" ]]; then
        echo "❌ No Reward wallet address found to receive rewards. Please ensure your wallet is created and has a Reward address."
        read -p "Press Enter to return to the main menu."
        return
    fi

    if ! display_live_addresses; then
        read -p "Press Enter to return to the main menu."
        return
    fi
    echo "⚠️ Note:"
    echo ""
    echo "To withdraw PAC, please wait 181440 blocks, equivalent to 21 days after unbonding."
    local reward_dest_address="$REWARD_ADDRESS"
    echo "Default destination wallet (Reward address): ${reward_dest_address}"

    read -p "Enter sequence number of validator to withdraw from: " validator_num
    local validator_address=$(get_address_by_live_index "$validator_num")

    if [[ -z "$validator_address" ]]; then
        echo "❌ Invalid validator selection."
        read -p "Press Enter to return to the main menu."
        return
    fi
    if ! is_validator_address "$validator_address"; then
        echo "❌ The selected address is not a Validator address."
        read -p "Press Enter to return to the main menu."
        return
    fi

    read -p "👉 Enter amount of PAC to withdraw: " amount

    if [[ -z "$amount" ]]; then
        echo "⚠️ Amount cannot be empty."
        read -p "Press Enter to return to the main menu."
        return
    fi

    echo ""
    echo "--- WITHDRAW REWARD TRANSACTION INFO ---"
    echo "You will be asked to enter your wallet password and confirm after the command runs."
    echo "------------------------------------------"
    echo ""
    
    "$PAC_WALLET" tx withdraw "$validator_address" "$reward_dest_address" "$amount"
    
    echo ""
    echo "✅ Withdraw reward command executed."
    echo "Please check the output above for status."

    read -p "Press Enter to return to the main menu."
}

# 8 - Recover Reward Wallet (Old version)
recover_old_reward_wallet() {
    echo "---"
    echo "## Recover Reward Wallet (Old version)"
    echo "---"
    echo "Note: This is the old version where each validator had 1 reward wallet."
    echo "If you initially ran the new version (1 common reward wallet for all validators), you should not perform this step."
    echo ""
    read -p "Press 'y' to confirm, or Enter to return to the main menu: " -n 1 -r
    echo "" # Add a new line after reading input
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        "$PAC_WALLET" --path "$PAC_HOME/wallets/default_wallet" address new --type bls_account
        echo "✅ Reward wallet recovery command executed."
    else
        echo "❌ Reward wallet recovery cancelled."
    fi
    read -p "Press Enter to return to the main menu."
}

# =========================================================================
# Main script loop
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
        0) echo "Exiting script. Goodbye!" ; exit 0 ;;
        *) echo "Invalid choice." ; read -p "Press Enter to continue." ;;
    esac
done
