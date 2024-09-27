# Frappe & ERPNext Auto-Installer for WSL

Welcome to the Frappe & ERPNext Auto-Installer for Windows Subsystem for Linux (WSL)! This script automates the installation of Frappe Framework and optionally ERPNext and HRMS on your WSL environment, making it easy to get started with development or testing.

## 🌟 Features

-   Automated Installation: Installs Frappe Framework version 15 on WSL with minimal input.
-   Optional Apps: Choose to install ERPNext and/or HRMS during the setup.
-   Custom Configuration: Generates a unique identifier to prevent conflicts with existing installations.
-   MariaDB Configuration: Sets up MariaDB 10.6 with secure settings.
-   Environment Setup: Installs all necessary dependencies including Node.js, Redis, and wkhtmltopdf.
-   User-Friendly Prompts: Guides you through the setup with clear and friendly prompts.

## 📦 Prerequisites

-   Windows Subsystem for Linux (WSL) installed on your Windows machine.
-   Ubuntu 22.04 LTS or a compatible Linux distribution running in WSL.
-   No other WSL instances running Frappe benches. Ensure all other WSL instances with benches are closed before running the installer.

## 🚀 Installation

Follow these steps to install Frappe and optionally ERPNext and HRMS on your WSL environment.

### 1. Clone the Repository

Open your WSL terminal and clone the repository:


`git clone https://github.com/kamikazce/Frappe-ErpNext-Autoinstall-WSL.git`

`cd Frappe-ErpNext-Autoinstall-WSL`

3. Make the Installer Executable

`chmod +x install.sh` 

4. Run the Installer Execute the installer script with root privileges:

`sudo ./install.sh` 

## 🛠 Usage The installer will guide you through several prompts: 
1. Create a New User: You can choose to create a new system user or use the current one.
2. MariaDB Root Password: Set a password for the MariaDB root user.
3. Administrator Password: Set a password for the Frappe administrator account.
4. Site Name: Specify the name of the new Frappe site.
5. Install ERPNext: Choose whether to install the ERPNext application.
6. Install HRMS: Choose whether to install the HRMS application.
7. Starting the Bench After the installation is complete, switch to the specified user and start the bench:

`sudo su - your_username cd /var/bench/frappe-bench15_unique_id/ bench start` 
* Replace `your_username` with the username you selected during installation. * Replace `unique_id` with the unique identifier generated during installation (e.g., `frappe-bench15_a3b99f84`).

* Accessing Your Site Open your web browser and navigate to:

`http://localhost:8000` 
Log in using: 
* Username: `Administrator`
* Password: The administrator password you set during installation.

## * ⚠ Important Notes * 
Close Other WSL Instances: Before running the installer, ensure that no other WSL instances with Frappe benches are running. Having multiple benches running simultaneously can cause conflicts and prevent `bench start` from working correctly. 
* MariaDB Service: The installer starts MariaDB manually due to WSL limitations. Ensure MariaDB is running when you need it.
* Permissions: If you encounter any permissions issues, verify that directories and files have the correct ownership (`mysql:mysql` for MariaDB data directories).

## * 🐞 Troubleshooting * 
* Bench Start Issues: If `bench start` fails, check that no other benches are running and that MariaDB is active. 
* MariaDB Connection Errors: Ensure MariaDB is running and accepting connections on `127.0.0.1`. The script configures MariaDB to listen on localhost.
* Port Conflicts: If port `8000` is already in use, you can specify a different port when starting the bench:

`bench start --port 8001` 

🤝 Contributing We welcome contributions! If you have suggestions for improvements or encounter any issues, feel free to open an issue or submit a pull request on GitHub.

