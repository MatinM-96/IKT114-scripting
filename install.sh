
#!/usr/bin/env bash

echo  "script is running now"




#parse input argumnet


while [[ "$#" -gt 0 ]]; do
    case $1 in
        --users) USERS="$2"; shift ;;
        --groups) GROUPS="$2"; shift ;;
        --mtu) MTU="$2"; shift ;;
        --verbose|-v) VERBOSE=true ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

#detect operating system 




detect_os_and_package_manager() {
    if [ -f /etc/debian_version ]; then
        OS="Debian"
        PACKAGE_MANAGER="apt"
    elif [ -f /etc/redhat-release ]; then
        OS="AlmaLinux"
        PACKAGE_MANAGER="dnf"
    elif [ -f /etc/alpine-release ]; then
        OS="Alpine"
        PACKAGE_MANAGER="apk"
    else
        echo "Unsupported operating system."
        exit 1
    fi
    echo "Detected OS: $OS, Package Manager: $PACKAGE_MANAGER"
}


#insall the docker and the docer compose 


install_docker() {
    echo "Installing Docker and Docker Compose..."
    if [ "$PACKAGE_MANAGER" = "apt" ]; then
        sudo apt update
        sudo apt install -y docker.io docker-compose-plugin
    elif [ "$PACKAGE_MANAGER" = "dnf" ]; then
        sudo dnf install -y docker docker-compose
    elif [ "$PACKAGE_MANAGER" = "apk" ]; then
        sudo apk add docker docker-compose
    fi
    echo "Docker and Docker Compose installed."
}
