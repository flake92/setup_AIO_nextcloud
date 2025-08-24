#!/bin/bash

# Скрипт для проверки статуса GitHub Actions
REPO="flake92/setup_AIO_nextcloud"
API_URL="https://api.github.com/repos/$REPO/actions/runs"

echo "🔍 Проверка статуса GitHub Actions для $REPO..."

# Получаем последние 5 запусков
curl -s "$API_URL?per_page=5" | \
python3 -c "
import json, sys
data = json.load(sys.stdin)
if 'workflow_runs' in data:
    runs = data['workflow_runs']
    print(f'Найдено {len(runs)} последних запусков:')
    print()
    for i, run in enumerate(runs[:5]):
        status = run['status']
        conclusion = run.get('conclusion', 'N/A')
        created = run['created_at'][:19].replace('T', ' ')
        commit_msg = run['head_commit']['message'][:50] + '...' if len(run['head_commit']['message']) > 50 else run['head_commit']['message']
        
        # Эмодзи для статуса
        if conclusion == 'success':
            emoji = '✅'
        elif conclusion == 'failure':
            emoji = '❌'
        elif status == 'in_progress':
            emoji = '🔄'
        else:
            emoji = '⏳'
            
        print(f'{emoji} {run[\"name\"]} - {status}/{conclusion}')
        print(f'   Коммит: {commit_msg}')
        print(f'   Время: {created}')
        print(f'   URL: {run[\"html_url\"]}')
        print()
else:
    print('Ошибка получения данных:', data.get('message', 'Неизвестная ошибка'))
"
