# Self-Hosted Sentry

[Sentry](https://sentry.io/), feature-complete and packaged up for low-volume deployments and proofs-of-concept.

Documentation [here](https://develop.sentry.dev/self-hosted/).


## Meticulous Espresso instance

### Geo location

In order to use the geolocation capabilites of sentry, You need to provide a geolocation database from MaxMind, for which You will require an valid Account in MaxMind, it is free

The Sentry Project makes use of the GeoIPUpdate product from MaxMind to download/update its database, so the only requirement is to provide the `GeoIP.conf` to the `geoip` directory, running `install.sh` will call an update process to the database alongside. If You dont provide a `GeoIP.conf` file, the database will be empty

For more information visit [Sentry: Geolocation](https://develop.sentry.dev/self-hosted/geolocation/) and [MaxMind: Updating GeoIP and GeoLite Databases ](https://dev.maxmind.com/geoip/updating-databases/#directly-downloading-databases)

### Custom files

#### configure-swap.sh

 This file will modify the sentry settings that are present in the `./sentry/config.yml` and `sentry/sentry.conf.py` files to get the installation ready to work.

 Changes done are the following
 - Set Kafka's `message.max.bytes` to `100000000` (`sentry/sentry.conf.py`)
 - Set Kafka's `socket.timeout.ms` to `60000` (`sentry/sentry.conf.py`)
 - Add to the `CSRF Trusted Origins` the registered domain `https://sentry.meticulousespresso.com` (`sentry/sentry.conf.py`)
 - Setting `system.url.prefix` to `https://sentry.meticulousespresso.com` (`./sentry/config.yml`)
 - Setting up sentry to work behind a reverse proxy
   - Uncomment `SSL/TSL` section (`sentry/sentry.conf.py`)
 - Set up `4G` of swap space if there is none

 #### .env.custom

 This file sets some custom KAFKA settings and the network port to bind sentry to (`8081`)

---

### External requirements

#### Docker
 The Self-Hosted Sentry deploymentent is mostly containarized

#### NGINX
 The VPS should run an NGINX instance that handles SSL termination and redirects the request to `http://localhost:8081` where its listen and responded to by the sentry deployment

#### Certbot
 To get the SSL certificates for `sentry.meticulousespresso.com` used by NGINX
