#!/bin/bash

# Admin API key goes here
#KEY=$( docker-compose run --rm app perl /app/bin/get-key.pl admin 2>/dev/null )
KEY="5d68ca8ae6f5f70038f2d34d:62353045408222ea9a23fd24824e4715af21d059b8431d95e37e5145ab810af6"

# Split the key into ID and SECRET
TMPIFS=$IFS
IFS=':' read ID SECRET <<< "$KEY"
IFS=$TMPIFS

# Prepare header and payload
NOW=$(date +'%s')
THIRTY_MINS=$(($NOW + 30 * 60))
HEADER="{\"alg\": \"HS256\",\"typ\": \"JWT\", \"kid\": \"$ID\"}"
PAYLOAD="{\"iat\":$NOW,\"exp\":$THIRTY_MINS,\"aud\": \"/v2/admin/\"}"

# Helper function for perfoming base64 URL encoding
base64_url_encode() {
    declare input=${1:-$(</dev/stdin)}
    # Use `tr` to URL encode the output from base64.
    printf '%s' "${input}" | base64 | tr -d '=' | tr '+' '-' |  tr '/' '_'
}

# Prepare the token body
HEADER_BASE64=$(base64_url_encode "$HEADER")
PAYLOAD_BASE64=$(base64_url_encode "$PAYLOAD")

HEADER_PAYLOAD="${HEADER_BASE64}.${PAYLOAD_BASE64}"

# Create the signature
SIGNATURE=$(printf '%s' "${HEADER_PAYLOAD}" | openssl dgst -binary -sha256 -mac HMAC -macopt hexkey:$SECRET | base64_url_encode)

# Concat payload and signature into a valid JWT token
TOKEN="${HEADER_PAYLOAD}.${SIGNATURE}"

# Make an authenticated request to create a post
#URL="http://$( hostname -f ):8080/ghost/api/v2/admin/posts/?source=html"
URL="https://lesliecannold.ghost.io/ghost/api/v2/admin/posts/?source=html"

CONTENT=$( docker-compose run --rm app perl /app/bin/backup-to-ghost.pl /app/data/backup.yml )

for ITEM in $( echo $CONTENT |jq -r '.[] | @base64' ); do

    DATA=$( echo $ITEM | base64 --decode )

    TITLE=$( echo "$DATA" | jq -r '.title' )

    echo ${TITLE}

    PARAM=$( printf '{"posts":[%s]}' "$DATA" )

    curl \
        -o /dev/null \
        -s -w "%{http_code}\n" \
        -H "Authorization: Ghost $TOKEN" \
        -H "Content-Type: application/json" \
        -d "$PARAM" \
        -X POST $URL

done
