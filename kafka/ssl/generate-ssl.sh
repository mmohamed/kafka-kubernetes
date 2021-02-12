#!/bin/bash
#Step 1
#Generate server keystore and client keystore
keytool -keystore kafka.server.keystore.jks -alias localhost -validity 365 -genkey -keyalg RSA
keytool -keystore kafka.client.keystore.jks -alias localhost -validity 365 -genkey -keyalg RSA
#Step 2
#Create CA
openssl req -new -x509 -keyout ca-key -out ca-cert -days 365
#Add generated CA to the trust store
keytool -keystore kafka.server.truststore.jks -alias CARoot -import -file ca-cert
keytool -keystore kafka.client.truststore.jks -alias CARoot -import -file ca-cert
#Step 3
#Sign the key store
keytool -keystore kafka.server.keystore.jks -alias localhost -certreq -file cert-file
openssl x509 -req -CA ca-cert -CAkey ca-key -in cert-file -out cert-signed -days 365 -CAcreateserial -passin pass:passcode -extfile ssl.cnf -extensions req_ext
keytool -keystore kafka.server.keystore.jks -alias CARoot -import -file ca-cert
keytool -keystore kafka.server.keystore.jks -alias localhost -import -file cert-signed
#Sign the client keystore
keytool -keystore kafka.client.keystore.jks -alias localhost -certreq -file cert-file-client
openssl x509 -req -CA ca-cert -CAkey ca-key -in cert-file-client -out cert-signed-client -days 365 -CAcreateserial -passin pass:passcode -extfile ssl.cnf -extensions req_ext
keytool -keystore kafka.client.keystore.jks -alias CARoot -import -file ca-cert
keytool -keystore kafka.client.keystore.jks -alias localhost -import -file cert-signed-client