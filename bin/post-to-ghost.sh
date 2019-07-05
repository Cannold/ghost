#!/bin/bash

# Admin API key goes here
KEY=$( get-key.pl admin )
#echo $KEY

# Split the key into ID and SECRET
TMPIFS=$IFS
IFS=':' read ID SECRET <<< "$KEY"
IFS=$TMPIFS

# Prepare header and payload
NOW=$(date +'%s')
FIVE_MINS=$(($NOW + 300))
HEADER="{\"alg\": \"HS256\",\"typ\": \"JWT\", \"kid\": \"$ID\"}"
PAYLOAD="{\"iat\":$NOW,\"exp\":$FIVE_MINS,\"aud\": \"/v2/admin/\"}"

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
URL="http://ghost:2368/ghost/api/v2/admin/posts/"

RESULT=$( curl -H "Authorization: Ghost $TOKEN" \
-H "Content-Type: application/json" \
-d '{"posts":[{"title":"Hello world", "html":"<p>My post conent. Work in progress</p>"}]}' \
-X POST $URL)

# switch to this when figuring out why curl POST works but nothing happens
#CONTENT=$( backup-to-ghost.pl )
#RESULT=$( curl -H "Authorization: Ghost $TOKEN" \
#-H "Content-Type: application/json" \
#-d $CONTENT
#-X POST $URL)

echo
echo $RESULT
echo
echo done
