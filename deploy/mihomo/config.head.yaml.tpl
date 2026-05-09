# Заготовка для scripts/gen-mihomo-config.sh (итог — state/mihomo/config.yaml).
mixed-port: 7890
allow-lan: true
bind-address: "*"
geo-auto-update: false
geodata-loader: memorizing

geoip-database: __GEO_PATH__/geoip.dat
geosite-database: __GEO_PATH__/geosite.dat

external-controller: 127.0.0.1:9090
secret: '__SECRET__'
external-controller-cors:
  allow-origins:
    - "*"

profile:
  tracing: false

proxy-groups:
  - name: PROXY
    type: select
    use:
      - vpn-subscription
    proxies:
      - DIRECT

proxy-providers:
  vpn-subscription:
    type: http
    url: '__SUBSCRIPTION_URL__'
    path: vpn-subscription.yaml
    interval: 3600
    health-check:
      enable: true
      interval: 600
      url: https://www.gstatic.com/generate_204
