#! /usr/bin/env bash

# hetzner-dyndns - A simple cli tool to manage your dns zones and records with hetzner.
#     Copyright (C) 2022  Frederic "wernerfred" Werner
#
#     This program is free software: you can redistribute it and/or modify
#     it under the terms of the GNU General Public License as published by
#     the Free Software Foundation, either version 3 of the License, or
#     (at your option) any later version.
#
#     This program is distributed in the hope that it will be useful,
#     but WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#     GNU General Public License for more details.
#
#     You should have received a copy of the GNU General Public License
#     along with this program.  If not, see <https://www.gnu.org/licenses/>.

HETZNER_API_URL="${HETZNER_API_URL:-"https://api.hetzner.cloud/v1"}"
HETZNER_API_TOKEN="${HETZNER_API_TOKEN:-}"
HETZNER_API_REQUIRED_TOOLS=(
  "curl"
  "jq"
  "dig"
)
HETZNER_DNS_DEFAULT_TTL="${HETZNER_DNS_DEFAULT_TTL:-"60"}"
RECORD_TTL="${HETZNER_DNS_DEFAULT_TTL}"

show_generic_help () {
  echo ""
  echo "USAGE:"
  echo "  ./hetzner-dyndns.sh -z ZONE_ID -R RECORD_NAME -t RECORD_TYPE [-T RECORD_TTL]"
  echo ""
  echo "OPTIONS:"
  echo "  -R     The record name"
  echo "  -t     The record type"
  echo "  -T     The record TTL (Default: 60)"
  echo "  -h     Show this help"
  echo "  -z     The zone id"
}

check_required_tools() {
    if ! command -v "${1}" >/dev/null 2>&1
    then
      echo "ERROR: Required tool '${1}' not found."
      exit 1
    fi
}

curl_call () {
  curl \
    --silent \
    --location \
    --show-error \
    --request "${1}" \
    "${HETZNER_API_URL}"/"${2}" \
    -H "Authorization: Bearer ${HETZNER_API_TOKEN}" \
    -H 'Content-Type: application/json; charset=utf-8' \
    -d "${3}"
}

get_current_public_ip () {
  RECORD_VALUE=$(${1} | awk -F '"' '{print $2}')
}

get_rrset_id () {
  response=$(curl_call GET "zones/${1}/rrsets" | jq -r '(.rrsets? // []) | map(select(.name=="'${2}'" and .type=="'${3}'")) | (.[0]?.id // empty)' | head -n1)
}

get_rrset_current_value () {
  response=$(curl_call GET "zones/${1}/rrsets" | jq -r '(.rrsets? // []) | map(select(.name=="'${2}'" and .type=="'${3}'")) | (.[0]?.records? // []) | (.[0]?.value // empty)' | head -n1)
  echo "${response}"
}

create_rrset () {
  payload="$(printf '%s\0%s\0%s\0%s' "${2}" "${3}" "${4}" "${RECORD_TTL}" | jq -Rs 'split("\u0000") as $i | {name:$i[0], type:$i[1], ttl:($i[3]|tonumber), records:[{value:$i[2]}]}')"
  response=$(curl_call POST "zones/${1}/rrsets" "$payload")
}

set_rrset_records() {
  payload="$(jq -nc --arg v "${3}" '{records:[{value:$v}]}')"
  response=$(curl_call POST "zones/${1}/rrsets/${2}/actions/set_records" "${payload}")
}


while getopts ":hz:R:t:T:" opt
do
  case "${opt}" in
    R ) RECORD_NAME="${OPTARG}";;
    t ) RECORD_TYPE="${OPTARG}";;
    T ) RECORD_TTL="${OPTARG}";;
    z ) ZONE_ID="${OPTARG}";;
    h ) show_generic_help
        exit 0
        ;;
    \?) echo "ERROR: Invalid option: -${OPTARG}, use -h to display help" >&2;
        exit 1
        ;;
    : ) echo "ERROR: Option -${OPTARG} requires an argument, use -h to display help" >&2;
        exit 1
        ;;
  esac
done

for tool in "${HETZNER_API_REQUIRED_TOOLS[@]}"
do
  check_required_tools "${tool}"
done

if [ -z "${HETZNER_API_TOKEN}" ]
then
  echo "ERROR: Variable 'HETZNER_API_TOKEN' not set."
  exit 1
fi

if [[ "$RECORD_TYPE" == "A" ]]
then
  query="dig -4 TXT +short o-o.myaddr.l.google.com @ns1.google.com"
  get_current_public_ip "$query"
else
  query="dig -6 TXT +short o-o.myaddr.l.google.com @ns1.google.com"
  get_current_public_ip "$query"
fi

RECORD_VALUE_UPSTREAM="$(get_rrset_current_value "${ZONE_ID}" "${RECORD_NAME}" "${RECORD_TYPE}" || true)"

if [[ "$RECORD_VALUE_UPSTREAM" == "$RECORD_VALUE" ]]
then
  echo "INFO: No update needed. Upstream value of record '${RECORD_NAME}' is already set to '${RECORD_VALUE}'."
  exit 0
else
  echo "INFO: Upstream value of record '${RECORD_NAME}' is set to '$RECORD_VALUE_UPSTREAM' and diverges from new value '$RECORD_VALUE'."
  echo "INFO: Updating upstream value of record '${RECORD_NAME}' to new value '$RECORD_VALUE'."
  RRSET_ID="$(get_rrset_id "${ZONE_ID}" "${RECORD_NAME}" "${RECORD_TYPE}" || true)"
  if [[ -n "${RRSET_ID}" ]]; then
    set_rrset_records "${ZONE_ID}" "${RRSET_ID}" "${RECORD_VALUE}"
  else
    create_rrset "${ZONE_ID}" "${RECORD_NAME}" "${RECORD_TYPE}" "${RECORD_VALUE}"
  fi

fi