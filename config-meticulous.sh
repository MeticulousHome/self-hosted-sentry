#!/usr/bin/env bash
set -euo pipefail

CSRF_TRUSTED_ORIGIN="https://sentry.meticulousespresso.com"
SENTRY_DIR="$(dirname "$0")"

# modify generated configuration files
echo ""
echo ""
echo "|: Auto-configuration for Meticulous :|"
echo ""

print_header() {
  local message=$1
  echo ""
  echo " > $message"
  echo ""
}

print_message() {
  local message=$1
  local symbol="->"
  if [ $# -ge 2 ]; then
    symbol=$2
  fi

  echo "   $symbol $message"
}

run_after_installation() {
  ERROR=0
  if [ ! -e "./sentry/config.yml" ]; then
    echo "missing file: ./sentry/config.yml"
    ERROR=2
  fi

  if [ ! -e "./sentry/sentry.conf.py" ]; then
    echo "missing file: ./sentry/sentry.conf.py"
    ERROR=2
  fi

  if ((ERROR != 0)); then
    echo "don't run this script individually, run ./install.sh instead"
    return $ERROR
  fi
}

set_kafka_options() {
  print_header "Updating default kafka options"

  sed -i \
    -e 's/\("message\.max\.bytes": \)[0-9]\+/\110000000/' \
    -e 's/\("socket\.timeout\.ms": \)[0-9]\+/\160000/' \
    ./sentry/sentry.conf.py

  print_message "message.max.bytes set to  100000000"
  print_message "socket.timeout.ms set to 60000"
}

set_connection_options() {

  print_header "Updating CSRF trusted origins"

  sed -i -E "s|^#?[[:space:]]*CSRF_TRUSTED_ORIGINS = \[.*\]|CSRF_TRUSTED_ORIGINS = [\"https://example.com\", \"http://127.0.0.1:9000\", \"$CSRF_TRUSTED_ORIGIN\"]|" ./sentry/sentry.conf.py

  print_message "added $CSRF_TRUSTED_ORIGIN to the CSRF trusted origins"
  print_header "Updating System URL prefix"

  sed -i -E "s|^#?[[:space:]]*system.url-prefix:.*|system.url-prefix: $CSRF_TRUSTED_ORIGIN|" ./sentry/config.yml

  print_message "system.url-prefix set to $CSRF_TRUSTED_ORIGIN"
  print_header "Configuring to work behind SSL reverse proxy"
  # SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')
  sed -i -E "s|^#?[[:space:]]*SECURE_PROXY_SSL_HEADER =.*|SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')|" ./sentry/sentry.conf.py
  # USE_X_FORWARDED_HOST = True
  sed -i -E "s|^#?[[:space:]]*USE_X_FORWARDED_HOST =.*|USE_X_FORWARDED_HOST = True|" ./sentry/sentry.conf.py
  # SESSION_COOKIE_SECURE = True
  sed -i -E "s|^#?[[:space:]]*SESSION_COOKIE_SECURE =.*|SESSION_COOKIE_SECURE = True|" ./sentry/sentry.conf.py
  # CSRF_COOKIE_SECURE = True
  sed -i -E "s|^#?[[:space:]]*CSRF_COOKIE_SECURE =.*|CSRF_COOKIE_SECURE = True|" ./sentry/sentry.conf.py
  # SOCIAL_AUTH_REDIRECT_IS_HTTPS = True
  sed -i -E "s|^#?[[:space:]]*SOCIAL_AUTH_REDIRECT_IS_HTTPS =.*|SOCIAL_AUTH_REDIRECT_IS_HTTPS = True|" ./sentry/sentry.conf.py

}

set_swap_space() {

  print_header "Checking use of Swap space"
  # check use of swap space
  SWAP_SIZE="$(swapon --show=SIZE | tail -1 | tr -d ' ')"
  NEW_SWAPFILE_SIZE=16
  MINIMUM_SPACE_REQUIRED=16

  available_space=$(df --output=avail -BG / | tail -1 | sed 's/G//' | tr -d ' ')

  CREATE_SWAP_FILE=0 #false

  # This relies that the swapon output resembles
  # NAME      TYPE SIZE USED PRIO
  # /swap.img file   8G   0B   -2
  # .
  # .
  # .

  if [ -n "$SWAP_SIZE" ]; then
    PRESENT_SWAP_SPACES=$(swapon | grep -c ^)
    TOTAL_SWAP_SPACE=0
    while IFS= read -r line; do
      TOTAL_SWAP_SPACE=$((TOTAL_SWAP_SPACE + $(echo "$line" | sed 's/G//' | tr -d ' ')))
    done < <(swapon --show=SIZE | tail -n "$((PRESENT_SWAP_SPACES - 1))")

    # SWAP_SIZE=$(echo "$SWAP_SIZE" | sed 's/G//')
    # if ((SWAP_SIZE < MINIMUM_SPACE_REQUIRED)); then
    if ((TOTAL_SWAP_SPACE < MINIMUM_SPACE_REQUIRED)); then
      print_message "insufficient swap space ($TOTAL_SWAP_SPACE G) , $MINIMUM_SPACE_REQUIRED G is necessary, resizing"
      if (((available_space + TOTAL_SWAP_SPACE) < MINIMUM_SPACE_REQUIRED)); then
        print_message "Less than $MINIMUM_SPACE_REQUIRED G available, cannot set up swap space" "[x]"
        print_message "Sentry might run into issues if going forward " "[x]"
      else
        NEW_SWAPFILE_SIZE=$((MINIMUM_SPACE_REQUIRED - TOTAL_SWAP_SPACE))
        CREATE_SWAP_FILE=1
      fi
    else
      print_message "swap space already configured to $TOTAL_SWAP_SPACE"
    fi
  else
    if ((available_space < MINIMUM_SPACE_REQUIRED)); then
      print_message "Less than $MINIMUM_SPACE_REQUIRED G available, cannot set up swap space" "[x]"
      print_message "Sentry might run into issues if going forward " "[x]"
    else
      CREATE_SWAP_FILE=1
    fi
  fi

  if ((CREATE_SWAP_FILE == 1)); then
    # set up swapspace

    SWAP_SIZE="${NEW_SWAPFILE_SIZE}G"
    SWAPFILE_PATH="/swapfile$NEW_SWAPFILE_SIZE"
    fallocate -l "$SWAP_SIZE" "$SWAPFILE_PATH"
    chmod 600 "$SWAPFILE_PATH"
    mkswap "$SWAPFILE_PATH"
    swapon "$SWAPFILE_PATH"

    #save the swap config
    print_message "Saving Swap space config"
    print_message "$SWAPFILE_PATH none swap sw 0 0" | sudo tee -a /etc/fstab
  fi

}

install_service() {

  SERVICE_NAME="meticulous-sentry.service"
  SYSTEMD_SERVICE_DIR="/etc/systemd/system"

  print_header "Setting up $SERVICE_NAME"

  systemctl daemon-reexec
  systemctl daemon-reload

  set +e
  systemctl status "$SERVICE_NAME" >/dev/null 2>&1
  RESULT=$?
  set -e
  # if the unit is not found systemctl returns 4
  if [ $RESULT -eq 4 ]; then
    print_message "Installing service…"
    cp -u "$SENTRY_DIR/$SERVICE_NAME" "$SYSTEMD_SERVICE_DIR"

    systemctl daemon-reexec
    systemctl daemon-reload
  fi

  set +e
  systemctl status "$SERVICE_NAME" >/dev/null 2>&1
  RESULT=$?
  set -e
  if [ $RESULT -lt 4 ]; then
    print_message "$SERVICE_NAME successfully installed"
    print_message "setting \$SENTRY_PATH environment variable to '$SENTRY_DIR'"

    if [ ! -d "/opt/sentrySH" ]; then
      mkdir -p "/opt/sentrySH"
    fi

    echo "SENTRY_PATH=$SENTRY_DIR" >"/opt/sentrySH/env"

    print_message " SENTRY_PATH variable successfully saved as $SENTRY_DIR"

    systemctl enable "$SERVICE_NAME"

    print_message "$SERVICE_NAME is enabled, will start on every boot"
    print_message "You can start the service now using"
    print_message "systemctl start $SERVICE_NAME" " >>> "
  else
    print_message "failed to install $SERVICE_NAME" "[x]"
    print_message "You can still run the service manually executing"
    print_message "docker compose -f $SENTRY_DIR/docker-compose.yml -f $SENTRY_DIR/docker-compose.override.yml --env-file .env --env-file .env.custom up --wait" " >>> "
  fi

}

if ! run_after_installation; then
  exit 1
fi

set_kafka_options
set_connection_options
set_swap_space
install_service
