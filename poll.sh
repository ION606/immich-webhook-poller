#!/usr/bin/env bash

required_vars=(
    "IMMICH_BASE_URL"
    "IMMICH_API_KEY"
)

for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "error: required environment variable $var is not set" >&2
        exit 1
    fi
done

if [ ! -f "/hooks.json" ]; then
    echo "MISSING hooks.json FILE"
	exit 1
fi

HOOKS=$(jq -c '.[]' /hooks.json)

STATS_FILE="/data/store.txt"
STAT_URL="$IMMICH_BASE_URL/api/assets/statistics"
SEARCH_URL="$IMMICH_BASE_URL/api/search/metadata"
interval=(${SECONDS_WAIT:-15} * 1000)


sendHooks() {
	RESP=$(curl -sS "$STAT_URL" -H "x-api-key: $IMMICH_API_KEY")

	# extract stats via jq
	images=$(jq -r '.images // 0' <<<"$RESP")
	videos=$(jq -r '.videos // 0' <<<"$RESP")
	total=$(jq -r '.total  // 0' <<<"$RESP")

	# read
	if [ ! -f "$STATS_FILE" ]; then
		echo "file does not exist, creating it and skipping iteration"
		TOWRITE="{\"images\":$images,\"videos\":$videos,\"total\":$total,\"timestamp\":$(date +%s)}"
		echo "$TOWRITE" > "$STATS_FILE"
		return
	fi

	# extract old values from the stored json file
	imgsOld=$(jq -r '.images     // 0' "$STATS_FILE")
	vidsOld=$(jq -r '.videos     // 0' "$STATS_FILE")
	totalOld=$(jq -r '.total     // 0' "$STATS_FILE")
	tsOld=$(jq -r '.timestamp   // 0' "$STATS_FILE")

	if [ "$totalOld" -eq "$total" ]; then
		return
	fi

	TOWRITE="{\"images\":$images,\"videos\":$videos, \"total\": $total,\"timestamp\":$(date +%s)}"

	echo $TOWRITE > $STATS_FILE

	NEW_TS="$(date -u -d "@$(date +%s)" +"%Y-%m-%dT%H:%M:%SZ")"
	PAYLOAD="{\"createdAfter\":\"$NEW_TS\",\"page\":1,\"size\":50,\"order\":\"desc\"}"

	RESP=$(curl -sS "$SEARCH_URL" \
		-X POST \
		-H "x-api-key: $IMMICH_API_KEY" \
		-H "Content-Type: application/json" \
		-H "Accept: application/json" \
		-d "$PAYLOAD")

	PAYLOAD=$(jq -c '[.assets.items[] | {id, type}]' <<<"$RESP")

	for hook in $HOOKS; do
		url=$(jq -r '.url' <<<"$hook")
		key=$(jq -r '.key' <<<"$hook")

		curl -X POST \
			-H "authorization: bearer $key" \
			-H "content-type: application/json" \
			-d "$PAYLOAD" \
			"$url" \
			|| echo "post to $url failed, continuing"
	done
}


while true; do
    sendHooks
    sleep "$interval"
done