#!/usr/bin/env bash

die()
{
  echo "$*"
  exit;
}

# Get server to test, and timeout in seconds
server=$1
timeout_in_seconds=${2:-20}
case "$timeout_in_seconds" in
  ''|*[!0-9]*) die "Your timeout value should be an integer value, not '$2'"
esac

# where to log full responses to
dump_file=${3:-/tmp/__dump_tls_info}
rm -f "$dump_file"

show_help()
{
  me=$(basename "$0")
  info=$(cat <<EOF
  Shows which versions of TLS a server supports.

  usage: $me SERVER {TIMEOUT_IN_SECONDS} {DUMP_FILE}

  e.g.  The following are public test servers that demonstrate
  support for various TLS versions.

  $ $me tls1test.salesforce.com       # validate TLS 1.0 is blocked
  $ $me tls-v1-0.badssl.com:1010      # validate only TLS 1.0 enabled
  $ $me tls-v1-1.badssl.com:1011      # validate only TLS 1.1 enabled
  $ $me smtp.gmail.com:465            # validate TLS 1.0+ are all supported

  Note: default timeout in seconds is 20, and it dumps full output to $dump_file
EOF
  )
  echo "$info"
  exit
}

if [ -z "$server" ]; then
  show_help
fi

testTLS()
{
  tls="$1"
  tlsDisplay=${2:-$1}
  if [ -n "$tls" ]; then
    tls_cmd="--tlsv$1"
  else
    tls_cmd=""
  fi

  CMD="curl --max-time "$timeout_in_seconds" -v -I --silent "$tls_cmd" "https://$server/""
  OUT=$($CMD 2>&1)
  CURL_VERSION=$(curl --version)
  OUT_CURL_OLD=$(echo "$OUT" | grep "option --tls" | grep "unknown")
  OUT_TLS=$(echo "$OUT" | grep "topped the pause stream")
  OUT_TLS_HANDSHAKE=$(echo "$OUT" | grep "handshake fail")
  OUT_TIMEOUT=$(echo "$OUT" | grep "onnection timed out after")

  {
    echo
    echo "#######################################"
    echo "testing TLS$tls is supported on $server"
    echo "curl version: $CURL_VERSION"
    echo "curl location: `which curl`"
    echo "os version: `sw_vers`"
    echo "ran the following:"
    echo "$CMD"
    echo "$OUT"
    echo
  } >> "$dump_file"

  if [ -n "$OUT_TIMEOUT" ]; then
    echo "connection to $server timed out after $timeout_in_seconds seconds"
  fi
  if [ -n "$OUT_CURL_OLD" ]; then
    echo "Your version of curl is too old, and can't test for TLS $tls support"
    return;
  fi

  if [ -n "$OUT_TLS" ]; then
    echo "### TLS $tlsDisplay is NOT SUPPORTED on $server ###"
  else
    if [ -n "$OUT_TLS_HANDSHAKE" ]; then
      echo "### TLS $tlsDisplay is NOT SUPPORTED on $server ###"
    else
      echo "TLS $tlsDisplay is supported on $server"
    fi
  fi
}

testTLS 1.2
testTLS 1.1
testTLS 1.0

#usage
# tls_test.sh google.com
