#!/usr/bin/env bash
set -euo pipefail

host="${1:-api2.cursor.sh}"

python3 - "$host" <<'PY'
import socket
import sys

host = sys.argv[1]

try:
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.close()
except PermissionError as exc:
    print(
        "cursor-network: socket creation is blocked in this Codex execution "
        f"environment: {exc}",
        file=sys.stderr,
    )
    sys.exit(75)
except OSError as exc:
    print(f"cursor-network: socket creation failed: {exc}", file=sys.stderr)
    sys.exit(75)

try:
    socket.getaddrinfo(host, 443, proto=socket.IPPROTO_TCP)
except socket.gaierror as exc:
    print(f"cursor-network: DNS lookup failed for {host}: {exc}", file=sys.stderr)
    sys.exit(75)
except OSError as exc:
    print(f"cursor-network: network lookup failed for {host}: {exc}", file=sys.stderr)
    sys.exit(75)
PY
