# Firewall (домашний шлюз)

Стек под гибрид **ПК/Ethernet ↔ Pi/Wi‑Fi**: списки в духе **Flowseal** как текст для merge, DPI через **bol-van/zapret** на Linux, клиент — **Mihomo** (+ geodata runetfreedom), панель — **nginx** + **shell2http** на loopback.

**Детально по шагам (RU):** [SETUP-RU.txt](SETUP-RU.txt).

---

## Требования

- Linux с `curl`/`wget`, `git`, желательно `systemd`; на Pi обычно **Debian / Raspberry Pi OS**.
- Свободное место для геодаты и списков (порядка **~100 МБ+** после первых sync).
- **SUBSCRIPTION_URL** — HTTPS-ссылка на вашу подписку **Clash / Mihomo** (не используйте мой URL в документации — подставляйте свой).

---

## One-liner: удалённая установка

Подставьте **свои** значения (`YOUR_ORG`, `YOUR_REPO` или любой свой `FIREWALL_REPO_URL`). Скрипт клонирует репозиторий в `FIREWALL_CLONE` (по умолчанию `/tmp/fw`), затем вызывает `install.sh`.

### 1. Полная установка (дефолт)

Пакеты, копирование в `/opt/firewall`, Mihomo/shell2http с GitHub, первый sync, unit-файлы:

```bash
sudo apt-get update && sudo apt-get install -y curl git \
  && curl -fsSL "https://raw.githubusercontent.com/falcga/firewall/main/contrib/remote-install.sh" \
  | sudo -E env \
      SUBSCRIPTION_URL='https://ВАША_ПОДПИСКА' \
      FIREWALL_REPO_URL='https://github.com/falcga/firewall.git' \
      sh -
```

На ветке не `main` задайте `FIREWALL_BRANCH=staging`.

### 2. Медленный GitHub или ручная закачка бинарников

Не качает Mihomo и shell2http через установщик; доставьте бинари в `/usr/local/bin` сами ([SETUP-RU](SETUP-RU.txt), п.5–7):

```bash
curl -fsSL "https://raw.githubusercontent.com/falcga/firewall/main/contrib/remote-install.sh" \
  | sudo -E env \
      SUBSCRIPTION_URL='https://ВАША_ПОДПИСКА' \
      FIREWALL_REPO_URL='https://github.com/falcga/firewall.git' \
      SKIP_BINARIES=1 \
      sh -
```

### 3. Уже есть списки / не гонять тяжёлый первый sync

Отключает шаг синхронизации во время установки (позже выполните скрипты из `/opt/firewall/scripts/`):

```bash
curl -fsSL "https://raw.githubusercontent.com/falcga/firewall/main/contrib/remote-install.sh" \
  | sudo -E env \
      SUBSCRIPTION_URL='https://ВАША_ПОДПИСКА' \
      FIREWALL_REPO_URL='https://github.com/falcga/firewall.git' \
      SKIP_SYNC=1 \
      sh -
```

### 4. Только дерево файлов + пакеты, без systemd-хелперов

Unit-файлы не записывает (настройте вручную):

```bash
curl -fsSL "https://raw.githubusercontent.com/falcga/firewall/main/contrib/remote-install.sh" \
  | sudo -E env \
      SUBSCRIPTION_URL='https://ВАША_ПОДПИСКА' \
      FIREWALL_REPO_URL='https://github.com/falcga/firewall.git' \
      SKIP_SYSTEMD=1 \
      sh -
```

### 5. Просмотр команд без изменений

```bash
curl -fsSL "https://raw.githubusercontent.com/falcga/firewall/main/contrib/remote-install.sh" \
  | sudo -E env \
      SUBSCRIPTION_URL='https://ВАША_ПОДПИСКА' \
      FIREWALL_REPO_URL='https://github.com/falcga/firewall.git' \
      DRY_RUN=1 \
      sh -
```

### 6. Другой каталог установки или clone

```bash
sudo -E env \
  SUBSCRIPTION_URL='https://ВАША_ПОДПИСКА' \
  FIREWALL_REPO_URL='https://github.com/falcga/firewall.git' \
  FIREWALL_ROOT='/srv/firewall' \
  FIREWALL_CLONE='/var/tmp/fw-clone' \
  sh contrib/remote-install.sh
```

Последняя строка — если вы **уже** внутри клона репозитория.

---

## Установка из локального clone

```bash
sudo apt-get install -y dialog git curl   # dialog — для scripts/setup-tui.sh
sudo env SUBSCRIPTION_URL='https://…' ./install.sh -r /opt/firewall
./install.sh -h
```

После установки:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now mihomo.service firewall-shell2http.service
```

---

## Интерактивная настройка (TUI)

Одно меню для портов, nginx, доменного импорта, режима **split/tunnel**, запусков sync и systemd — см. [SETUP-RU.txt](SETUP-RU.txt):

```bash
sudo apt-get install -y dialog
sudo bash scripts/setup-tui.sh
```

Настройки сохраняются в `~/.config/firewall-setup-tui/state.conf`.

---

## Сетевые значения по умолчанию (панель)

| Сервис        | По умолчанию (из примеров)       |
|---------------|----------------------------------|
| shell2http    | `127.0.0.1:8899`                 |
| nginx (LAN)   | `192.168.50.2:8088` (пример)     |
| Путь UI       | `http://LAN_IP:PORT/dashboard/`  |

Подставьте IP своего Pi на LAN. Генерация конфигов — в TUI раздел **«Панель»** или вручную по [contrib/nginx-dashboard.conf.example](contrib/nginx-dashboard.conf.example).

---

## Ручной сценарий (кратко)

1. Пакеты: `curl`, `python3`, `nftables`, `iptables`, `nginx`, `apache2-utils`.
2. Каталог с репозиторием → целевой `FIREWALL_ROOT` (rsync или `install.sh`).
3. `secrets/subscription.url` с HTTPS подпиской.
4. Скрипты: `sync-zapret-lists-upstream.sh`, `sync-geodat.sh`, `build-lists.sh`, `gen-mihomo-config.sh`.
5. **Zapret** bol-van: см. [contrib/zapret-bolvan-note.txt](contrib/zapret-bolvan-note.txt) и `state/generated/*`.
6. Режим **полного VPN**: `FIREWALL_VPN_ROUTE=tunnel` перед `gen-mihomo-config.sh`.
7. Память **~1 ГБ**: не жать «полное обновление» слишком часто под нагрузкой.

Полный текст — [SETUP-RU.txt](SETUP-RU.txt).

---

## English (short)

- **Stack:** domestic gateway with Flowseal-style text lists, bol-van/zapret DPI ideas, **Mihomo** + runetfreedom geodata, **nginx** + **shell2http** dashboard on loopback.
- **Quick remote install:** set `SUBSCRIPTION_URL` and `FIREWALL_REPO_URL`, then pipe [contrib/remote-install.sh](contrib/remote-install.sh) (see one-liners above).
- **Flags:** `SKIP_BINARIES`, `SKIP_SYNC`, `SKIP_SYSTEMD`, `DRY_RUN` — same as `install.sh`.
- **Details:** [SETUP-RU.txt](SETUP-RU.txt) (Russian walkthrough).

---

## Безопасность

- Не публикуйте **SUBSCRIPTION_URL** и логи с ним.
- После тестов с примерами в чатах **обновите** подписку на стороне провайдера.
