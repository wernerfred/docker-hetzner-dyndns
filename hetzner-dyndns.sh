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

HETZNER_DNS_API_URL="${HETZNER_DNS_API_URL:-"https://dns.hetzner.com/api/v1"}"
HETZNER_DNS_API_TOKEN="${HETZNER_DNS_API_TOKEN:-}"
HETZNER_DNS_API_REQUIRED_TOOLS=(
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
    "${HETZNER_DNS_API_URL}"/"${2}" \
    -H "Auth-API-Token: ${HETZNER_DNS_API_TOKEN}" \
    -H 'Content-Type: application/json; charset=utf-8' \
    -d "${3}"
}

get_single_zone () {
  response=$(curl_call GET "zones/${1}")
  if [[ $(echo "${response}" | jq -r 'has("error")') == "true" ]]
  then
    echo "ERROR: Zone with ID '${1}' not found."
    exit 1
  fi
}

get_all_records () {
  response=$(curl_call GET "records?zone_id=${1}")
  echo "${response}"
}

get_record_by_name () {
  response=$(get_all_records "${1}" | jq -r '.records[] | select(.type == "'${2}'") | select(.name == "'${3}'") | .id')
  if [ -z "$response" ]
  then
    echo "INFO: Record with name '${RECORD_NAME}' not found."
    return 1
  else
    RECORD_ID="${response}"
    return 0
  fi
}

get_record_by_id () {
  response=$(curl_call GET "records/${RECORD_ID}")
  echo "${response}"
}

create_record () {
  echo "INFO: Creating record with name '${RECORD_NAME}'."
  payload="{\"value\": \"${1}\", \"ttl\": ${2}, \"type\": \"${3}\", \"name\": \"${4}\", \"zone_id\": \"${5}\"}"
  response=$(curl_call POST records "$payload")
  if [[ $(echo "${response}" | jq -r 'has("error")') == "true" ]]
  then
    error=$(echo "${response}" | jq -r '.error | .message')
    echo "ERROR: Could not create record: ${error}"
    exit 1
  else
    RECORD_ID=$(echo "${response}" | jq -r '.record | .id')
    return 0
  fi
}

update_record () {
  payload="{\"value\": \"${1}\", \"ttl\": ${2}, \"type\": \"${3}\", \"name\": \"${4}\", \"zone_id\": \"${5}\"}"
  response=$(curl_call PUT "records/${RECORD_ID}" "$payload")
  if [[ $(echo "${response}" | jq -r 'has("error")') == "true" ]]
  then
    error=$(echo "${response}" | jq -r '.error | .message')
    echo "ERROR: Could not update record: ${error}"
    exit 1
  else
    echo "INFO: Updated record successfully. New value of record '${RECORD_NAME}' is '${RECORD_VALUE}'."
    return 0
  fi
}

get_current_public_ip () {
  RECORD_VALUE=$(${1} | awk -F '"' '{print $2}')
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

for tool in "${HETZNER_DNS_API_REQUIRED_TOOLS[@]}"
do
  check_required_tools "${tool}"
done

if [ -z "${HETZNER_DNS_API_TOKEN}" ]
then
  echo "ERROR: Variable 'HETZNER_DNS_API_TOKEN' not set."
  exit 1
fi

#check if zone is valid
get_single_zone "${ZONE_ID}"

if [[ "$RECORD_TYPE" == "A" ]]
then
  query="dig TXT +short o-o.myaddr.l.google.com @ns1.google.com"
  get_current_public_ip "$query"
else
  query="dig -6 TXT +short o-o.myaddr.l.google.com @ns1.google.com"
  get_current_public_ip "$query"
fi

#get record id by name or create record if it doesn't exist
get_record_by_name "${ZONE_ID}" "${RECORD_TYPE}" "${RECORD_NAME}" || create_record "${RECORD_VALUE}" "${RECORD_TTL}" "${RECORD_TYPE}" "${RECORD_NAME}" "${ZONE_ID}"

RECORD_VALUE_UPSTREAM=$(get_record_by_id "${RECORD_ID}" | jq -r '.record | .value')

if [[ "$RECORD_VALUE_UPSTREAM" == "$RECORD_VALUE" ]]
then
  echo "INFO: No update needed. Upstream value of record '${RECORD_NAME}' is already set to '${RECORD_VALUE}'."
  exit 0
else
  echo "INFO: Upstream value of record '${RECORD_NAME}' is set to '$RECORD_VALUE_UPSTREAM' and diverges from new value '$RECORD_VALUE'."
  echo "INFO: Updating upstream value of record '${RECORD_NAME}' to new value '$RECORD_VALUE'."
  update_record "${RECORD_VALUE}" "${RECORD_TTL}" "${RECORD_TYPE}" "${RECORD_NAME}" "${ZONE_ID}"
fi