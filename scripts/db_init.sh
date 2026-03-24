#!/bin/bash
###############################################################
# db_init.sh — RDS Database Init
# Runs FROM app tier after app_tier_setup.sh completes
###############################################################

set -e
exec > /var/log/db_init.log 2>&1

echo "===== DB INIT STARTED: $(date) ====="

# ── Wait for RDS
echo "[1/3] Waiting for RDS..."
MAX_ATTEMPTS=30
COUNT=0
until mysql -h "${db_host}" -u "${db_user}" -p"${db_password}" -e "SELECT 1;" > /dev/null 2>&1; do
  COUNT=$((COUNT + 1))
  if [ "$COUNT" -ge "$MAX_ATTEMPTS" ]; then
    echo "ERROR: RDS not reachable after $MAX_ATTEMPTS attempts."
    exit 1
  fi
  echo "Attempt $COUNT/$MAX_ATTEMPTS — waiting 10s..."
  sleep 10
done
echo "RDS reachable!"

# ── Create tables
echo "[2/3] Creating schema..."
mysql -h "${db_host}" -u "${db_user}" -p"${db_password}" << SQL
CREATE DATABASE IF NOT EXISTS ${db_name};
USE ${db_name};

CREATE TABLE IF NOT EXISTS transactions (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  amount      DECIMAL(10,2) NOT NULL,
  description VARCHAR(255),
  created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO transactions (amount, description) VALUES
  (100.00, 'Initial test transaction'),
  (250.50, 'Sample purchase'),
  (75.00,  'Sample refund');

SELECT 'DB init complete' AS status;
SELECT COUNT(*) AS row_count FROM transactions;
SQL

echo "[3/3] Verifying..."
mysql -h "${db_host}" -u "${db_user}" -p"${db_password}" \
  -e "USE ${db_name}; SHOW TABLES; SELECT * FROM transactions;"

echo "===== DB INIT COMPLETE: $(date) ====="
