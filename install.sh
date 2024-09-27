#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

# ----------------------------
# Color Codes for Echo Messages
# ----------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

echo -e "${CYAN}----------------------------------------------------------"
echo "----------------------------------------------------------"
echo "                   Kamikazce - CT-GALEGA                  "
echo "----------------------------------------------------------"
echo -e "----------------------------------------------------------${NC}"

# ----------------------------
# Generate Unique Identifier
# ----------------------------
UNIQUE_ID=$(date +%s%N | sha256sum | head -c 8)
echo -e "${BLUE}Generated Unique ID: $UNIQUE_ID${NC}"

# ----------------------------
# Function Definitions
# ----------------------------

# Function to prompt for MariaDB password
prompt_for_mariadb_password() {
    while true; do
        echo -ne "${YELLOW}Enter the desired password for MariaDB root user:${NC} "
        read -s mariadb_password
        echo
        echo -ne "${YELLOW}Confirm the MariaDB root password:${NC} "
        read -s mariadb_password_confirm
        echo
        if [ "$mariadb_password" = "$mariadb_password_confirm" ]; then
            break
        else
            echo -e "${RED}Passwords do not match. Please try again.${NC}"
        fi
    done
}

# Function to prompt for administrator password
prompt_for_admin_password() {
    while true; do
        echo -ne "${YELLOW}Enter the desired Frappe administrator password:${NC} "
        read -s admin_password
        echo
        echo -ne "${YELLOW}Confirm the Frappe administrator password:${NC} "
        read -s admin_password_confirm
        echo
        if [ "$admin_password" = "$admin_password_confirm" ]; then
            break
        else
            echo -e "${RED}Passwords do not match. Please try again.${NC}"
        fi
    done
}

# ----------------------------
# Collect All Inputs at the Start
# ----------------------------

# Check for Root Privileges
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}This script must be run as root. Please run with sudo or as root.${NC}"
    exit 1
fi

# Prompt to create a new user
echo -ne "${YELLOW}Do you want to create a new user? (yes/no):${NC} "
read create_user
if [ "$create_user" = "yes" ]; then
    echo -ne "${YELLOW}Enter the new username:${NC} "
    read new_username
    if id "$new_username" &>/dev/null; then
        echo -e "${YELLOW}User '$new_username' already exists.${NC}"
    else
        adduser "$new_username"
        usermod -aG sudo "$new_username"
        echo -e "${GREEN}New user '$new_username' created and added to the sudo group.${NC}"
    fi
    username="$new_username"
else
    username=$(logname)
fi

# Prompt for passwords
prompt_for_mariadb_password
prompt_for_admin_password

# Prompt for site name
echo -ne "${YELLOW}Enter the name of the site to create:${NC} "
read site_name

# Optional Installation of ERPNext
echo -ne "${YELLOW}Do you want to install ERPNext? (yes/no):${NC} "
read install_erpnext

# Optional Installation of HRMS
echo -ne "${YELLOW}Do you want to install HRMS? (yes/no):${NC} "
read install_hrms

# ----------------------------
# Export Variables
# ----------------------------
export username
export mariadb_password
export admin_password
export site_name
export install_erpnext
export install_hrms
export UNIQUE_ID

# ----------------------------
# Update and Upgrade System
# ----------------------------
echo -e "${BLUE}Updating and upgrading the system...${NC}"
apt-get update -y
apt-get upgrade -y
apt-get install -y apt-transport-https curl lsb-release gnupg ca-certificates software-properties-common

# ----------------------------
# Install MariaDB 10.6
# ----------------------------
install_mariadb() {
    echo -e "${BLUE}Installing MariaDB Server 10.6...${NC}"    
    apt-get install -y curl gnupg lsb-release software-properties-common    
    curl -LsS https://r.mariadb.com/downloads/mariadb_repo_setup -o mariadb_repo_setup    
    chmod +x mariadb_repo_setup    
    sudo ./mariadb_repo_setup --mariadb-server-version="mariadb-10.6"    
    rm mariadb_repo_setup    
    apt-get update -y    
    apt-get install -y mariadb-server mariadb-backup

    # Verify MariaDB version
    mariadb_version=$(mariadb --version | awk '{print $5}' | cut -d'.' -f1-2)
    if [ "$mariadb_version" != "10.6" ]; then
        echo -e "${RED}MariaDB version $mariadb_version installed, but version 10.6 is required.${NC}"
        exit 1
    fi
    echo -e "${GREEN}MariaDB 10.6 installed successfully.${NC}"
}

# Start MariaDB Service with Unique Configuration
start_mariadb() {
    echo -e "${BLUE}Starting MariaDB service with unique configuration...${NC}"

    # Generate unique identifiers based on UNIQUE_ID
    SOCKET_FILE="/var/run/mysqld/mysqld_${UNIQUE_ID}.sock"
    PID_FILE="/run/mysqld/mysqld_${UNIQUE_ID}.pid"
    DATA_DIR="/var/lib/mysql_${UNIQUE_ID}"

    export SOCKET_FILE
    export PID_FILE
    export DATA_DIR

    # Ensure directories exist
    mkdir -p /var/run/mysqld
    mkdir -p "$DATA_DIR"
    chown -R mysql:mysql /var/run/mysqld
    chown -R mysql:mysql "$DATA_DIR"

    # Initialize the database if it doesn't exist
    if [ ! -d "$DATA_DIR/mysql" ]; then
        echo -e "${BLUE}Initializing MariaDB data directory...${NC}"
        mysql_install_db --user=mysql --datadir="$DATA_DIR" --auth-root-authentication-method=normal
    fi

    # Create custom configuration file
    CUSTOM_CNF="/etc/mysql/mariadb.conf.d/99-custom_${UNIQUE_ID}.cnf"
    cat <<EOF > "$CUSTOM_CNF"
[mysqld]
datadir = $DATA_DIR
socket = $SOCKET_FILE
pid-file = $PID_FILE
bind-address = 127.0.0.1
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
character-set-client-handshake = FALSE

[client]
socket = $SOCKET_FILE
EOF

    # Start MariaDB with custom configuration
    mysqld_safe --defaults-file="$CUSTOM_CNF" &

    # Wait until MariaDB is running
    for i in {1..10}; do
        if mysqladmin --socket="$SOCKET_FILE" ping --silent; then
            echo -e "${GREEN}MariaDB is running.${NC}"
            return 0
        else
            echo -e "${YELLOW}Waiting for MariaDB to start... ($i/10)${NC}"
            sleep 2
        fi
    done

    echo -e "${RED}MariaDB did not start within the expected time.${NC}"
    exit 1
}

# Secure MariaDB Installation
secure_mariadb() {
    echo -e "${BLUE}Securing MariaDB installation...${NC}"

    # Use mysql to connect via socket
    mysql --socket="$SOCKET_FILE" -u root <<EOF
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
-- Use GRANT to set password and privileges for 'root'@'127.0.0.1'
GRANT ALL PRIVILEGES ON *.* TO 'root'@'127.0.0.1' IDENTIFIED BY '$mariadb_password' WITH GRANT OPTION;
ALTER USER 'root'@'localhost' IDENTIFIED BY '$mariadb_password';
FLUSH PRIVILEGES;
EOF

    echo -e "${GREEN}MariaDB has been secured successfully.${NC}"
}

# Run the functions
install_mariadb
start_mariadb
secure_mariadb

# Install necessary packages
echo -e "${BLUE}Installing additional packages...${NC}"
apt-get install -y git python3-dev python3-setuptools python3-pip python3-distutils redis-server python3-venv xvfb libfontconfig

# Install wkhtmltopdf
echo -e "${BLUE}Installing wkhtmltopdf...${NC}"
wget https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-2/wkhtmltox_0.12.6.1-2.jammy_amd64.deb
apt install -y ./wkhtmltox_0.12.6.1-2.jammy_amd64.deb
rm wkhtmltox_0.12.6.1-2.jammy_amd64.deb

# Install Node.js 18.x
echo -e "${BLUE}Installing Node.js 18.x...${NC}"
curl -s https://deb.nodesource.com/gpgkey/nodesource.gpg.key | gpg --dearmor | sudo tee /usr/share/keyrings/nodesource-archive-keyring.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/nodesource-archive-keyring.gpg] https://deb.nodesource.com/node_18.x $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/nodesource.list
apt-get update -y
apt-get install -y nodejs

# Set Up Bench Environment
echo -e "${BLUE}Setting up Bench environment...${NC}"

# Create /var/bench directory if it doesn't exist
if [ ! -d "/var/bench" ]; then
    mkdir /var/bench
fi

# Change ownership to the user
sudo chown -R "$username":"$username" /var/bench

# Install frappe-bench and yarn
sudo pip3 install frappe-bench
sudo npm install -g yarn

# Initialize Frappe Bench
echo -e "${BLUE}Initializing Frappe Bench Version 15...${NC}"

# Run commands as the specified user
sudo -H -u "$username" bash -c "
cd /var/bench
bench init --verbose --frappe-path https://github.com/frappe/frappe --frappe-branch version-15 --python /usr/bin/python3 frappe-bench15_${UNIQUE_ID}
cd frappe-bench15_${UNIQUE_ID}
"

# Ensure MariaDB is running
start_mariadb

# Create a new site
sudo -H -u "$username" bash -c "
cd /var/bench/frappe-bench15_${UNIQUE_ID}
bench new-site '$site_name' --db-root-password '$mariadb_password' --admin-password '$admin_password'
bench use '$site_name'
bench enable-scheduler
bench set-config developer_mode 1
bench --site '$site_name' set-maintenance-mode off
./env/bin/pip3 install cython==0.29.21
./env/bin/pip3 install numpy numpy-financial
"

# Install ERPNext if selected
if [ "$install_erpnext" = "yes" ]; then
    echo -e "${BLUE}Installing ERPNext for Frappe Version 15...${NC}"
    sudo -H -u "$username" bash -c "
    cd /var/bench/frappe-bench15_${UNIQUE_ID}
    bench get-app erpnext --branch version-15
    bench install-app erpnext
    ./env/bin/pip3 install -e apps/erpnext/
    "
    echo -e "${GREEN}ERPNext has been installed successfully.${NC}"
else
    echo -e "${YELLOW}Skipping ERPNext installation.${NC}"
fi

# Install HRMS if selected
if [ "$install_hrms" = "yes" ]; then
    echo -e "${BLUE}Installing HRMS for Frappe Version 15...${NC}"
    sudo -H -u "$username" bash -c "
    cd /var/bench/frappe-bench15_${UNIQUE_ID}
    bench get-app hrms --branch version-15
    bench install-app hrms
    ./env/bin/pip3 install -e apps/hrms/
    "
    echo -e "${GREEN}HRMS has been installed successfully.${NC}"
else
    echo -e "${YELLOW}Skipping HRMS installation.${NC}"
fi

# ----------------------------
# Configure System for Redis
# ----------------------------
echo -e "${BLUE}Configuring system for Redis optimizations...${NC}"
echo 'never' | sudo tee /sys/kernel/mm/transparent_hugepage/enabled
echo 'vm.overcommit_memory = 1' | sudo tee -a /etc/sysctl.conf
sudo sysctl -w vm.overcommit_memory=1
echo 'net.core.somaxconn = 511' | sudo tee -a /etc/sysctl.conf
sudo sysctl -w net.core.somaxconn=511

# ----------------------------
# Installation Resume
# ----------------------------
echo -e "${MAGENTA}#######################"
echo "## Installation Complete ##"
echo -e "#######################${NC}"
echo -e "${GREEN}MariaDB password is set."
echo "Administrator password is set."
echo "Your new bench is located at /var/bench/frappe-bench15_${UNIQUE_ID}/"
echo "To start using your bench, switch to the '$username' user and navigate to /var/bench/frappe-bench15_${UNIQUE_ID}/"
echo -e "Example:${NC}"
echo -e "${YELLOW}  sudo su - $username"
echo "  cd /var/bench/frappe-bench15_${UNIQUE_ID}"
echo -e "  bench start${NC}"
echo -e "${MAGENTA}#######################${NC}"
