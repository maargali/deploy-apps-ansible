#!/bin/bash

set -e

# ============================================================
# Application Deployment Script
# ============================================================

clear

echo "=============================================="
echo "        FUELMAN APPLICATION DEPLOYMENT"
echo "=============================================="
echo ""

# ------------------------------------------------------------
# 1. Select Environment
# ------------------------------------------------------------

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

# ------------------------------------------------------------
# 2. Check Inventory
# ------------------------------------------------------------

INVENTORY="inventory/$ENV/hosts.ini"

if [ ! -f "$INVENTORY" ]; then
    echo ""
    echo "ERROR: Inventory file not found:"
    echo "       $INVENTORY"
    exit 1
fi

# ------------------------------------------------------------
# 3. Enter Application Name
# ------------------------------------------------------------

echo ""
echo "Environment selected: $ENV"
echo ""

read -p "Enter application name: " APP_NAME

if [ -z "$APP_NAME" ]; then
    echo ""
    echo "ERROR: Application name cannot be empty."
    exit 1
fi

# ------------------------------------------------------------
# 4. Select Deployment Type
# ------------------------------------------------------------

echo ""
echo "Select Deployment Type:"
echo ""
echo "  1) Backend"
echo "  2) Frontend"
echo "  3) Nginx"
echo "  4) Docker"
echo ""

read -p "Enter deployment type [1-4]: " TYPE_CHOICE

case "$TYPE_CHOICE" in
    1)
        DEPLOY_TYPE="backend"
        PLAYBOOK="deploy-backend.yml"
        ;;
    2)
        DEPLOY_TYPE="frontend"
        PLAYBOOK="deploy-frontend.yml"
        ;;
    3)
        DEPLOY_TYPE="nginx"
        PLAYBOOK="deploy-nginx.yml"
        ;;
    4)
        DEPLOY_TYPE="docker"
        PLAYBOOK="deploy-docker.yml"
        ;;
    *)
        echo ""
        echo "ERROR: Invalid deployment type."
        exit 1
        ;;
esac

# ------------------------------------------------------------
# 5. Check Playbook
# ------------------------------------------------------------

PLAYBOOK_PATH="playbooks/$PLAYBOOK"

if [ ! -f "$PLAYBOOK_PATH" ]; then
    echo ""
    echo "ERROR: Playbook not found:"
    echo "       $PLAYBOOK_PATH"
    exit 1
fi

# ------------------------------------------------------------
# 6. Deployment Summary
# ------------------------------------------------------------

echo ""
echo ""
echo "=============================================="
echo "              DEPLOYMENT SUMMARY"
echo "=============================================="
echo ""
echo " Environment : $ENV"
echo " Application : $APP_NAME"
echo " Type        : $DEPLOY_TYPE"
echo " Inventory   : $INVENTORY"
echo " Playbook    : $PLAYBOOK_PATH"
echo ""
echo "=============================================="
echo ""

# ------------------------------------------------------------
# 7. Production Warning
# ------------------------------------------------------------

if [ "$ENV" = "prod" ]; then

    echo "************************************************"
    echo "              !!! WARNING !!!"
    echo "************************************************"
    echo ""
    echo "You are about to deploy to PRODUCTION."
    echo ""
    echo "Application : $APP_NAME"
    echo "Type        : $DEPLOY_TYPE"
    echo ""
    read -p "Type 'DEPLOY' to continue: " PROD_CONFIRM

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

# ------------------------------------------------------------
# 8. Build Ansible Command
# ------------------------------------------------------------

ANSIBLE_COMMAND="ansible-playbook \
-i \"$INVENTORY\" \
\"$PLAYBOOK_PATH\" \
-e \"app_name=$APP_NAME\""

# ------------------------------------------------------------
# 9. Display Command
# ------------------------------------------------------------

echo ""
echo "=============================================="
echo "             EXECUTING DEPLOYMENT"
echo "=============================================="
echo ""
echo "$ANSIBLE_COMMAND"
echo ""

# ------------------------------------------------------------
# 10. Execute Ansible
# ------------------------------------------------------------

ansible-playbook \
    -i "$INVENTORY" \
    "$PLAYBOOK_PATH" \
    -e "app_name=$APP_NAME"

# ------------------------------------------------------------
# 11. Deployment Completed
# ------------------------------------------------------------

echo ""
echo ""
echo "=============================================="
echo "        DEPLOYMENT COMPLETED SUCCESSFULLY"
echo "=============================================="
echo ""
echo " Environment : $ENV"
echo " Application : $APP_NAME"
echo " Type        : $DEPLOY_TYPE"
echo ""
echo "=============================================="