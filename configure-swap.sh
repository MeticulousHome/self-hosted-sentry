set -euo pipefail

# CSRF_TRUSTED_ORIGIN="http://65.109.232.162:9000"
CSRF_TRUSTED_ORIGIN="http://sentry.meticulousespresso.com"

# modify generated configuration files

ERROR=0
if [ ! -e "./sentry/config.yml" ]; then
    echo "missing file: ./sentry/config.yml"
    ERROR=2
fi

if [ ! -e "./sentry/sentry.conf.py" ]; then
    echo "don't run this script individually, run ./install.sh instead"
    ERROR=2
fi

if (( ERROR != 0 )); then
    exit $ERROR
fi

echo ""
echo ""
echo " Oops, forgot to check something"
echo ""

echo " > Updating default kafka options"

sed -i \
    -e 's/\("message\.max\.bytes": \)[0-9]\+/\110000000/' \
    -e 's/\("socket\.timeout\.ms": \)[0-9]\+/\160000/' \
    ./sentry/sentry.conf.py

echo ""
echo -e "   -> message.max.bytes set to  100000000\n   -> socket.timeout.ms set to 60000"
echo ""
echo ""
echo " > Updating CSRF trusted origins"
echo ""

sed -i -E "s|^#?[[:space:]]*CSRF_TRUSTED_ORIGINS = \[.*\]|CSRF_TRUSTED_ORIGINS = [\"https://example.com\", \"http://127.0.0.1:9000\", \"$CSRF_TRUSTED_ORIGIN\"]|" ./sentry/sentry.conf.py

echo "   -> added $CSRF_TRUSTED_ORIGIN to the CSRF trusted origins"
echo ""
echo ""
echo " > Updating System URL prefix"
echo ""

sed -i -E "s|^#?[[:space:]]*system.url-prefix:.*|system.url-prefix: $CSRF_TRUSTED_ORIGIN|" ./sentry/config.yml

echo -e "   -> system.url-prefix set to $CSRF_TRUSTED_ORIGIN"

echo " > Checking use of Swap space"
echo ""
# check use of swap space
SWAP_CHECK="$(swapon --show)"

if [ -n "$SWAP_CHECK" ]; then
    echo "   -> swap space already configured"
    echo "$SWAP_CHECK" | awk 'END{print}'
else
    # set up swapspace
    MINIMUM_SPACE_REQUIRED=4

    available_space=$(df --output=avail -BG / | tail -1 | sed 's/G//' | tr -d ' ')

    if (( available_space < MINIMUM_SPACE_REQUIRED )); then
        echo " [x] Less than $MINIMUM_SPACE_REQUIRED G available, cannot set up swap space"
        exit 1
    fi

    SWAP_SIZE="${MINIMUM_SPACE_REQUIRED}G"
    fallocate -l "$SWAP_SIZE" /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile

    #save the swap config
    echo "   -> Saving Swap space config"
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
fi


  echo ""
  echo "-----------------------------------------------------------------"
  echo ""
  echo "Now You're all set! Trust me :P"
  echo ""
  echo "-----------------------------------------------------------------"
  echo ""