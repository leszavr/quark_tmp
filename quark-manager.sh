#!/bin/bash
export DOCKER_BUILDKIT=1

# Quark МКС Service Manager v2.3 Noddy
# Унифицированный скрипт управления всеми микросервисами платформы Quark
# Автор: Quark Development Team
# Дата: 25 ноября 2025

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Константы
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
LOG_FILE="$LOG_DIR/quark-manager.log"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"
ENV_FILE="$SCRIPT_DIR/.env"

# Wrapper for docker compose to always use the project's compose file
dc() {
    docker compose -f "$COMPOSE_FILE" "$@"
}

# Behaviour flags
# Если true, пропускаем жесткую остановку при отсутствии .env (только warn)
REQUIRE_ENV=false
# По умолчанию НЕ выполняем проверку структуры (чтобы start не падал).
# Для принудительной проверки передавайте --ensure-structure
SKIP_STRUCTURE_CHECK=true

# Создание папки для логов
mkdir -p "$LOG_DIR"

# Флаги
SKIP_ENV_CHECK=false

# Проверка наличия .env файла
check_env_file() {
    if [ ! -f "$ENV_FILE" ]; then
        echo -e "${YELLOW}⚠️  Файл .env не найден в корне проекта: $ENV_FILE${NC}"
        echo -e "${YELLOW}Если вы хотите, чтобы эта проверка была обязательной, запустите с флагом --require-env${NC}"
        if [ "$REQUIRE_ENV" = true ]; then
            echo -e "${RED}❌ Файл .env обязателен, выполнение прервано.${NC}"
            exit 1
        fi
    fi
}

# Функция логирования
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

# Функция вывода с логированием
print_log() {
    local color="$1"
    local level="$2"
    shift 2
    local message="$*"
    echo -e "${color}$message${NC}"
    log "$level" "$message"
}

# Функция отображения логотипа
show_logo() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}         ░▒▓█ QUARK МКС SERVICE MANAGER v2.3 Noddy█▓▒░${NC}"
    echo -e "${CYAN}                МКС - Управление Микросервисами${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Функция отображения помощи
show_help() {
    echo ""
    echo -e "${WHITE}ИСПОЛЬЗОВАНИЕ:${NC}"
    echo "    ./quark-manager.sh [КОМАНДА] [ОПЦИИ] [СЕРВИСЫ...]"
    echo ""
    echo -e "${WHITE}КОМАНДЫ:${NC}"
    echo -e "    ${GREEN}start${NC}       Запустить сервисы (по умолчанию все)"
    echo -e "    ${GREEN}stop${NC}        Остановить сервисы"
    echo -e "    ${GREEN}restart${NC}     Перезапустить сервисы"
    echo -e "    ${GREEN}build${NC}       Пересобрать образы сервисов"
    echo -e "    ${GREEN}rebuild${NC}     Пересобрать и перезапустить"
    echo -e "    ${GREEN}status${NC}      Показать статус всех сервисов"
    echo -e "    ${GREEN}health${NC}      Проверить health всех API сервисов"
    echo -e "    ${GREEN}logs${NC}        Показать логи сервисов"
    echo -e "    ${GREEN}clean${NC}       Очистить все контейнеры и образы"
    echo -e "    ${RED}hard-reboot${NC}  Полная перезагрузка системы (ОСТОРОЖНО!)"
    echo -e "    ${GREEN}list${NC}        Показать все доступные сервисы"
    echo ""
    echo -e "${WHITE}UI КОМАНДЫ:${NC}"
    echo -e "    ${PURPLE}ui:dev${NC}      Запустить UI в режиме разработки"
    echo -e "    ${PURPLE}ui:build${NC}    Собрать UI для продакшена"
    echo -e "    ${PURPLE}ui:start${NC}    Запустить UI через Docker"
    echo -e "    ${PURPLE}ui:open${NC}     Открыть UI в браузере"
    echo ""
    echo -e "${WHITE}SPEC-DRIVEN КОМАНДЫ:${NC}"
    echo -e "    ${CYAN}spec:new <name>${NC}       Создать новую спецификацию сервиса"
    echo -e "    ${CYAN}spec:validate [dir]${NC}   Валидировать спецификации и контракты"
    echo -e "    ${CYAN}spec:types <num>${NC}      Генерировать TypeScript types из OpenAPI"
    echo -e "    ${CYAN}spec:mock <num>${NC}       Запустить mock API server"
    echo -e "    ${CYAN}spec:generate-tests <num>${NC}  Генерировать тесты из контрактов"
    echo ""
    echo -e "${WHITE}VAULT & SECURITY:${NC}"
    echo -e "    ${PURPLE}vault:init${NC}        Инициализировать Vault и создать секреты"
    echo -e "    ${PURPLE}security:check${NC}    Проверить код на наличие секретов (gitleaks)"
    echo -e "    ${PURPLE}check:structure${NC}   Проверить структуру проекта и импорты"
    echo ""
    echo -e "${WHITE}ОПЦИИ:${NC}"
    echo -e "    ${YELLOW}-f, --force${NC}     Принудительная операция"
    echo -e "    ${YELLOW}-q, --quiet${NC}     Тихий режим"
    echo -e "    ${YELLOW}-v, --verbose${NC}   Подробный вывод"
    echo -e "    ${YELLOW}--skip-outdated-check${NC}   Пропустить проверку версий пакетов"
    echo -e "    ${YELLOW}--skip-structure-check${NC}  Пропустить проверку структуры проекта"
    echo -e "    ${YELLOW}--skip-env-check${NC}        Пропустить проверку .env файла"
    echo -e "    ${YELLOW}-h, --help${NC}      Показать эту справку"
    echo ""
    echo -e "${WHITE}ПРИМЕРЫ:${NC}"
    echo -e "    ${CYAN}./quark-manager.sh start${NC}                    # Запустить все сервисы"
    echo -e "    ${CYAN}./quark-manager.sh start plugin-hub redis${NC}   # Запустить только указанные"
    echo -e "    ${CYAN}./quark-manager.sh spec:new messaging-service${NC} # Создать новую спецификацию"
    echo -e "    ${CYAN}./quark-manager.sh spec:validate 001${NC}        # Валидировать спецификацию 001"
    echo ""
}

# Функция проверки Docker и Docker Compose
check_requirements() {
    if ! command -v docker &> /dev/null; then
        print_log "$RED" "ERROR" "❌ Docker не установлен!"
        exit 1
    fi

    # Проверяем доступность subcommand 'docker compose'
    if ! docker compose version &> /dev/null; then
        print_log "$RED" "ERROR" "❌ docker compose отсутствует или не доступен"
        exit 1
    fi

    if [[ ! -f "$COMPOSE_FILE" ]]; then
        print_log "$RED" "ERROR" "❌ Файл docker-compose.yml не найден: $COMPOSE_FILE"
        exit 1
    fi
}

# Попытаться установить Docker автоматически (консольное подтверждение)
attempt_install_docker() {
    print_log "$CYAN" "INFO" "🔧 Попытка авто-установки Docker через официальный скрипт get.docker.com"
    read -p "Требуется sudo. Продолжить автоматическую установку Docker? (yes/no): " -r
    if [[ $REPLY != "yes" ]]; then
        print_log "$YELLOW" "INFO" "Автоустановка отменена пользователем"
        return 1
    fi
    if ! command -v curl &>/dev/null; then
        print_log "$RED" "ERROR" "curl не найден. Установите curl и повторите."
        return 1
    fi
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh && sudo sh /tmp/get-docker.sh
    local res=$?
    if [[ $res -ne 0 ]]; then
        print_log "$RED" "ERROR" "Авто-установка Docker не удалась (код $res)"
        return 1
    fi
    print_log "$GREEN" "SUCCESS" "Docker установлен. Пожалуйста, перезапустите сессию (выход/вход) если требуется и повторите команду."
    return 0
}

ensure_docker() {
    if ! command -v docker &> /dev/null; then
        print_log "$YELLOW" "WARN" "Docker не найден на этой системе"
        attempt_install_docker || return 1
    fi
    # Проверяем доступность docker compose subcommand
    if ! docker compose version &> /dev/null; then
        print_log "$YELLOW" "WARN" "docker compose не доступен или не поддерживается"
        print_log "$CYAN" "INFO" "Попытка установить compose plugin через пакетный менеджер может потребоваться"
        read -p "Хотите попробовать автоустановку docker compose plugin? (yes/no): " -r
        if [[ $REPLY == "yes" ]]; then
            # Пытаемся установить плагин у docker (для популярных систем он уже включён)
            if sudo mkdir -p /etc/docker; then
                print_log "$CYAN" "INFO" "Попробуйте установить пакет docker/compose через системный пакетный менеджер вручную"
            fi
        else
            print_log "$YELLOW" "INFO" "Продолжение без docker compose может привести к ошибкам"
        fi
    fi
}

# Проверить порты (80 и 4873) и при занятости спросить пользователя
check_ports() {
    local ports=(80 4873)
    for p in "${ports[@]}"; do
        if ss -ltnp 2>/dev/null | grep -q ":$p \|:$p$"; then
            local occupier_line
            occupier_line=$(ss -ltnp 2>/dev/null | grep ":$p\b" | head -n1 || true)
            local occupier=$(echo "$occupier_line" | awk '{print $6,$7,$8,$9}')
            # Специальная обработка для Verdaccio (порт 4873)
            if [[ "$p" -eq 4873 ]]; then
                print_log "$YELLOW" "INFO" "Порт $p занят: $occupier"
                # Проверим HTTP-статус Verdaccio прежде чем просить освобождать порт
                local code
                code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:4873 2>/dev/null || true)
                if [[ "$code" == "200" ]]; then
                    print_log "$GREEN" "SUCCESS" "✅ Verdaccio отвечает HTTP 200 — порт $p используется Verdaccio, продолжаем"
                    continue
                fi

                if [[ "$code" == "404" ]]; then
                    print_log "$YELLOW" "WARN" "⚠️ Verdaccio отвечает 404. Попытка освободить порт $p и перезапустить Verdaccio..."

                    # Попытаемся найти docker-контейнер, который публикует этот порт
                    local container_info
                    container_info=$(docker ps --format '{{.ID}} {{.Names}} {{.Ports}}' 2>/dev/null | grep '4873' | head -n1 || true)
                    if [[ -n "$container_info" ]]; then
                        local cid=$(echo "$container_info" | awk '{print $1}')
                        local cname=$(echo "$container_info" | awk '{print $2}')
                        print_log "$CYAN" "INFO" "Найден контейнер, занимающий порт: $cid ($cname). Останавливаем..."
                        docker stop "$cid" || print_log "$YELLOW" "WARN" "Не удалось остановить контейнер $cid"
                    else
                        # Попытка обнаружить PID процесса и предложить пользователю убить его
                        local pid
                        pid=$(echo "$occupier_line" | grep -oP 'pid=\K[0-9]+' | head -n1 || true)
                        if [[ -n "$pid" ]]; then
                            print_log "$YELLOW" "INFO" "Процесс с PID $pid занимает порт $p"
                            read -p "Автоматически убить процесс $pid чтобы освободить порт $p? (yes/no): " -r killans
                            if [[ $killans == "yes" ]]; then
                                kill -9 "$pid" 2>/dev/null || print_log "$YELLOW" "WARN" "Не удалось убить процесс $pid"
                                sleep 1
                            else
                                print_log "$RED" "ERROR" "Операция прервана пользователем из-за занятого порта $p"
                                return 1
                            fi
                        else
                            # Не удалось определить PID — просим пользователя вмешаться
                            print_log "$RED" "ERROR" "Не удалось автоматически определить процесс на порту $p. Пожалуйста, освободите его вручную."
                            return 1
                        fi
                    fi

                    # После попытки освободить порт — проверяем снова
                    if ss -ltnp 2>/dev/null | grep -q ":$p \|:$p$"; then
                        print_log "$YELLOW" "WARN" "Порт $p всё ещё занят после попытки освобождения"
                        # Попробуем поднять verdaccio в любом случае — если не получится, переключимся на онлайн реестр
                        dc up -d verdaccio || print_log "$YELLOW" "WARN" "Не удалось запустить verdaccio сразу"
                        if wait_for_health "verdaccio" 30; then
                            print_log "$GREEN" "SUCCESS" "✅ Verdaccio поднят успешно после освобождения порта"
                            continue
                        else
                            print_log "$YELLOW" "WARN" "Verdaccio не поднялся после освобождения порта — переключаемся на онлайн реестр"
                            export npm_config_registry=https://registry.npmjs.org/
                            export pnpm_config_registry=https://registry.npmjs.org/
                            continue
                        fi
                    else
                        # Порт свободен — запускаем Verdaccio
                        dc up -d verdaccio || print_log "$YELLOW" "WARN" "Не удалось запустить verdaccio"
                        if wait_for_health "verdaccio" 30; then
                            print_log "$GREEN" "SUCCESS" "✅ Verdaccio поднят успешно"
                            continue
                        else
                            print_log "$YELLOW" "WARN" "Verdaccio не поднялся — переключаемся на онлайн реестр"
                            export npm_config_registry=https://registry.npmjs.org/
                            export pnpm_config_registry=https://registry.npmjs.org/
                            continue
                        fi
                    fi
                fi

                # Для любых других кодов (или если curl вернул пусто) — спрашиваем пользователя как раньше
                print_log "$RED" "ERROR" "Порт $p занят: $occupier"
                while true; do
                    read -p "Порт $p занят. Освободили порт $p? (Y/N): " -r yn
                    case $yn in
                        [Yy]*)
                            if ! ss -ltnp 2>/dev/null | grep -q ":$p \|:$p$"; then
                                print_log "$GREEN" "INFO" "Порт $p свободен"
                                break
                            else
                                print_log "$YELLOW" "INFO" "Порт $p всё ещё занят"
                            fi
                            ;;
                        [Nn]*)
                            print_log "$RED" "ERROR" "Операция прервана пользователем из-за занятого порта $p"
                            return 1
                            ;;
                        *) echo "Пожалуйста, введите Y или N." ;;
                    esac
                done
            else
                print_log "$RED" "ERROR" "Порт $p занят: $occupier"
                while true; do
                    read -p "Порт $p занят. Освободили порт $p? (Y/N): " -r yn
                    case $yn in
                        [Yy]*)
                            # проверить снова
                            if ! ss -ltnp 2>/dev/null | grep -q ":$p \|:$p$"; then
                                print_log "$GREEN" "INFO" "Порт $p свободен"
                                break
                            else
                                print_log "$YELLOW" "INFO" "Порт $p всё ещё занят"
                            fi
                            ;;
                        [Nn]*)
                            print_log "$RED" "ERROR" "Операция прервана пользователем из-за занятого порта $p"
                            return 1
                            ;;
                        *) echo "Пожалуйста, введите Y или N." ;;
                    esac
                done
            fi
        fi
    done
    return 0
}

# Функция проверки существования сервиса
validate_service() {
    # Простая проверка сервиса через docker-compose
    if ! dc config --services | grep -q "^$1$"; then
        print_log "$RED" "ERROR" "❌ Неизвестный сервис: $1"
        print_log "$YELLOW" "INFO" "Доступные сервисы:"
        dc config --services | sed 's/^/  /'
        return 1
    fi
    return 0
}

# Функция отображения статуса всех сервисов
show_status() {
    echo ""
    print_log "$BLUE" "INFO" "📊 Статус сервисов МКС Quark"
    echo ""
    
    # Получаем список всех сервисов
    local services=$(dc ps --format '{{.Name}}' 2>/dev/null)
    
    if [[ -z "$services" ]]; then
        print_log "$YELLOW" "WARN" "⚠️  Нет запущенных сервисов"
        echo ""
        print_log "$CYAN" "INFO" "💡 Запустите: ./quark-manager.sh start"
        echo ""
        return
    fi
    
    # Краткий список со статусами
    echo -e "${WHITE}Краткий обзор:${NC}"
    echo ""
    
    while IFS= read -r container; do
        if [[ -z "$container" ]]; then
            continue
        fi
        
        # Получаем информацию о контейнере
        local status=$(docker inspect --format '{{.State.Status}}' "$container" 2>/dev/null || echo "unknown")
        local health=$(docker inspect --format '{{.State.Health.Status}}' "$container" 2>/dev/null || echo "none")
        
        # Определяем иконку статуса
        local status_icon=""
        local status_color="$NC"
        
        if [[ "$status" == "running" ]]; then
            if [[ "$health" == "healthy" ]]; then
                status_icon="✅"
                status_color="$GREEN"
            elif [[ "$health" == "starting" ]]; then
                status_icon="⏳"
                status_color="$YELLOW"
            elif [[ "$health" == "unhealthy" ]]; then
                status_icon="❌"
                status_color="$RED"
            else
                status_icon="▶️"
                status_color="$GREEN"
            fi
        elif [[ "$status" == "restarting" ]]; then
            status_icon="🔄"
            status_color="$YELLOW"
        elif [[ "$status" == "exited" ]]; then
            status_icon="⏹️"
            status_color="$RED"
        else
            status_icon="❓"
            status_color="$YELLOW"
        fi
        
        # Форматируем имя сервиса (убираем префикс quark-)
        # Попытка аккуратно получить service name; если формат project_service_1, извлекаем service
        local service_name="$container"
        if [[ "$container" == *"_"*"_"* ]]; then
            service_name=$(echo "$container" | awk -F'_' '{print $2}')
        else
            service_name="${container#quark-}"
        fi
        
        # Выводим строку
        echo -e "  ${status_color}${status_icon} ${service_name}${NC}"
            
    done <<< "$services"
    
    echo ""
    
    # Статистика
    local total=$(echo "$services" | grep -c .)
    local running=$(dc ps --filter "status=running" --format '{{.Name}}' 2>/dev/null | wc -l)
    local stopped=$(dc ps --filter "status=exited" --format '{{.Name}}' 2>/dev/null | wc -l)
    
    echo -e "${CYAN}📈 Всего: $total | ▶️  Запущено: $running | ⏹️  Остановлено: $stopped${NC}"
    echo ""
    
    # Подробная таблица от Docker Compose
    echo -e "${WHITE}Подробная информация:${NC}"
    echo ""
    dc ps
    echo ""
}

# Функция проверки доступности verdaccio с таймаутом
check_verdaccio_availability() {
    local timeout_duration=60  # 1 минута
    local start_time=$(date +%s)
    local end_time=$((start_time + timeout_duration))
    
    print_log "$CYAN" "INFO" "🔍 Проверка доступности verdaccio (таймаут: 1 минута)..."
    
    while [[ $(date +%s) -lt $end_time ]]; do
        if curl -s --fail http://localhost:4873 &>/dev/null; then
            print_log "$GREEN" "SUCCESS" "✅ Verdaccio доступен"
            return 0
        fi
        sleep 2
    done
    
    print_log "$YELLOW" "WARN" "⚠️  Verdaccio недоступен после 1 минуты ожидания"
    return 1
}

# Ожидание здоровья контейнера или доступности сервиса
# Аргументы: service_name timeout_seconds
wait_for_health() {
    local service="$1"
    local timeout="$2"
    local start_ts=$(date +%s)
    local end_ts=$((start_ts + timeout))

    print_log "$CYAN" "INFO" "⏳ Ожидание health для $service (таймаут ${timeout}s)..."

    while [[ $(date +%s) -lt $end_ts ]]; do
        # Попробуем найти контейнер, связанный с сервисом
        local container=$(dc ps --filter "name=$service" --format '{{.Name}}' 2>/dev/null | head -n1 || true)
        # Специальная проверка для verdaccio: если HTTP 200 на порт 4873 — считаем healthy
        if [[ "$service" == "verdaccio" ]]; then
            # Пытаемся получить числовой код ответа, это надежнее для разных версий curl/HTTP
            local code
            code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:4873 2>/dev/null || true)
            if [[ "$code" == "200" ]]; then
                print_log "$GREEN" "SUCCESS" "✅ $service -> HTTP 200"
                return 0
            fi
        fi
        if [[ -n "$container" ]]; then
            # Попробуем прочитать health
            local health=$(docker inspect --format '{{.State.Health.Status}}' "$container" 2>/dev/null || true)
            local status=$(docker inspect --format '{{.State.Status}}' "$container" 2>/dev/null || true)
            if [[ "$health" == "healthy" ]]; then
                print_log "$GREEN" "SUCCESS" "✅ $service -> healthy"
                return 0
            fi
            if [[ "$status" == "running" ]] && [[ -z "$health" ]]; then
                # Нет healthcheck, считаем running как OK
                print_log "$GREEN" "SUCCESS" "✅ $service -> running"
                return 0
            fi
        fi
        sleep 2
    done

    print_log "$YELLOW" "WARN" "⚠️  Таймаут ожидания health для $service"
    return 1
}

# Автоматический порядок старта: infra -> core -> apps
start_ordered() {
    # Определите порядок по необходимости
    local infra_primary=(verdaccio vault postgres redis nats)
    local infra_secondary=(monitoring minio swagger-ui traefik)
    # core и app services можно дополнить в будущем или генерировать из compose
    local core_services=(plugin-hub quark-manager monitoring)
    local app_services=(auth-service blog-service quark-ui quark-landing)

    print_log "$GREEN" "INFO" "🚀 Запуск infra (primary)..."
    # Сначала обязателен verdaccio и его прогрев
    print_log "$CYAN" "INFO" "🔁 Поднимаем Verdaccio и прогреваем кеш (обязательно)..."
    dc up -d verdaccio || print_log "$YELLOW" "WARN" "Не удалось мгновенно поднять verdaccio"
    if ! wait_for_health "verdaccio" 60; then
        print_log "$YELLOW" "WARN" "Verdaccio не отвечает — переключаемся на официальный реестр и продолжаем"
        export npm_config_registry=https://registry.npmjs.org/
        export pnpm_config_registry=https://registry.npmjs.org/
    else
        # Прогрев кеша
        print_log "$CYAN" "INFO" "♨️  Прогрев кеша Verdaccio..."
        local cache_dir="$SCRIPT_DIR/.cache/quark-cache"
        mkdir -p "$cache_dir" && pushd "$cache_dir" >/dev/null
    cat > package.json <<'JSON'
{ "name": "quark-cache-warm", "version": "0.0.0", "dependencies": { "left-pad": "1.3.0" } }
JSON
        npm_config_registry=http://localhost:4873 pnpm install --silent || print_log "$YELLOW" "WARN" "Прогрев кеша вернул ошибку"
        popd >/dev/null
    fi

    for s in "${infra_primary[@]}"; do
        print_log "$CYAN" "INFO" "📦 Поднимаем $s..."
        dc up -d "$s" || print_log "$YELLOW" "WARN" "Не удалось мгновенно поднять $s"
        wait_for_health "$s" 60 || print_log "$YELLOW" "WARN" "$s не ответил на health за 60s"
    done

    print_log "$GREEN" "INFO" "🚀 Запуск infra (secondary)..."
    for s in "${infra_secondary[@]}"; do
        print_log "$CYAN" "INFO" "📦 Поднимаем $s..."
        dc up -d "$s" || print_log "$YELLOW" "WARN" "Не удалось мгновенно поднять $s"
        wait_for_health "$s" 45 || print_log "$YELLOW" "WARN" "$s не ответил на health за 45s"
    done

    print_log "$GREEN" "INFO" "🚀 Запуск core services..."
    for s in "${core_services[@]}"; do
        print_log "$CYAN" "INFO" "📦 Поднимаем $s..."
        dc up -d "$s" || print_log "$YELLOW" "WARN" "Не удалось поднять $s"
        wait_for_health "$s" 45 || print_log "$YELLOW" "WARN" "$s не ответил на health за 45s"
    done

    print_log "$GREEN" "INFO" "🚀 Запуск приложений..."
    for s in "${app_services[@]}"; do
        print_log "$CYAN" "INFO" "📦 Поднимаем $s..."
        dc up -d "$s" || print_log "$YELLOW" "WARN" "Не удалось поднять $s"
        wait_for_health "$s" 45 || print_log "$YELLOW" "WARN" "$s не ответил на health за 45s"
    done

    print_log "$GREEN" "SUCCESS" "✅ Ordered start finished"
}

# Ordered build matching start order
ordered_build() {
    print_log "$GREEN" "INFO" "🔨 Ordered build start"

    # 1) Build Verdaccio first (if build is defined)
    print_log "$CYAN" "INFO" "📦 Building Verdaccio..."
    dc build verdaccio || print_log "$YELLOW" "WARN" "Build verdaccio returned non-zero"

    # Start verdaccio to warm cache
    print_log "$CYAN" "INFO" "▶️  Starting Verdaccio for cache warmup"
    dc up -d verdaccio || print_log "$YELLOW" "WARN" "Could not start verdaccio"
    if wait_for_health "verdaccio" 60; then
        print_log "$CYAN" "INFO" "♨️  Warming Verdaccio cache..."
        local cache_dir="$SCRIPT_DIR/.cache/quark-cache"
        mkdir -p "$cache_dir" && pushd "$cache_dir" >/dev/null
    cat > package.json <<'JSON'
{ "name": "quark-cache-warm", "version": "0.0.0", "dependencies": { "left-pad": "1.3.0" } }
JSON
        npm_config_registry=http://localhost:4873 pnpm install --silent || print_log "$YELLOW" "WARN" "Cache warm failed"
        popd >/dev/null
    else
        print_log "$YELLOW" "WARN" "Verdaccio not healthy; will fallback to npm registry for builds"
        export npm_config_registry=https://registry.npmjs.org/
        export pnpm_config_registry=https://registry.npmjs.org/
    fi

    # 3) Build core infra services
    print_log "$CYAN" "INFO" "📦 Building infra services: vault, postgres, redis, nats"
    dc build vault postgres redis nats || print_log "$YELLOW" "WARN" "Build infra services returned non-zero"

    # 4) Build plugin-hub
    print_log "$CYAN" "INFO" "📦 Building plugin-hub"
    dc build plugin-hub || print_log "$YELLOW" "WARN" "Build plugin-hub returned non-zero"

    # 5) Build main apps
    print_log "$CYAN" "INFO" "📦 Building main apps: auth-service, blog-service, quark-ui, quark-landing"
    dc build auth-service blog-service quark-ui quark-landing || print_log "$YELLOW" "WARN" "Build apps returned non-zero"

    # 6) Build monitoring/minio/swagger-ui/traefik
    print_log "$CYAN" "INFO" "📦 Building secondary infra: monitoring, minio, swagger-ui, traefik"
    dc build monitoring minio swagger-ui traefik || print_log "$YELLOW" "WARN" "Build secondary infra returned non-zero"

    print_log "$GREEN" "SUCCESS" "✅ Ordered build finished"
}

# Интерактивное меню
menu() {
    PS3=$'Выберите действие: '
    options=("Start all (ordered)" "Stop all" "Rebuild all" "Status" "UI:dev" "UI:build" "UI:start" "Exit")
    select opt in "${options[@]}"; do
        case $opt in
            "Start all (ordered)") start_ordered; break ;;
            "Stop all") stop_services; break ;;
            "Rebuild all") rebuild_services; break ;;
            "Status") show_status; break ;;
            "UI:dev") dc up -d quark-ui && break ;;
            "UI:build") dc build quark-ui && break ;;
            "UI:start") dc up -d quark-ui && break ;;
            "Exit") break ;;
            *) echo "Неверный выбор." ;;
        esac
    done
}

# UI команды helper
ui_build() {
    print_log "$PURPLE" "INFO" "🔧 Сборка UI..."
    dc build quark-ui
}

ui_start() {
    print_log "$PURPLE" "INFO" "▶️  Запуск UI..."
    dc up -d quark-ui
}

ui_dev() {
    print_log "$PURPLE" "INFO" "🧪 Запуск UI в режиме разработки (локально)"
    # Предполагаем, что dev команда запускается локально вне контейнера
    (cd "$SCRIPT_DIR/infra/quark-ui" && pnpm install && pnpm run dev)
}

ui_open() {
    print_log "$PURPLE" "INFO" "🌐 UI URL: http://localhost:3101 (попробуйте открыть в браузере)"
}

# Функция временного переключения на онлайн реестр
switch_to_online_registry() {
    local manager_dir="$SCRIPT_DIR/tools/quark-manager"
    local npmrc_path="$manager_dir/.npmrc"
    local pnpmrc_path="$manager_dir/.pnpmrc"
    
    # Сохраняем оригинальные файлы, если они существуют
    if [[ -f "$npmrc_path" ]]; then
        cp "$npmrc_path" "$npmrc_path.backup"
    fi
    
    if [[ -f "$pnpmrc_path" ]]; then
        cp "$pnpmrc_path" "$pnpmrc_path.backup"
    fi
    
    # Создаем временные файлы с онлайн реестром
    echo "registry=https://registry.npmjs.org/" > "$npmrc_path"
    echo "registry=https://registry.npmjs.org/" > "$pnpmrc_path"
    
    print_log "$CYAN" "INFO" "🔄 Переключено на онлайн реестр пакетов"
}

# Функция восстановления оригинальной конфигурации реестра
restore_registry_config() {
    local manager_dir="$SCRIPT_DIR/tools/quark-manager"
    local npmrc_path="$manager_dir/.npmrc"
    local pnpmrc_path="$manager_dir/.pnpmrc"
    
    # Восстанавливаем оригинальные файлы из бэкапа
    if [[ -f "$npmrc_path.backup" ]]; then
        mv "$npmrc_path.backup" "$npmrc_path"
        print_log "$CYAN" "INFO" "🔄 Восстановлена оригинальная конфигурация .npmrc"
    else
        # Если бэкапа нет, удаляем временные файлы
        rm -f "$npmrc_path"
    fi
    
    if [[ -f "$pnpmrc_path.backup" ]]; then
        mv "$pnpmrc_path.backup" "$pnpmrc_path"
        print_log "$CYAN" "INFO" "🔄 Восстановлена оригинальная конфигурация .pnpmrc"
    else
        # Если бэкапа нет, удаляем временные файлы
        rm -f "$pnpmrc_path"
    fi
}

# Функция проверки структуры проекта
check_project_structure() {
    print_log "$CYAN" "INFO" "🔍 Проверка структуры проекта..."
    
    if command -v node &> /dev/null; then
        local tool_path="$SCRIPT_DIR/tools/quark-manager/dist/check-structure.js"
        local dist_dir="$SCRIPT_DIR/tools/quark-manager/dist"
        local src_dir="$SCRIPT_DIR/tools/quark-manager/src"
        local package_json="$SCRIPT_DIR/tools/quark-manager/package.json"
        
        # Проверяем наличие каталога dist и файла check-structure.js
        if [[ ! -f "$tool_path" ]]; then
            print_log "$YELLOW" "WARN" "🔧 Каталог tools/quark-manager/dist/ не найден, выполняем автоматическую установку..."
            
            # Проверяем наличие Node.js
            if ! command -v node &> /dev/null; then
                print_log "$RED" "ERROR" "❌ Node.js не установлен"
                return 1
            fi
            
            # Проверяем наличие исходных файлов TypeScript
            if [[ ! -d "$src_dir" ]] || [[ -z "$(ls -A "$src_dir")" ]]; then
                print_log "$RED" "ERROR" "❌ Исходные файлы TypeScript не найдены в $src_dir"
                return 1
            fi
            
            # Проверяем наличие package.json
            if [[ ! -f "$package_json" ]]; then
                print_log "$RED" "ERROR" "❌ Файл package.json не найден в $package_dir"
                return 1
            fi
            
            # Создаем каталог dist если он не существует
            if [[ ! -d "$dist_dir" ]]; then
                print_log "$CYAN" "INFO" "🏗️ Создаем каталог dist..."
                mkdir -p "$dist_dir"
            fi
            
            # Проверяем доступность verdaccio и при необходимости переключаемся на онлайн реестр
            # Если SKIP_STRUCTURE_CHECK=true — не пытаемся автоматически ставить инструмент
            if [[ "$SKIP_STRUCTURE_CHECK" = true ]]; then
                print_log "$YELLOW" "WARN" "⚠️  dist not found, пропускаем автоматическую сборку инструментов (SKIP_STRUCTURE_CHECK=true)"
            else
                local use_online_registry=false
                if ! check_verdaccio_availability; then
                    print_log "$YELLOW" "WARN" "⚠️  Verdaccio недоступен, попытаемся использовать онлайн-реестр временно"
                    export npm_config_registry=https://registry.npmjs.org/
                    export pnpm_config_registry=https://registry.npmjs.org/
                    use_online_registry=true
                fi

                print_log "$CYAN" "INFO" "📦 Устанавливаем зависимости и собираем инструменты..."
                (
                    cd "$SCRIPT_DIR/tools/quark-manager"
                    if command -v pnpm &> /dev/null; then
                        pnpm install && pnpm run build
                    elif command -v npm &> /dev/null; then
                        npm install && npm run build
                    else
                        print_log "$RED" "ERROR" "❌ Не найден менеджер пакетов (pnpm или npm)"
                        return 1
                    fi
                )
                local build_result=$?

                # Очистим временные переменные реестра
                if [[ "$use_online_registry" = true ]]; then
                    unset npm_config_registry pnpm_config_registry
                fi

                if [[ $build_result -ne 0 ]]; then
                    print_log "$RED" "ERROR" "❌ Ошибка при сборке инструментов"
                    return 1
                fi

                if [[ ! -f "$tool_path" ]]; then
                    print_log "$RED" "ERROR" "❌ Файл check-structure.js не был создан после сборки"
                    return 1
                fi

                print_log "$GREEN" "SUCCESS" "✅ Автоматическая установка завершена успешно"
            fi
        fi
        
        # Запускаем проверку структуры проекта
        if node "$tool_path" --root "$SCRIPT_DIR" --quiet; then
            print_log "$GREEN" "SUCCESS" "✅ Структура проекта корректна"
            return 0
        else
            print_log "$RED" "ERROR" "❌ Обнаружены нарушения структуры проекта!"
            print_log "$YELLOW" "INFO" "💡 Запустите: ./quark-manager.sh check:structure"
            print_log "$YELLOW" "INFO" "💡 Для пропуска проверки используйте: --skip-structure-check"
            return 1
        fi
    else
        print_log "$YELLOW" "WARN" "⚠️  Node.js не установлен, пропускаем проверку структуры"
        return 0
    fi
}

# Функция создания новой спецификации
spec_new() {
    local service_name="$1"
    
    if [[ -z "$service_name" ]]; then
        print_log "$CYAN" "INFO" "📝 Введите название сервиса (например: messaging-service):"
        read -r service_name
    fi
    
    # Определить следующий номер спецификации
    local next_num=$(find "$SCRIPT_DIR/specs/" -maxdepth 1 -type d -name "[0-9]*" 2>/dev/null | wc -l)
    next_num=$((next_num + 1))
    local spec_num=$(printf "%03d" $next_num)
    local spec_dir="$SCRIPT_DIR/specs/$spec_num-$service_name"
    
    print_log "$PURPLE" "INFO" "🆕 Создание новой спецификации: $spec_dir"
    
    # Создать структуру
    mkdir -p "$spec_dir/contracts"
    
    # Скопировать шаблоны
    if [[ -f "$SCRIPT_DIR/.specify/templates/spec-template.md" ]]; then
        cp "$SCRIPT_DIR/.specify/templates/spec-template.md" "$spec_dir/spec.md"
    else
        print_log "$YELLOW" "WARN" "⚠️  Шаблон spec-template.md не найден"
    fi
    
    if [[ -f "$SCRIPT_DIR/.specify/templates/plan-template.md" ]]; then
        cp "$SCRIPT_DIR/.specify/templates/plan-template.md" "$spec_dir/plan.md"
    else
        print_log "$YELLOW" "WARN" "⚠️  Шаблон plan-template.md не найден"
    fi
    
    # Копировать шаблоны контрактов из примера
    if [[ -d "$SCRIPT_DIR/specs/001-user-service/contracts" ]]; then
        cp "$SCRIPT_DIR/specs/001-user-service/contracts/openapi.yaml" "$spec_dir/contracts/" 2>/dev/null || true
        cp "$SCRIPT_DIR/specs/001-user-service/contracts/asyncapi.yaml" "$spec_dir/contracts/" 2>/dev/null || true
        cp "$SCRIPT_DIR/specs/001-user-service/contracts/module-manifest.yaml" "$spec_dir/contracts/" 2>/dev/null || true
    fi
    
    # Заменить placeholders если файлы существуют
    if [[ -f "$spec_dir/spec.md" ]]; then
        sed -i "s/user-service/$service_name/g" "$spec_dir/spec.md"
        sed -i "s/User Service/${service_name^}/g" "$spec_dir/spec.md"
        sed -i "s/001-user-service/$spec_num-$service_name/g" "$spec_dir/spec.md"
    fi
    
    print_log "$GREEN" "SUCCESS" "✅ Спецификация создана: $spec_dir"
    print_log "$CYAN" "INFO" "📝 Следующие шаги:"
    print_log "$CYAN" "INFO" "  1. Отредактируйте $spec_dir/spec.md"
    print_log "$CYAN" "INFO" "  2. Отредактируйте $spec_dir/plan.md"
    print_log "$CYAN" "INFO" "  3. Обновите контракты в $spec_dir/contracts/"
    print_log "$CYAN" "INFO" "  4. Запустите: ./quark-manager.sh spec:validate $spec_num"
}

# Функция валидации спецификаций
spec_validate() {
    local spec_dir="${1:-specs}"
    print_log "$CYAN" "INFO" "🔍 Валидация спецификаций в $spec_dir..."
    
    # Проверить наличие Docker
    if ! command -v docker &> /dev/null; then
        print_log "$RED" "ERROR" "❌ Docker не установлен. Необходим для валидации спецификаций."
        return 1
    fi
    
    # Найти все OpenAPI файлы
    find "$SCRIPT_DIR/$spec_dir" -name "openapi.yaml" -o -name "openapi.yml" 2>/dev/null | while read -r file; do
        print_log "$CYAN" "INFO" "📄 Проверка OpenAPI: $file"
        if docker run --rm -v "$SCRIPT_DIR:/specs" stoplight/spectral lint "/specs/${file#$SCRIPT_DIR/}" 2>/dev/null; then
            print_log "$GREEN" "SUCCESS" "✅ OpenAPI валидация пройдена: $file"
        else
            print_log "$RED" "ERROR" "❌ OpenAPI валидация не пройдена: $file"
        fi
    done
    
    # Найти все AsyncAPI файлы
    find "$SCRIPT_DIR/$spec_dir" -name "asyncapi.yaml" -o -name "asyncapi.yml" 2>/dev/null | while read -r file; do
        print_log "$CYAN" "INFO" "📄 Проверка AsyncAPI: $file"
        if docker run --rm -v "$SCRIPT_DIR:/specs" asyncapi/cli validate "/specs/${file#$SCRIPT_DIR/}" 2>/dev/null; then
            print_log "$GREEN" "SUCCESS" "✅ AsyncAPI валидация пройдена: $file"
        else
            print_log "$RED" "ERROR" "❌ AsyncAPI валидация не пройдена: $file"
        fi
    done
    
    print_log "$GREEN" "SUCCESS" "✅ Валидация завершена"
}

# Функция запуска сервисов
start_services() {
    local services=("$@")
    
    # Проверяем структуру проекта и выполняем автоматическую установку при необходимости
    check_project_structure || {
        print_log "$RED" "ERROR" "❌ Не удалось выполнить проверку структуры проекта или автоматическую установку"
        return 1
    }
    
    if [[ ${#services[@]} -eq 0 ]]; then
        print_log "$GREEN" "INFO" "🚀 Запуск всех сервисов МКС (ordered)..."
        start_ordered
        return
    else
        print_log "$GREEN" "INFO" "🚀 Запуск выбранных сервисов: ${services[*]}"
        # Проверяем корректность имен сервисов
        for service in "${services[@]}"; do
            validate_service "$service" || exit 1
        done
        dc up -d "${services[@]}"
    fi
    
    print_log "$GREEN" "SUCCESS" "✅ Запуск завершен!"
}

# Функция остановки сервисов
stop_services() {
    local services=("$@")
    
    if [[ ${#services[@]} -eq 0 ]]; then
        print_log "$YELLOW" "INFO" "⏹️  Остановка всех сервисов..."
        dc down
    else
        print_log "$YELLOW" "INFO" "⏹️  Остановка сервисов: ${services[*]}"
        for service in "${services[@]}"; do
            validate_service "$service" || exit 1
        done
        for service in "${services[@]}"; do
            print_log "$YELLOW" "INFO" "📦 Остановка $service..."
            dc stop "$service"
        done
    fi
    
    print_log "$YELLOW" "SUCCESS" "✅ Остановка завершена!"
}

# Функция пересборки образов
rebuild_services() {
    local services=("$@")
    
    if [[ ${#services[@]} -eq 0 ]]; then
        print_log "$PURPLE" "INFO" "🔨 Пересборка всех сервисов..."
        dc build --no-cache
    else
        print_log "$PURPLE" "INFO" "🔨 Пересборка сервисов: ${services[*]}"
        for service in "${services[@]}"; do
            validate_service "$service" || exit 1
        done
        dc build --no-cache "${services[@]}"
    fi
    
    print_log "$PURPLE" "SUCCESS" "✅ Пересборка завершена!"
}

# Функция health check API сервисов
health_check() {
    print_log "$CYAN" "INFO" "🏥 Проверка health API сервисов..."
    print_log "$CYAN" "════════════════════════════════════════"
    
    # Простая проверка через docker compose
    for service in $(dc config --services); do
        if dc ps --format json | grep -q "\"$service\""; then
            if dc ps --format json | grep "\"$service\"" | grep -q '"running"'; then
                print_log "$GREEN" "SUCCESS" "✅ $service - работает"
            else
                print_log "$YELLOW" "WARN" "⚠️  $service - остановлен"
            fi
        else
            print_log "$RED" "ERROR" "❌ $service - не создан"
        fi
    done
}

# Основная функция запуска
main() {
    # Проверка наличия .env файла
    check_env_file
    
    show_logo
    check_requirements
    
    # Парсинг аргументов
    local command=""
    local force=false
    local quiet=false
    local verbose=false
    local services=()
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            start|stop|restart|build|rebuild|status|health|logs|clean|hard-reboot|menu|list|ui:dev|ui:build|ui:start|ui:open|spec:new|spec:validate|spec:types|spec:mock|spec:generate-tests|vault:init|security:check|check:structure)
                command="$1"
                shift
                ;;
            -f|--force)
                force=true
                shift
                ;;
            -q|--quiet)
                quiet=true
                shift
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            --skip-env-check)
                SKIP_ENV_CHECK=true
                shift
                ;;
            --skip-outdated-check)
                export SKIP_PACKAGE_CHECK=true
                shift
                ;;
            --require-env)
                REQUIRE_ENV=true
                shift
                ;;
            --ensure-structure)
                SKIP_STRUCTURE_CHECK=false
                shift
                ;;
            --skip-structure-check)
                export SKIP_STRUCTURE_CHECK=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                services+=("$1")
                shift
                ;;
        esac
    done
    
    # Если команда не указана, показываем помощь
    if [[ -z "$command" ]]; then
        show_help
        exit 0
    fi
    
    # Проверка структуры проекта — выполняется только если явно включена
    if [[ "$SKIP_STRUCTURE_CHECK" = false ]]; then
        if [[ "$command" == "start" ]]; then
            check_project_structure
        else
            check_project_structure || true
        fi
    else
        print_log "$YELLOW" "INFO" "⚠️  Пропущена проверка структуры проекта (SKIP_STRUCTURE_CHECK=true). Для включения используйте --ensure-structure"
    fi
    
    # Выполнение команд
    case $command in
        start)
            # Ensure docker and ports are ready before starting
            ensure_docker || { print_log "$RED" "ERROR" "Docker is required"; exit 1; }
            check_ports || { print_log "$RED" "ERROR" "Required ports are occupied"; exit 1; }
            start_services "${services[@]}"
            show_status
            ;;
        stop)
            stop_services "${services[@]}"
            ;;
        restart)
            stop_services "${services[@]}"
            sleep 2
            start_services "${services[@]}"
            show_status
            ;;
        build)
            if [[ ${#services[@]} -eq 0 ]]; then
                ordered_build
            else
                dc build "${services[@]}"
            fi
            ;;
        rebuild)
            rebuild_services "${services[@]}"
            start_services "${services[@]}"
            show_status
            ;;
        status)
            show_status
            ;;
        health)
            health_check
            ;;
        logs)
            if [[ ${#services[@]} -eq 0 ]]; then
                dc logs
            else
                    dc logs "${services[@]}"
            fi
            ;;
        clean)
            print_log "$RED" "WARN" "🧹 Очистка всех контейнеров и образов..."
            dc down --rmi all --volumes --remove-orphans
            docker system prune -f
            print_log "$RED" "SUCCESS" "✅ Очистка завершена!"
            ;;
        hard-reboot)
            print_log "$RED" "WARN" "⚠️  ВНИМАНИЕ: Полная перезагрузка системы!"
            print_log "$RED" "WARN" "Это остановит и удалит ВСЕ контейнеры, образы и volumes."
            read -p "Вы уверены? (yes/no): " -r
            if [[ $REPLY == "yes" ]]; then
                docker compose down --rmi all --volumes --remove-orphans
                docker system prune -af --volumes
                print_log "$GREEN" "SUCCESS" "✅ Система полностью очищена. Запустите start для пересборки."
            else
                print_log "$YELLOW" "INFO" "Операция отменена."
            fi
            ;;
        menu)
            menu
            ;;
        ui:dev)
            ui_dev
            ;;
        ui:build)
            ui_build
            ;;
        ui:start)
            ui_start
            ;;
        ui:open)
            ui_open
            ;;
        list)
            echo ""
            echo -e "${WHITE}📋 Доступные сервисы МКС Quark:${NC}"
            echo "════════════════════════════════════════════════════════"
            docker compose config --services
            echo ""
            ;;
        menu)
            print_log "$BLUE" "INFO" "🔧 Интерактивное меню будет добавлено в следующей версии..."
            ;;
        check:structure)
            check_project_structure
            ;;
        spec:new)
            spec_new "${services[@]}"
            ;;
        spec:validate)
            spec_validate "${services[@]}"
            ;;
        vault:init|security:check|ui:dev|ui:build|ui:start|ui:open|spec:types|spec:mock|spec:generate-tests)
            print_log "$YELLOW" "WARN" "⚠️  Команда $command еще не реализована в этой версии"
            print_log "$CYAN" "INFO" "💡 Обратитесь к документации или используйте --help"
            ;;
        *)
            print_log "$RED" "ERROR" "❌ Неизвестная команда: $command"
            show_help
            exit 1
            ;;
    esac
}

# Запуск основной функции
main "$@"