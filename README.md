Sinatra REST API
================

CRUD REST API на Sinatra поверх базы данных на MySQL.

Установка и запуск
------------------
```bash
git clone https://github.com/cochegarka/eduex-sinatra-api.git
cd eduex-sinatra-api
bundle install
touch .env
# ...
# ... Настройка окружения ...
# ...
ruby app.rb
```

Пример .env
-----------
```
DB_HOST=127.0.0.1
DB_NAME=eduex
DB_USER=eduex_demander
DB_PASS=123456
PORT=3001
SPA_URL=http://localhost:5000
```