set -euo pipefail

CSRF_TRUSTED_ORIGIN="http://65.109.232.162:9000"

# modify generated configuration files

if [ ! -e "./sentry/sentry.config.py" ]; then
    echo "don't run this script individually, run ./install.sh instead"
    exit 2
fi

echo ""
echo "Oops, forgot to check something"
echo ""

echo "updating default kafka options"

sed -i \
    -e 's/\("message\.max\.bytes": \)[0-9]\+/\110000000/' \
    -e 's/\("socket\.timeout\.ms": \)[0-9]\+/\160000/' \
    ./sentry/sentry.conf.py

echo -e "message.max.bytes set to  100000000\nsocket.timeout.ms set to 60000"

echo "updating CSRF trusted origins"

sed -i "s|^# CSRF_TRUSTED_ORIGINS = \[.*\]|CSRF_TRUSTED_ORIGINS = [\"https://example.com\", \"http://127.0.0.1:9000\", \"$CSRF_TRUSTED_ORIGIN\"]|" ./sentry/sentry.conf.py

echo "added $CSRF_TRUSTED_ORIGIN to the CSRF trusted origins"

# check use of swap space
SWAP_CHECK="$(swapon --show)"

if [ -n "$SWAP_CHECK" ]; then
    echo "swap space already configured"
    echo "$SWAP_CHECK" | awk 'END{print}'
    exit 0
fi

# set up swapspace
MINIMUM_SPACE_REQUIRED=4

available_space=$(df --output=avail -BG / | tail -1 | sed 's/G//' | tr -d ' ')

if (( available_space < MINIMUM_SPACE_REQUIRED )); then
    echo "Less than $MINIMUM_SPACE_REQUIRED G available, cannot set up swap space"
    exit 1
fi

SWAP_SIZE="${MINIMUM_SPACE_REQUIRED}G"
fallocate -l "$SWAP_SIZE" /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile

#save the swap config
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

  echo "-----------------------------------------------------------------"
  echo ""
  echo "Now You're really all set! :P"
  echo ""
  echo "-----------------------------------------------------------------"
  echo ""