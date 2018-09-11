#!/bin/bash
IP_HOST="192.168.1.106"
IP_MANAGER="192.168.1.84"
USER="skywire"

ssl_install ()
{
    export GOPATH=/home/${USER}/go
    export GOBIN=${GOPATH}/bin

    # Install certutil:
    # "The Certificate Database tool or Certutil is a simple command-line
    #   utility that can create/modify certificate[s] and their key databases."
    #   -Saheetha Shameer [thank you]
    #https://linoxide.com/linux-how-to/mkcert-localhost-ssl-certificates-linux/
    #
#    apt install libnss3-tools

    # Build mkcert [brilliant]
#    /usr/local/go/bin/go get -u github.com/FiloSottile/mkcert
#    cp /home/${USER}/go/bin/mkcert /usr/bin/
#    mkcert -install

#    mkcert -CAROOT

#    mkcert $IP_MANAGER

#    cp "$IP_MANAGER".pem /etc/ssl/certs/
#    cp "$IP_MANAGER"-key.pem /etc/ssl/private/
    # OK up to here

#    apt-get install nginx -y

mkdir -p /etc/nginx/ssl
cd /etc/nginx/ssl
openssl dhparam -out dhparam.pem 4096   # long time; only for master node only

/etc/nginx/conf.d/skywire.conf







}
ssl_install