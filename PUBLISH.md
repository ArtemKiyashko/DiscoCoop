# Публикация репозитория DiscoCoop

Инструкции по публикации проекта на GitHub.

## Первая публикация

1. **Инициализация Git репозитория (если еще не сделано):**
```bash
cd /Users/artem/repos/disco_coop
git init
```

2. **Добавление файлов:**
```bash
git add .
git commit -m "Initial commit: Disco Coop - кооперативная игра в Disco Elysium через Telegram"
```

3. **Добавление удаленного репозитория:**
```bash
git remote add origin git@github.com:ArtemKiyashko/DiscoCoop.git
```

4. **Публикация:**
```bash
git branch -M main
git push -u origin main
```

## Обновление репозитория

```bash
git add .
git commit -m "Описание изменений"
git push
```

## Создание релиза

1. **Создание тега:**
```bash
git tag -a v1.0.0 -m "Первый релиз Disco Coop"
git push origin v1.0.0
```

2. **Создание релиза на GitHub:**
- Перейдите на страницу репозитория
- Нажмите "Releases" → "Create a new release"
- Выберите тег v1.0.0
- Заполните описание релиза

## README для GitHub

После публикации убедитесь, что README.md корректно отображается на главной странице репозитория.

## Структура проекта для публикации

```
DiscoCoop/
├── README.md                 # Главное описание проекта
├── LICENSE                   # Лицензия (рекомендуется MIT)
├── requirements.txt          # Python зависимости
├── main.py                   # Точка входа
├── install.sh               # Скрипт установки
├── .gitignore               # Исключения Git
├── .env.example             # Пример переменных окружения
├── config/
│   └── config.example.yaml  # Пример конфигурации
├── src/                     # Исходный код
├── docs/                    # Документация
└── tests/                   # Тесты
```

## Настройка GitHub Actions (опционально)

Можно добавить автоматическое тестирование:

```yaml
# .github/workflows/test.yml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    - uses: actions/setup-python@v2
      with:
        python-version: '3.11'
    - run: pip install -r requirements.txt
    - run: python -m pytest tests/
```

## Добавление лицензии

Рекомендуется добавить файл LICENSE с MIT лицензией для открытого проекта.

## Badges для README

После публикации можно добавить badges:

```markdown
![Python](https://img.shields.io/badge/python-v3.11+-blue.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)
![Platform](https://img.shields.io/badge/platform-SteamDeck%20%7C%20Linux%20%7C%20Windows-lightgrey.svg)
```