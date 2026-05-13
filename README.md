# Firewall (Домашний шлюз)

Стек для организации домашнего шлюза на Raspberry Pi / Linux с обходом DPI и проксированием трафика.

**Компоненты:**
- **Flowseal** — списки заблокированных доменов/IP
- **bol-van/zapret** — обход DPI (nfqws/tpws)
- **Mihomo** (Clash Meta) — прокси-клиент с geodata
- **nginx + shell2http** — веб-панель управления
- **runetfreedom** — геодата для Mihomo

## Быстрая установка

```bash
# 1. Клонировать репозиторий
git clone https://github.com/falcga/firewall.git /tmp/fw
cd /tmp/fw

# 2. Запустить установку (подставьте свою подписку)
sudo env SUBSCRIPTION_URL='https://ВАША_ПОДПИСКА' ./install.sh -r /opt/firewall

# 3. Запустить сервисы
sudo firewall start
```

**Флаги установки:**
| Флаг | Описание |
|------|----------|
| `SKIP_BINARIES=1` | Не скачивать Mihomo/shell2http |
| `SKIP_SYNC=1` | Пропустить первый sync |
| `SKIP_SYSTEMD=1` | Не создавать systemd-сервисы |
| `DRY_RUN=1` | Показать команды без выполнения |

## CLI управление

После установки используйте команду `firewall`:

```bash
sudo firewall start       # Запустить mihomo + shell2http + zapret
sudo firewall stop        # Остановить все сервисы
sudo firewall restart     # Перезапустить все сервисы
sudo firewall status      # Показать статус, диск, списки
sudo firewall settings    # Интерактивная настройка (TUI)
sudo firewall update      # Обновить списки, geodata, подписку
sudo firewall logs        # Показать последние логи
sudo firewall install     # Установить/переустановить компоненты
sudo firewall help        # Справка
```

## TUI настройка

```bash
sudo bash /opt/firewall/scripts/setup-tui.sh
```

**Разделы TUI:**
- 🌐 **VPN режим** — split (только заблокированные) / tunnel (весь трафик)
- 🛡️ **Zapret DPI** — установка zapret, выбор стратегий (nfqws/tpws), настройка параметров
- 📋 **Списки хостов** — импорт доменов, просмотр/обновление списков
- 🖥️ **Панель** — настройка nginx + shell2http
- 🔧 **Сервисы** — запуск/остановка/рестарт, автозапуск
- ⚡ **Powerbank** — режим энергосбережения
- 🔄 **Синхронизация** — обновление списков, geodata, подписки
- 📊 **Статус** — состояние всех компонентов

## Веб-панель

```
http://<IP_на_Pi>:8088/dashboard/
```

**API endpoints:**
- `POST /api/full-refresh` — полное обновление
- `POST /api/subscription-refresh` — обновить подписку
- `POST /api/sync-build` — синхронизировать списки
- `POST /api/zapret-restart` — рестарт zapret
- `POST /api/mihomo-restart` — рестарт mihomo
- `POST /api/bypass-off` — выключить обходы
- `POST /api/bypass-on` — включить обходы
- `POST /api/low-power-on/off` — powerbank режим

## Структура проекта

```
firewall/
├── install.sh              ← точка входа (установщик)
├── firewall                ← CLI команда
├── README.md
├── .gitignore
├── catalog/
│   ├── upstream/           ← списки Flowseal (скачиваются)
│   └── user/               ← пользовательские домены
├── contrib/
│   └── install/
│       └── parts/          ← оригинальные parts из falcga/firewall
├── deploy/
├── scripts/
│   └── setup-tui.sh        ← интерактивная настройка
├── secrets/
│   └── subscription.url    ← ваша подписка (создаётся при установке)
├── srv/
│   └── dashboard/
│       └── index.html      ← веб-панель
└── state/
    ├── generated/          ← сгенерированные списки zapret
    └── geodata/            ← geoip.dat + geosite.dat
```

## Требования

- Linux с `systemd` (Debian / Raspberry Pi OS / Ubuntu)
- `curl`, `git`, `dialog`, `nftables`
- ~100 МБ свободного места после установки
- ~1 ГБ RAM для полного обновления

## Безопасность

- Не публикуйте `SUBSCRIPTION_URL` и логи с ним
- После тестов обновите подписку на стороне провайдера
- `subscription.url` хранится в `secrets/` с правами 600

## Ручная установка zapret

Если автоустановка не сработала:

```bash
cd /tmp
git clone --depth=1 https://github.com/bol-van/zapret.git
cd zapret
# Для Raspberry Pi (aarch64):
# Бинарники уже есть в binaries/linux-arm64/
./install_bin.sh          # установит бинарники
./install_easy.sh         # интерактивная настройка
```

## Логи и отладка

```bash
# Логи установки
cat /tmp/firewall-install.log
cat /tmp/zapret-install.log

# Логи сервисов
sudo journalctl -u mihomo.service -n 50
sudo journalctl -u zapret.service -n 50
sudo journalctl -u firewall-shell2http.service -n 50

# Проверка процессов
pgrep -a nfqws
pgrep -a tpws
pgrep -a mihomo
```

## Лицензия

MIT / GPL — зависит от компонентов. См. лицензии bol-van/zapret, MetaCubeX/mihomo, msoap/shell2http.
