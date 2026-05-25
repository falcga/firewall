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

**Зеркала для бинарников:**
Если GitHub недоступен, укажите прямую ссылку на зеркало (SourceForge, GitLab Generic Packages, Яндекс.Диск и т.п.).

**Шаблонные переменные в URL** (автоматически подставляются при установке):
| Переменная | Описание |
|------------|----------|
| `{version}` | Последняя версия с GitHub (например `v1.19.25`) |
| `{arch}`    | Архитектура системы (`arm64`, `amd64`, `armv7`, `armv6`) |
| `{bin}`     | Имя бинарника (`mihomo` / `shell2http`) |
| `{suffix}`  | Расширение файла (`.gz` / `.tar.gz`) |

**Переменные окружения для зеркал:**
| Переменная | Приоритет | Описание |
|------------|-----------|----------|
| `MIHOMO_MIRROR_URL_AARCH64` | 1 (высший) | Только для ARM64 |
| `MIHOMO_MIRROR_URL_AMD64` | 1 | Только для x86_64 |
| `MIHOMO_MIRROR_URL` | 2 | Для любой архитектуры (шаблоны работают) |
| `SHELL2HTTP_MIRROR_URL` | 2 | Для shell2http (шаблоны работают) |

Пример для **GitLab Generic Package Registry** (с шаблонами — версия подтянется автоматически):
```bash
sudo env \
  SUBSCRIPTION_URL='https://ВАША_ПОДПИСКА' \
  MIHOMO_MIRROR_URL='https://gitlab.com/falcga/mihomo-mirror/-/packages/generic/mihomo/{version}/mihomo-linux-{arch}-{version}.gz' \
  ./install.sh -r /opt/firewall
```

Пример для **SourceForge** (без шаблонов, с фиксированной версией):
```bash
sudo env \
  SUBSCRIPTION_URL='https://ВАША_ПОДПИСКА' \
  MIHOMO_MIRROR_URL='https://sourceforge.net/projects/ваш-проект/files/mihomo-linux-arm64-v1.19.25.gz/download' \
  ./install.sh -r /opt/firewall
```

> **Лицензии:** MetaCubeX/mihomo — **GPL-3.0**, msoap/shell2http — **MIT**. Обе разрешают копирование, зеркалирование и распространение.
> **Лог установки** пишется в `$FIREWALL_ROOT/firewall-install.log` — сохраняется после удаления `/tmp/fw`.
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

### Разделы TUI:

| # | Раздел | Описание |
|---|--------|----------|
| 1 | 🌐 **VPN режим** | split / tunnel |
| 2 | 🛡️ **Zapret DPI** | установка zapret, стратегии, параметры |
| 3 | 📋 **Списки хостов** | импорт, просмотр, обновление |
| 4 | 🔌 **Управление прокси (v2rayN-like)** | CRUD прокси, URI импорт, переключение |
| 5 | 📡 **Подписки прокси** | добавление, обновление, управление |
| 6 | 🖥️ **Панель** | настройка nginx + shell2http |
| 7 | 🔧 **Сервисы** | запуск/остановка/перезапуск, автозапуск |
| 8 | ⚡ **Powerbank** | режим энергосбережения |
| 9 | 🔄 **Синхронизация** | обновление списков, geodata, подписки |
| 10 | 📊 **Статус** | состояние всех компонентов |

### Управление прокси (v2rayN-like)

Позволяет управлять прокси-серверами в стиле v2rayN, но в bash-интерфейсе:

- **Список прокси** — просмотр всех добавленных прокси с указанием активного
- **Добавить прокси** — импорт через URI (vless://, vmess://, trojan://)
- **Редактировать** — замена конфигурации
- **Удалить** — удаление конфигурации
- **Переключить активное** — выбор активного прокси
- **Рестарт Mihomo** — перезапуск бэкенда
- **Логи Mihomo** — просмотр последних строк лога
- **Системное прокси** — включение/выключение системного прокси (ОС-зависимое)
- **Обновить Geo-базы** — скачивание geoip.dat + geosite.dat

### Подписки прокси

Подписки прокси-серверов (аналогично v2rayN):

- **Список подписок** — просмотр добавленных URL
- **Добавить подписку** — указать название и URL
- **Удалить** — удаление подписки
- **Вкл/Выкл** — активация/деактивация
- **Обновить одну** — загрузить и импортировать прокси из конкретной подписки
- **Обновить ВСЕ** — массовое обновление всех активных подписок

## Веб-панель

```
http://<IP_на_Pi>:8088/dashboard/
```

### API endpoints (shell2http):

**Основные:**
- `POST /api/full-refresh` — полное обновление
- `POST /api/subscription-refresh` — обновить подписку Mihomo
- `POST /api/sync-build` — синхронизировать списки
- `POST /api/zapret-restart` — рестарт zapret
- `POST /api/mihomo-restart` — рестарт mihomo
- `POST /api/bypass-off` — выключить обходы
- `POST /api/bypass-on` — включить обходы
- `POST /api/low-power-on/off` — powerbank режим

**Управление прокси (v2rayN-like):**
- `GET  /api/proxy-status` — статус прокси (Mihomo + system proxy)
- `GET  /api/proxy-list` — список всех прокси (JSON)
- `POST /api/proxy-add` — добавить прокси (body: URI)
- `POST /api/proxy-delete` — удалить прокси (body: index)
- `POST /api/proxy-toggle` — переключить активное (body: index)
- `GET  /api/mihomo-logs` — последние 100 строк лога
- `POST /api/geo-update` — обновить geodata

**Подписки:**
- `GET  /api/sub-list` — список подписок (JSON)
- `POST /api/sub-add` — добавить подписку (body: name + url)
- `POST /api/sub-remove` — удалить подписку (body: index)
- `POST /api/sub-toggle` — вкл/выкл (body: index)
- `POST /api/sub-fetch` — обновить одну (body: url)
- `POST /api/sub-update-all` — обновить все активные

**Системное прокси:**
- `POST /api/sysproxy-on` — включить системный прокси
- `POST /api/sysproxy-off` — выключить системный прокси
- `GET  /api/sysproxy-status` — статус системного прокси

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
│   ├── shell2http-launcher.sh  ← маршруты shell2http (включая proxy API)
│   ├── shell2http.service.example
│   └── install/
│       └── parts/
├── deploy/
│   └── mihomo/
│       └── config.head.yaml.tpl
├── scripts/
│   ├── setup-tui.sh        ← интерактивная настройка (dialog)
│   ├── proxy-mgmt.sh       ← управление прокси/подписками (bash)
│   ├── proxy-parse.py      ← парсинг URI/base64 (только Python)
│   ├── lib.sh              ← общие функции/логирование
│   ├── sync-geodat.sh      ← обновление geoip/geosite
│   ├── gen-mihomo-config.sh
│   ├── svc-restart-mihomo.sh
│   ├── svc-restart-zapret.sh
│   └── ...                 ← остальные скрипты
├── secrets/
│   └── subscription.url    ← ваша подписка (создаётся при установке)
├── srv/
│   └── dashboard/
│       └── index.html      ← веб-панель
├── v2ray_tui/              ← вспомогательные данные (configs.json, subscriptions.json)
└── state/
    ├── generated/          ← сгенерированные списки zapret
    └── geodata/            ← geoip.dat + geosite.dat
```

## Требования

- Linux с `systemd` (Debian / Raspberry Pi OS / Ubuntu)
- `curl`, `git`, `dialog`, `nftables`, `python3` (только для парсинга URI)
- ~100 МБ свободного места после установки
- ~256 МБ RAM (минимально) для работы

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

# Логи TUI и скриптов
cat /opt/firewall/logs/firewall-update.log

# Проверка процессов
pgrep -a nfqws
pgrep -a tpws
pgrep -a mihomo
```

## Лицензия

MIT / GPL — зависит от компонентов. См. лицензии bol-van/zapret, MetaCubeX/mihomo, msoap/shell2http.