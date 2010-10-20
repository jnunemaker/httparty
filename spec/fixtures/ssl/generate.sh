#!/bin/sh
set -e

if [ -d "generated" ] ; then
    echo >&2 "error: 'generated' directory already exists.  Delete it first."
    exit 1
fi

mkdir generated

# Generate the CA private key and certificate
openssl req -batch -subj '/CN=INSECURE Test Certificate Authority' -newkey rsa:1024 -new -x509 -days 999999 -keyout generated/ca.key -nodes -out generated/ca.crt

# Create symlinks for ssl_ca_path
c_rehash generated

# Generate the server private key and self-signed certificate
openssl req -batch -subj '/CN=localhost' -newkey rsa:1024 -new -x509 -days 999999 -keyout generated/server.key -nodes -out generated/selfsigned.crt

# Generate certificate signing request with bogus hostname
openssl req -batch -subj '/CN=bogo' -new -days 999999 -key generated/server.key -nodes -out generated/bogushost.csr

# Sign the certificate requests
openssl x509 -CA generated/ca.crt -CAkey generated/ca.key -set_serial 1 -in generated/selfsigned.crt -out generated/server.crt -clrext -extfile openssl-exts.cnf -extensions cert -days 999999
openssl x509 -req -CA generated/ca.crt -CAkey generated/ca.key -set_serial 1 -in generated/bogushost.csr -out generated/bogushost.crt -clrext -extfile openssl-exts.cnf -extensions cert -days 999999

# Remove certificate signing requests
rm -f generated/*.csr

