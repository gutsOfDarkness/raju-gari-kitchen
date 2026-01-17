#!/bin/sh
set -e

echo "Waiting for postgres at $DB_HOST..."
until PGPASSWORD=$DB_PASSWORD psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -c '\q'; do
  >&2 echo "Postgres is unavailable - sleeping"
  sleep 1
done

echo "Postgres is up - running migrations..."
if [ -d "/migrations" ]; then
    for file in /migrations/*.sql; do
        echo "Applying $file..."
        PGPASSWORD=$DB_PASSWORD psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -f "$file"
    done
else
    echo "No migrations found!"
fi

echo "Migrations completed."
