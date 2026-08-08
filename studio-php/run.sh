#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
exec php -S 127.0.0.1:${ODC_STUDIO_PORT:-8088} -t studio-php/public
