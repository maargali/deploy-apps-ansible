#!/bin/bash

set -e

# ============================================================
# FUELMAN APPLICATION DEPLOYMENT SCRIPT
#
# Usage:
#   ./deploy.sh
#   ./deploy.sh debug
#
# Normal mode:
#   Ansible runs normally
#
# Debug mode:
#   Bash command tracing is enabled
#   Ansible runs with -vvvv
# ============================================================

DEBUG_MODE=false

if [ "${1:-}" = "debug" ]; then
    DEBUG_MODE=true
    set -x
fi


# ============================================================
# 1. Select Environment
# ============================================================

clear

echo "=============================================="
echo "        FUELMAN APPLICATION DEPLOYMENT"
echo "=============================================="
echo ""

if [ "$DEBUG_MODE" = true ]; then
    echo "              DEBUG MODE ENABLED"
    echo "=============================================="
    echo ""
fi

echo "Select Environment:"
echo ""
echo "  1) Production"
echo "  2) Staging"
echo "  3) Test"
echo ""

read -p "Enter environment [1-3]: " ENV_CHOICE

case "$ENV_CHOICE" in
    1)
        ENV="prod"
        ;;
    2)
        ENV="staging"
        ;;
    3)
        ENV="test"
        ;;
    *)
        echo ""
        echo "ERROR: Invalid environment selection."
        exit 1
        ;;
esac


# ============================================================
# 2. Check Inventory
# ============================================================

INVENTORY="inventory/$ENV/hosts.ini"

if [ ! -f "$INVENTORY" ]; then
    echo ""
    echo "ERROR: Inventory file not found:"
    echo "       $INVENTORY"
    exit 1
fi


# ============================================================
# 3. Select Deployment Type
# ============================================================

echo ""
echo "Environment selected: $ENV"
echo ""

echo "Select Deployment Type:"
echo ""
echo "  1) Backend"
echo "  2) Frontend"
echo "  3) Nginx"
echo "  4) PostgreSQL"
echo "  5) Certbot"
echo "  6) Docker"
echo ""

read -p "Enter deployment type [1-6]: " TYPE_CHOICE

case "$TYPE_CHOICE" in

    1)
        DEPLOY_TYPE="backend"
        PLAYBOOK="deploy-backend.yml"
        NEED_APP=true
        ;;

    2)
        DEPLOY_TYPE="frontend"
        PLAYBOOK="deploy-frontend.yml"
        NEED_APP=true
        ;;

    3)
        DEPLOY_TYPE="nginx"
        PLAYBOOK="deploy-nginx.yml"
        NEED_APP=false
        ;;

    4)
        DEPLOY_TYPE="postgres"
        PLAYBOOK="deploy-postgres.yml"
        NEED_APP=false
        ;;

    5)
        DEPLOY_TYPE="certbot"
        PLAYBOOK="deploy-certbot.yml"
        NEED_APP=false
        ;;

    6)
        DEPLOY_TYPE="docker"
        PLAYBOOK="deploy-docker.yml"
        NEED_APP=false
        ;;

    *)
        echo ""
        echo "ERROR: Invalid deployment type selection."
        exit 1
        ;;
esac


# ============================================================
# 4. Select Application
# ============================================================

APP_NAME=""

if [ "$NEED_APP" = true ]; then

    APP_DIR="inventory/$ENV/group_vars/$DEPLOY_TYPE"

    if [ ! -d "$APP_DIR" ]; then
        echo ""
        echo "ERROR: Application directory not found:"
        echo "       $APP_DIR"
        exit 1
    fi


    # --------------------------------------------------------
    # Find application YAML files
    # --------------------------------------------------------

    APPS=()

    while IFS= read -r file; do
        APP=$(basename "$file" .yml)
        APPS+=("$APP")
    done < <(
        find "$APP_DIR" \
            -maxdepth 1 \
            -type f \
            -name "*.yml" \
            | sort
    )


    # --------------------------------------------------------
    # Check applications exist
    # --------------------------------------------------------

    if [ ${#APPS[@]} -eq 0 ]; then
        echo ""
        echo "ERROR: No applications found."
        echo ""
        echo "Directory:"
        echo "  $APP_DIR"
        exit 1
    fi


    # --------------------------------------------------------
    # Display applications
    # --------------------------------------------------------

    echo ""
    echo "=============================================="
    echo "          AVAILABLE APPLICATIONS"
    echo "=============================================="
    echo ""
    echo "Environment : $ENV"
    echo "Deployment  : $DEPLOY_TYPE"
    echo ""

    for i in "${!APPS[@]}"; do
        echo "  $((i+1))) ${APPS[$i]}"
    done

    echo ""

    read -p "Select application [1-${#APPS[@]}]: " APP_CHOICE


    # --------------------------------------------------------
    # Validate application selection
    # --------------------------------------------------------

    if ! [[ "$APP_CHOICE" =~ ^[0-9]+$ ]]; then
        echo ""
        echo "ERROR: Invalid application selection."
        exit 1
    fi

    if [ "$APP_CHOICE" -lt 1 ] || \
       [ "$APP_CHOICE" -gt "${#APPS[@]}" ]; then
        echo ""
        echo "ERROR: Invalid application selection."
        exit 1
    fi


    APP_NAME="${APPS[$((APP_CHOICE-1))]}"

fi


# ============================================================
# 5. Check Playbook
# ============================================================

PLAYBOOK_PATH="playbooks/$PLAYBOOK"

if [ ! -f "$PLAYBOOK_PATH" ]; then
    echo ""
    echo "ERROR: Playbook not found:"
    echo "       $PLAYBOOK_PATH"
    exit 1
fi


# ============================================================
# 6. Deployment Summary
# ============================================================

echo ""
echo ""
echo "=============================================="
echo "              DEPLOYMENT SUMMARY"
echo "=============================================="
echo ""

echo " Environment : $ENV"
echo " Type        : $DEPLOY_TYPE"

if [ "$NEED_APP" = true ]; then
    echo " Application : $APP_NAME"
fi

echo " Inventory   : $INVENTORY"
echo " Playbook    : $PLAYBOOK_PATH"

if [ "$DEBUG_MODE" = true ]; then
    echo " Debug       : ENABLED"
    echo " Ansible     : -vvvv"
fi

echo ""
echo "=============================================="
echo ""


# ============================================================
# 7. Build Ansible Command
# ============================================================

ANSIBLE_ARGS=(
    -i "$INVENTORY"
    "$PLAYBOOK_PATH"
)

if [ "$NEED_APP" = true ]; then
    ANSIBLE_ARGS+=(
        -e "app_name=$APP_NAME"
    )
fi

if [ "$DEBUG_MODE" = true ]; then
    ANSIBLE_ARGS+=(
        -vvvv
    )
fi


# ============================================================
# 8. Production Warning / Confirmation
# ============================================================

if [ "$ENV" = "prod" ]; then

    echo "************************************************"
    echo "              !!! WARNING !!!"
    echo "************************************************"
    echo ""
    echo "You are about to deploy to PRODUCTION."
    echo ""

    echo " Environment : $ENV"
    echo " Type        : $DEPLOY_TYPE"

    if [ "$NEED_APP" = true ]; then
        echo " Application : $APP_NAME"
    fi

    echo ""

    if [ "$DEBUG_MODE" = true ]; then
        echo " DEBUG MODE  : ENABLED"
        echo ""
    fi

    echo "Type 'DEPLOY' to continue:"
    read PROD_CONFIRM

    if [ "$PROD_CONFIRM" != "DEPLOY" ]; then
        echo ""
        echo "Production deployment cancelled."
        exit 0
    fi

else

    read -p "Continue deployment? [y/N]: " CONFIRM

    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
        echo ""
        echo "Deployment cancelled."
        exit 0
    fi

fi


# ============================================================
# 9. Display Ansible Command
# ============================================================

echo ""
echo "=============================================="
echo "             EXECUTING DEPLOYMENT"
echo "=============================================="
echo ""

if [ "$DEBUG_MODE" = true ]; then
    echo "DEBUG MODE: ENABLED"
    echo "Ansible verbosity: -vvvv"
    echo ""
fi

echo "Command:"
printf 'ansible-playbook'
printf ' %q' "${ANSIBLE_ARGS[@]}"
echo ""

echo ""


# ============================================================
# 10. Execute Ansible
# ============================================================

ansible-playbook "${ANSIBLE_ARGS[@]}"


# ============================================================
# 11. Deployment Completed
# ============================================================

echo ""
echo ""
echo "=============================================="
echo "        DEPLOYMENT COMPLETED SUCCESSFULLY"
echo "=============================================="
echo ""

echo " Environment : $ENV"
echo " Type        : $DEPLOY_TYPE"

if [ "$NEED_APP" = true ]; then
    echo " Application : $APP_NAME"
fi

if [ "$DEBUG_MODE" = true ]; then
    echo " Debug       : ENABLED"
fi

echo ""
echo "=============================================="