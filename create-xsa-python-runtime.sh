#!/bin/bash

# This script builds a Python runtime from source code and deploys it to XS Advanced.

# Put the Python tarball in this mount directory: ${python_tarball_mnt_directory}/
python_tarball_mnt_directory="/mnt/your_mount_directory"

ESC_START="\e[1;33m"
ESC_START2="\e[33m"
ESC_END="\e[0m"

# This code block checks if the script is being run as _.
if [ "$EUID" -ne 0 ]; then
    echo -e "${ESC_START2}WARNING: Please run as root${ESC_END}"
    exit 1
fi

# Check if /mnt is mounted, exit with error if not
if ! mount | grep -q "/mnt"; then
    echo -e "${ESC_START2}WARNING: /mnt is not mounted${ESC_END}"
    exit 1
fi

# Check if both arguments are set, if not, print usage and exit with error code 1
if [ -z "$1" ] || [ -z "$2" ]; then
    echo -e "${ESC_START2}WARNING: One or both arguments are not set${ESC_END}"
    echo 'Usage:'
    echo './create-xsa-python-runtime.sh 3.7.2 SID'
    exit 1
else
    # Set sid variable to second argument and convert it to lowercase
    sid="$2"
    sid="$(echo "$sid" | tr '[:upper:]' '[:lower:]')"
    adm="adm"
    sidadm="$sid$adm"
    hostname=$(hostname)
    echo "sidadm: ${sidadm}"
    echo "Argument 1: $1"
    echo "Argument 2: $sid"
    echo "Argument 2 (lowercase): $sid"
    echo "Both arguments are set."
fi

# Check if the Python source directory already exists
# $1 - Python version
python_source_directory="/usr/sap/${sidadm}/home/builds/Python-$1"
if [ -d "$python_source_directory" ]; then
    echo -e "${ESC_START2}WARNING: This Python-$1 source already exists in ${python_source_directory}${ESC_END}"
    exit 1
fi

# Install dependencies required for building Python runtime
echo -e "${ESC_START}Installing dependencies...${ESC_END}"

# This script installs the required packages for creating an XSA Python runtime.
# It checks if each package is already installed, and if not, installs it using yum.
# The list of required packages is stored in the 'packages' array.
packages=("tk-devel" "tcl-devel" "libffi-devel" "openssl-devel" "readline-devel" "sqlite-devel" "ncurses-devel" "xz-devel" "zlib-devel" "bzip2-devel")

# Install any missing packages.
for package in "${packages[@]}"; do
    if rpm -q "$package" &>/dev/null; then
        echo "$package is already installed."
    else
        sudo yum install -y "$package"
        echo "$package has been installed."
    fi
done

# Check if "gcc" is installed, if not, install "Development Tools" group
if ! rpm -q "gcc" &>/dev/null; then
    dnf group install -y "Development Tools"
fi

# Check if the Python-$1.tgz file exists in ${python_tarball_mnt_directory}/ directory.
# If the file does not exist, print an error message and exit with status code 1.
if ! test -e "${python_tarball_mnt_directory}/Python-$1.tgz"; then
    echo -e "${ESC_START2}WARNING: Python-$1.tgz is not in ${python_tarball_mnt_directory}/${ESC_END}"
    exit 1
else
    echo "Python-$1.tgz is in ${python_tarball_mnt_directory}/"

    # Copy the Python tarball with the specified version number to the Downloads directory
    cp ${python_tarball_mnt_directory}/Python-"$1".tgz /usr/sap/"${sidadm}"/home/Downloads/

    # Check if the Python-$1.tgz file exists in /usr/sap/${sidadm}/home/Downloads/ directory.
    # If the file does not exist, print an error message and exit with status code 1.

    file_path_Downloads_python="/usr/sap/${sidadm}/home/Downloads/Python-${1}.tgz"
    echo "This is the Downloads Path $\"{file_path_Downloads_python}\""

    if [ ! -e "$file_path_Downloads_python" ]; then
        # if ! test -e "/usr/sap/${sidadm}/home/Downloads/Python-${1}.tgz"; then
        echo -e "${ESC_START2}WARNING: Python-$1.tgz is not in $file_path_Downloads_python${ESC_END}"
        exit 1
    else
        echo "Python-$1.tgz is in /usr/sap/${sidadm}/home/Downloads/"
        echo "extract Python-$1.tgz"
        cd /usr/sap/"${sidadm}"/home/Downloads/ || exit
        tar -xvf Python-"$1".tgz
        rm -rf Python-"$1".tgz

        # Check if the Python-$1 directory exists in /usr/sap/${sidadm}/home/Downloads/ directory.
        # If the directory does not exist, print an error message and exit with status code 1.
        if ! test -d "/usr/sap/${sidadm}/home/Downloads/Python-${1}"; then
            echo -e "${ESC_START2}WARNING: Python-$1 is not in /usr/sap/${sidadm}/home/Downloads/${ESC_END}"

            exit 1
        else
            # Delete the Python version from the source directory
            rm -rf /usr/sap/"${sidadm}"/home/source/Python-"$1"

            # Copy the downloaded Python version to the source ddirectory
            cp -R /usr/sap/"${sidadm}"/home/Downloads/Python-"$1" /usr/sap/"${sidadm}"/home/source/

            # Delete the Python version from the Downloads directory
            rm -rf /usr/sap/"${sidadm}"/home/Downloads/Python-"$1"

            echo "ls -la /usr/sap/${sidadm}/home/source"
            ls -la /usr/sap/"${sidadm}"/home/source

            # This command changes the ownership of all files and directories under /usr/sap/${sidadm}/home/source/
            # to the user and group specified by ${sidadm} and sapsys respectively.
            echo "chown -R ${sidadm}:sapsys /usr/sap/${sidadm}/home/source/*"
            chown -R "${sidadm}":sapsys /usr/sap/"${sidadm}"/home/source/*

            echo "ls -la /usr/sap/${sidadm}/home/source"
            ls -la /usr/sap/"${sidadm}"/home/source

            # Changes the current working directory to the Python source directory for the specified version.
            echo "cd /usr/sap/${sidadm}/home/source/Python-$1"
            cd /usr/sap/"${sidadm}"/home/source/Python-"$1" || exit 1
            echo "configure Python-$1"
            # Configures the Python build with the specified version and optimizations.
            # The prefix and exec-prefix options set the installation directory for the build.
            ./configure \
                --prefix=/usr/sap/"${sidadm}"/home/builds/Python-"$1" \
                --exec-prefix=/usr/sap/"${sidadm}"/home/builds/Python-"$1" \
                --enable-optimizations

            # This code block compiles and installs a Python runtime from source code.
            # The `make -j4` command compiles the source code using 4 threads.
            # The `unset PYTHONHOME` and `unset PYTHONPATH` commands ensure that the Python environment variables are not set.
            # The `make altinstall` command installs the compiled Python runtime as an alternative version of Python.
            # The `clean` command removes any temporary files created during the compilation process.
            # make -j4 && unset PYTHONHOME && unset PYTHONPATH && make altinstall clean
            # if the system has 8 cores, then you could use the make -j8 option to speed up the compilation process.
            make -j8 && unset PYTHONHOME && unset PYTHONPATH && make altinstall clean

            echo "chown Python-$1"
            chown -R "${sidadm}":sapsys /usr/sap/"${sidadm}"/home/builds/Python-"$1"

            # This code block creates a runtime for Python with the specified version number.
            # It uses the 'xs' command to create the runtime in the specified directory.
            # The command is executed as the user specified in the ${sidadm} variable.
            # The directory where the runtime is created is /usr/sap/${sidadm}/home/builds/Python-$1.
            # The version number is passed as an argument to the script.
            echo -e "${ESC_START}============================================================${ESC_END}"
            echo -e "${ESC_START}The building of Python-$1 from the sources was successful!!!${ESC_END}"
            echo -e "${ESC_START}============================================================${ESC_END}"
            echo -e "${ESC_START}Now create runtime for source Python-$1${ESC_END}"
            echo -e "${ESC_START}Login to XS CLI: xs login -a https://api.${hostname}.domain:30033 -u XSA_ADMIN -o XSA -s SAP${ESC_END}"
            echo -e "${ESC_START}Create runtime: xs create-runtime -p ${python_source_directory}{ESC_END}"
            echo -e "${ESC_START}List runtimes: xs runtimes${ESC_END}"
        fi
    fi

fi
