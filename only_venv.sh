#!/bin/bash

ansible_version="9.5.1"
python_version="3.11"
venv_py=python$python_version
os_release_data="/etc/os-release"

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
    else
        echo "Rocky Linux $OS_VERSION is not an allowed version."
        exit 1
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
# exit 1

get_installed_ansible_version() {
    $venv_py -m pip show ansible 2>/dev/null | grep Version | awk '{print $2}'
}

install_ansible() {
    echo "Installing Ansible $ansible_version..."
    $venv_py -m pip install ansible=="$ansible_version" #--force-reinstall or --ignore-installed is not required
}

os_id=$(awk -F= '$1=="ID" { print $2 ;}' $os_release_data | tr -d '"')
echo $os_id

if [[ $os_id = @(ubuntu-server|rhel|rocky) ]]; then
    echo "Supported OS"
else
    echo "Unsupported OS"
    exit 1
fi

os_version=$(awk -F= '$1=="VERSION_ID" { print $2 ;}' $os_release_data | tr -d '"')
echo $os_version
#TODO - supported versions might have a patch release var
if [[ $os_version = @(9.5|22.04|20.04) ]]; then
    echo "Supported OS version"
else
    echo "Unsupported OS version"
    #TODO
fi

venv_location=/opt/omnia/venv

[ -d /opt/omnia ] || mkdir $venv_location
[ -d /var/log/omnia ] || mkdir /var/log/omnia


if command -v $venv_py >/dev/null 2>&1; then
    echo "Python $python_version is installed"
else
    req_py_packages="python$python_version python$python_version-pip python$python_version-devel"
    echo "Python $python_version is not installed"
    echo "$req_py_packages will be installed"
    if [[ "$os_id" == "ubuntu-server" ]]; then
        if [[ "$os_version" == "22.04" ]]; then
            echo "deb [trusted=yes] http://ppa.launchpad.net/deadsnakes/ppa/ubuntu jammy main" > /etc/apt/sources.list.d/deadsnakes-ppa.list
        elif [[ "$os_version" == "20.04" ]]; then
            echo "deb [trusted=yes] http://ppa.launchpad.net/deadsnakes/ppa/ubuntu focal main" > /etc/apt/sources.list.d/deadsnakes-ppa.list
        else
            apt-add-repository ppa:deadsnakes/ppa -y
        fi
        apt update # THIS will take time
        apt install $req_py_packages -y
    elif [[ "$os_id" == "rocky" ]]; then
        dnf install epel-release $req_py_packages-y
    else
        dnf install $req_py_packages -y
    fi
fi

if command -v $venv_py >/dev/null 2>&1; then
    echo "$venv_py is installed"
else
    echo "$venv_py could not be installed !!"
    exit 1

if [ -z "${VIRTUAL_ENV:-}" ]; then
    echo "Virtual environment not activated"
    python$python_version -m venv $venv_location --prompt OMNIA
    source $venv_location/bin/activate
fi

echo "venv activated in $VIRTUAL_ENV"
# Upgrade pip
$venv_py -m pip install --upgrade pip

INSTALLED_VERSION=$(get_installed_ansible_version)

if [ "$INSTALLED_VERSION" == "$ansible_version" ]; then
    echo "Ansible $ansible_version is already installed."
else
    echo "Ansible $ansible_version is not installed."
    install_ansible
fi

# exit 1

# check anisble exists
# check version
#
# check ansible within venv
#
# python$python_version -m ensurepip --upgrade
# check ansible installed within venv