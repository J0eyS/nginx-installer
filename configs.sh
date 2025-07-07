#!/bin/bash

prompt "Enter your domain (e.g. example.com): "
read -r domain
domain=${domain,,}

prompt "Use SSL? (y/n): "
read -r use_ssl
use_ssl=${use_ssl,,}

if [[ "$use_ssl" == "y" || "$use_ssl" == "yes" ]]; then
    prompt "Enter your email for Let's Encrypt: "
    read -r email
else
    email=""
fi

export domain use_ssl email
