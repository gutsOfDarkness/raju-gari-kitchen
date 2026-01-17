#!/bin/sh

set -e

echo "Waiting for postgres..."
until PGPASSWORD=$DB_PASSWORD psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -c '\q'; do
  >&2 echo "Postgres is unavailable - sleeping"
  sleep 1
done

echo "Postgres is up - running migrations..."
# Assuming migrations are in the migrations folder
# Check if there are any .sql files
if [ -d "migrations" ]; then
    for file in migrations/*.sql; do
        echo "Applying migration $file..."
        PGPASSWORD=$DB_PASSWORD psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -f "$file"
    done
fi

echo "Starting server..."
./api
