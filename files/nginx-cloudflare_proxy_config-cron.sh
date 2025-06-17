#!/bin/bash
# Cloudflare - NGINX config utility
# Get Real Visitor IP Address (Restoring Visitor IPs) with Nginx and CloudFlare
# Optionally restrict connections from CloudFlare only.
# inspired by https://github.com/ergin/nginx-cloudflare-real-ip

ENABLE_RESTRICT=${1:-false}
CLOUDFLARE_REAL_IP_PATH=/etc/nginx/conf.d/cloudflare_real_ip.conf
CLOUDFLARE_RESTRICT_PATH=/etc/nginx/conf.d/cloudflare_proxy_restrict.conf

echo "#Cloudflare" > $CLOUDFLARE_REAL_IP_PATH;
echo "" >> $CLOUDFLARE_REAL_IP_PATH;

echo "# - IPv4" >> $CLOUDFLARE_REAL_IP_PATH;
for i in `curl -s -L https://www.cloudflare.com/ips-v4`; do
        echo "set_real_ip_from $i;" >> $CLOUDFLARE_REAL_IP_PATH;
        if [ "$ENABLE_RESTRICT" = "true" ]; then
            echo "allow $i;" >> $CLOUDFLARE_RESTRICT_PATH;
        fi
done

echo "" >> $CLOUDFLARE_REAL_IP_PATH;
echo "# - IPv6" >> $CLOUDFLARE_REAL_IP_PATH;
for i in `curl -s -L https://www.cloudflare.com/ips-v6`; do
        echo "set_real_ip_from $i;" >> $CLOUDFLARE_REAL_IP_PATH;
        if [ "$ENABLE_RESTRICT" = "true" ]; then
            echo "allow $i;" >> $CLOUDFLARE_RESTRICT_PATH;
        fi
done

echo "" >> $CLOUDFLARE_REAL_IP_PATH;
echo "real_ip_header CF-Connecting-IP;" >> $CLOUDFLARE_REAL_IP_PATH;

if [ "$ENABLE_RESTRICT" = "true" ]; then
    echo "deny all;" >> $CLOUDFLARE_RESTRICT_PATH;
fi

#test configuration and reload nginx
nginx -t && systemctl reload nginx