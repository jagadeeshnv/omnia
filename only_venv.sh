#!/bin/bash

ansible_version="9.5.1"
python_version="3.11"
py_major_version="3"
py_minor_version="11"
venv_py=python$python_version
os_release_data="/etc/os-release"
venv_location=/opt/omniavenv_1.7
# venv_location=~/omnia_venv
# venv_location=/home/jag/omnia/venvy/py39venv

ALLOWED_UBUNTU_VERSIONS=("20.04" "22.04")
ALLOWED_RHEL_VERSIONS=("8.4" "8.5", "9.5")
ALLOWED_ROCKY_VERSIONS=("8.4" "8.5")

# Function to get OS information
get_os_info() {
    if [ -f $os_release_data ]; then
        . $os_release_data
        OS_ID=$ID
        OS_VERSION=$VERSION_ID
    else
        OS_ID="Unknown"
        OS_VERSION="Unknown"
        echo "Unable to determine OS version."
        exit 1
    fi
}

# Function to check if a version is in the allowed list
is_version_allowed() {
    local version=$1
    shift
    local allowed_versions=("$@")
    for allowed_version in "${allowed_versions[@]}"; do
        if [[ "$version" == "$allowed_version" ]]; then
            return 0
        fi
    done
    return 1
}

# Function to check Ubuntu
check_ubuntu() {
    if is_version_allowed "$OS_VERSION" "${ALLOWED_UBUNTU_VERSIONS[@]}"; then
        echo "Ubuntu $OS_VERSION is an allowed version."
    else
        echo "Ubuntu $OS_VERSION is not an allowed version."
        exit 1
    fi
}

# Function to check RHEL
check_rhel() {
    if is_version_allowed "$OS_VERSION" "${ALLOWED_RHEL_VERSIONS[@]}"; then
        echo "RHEL $OS_VERSION is an allowed version."
    else
        echo "RHEL $OS_VERSION is not an allowed version."
        exit 1
    fi
}

# Function to check Rocky Linux
check_rocky() {
    if is_version_allowed "$OS_VERSION" "${ALLOWED_ROCKY_VERSIONS[@]}"; then
        echo "Rocky Linux $OS_VERSION is an allowed version."
        dnf install epel-release -y
    else
        echo "Rocky Linux $OS_VERSION is not an allowed version."
        exit 1
    fi
}

get_installed_ansible_version() {
    $venv_py -m pip show ansible 2>/dev/null | grep Version | awk '{print $2}'
}

install_ansible() {
    # TOTHINK Will it replace the collections installed?
    echo "Installing Ansible $ansible_version..."
    $venv_py -m pip install ansible=="$ansible_version" #--force-reinstall or --ignore-installed is not required
}

disable_selinux() {
    selinux_count="$(grep "^SELINUX=disabled" /etc/selinux/config | wc -l)"
    if [[ $selinux_count == 0 ]]; then
        echo "DISABLING SELINUX:"
        sed -i 's/^SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config
        echo "SELinux is disabled. Reboot system to notice the change in status before executing playbooks in control plane!!"
    fi
}

get_os_info

if [[ "$OS_ID" == "ubuntu-server" ]]; then
    check_ubuntu
elif [[ "$OS_ID" == "rhel" ]]; then
    check_rhel
elif [[ "$OS_ID" == "rocky" ]]; then
    check_rocky
else
    echo "Unsupported OS: $OS_ID"
    exit 1
fi

[ -d $venv_location ] || mkdir $venv_location
[ -d /var/log/omnia ] || mkdir /var/log/omnia

if command -v $venv_py >/dev/null 2>&1; then
    echo "Python $python_version is already installed"
else
    req_py_packages="python$python_version python$python_version-pip python$python_version-devel"
    echo "Python $python_version is not installed"
    echo "$req_py_packages will be installed"
    if [[ "$os_id" == "ubuntu"* ]]; then
        echo "Ubuntu os found $os_id"
        if [[ "$os_version" == "22.04" ]]; then
            echo "deb [trusted=yes] http://ppa.launchpad.net/deadsnakes/ppa/ubuntu jammy main" > /etc/apt/sources.list.d/deadsnakes-ppa.list
        elif [[ "$os_version" == "20.04" ]]; then
            echo "deb [trusted=yes] http://ppa.launchpad.net/deadsnakes/ppa/ubuntu focal main" > /etc/apt/sources.list.d/deadsnakes-ppa.list
        else
            apt-add-repository ppa:deadsnakes/ppa -y
        fi
        apt update # THIS will take time
        apt install $req_py_packages -y
        apt install git git-lfs -y
        git lfs pull
    else
        echo "Non Ubuntu os found $os_id"
        dnf install $req_py_packages -y
        dnf install git-lfs -y
        git lfs pull
        disable_selinux
    fi
fi

if command -v $venv_py >/dev/null 2>&1; then
    echo "$venv_py is installed"
else
    echo "$venv_py could not be installed !!"
    exit 1
fi

# if [ -z "${VIRTUAL_ENV:-}" ]; then
#     echo "Virtual environment not activated"
#     python$python_version -m venv $venv_location --prompt OMNIA
#     source $venv_location/bin/activate
# fi

# Check if activated venv location equal to the venv_location
if [ "$VIRTUAL_ENV" != "$venv_location" ]; then
    # Either no venv not activated or the desired location
    echo "Virtual environment not this"
    # Create the venv path if it doesn't exist
    if [ ! -f "$venv_location/bin/activate" ]; then
       $venv_py -m venv $venv_location --prompt OMNIA
    fi
    # activate the venv
    source $venv_location/bin/activate
    
    if [ "$VIRTUAL_ENV" == "$venv_location" ]; then
        echo "Virtual environment activated successfully."
    else
        echo "Failed to activate virtual environment."
        exit 1
    fi  
fi

echo "venv activated in $VIRTUAL_ENV"

# Function to check Python major and minor version
check_python_version_venv() {
    # Extract Python version from the virtual environment
    local venv_py_version=$(python --version 2>&1 | awk '{print $2}')
    
    # Extract major and minor versions
    local venv_major_version=$(echo "$venv_py_version" | cut -d '.' -f 1)
    local venv_minor_version=$(echo "$venv_py_version" | cut -d '.' -f 2)
    
    # Compare major and minor versions
    if [ "$venv_major_version" == "$py_major_version" ] && [ "$venv_minor_version" == "$py_minor_version" ]; then
        echo "Python version $venv_py_version matches the required version $py_major_version.$py_minor_version."
    else
        echo "Python version $venv_py_version does not match the required version $py_major_version.$py_minor_version."
        exit 1
    fi
}

check_python_version_venv

echo "Virtual environment is active with the correct Python major and minor version."

# Upgrade pip
# TOTHINK: activated venv has both python and python3.11 execs so $venv_py is needed?
$venv_py -m pip install --upgrade pip

INSTALLED_VERSION=$(get_installed_ansible_version)

if [ "$INSTALLED_VERSION" == "$ansible_version" ]; then
    echo "Ansible $ansible_version is already installed."
else
    echo "Ansible $ansible_version is not installed."
    install_ansible
fi
