#!/bin/bash

# Скрипт для детального анализа провалов CI
REPO="flake92/setup_AIO_nextcloud"

echo "🔍 Анализ провалов GitHub Actions..."

# Получаем последний провалившийся запуск
FAILED_RUN=$(curl -s "https://api.github.com/repos/$REPO/actions/runs?status=failure&per_page=1" | \
python3 -c "
import json, sys
data = json.load(sys.stdin)
if 'workflow_runs' in data and data['workflow_runs']:
    run = data['workflow_runs'][0]
    print(f'{run[\"id\"]}|{run[\"name\"]}|{run[\"conclusion\"]}')
else:
    print('no_failures')
")

if [ "$FAILED_RUN" = "no_failures" ]; then
    echo "✅ Нет провалившихся тестов!"
    exit 0
fi

RUN_ID=$(echo "$FAILED_RUN" | cut -d'|' -f1)
RUN_NAME=$(echo "$FAILED_RUN" | cut -d'|' -f2)

echo "📋 Анализируем провал: $RUN_NAME (ID: $RUN_ID)"

# Получаем детали джобов
curl -s "https://api.github.com/repos/$REPO/actions/runs/$RUN_ID/jobs" | \
python3 -c "
import json, sys
data = json.load(sys.stdin)
if 'jobs' in data:
    print('Статус джобов:')
    for job in data['jobs']:
        status = job['conclusion'] or job['status']
        name = job['name']
        if status == 'failure':
            print(f'❌ {name}')
            print(f'   URL: {job[\"html_url\"]}')
            # Пытаемся получить последние строки лога
            if 'steps' in job:
                for step in job['steps']:
                    if step.get('conclusion') == 'failure':
                        print(f'   Провалившийся шаг: {step[\"name\"]}')
        elif status == 'success':
            print(f'✅ {name}')
        else:
            print(f'⏳ {name} - {status}')
    print()
else:
    print('Ошибка получения данных о джобах')
"

echo "💡 Рекомендации:"
echo "1. Проверьте локальные тесты: ./test-script.sh"
echo "2. Проверьте интеграционные тесты: ./test-installation.sh"
echo "3. Убедитесь что все функции существуют в скрипте"
