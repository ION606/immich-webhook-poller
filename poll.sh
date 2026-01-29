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

writeToFile() {
		T=$(date +%s)

		if [ $LOGGING ]; then
			echo "updated counts at $(date -u -d "@$T" +"%Y-%m-%dT%H:%M:%SZ")"
		fi

		TOWRITE="{\"images\":$1,\"videos\":$2,\"total\":$3,\"timestamp\":$T}"
		echo "$TOWRITE" > "$STATS_FILE"
}

sendHooks() {
	RESP=$(curl -sS "$STAT_URL" -H "x-api-key: $IMMICH_API_KEY")

	# extract stats via jq
	images=$(jq -r '.images // 0' <<<"$RESP")
	videos=$(jq -r '.videos // 0' <<<"$RESP")
	total=$(jq -r '.total  // 0' <<<"$RESP")

	# read
	if [ ! -f "$STATS_FILE" ]; then
		echo "file does not exist, creating it and skipping iteration"
		return $(writeToFile "$images" "$videos" "$total")
	fi

	# extract old values from the stored json file
	imgsOld=$(jq -r '.images     // 0' "$STATS_FILE")
	vidsOld=$(jq -r '.videos     // 0' "$STATS_FILE")
	totalOld=$(jq -r '.total     // 0' "$STATS_FILE")
	tsOld=$(jq -r '.timestamp   // 0' "$STATS_FILE")

	if [ "$totalOld" -eq "$total" ]; then
		# do not update timestamp
		return
	elif [ "$totalOld" -gt "$total" ]; then
		# a photo was deleted, adjust so new one isn't skipped
		return $(writeToFile "$images" "$videos" "$total")
	fi

	writeToFile "$images" "$videos" "$total"

	NEW_TS="$(date -u -d "@$tsOld" +"%Y-%m-%dT%H:%M:%SZ")"
	PAYLOAD="{\"createdAfter\":\"$NEW_TS\",\"page\":1,\"size\":50,\"order\":\"desc\"}"

	RESP=$(curl -sS "$SEARCH_URL" \
		-X POST \
		-H "x-api-key: $IMMICH_API_KEY" \
		-H "Content-Type: application/json" \
		-H "Accept: application/json" \
		-d "$PAYLOAD")

	PAYLOAD=$(jq -c '[.assets.items[] | {id, type}]' <<<"$RESP")

	if [ "$(jq 'length' <<<"$PAYLOAD")" -eq 0 ]; then
		return;
	fi

	for hook in $HOOKS; do
		url=$(jq -r '.url' <<<"$hook")
		key=$(jq -r '.key' <<<"$hook")

		timeout 12s curl -sS --show-error \
			--connect-timeout 5 -m 10 --fail \
			-X POST \
			-H "authorization: bearer $key" \
			-H "content-type: application/json" \
			-d "$PAYLOAD" \
			"$url" \
			|| echo "post to $url failed (exit:$?) -- continuing"
	done
}


while true; do
    sendHooks
    sleep "$interval"
done