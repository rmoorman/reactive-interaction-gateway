#!/bin/bash -xe

# Based on https://raw.githubusercontent.com/klarna/brod/master/scripts/generate-certificates.sh (Apache-2.0)

HOST="*."
DAYS=36500
PASS="test1234"

CUR_DIR="$(pwd)"
CERTS_DIR="${CUR_DIR}/certs"
PROJ_DIR="${CUR_DIR}/.."
RIG_OUTBOUND_GATEWAY_PRIV_DIR="${PROJ_DIR}/apps/rig_outbound_gateway/priv"


rm -f "${CERTS_DIR}"/*.{jks,p12,crt,csr,key,srl}
mkdir -p "${CERTS_DIR}"
cd "${CERTS_DIR}"

# Generate self-signed server and client certificates
## generate CA
openssl req -new -x509 -keyout ca.key -out ca.crt -days $DAYS -nodes -subj "/C=AT/ST=Vienna/L=Vienna/O=RIG/OU=test/CN=$HOST"

## generate server certificate request
openssl req -newkey rsa:2048 -sha256 -keyout server.key -out server.csr -days $DAYS -nodes -subj "/C=AT/ST=Vienna/L=Vienna/O=RIG/OU=test/CN=$HOST"

## sign server certificate
openssl x509 -req -CA ca.crt -CAkey ca.key -in server.csr -out server.crt -days $DAYS -CAcreateserial

## generate client certificate request
openssl req -newkey rsa:2048 -sha256 -passout pass:$PASS -keyout client.key -out client.csr -days $DAYS -subj "/C=AT/ST=Vienna/L=Vienna/O=RIG/OU=test/CN=$HOST"

## sign client certificate
openssl x509 -req -CA ca.crt -CAkey ca.key -in client.csr -out client.crt -days $DAYS -CAserial ca.srl

# Convert self-signed certificate to PKCS#12 format
openssl pkcs12 -export -name $HOST -in server.crt -inkey server.key -out server.p12 -CAfile ca.crt -passout pass:$PASS

# Import PKCS#12 into a java keystore
keytool -importkeystore -destkeystore server.jks -srckeystore server.p12 -srcstoretype pkcs12 -alias $HOST -srcstorepass $PASS -deststorepass $PASS

# Import CA into java truststore
keytool -keystore truststore.jks -alias CARoot -importcert -file ca.crt -storepass $PASS -noprompt

# Copy CA and client certificates to :rig_outbound_gateway's priv dir
cp ca.crt "${RIG_OUTBOUND_GATEWAY_PRIV_DIR}"
cp client.crt "${RIG_OUTBOUND_GATEWAY_PRIV_DIR}"
cp client.key "${RIG_OUTBOUND_GATEWAY_PRIV_DIR}"
