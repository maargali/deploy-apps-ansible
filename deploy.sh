#!/bin/bash

set -e

# ============================================================
# FUELMAN APPLICATION DEPLOYMENT SCRIPT
#
# Usage:
#   ./deploy.sh
#   ./deploy.sh debug
#   ./deploy.sh restart
#   ./deploy.sh restart debug
#
# Interactive restart:
#
#   STEP 1 -> Environment
#   STEP 2 -> Deployment Type
#   STEP 3 -> Application
#   STEP 4 -> Review / Confirmation
#
# You can restart from any previous step before deployment.
# ============================================================


# ============================================================
# GLOBAL VARIABLES
# ============================================================

DEBUG_MODE=false

ENV=""
DEPLOY_TYPE=""
PLAYBOOK=""
NEED_APP=false
APP_NAME=""

INVENTORY=""
PLAYBOOK_PATH=""

START_STEP=1


# ============================================================
# COMMAND LINE ARGUMENTS
# ============================================================

for ARG in "$@"; do

    case "$ARG" in

        debug)
            DEBUG_MODE=true
            ;;

        restart)
            START_STEP=1
            ;;

        *)
            echo ""
            echo "ERROR: Unknown argument: $ARG"
            echo ""
            echo "Usage:"
            echo "  ./deploy.sh"
            echo "  ./deploy.sh debug"
            echo "  ./deploy.sh restart"
            echo "  ./deploy.sh restart debug"
            exit 1
            ;;

    esac

done


if [ "$DEBUG_MODE" = true ]; then
    set -x
fi


# ============================================================
# FUNCTION: Select Environment
# ============================================================

select_environment() {

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

    echo "STEP 1 - Select Environment"
    echo ""
    echo "  1) Production"
    echo "  2) Staging"
    echo "  3) Test"
    echo ""

    while true; do

        read -rp "Enter environment [1-3]: " ENV_CHOICE

        case "$ENV_CHOICE" in

            1)
                ENV="prod"
                break
                ;;

            2)
                ENV="staging"
                break
                ;;

            3)
                ENV="test"
                break
                ;;

            *)
                echo ""
                echo "Invalid environment selection."
                echo "Please enter 1, 2 or 3."
                echo ""
                ;;

        esac

    done


    # --------------------------------------------------------
    # Check inventory immediately
    # --------------------------------------------------------

    INVENTORY="inventory/$ENV/hosts.ini"

    if [ ! -f "$INVENTORY" ]; then

        echo ""
        echo "ERROR: Inventory file not found:"
        echo "       $INVENTORY"
        echo ""

        exit 1

    fi


    echo ""
    echo "Environment selected: $ENV"

}


# ============================================================
# FUNCTION: Select Deployment Type
# ============================================================

select_deployment_type() {

    echo ""
    echo "=============================================="
    echo "STEP 2 - Select Deployment Type"
    echo "=============================================="
    echo ""

    echo "  1) Backend"
    echo "  2) Frontend"
    echo "  3) Nginx"
    echo "  4) PostgreSQL"
    echo "  5) Certbot"
    echo "  6) Docker"
    echo ""

    while true; do

        read -rp "Enter deployment type [1-6]: " TYPE_CHOICE

        case "$TYPE_CHOICE" in

            1)

                DEPLOY_TYPE="backend"
                PLAYBOOK="deploy-backend.yml"
                NEED_APP=true

                break
                ;;

            2)

                DEPLOY_TYPE="frontend"
                PLAYBOOK="deploy-frontend.yml"
                NEED_APP=true

                break
                ;;

            3)

                DEPLOY_TYPE="nginx"
                PLAYBOOK="deploy-nginx.yml"
                NEED_APP=false

                break
                ;;

            4)

                DEPLOY_TYPE="postgres"
                PLAYBOOK="deploy-postgres.yml"
                NEED_APP=false

                break
                ;;

            5)

                DEPLOY_TYPE="certbot"
                PLAYBOOK="deploy-certbot.yml"
                NEED_APP=false

                break
                ;;

            6)

                DEPLOY_TYPE="docker"
                PLAYBOOK="deploy-docker.yml"
                NEED_APP=false

                break
                ;;

            *)

                echo ""
                echo "Invalid deployment type selection."
                echo "Please enter 1-6."
                echo ""

                ;;

        esac

    done


    echo ""
    echo "Deployment type selected: $DEPLOY_TYPE"

}


# ============================================================
# FUNCTION: Select Application
# ============================================================

select_application() {

    APP_NAME=""

    if [ "$NEED_APP" != true ]; then
        return
    fi


    if [ "$DEPLOY_TYPE" = "backend" ]; then

        APPS_FILE="inventory/$ENV/group_vars/backend/apps.yml"
        APPS_SECTION="backend_apps"

    else

        APPS_FILE="inventory/$ENV/group_vars/frontend/apps.yml"
        APPS_SECTION="frontend_apps"

    fi


    # --------------------------------------------------------
    # Check applications file
    # --------------------------------------------------------

    if [[ ! -f "$APPS_FILE" ]]; then

        echo ""
        echo "ERROR: Application configuration not found:"
        echo "       $APPS_FILE"
        echo ""

        exit 1

    fi


    # --------------------------------------------------------
    # Read applications
    # --------------------------------------------------------

    mapfile -t APPS < <(

        awk -v section="$APPS_SECTION" '

            $0 ~ "^" section ":" {

                in_apps=1
                next

            }

            in_apps && /^[^[:space:]]/ {

                exit

            }

            in_apps && /^  [A-Za-z0-9_-]+:/ {

                gsub(":", "", $1)

                print $1

            }

        ' "$APPS_FILE"

    )


    if [[ ${#APPS[@]} -eq 0 ]]; then

        echo ""
        echo "ERROR: No applications found."
        echo ""
        echo "File:"
        echo "  $APPS_FILE"
        echo ""

        exit 1

    fi


    # --------------------------------------------------------
    # Display applications
    # --------------------------------------------------------

    echo ""
    echo "=============================================="
    echo "STEP 3 - Select Application"
    echo "=============================================="
    echo ""

    echo "Environment : $ENV"
    echo "Deployment  : $DEPLOY_TYPE"
    echo ""

    echo "Available applications:"
    echo ""

    for i in "${!APPS[@]}"; do

        echo "  $((i+1))) ${APPS[$i]}"

    done

    echo ""


    while true; do

        read -rp "Select application: " APP_CHOICE

        if ! [[ "$APP_CHOICE" =~ ^[0-9]+$ ]]; then

            echo ""
            echo "Invalid application selection."
            echo ""

            continue

        fi


        if [ "$APP_CHOICE" -lt 1 ] ||
           [ "$APP_CHOICE" -gt "${#APPS[@]}" ]; then

            echo ""
            echo "Invalid application selection."
            echo ""

            continue

        fi


        APP_NAME="${APPS[$((APP_CHOICE-1))]}"

        break

    done


    echo ""
    echo "Selected application: $APP_NAME"

}


# ============================================================
# FUNCTION: Validate Playbook
# ============================================================

validate_playbook() {

    PLAYBOOK_PATH="playbooks/$PLAYBOOK"


    if [ ! -f "$PLAYBOOK_PATH" ]; then

        echo ""
        echo "ERROR: Playbook not found:"
        echo "       $PLAYBOOK_PATH"
        echo ""

        exit 1

    fi

}


# ============================================================
# FUNCTION: Deployment Summary
# ============================================================

show_summary() {

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

}


# ============================================================
# FUNCTION: Restart Menu
# ============================================================

restart_menu() {

    while true; do

        echo ""
        echo "=============================================="
        echo "             REVIEW SELECTION"
        echo "=============================================="
        echo ""

        echo " 1) Continue with deployment"
        echo " 2) Restart from Environment"
        echo " 3) Restart from Deployment Type"
        echo " 4) Restart from Application"
        echo " 5) Cancel deployment"
        echo ""

        read -rp "Select option [1-5]: " REVIEW_CHOICE

        case "$REVIEW_CHOICE" in

            1)

                return 0
                ;;


            2)

                START_STEP=1

                echo ""
                echo "Restarting from Environment..."
                echo ""

                select_environment
                select_deployment_type

                if [ "$NEED_APP" = true ]; then
                    select_application
                fi

                validate_playbook

                show_summary

                ;;


            3)

                START_STEP=2

                echo ""
                echo "Keeping environment: $ENV"
                echo "Restarting from Deployment Type..."
                echo ""

                select_deployment_type

                if [ "$NEED_APP" = true ]; then
                    select_application
                fi

                validate_playbook

                show_summary

                ;;


            4)

                if [ "$NEED_APP" != true ]; then

                    echo ""
                    echo "Application selection is not required for:"
                    echo "  $DEPLOY_TYPE"
                    echo ""

                    continue

                fi


                START_STEP=3

                echo ""
                echo "Keeping:"
                echo "  Environment : $ENV"
                echo "  Type        : $DEPLOY_TYPE"
                echo ""

                echo "Restarting from Application..."
                echo ""

                select_application

                validate_playbook

                show_summary

                ;;


            5)

                echo ""
                echo "Deployment cancelled."
                echo ""

                exit 0
                ;;


            *)

                echo ""
                echo "Invalid selection."
                echo ""

                ;;

        esac

    done

}


# ============================================================
# FUNCTION: Build Ansible Command
# ============================================================

build_ansible_command() {

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

}


# ============================================================
# FUNCTION: Confirmation
# ============================================================

confirm_deployment() {

    if [ "$ENV" = "prod" ]; then

        echo ""
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
        read -r PROD_CONFIRM


        if [ "$PROD_CONFIRM" != "DEPLOY" ]; then

            echo ""
            echo "Production deployment cancelled."
            echo ""

            exit 0

        fi

    else

        read -rp "Continue deployment? [y/N]: " CONFIRM

        if [[ "$CONFIRM" != "y" &&
              "$CONFIRM" != "Y" ]]; then

            echo ""
            echo "Deployment cancelled."
            echo ""

            exit 0

        fi

    fi

}


# ============================================================
# FUNCTION: Execute Deployment
# ============================================================

execute_deployment() {

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


    echo "Executing Ansible playbook..."
    echo ""


    ansible-playbook "${ANSIBLE_ARGS[@]}"


    # --------------------------------------------------------
    # Only show SUCCESS if Ansible really succeeded
    # --------------------------------------------------------

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

}


# ============================================================
# MAIN WORKFLOW
# ============================================================


# ------------------------------------------------------------
# STEP 1
# ------------------------------------------------------------

select_environment


# ------------------------------------------------------------
# STEP 2
# ------------------------------------------------------------

select_deployment_type


# ------------------------------------------------------------
# STEP 3
# ------------------------------------------------------------

if [ "$NEED_APP" = true ]; then

    select_application

fi


# ------------------------------------------------------------
# Validate
# ------------------------------------------------------------

validate_playbook


# ------------------------------------------------------------
# Summary
# ------------------------------------------------------------

show_summary


# ------------------------------------------------------------
# Allow restart from any previous step
# ------------------------------------------------------------

restart_menu


# ------------------------------------------------------------
# Build command
# ------------------------------------------------------------

build_ansible_command


# ------------------------------------------------------------
# Final confirmation
# ------------------------------------------------------------

confirm_deployment


# ------------------------------------------------------------
# Execute
# ------------------------------------------------------------

execute_deployment