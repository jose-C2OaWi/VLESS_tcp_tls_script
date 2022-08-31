# V2Ray, vless+tcp+tls self-signed certificate with fallbacks

> Currently the script only support Chinese language.

> 欲查阅简体中文撰写的介绍，请访问：[README.md](README.md)
## Preparations
* [V2Ray](https://www.v2fly.com/), some basic knowledge about V2Ray and tls can be found there.
* Some basic knowledge about Linux, Internet and basic usage of text editor (vim, nano, etc.)

## Installation/Update

```
wget -N --no-check-certificate -q -O install.sh "https://raw.githubusercontent.com/jose-C2OaWi/VLESS_tcp_tls_script/master/install.sh" && chmod +x install.sh && bash install.sh 
```

## V2Ray Introduction

* V2Ray is a free, open-source network proxy tool that be used to access the Internet (to circumvent censorship). It is cross-platform, multi-protocol support with other highly customizable features.
* The basic idea of V2Ray (and many other proxy tool such as Shadowsocks) is to set the program on a server (usually a VPS that is not censored) and client can get access to the unsensored Internet through the server.

## Why VLESS+TCP+TLS with self-signed certificate

* VLESS is light protocol and is designed to operate in correctly configured TLS connections, as it does not provide encryption on its own. Compared to VMess, it saves the cost of encrption and decryption.
* The common configuration of VMess+Websocket+TLS+Web Server or VMess+H2+TLS+Web Server use web servers(nginx, caddy, etc.) to forward the proxied traffic. However, these web servers are not designed for it and may cause low performance.
* Trojan uses the similar idea, it utilizes the TLS encryption and uses a local web server as camouflage.
* However, all these methods require a valid domain name, which can be expensive. What's more, using Let's Encrypt or other tools to acquire SSL for circumventing sensorship may bring trouble to normal website.
* WebSocket is generally [less efficient](https://guide.v2fly.org/en_US/advanced/not_recommend.html) than TCP. Using WebSocket is because Nginx / Caddy / Apache can only use WebSocket and use TLS because it can be encrypted, it obfuscates traffic like HTTPS. This is from the official [document](https://guide.v2fly.org/en_US/advanced/wss_and_web.html). 
* Since V2Ray version 4.27.2, VLESS has fallbacks object to forward traffic after TLS decryption, which means V2Ray can be able to forward the traffic failed  to the camouflage website, or forward other H2 or WebSocket traffic to specific address.

## Directories of relevant files

V2Ray server's configuration： `/usr/local/etc/v2ray/config.json`

self-signed CA certificate： `/usr/local/etc/v2ray/cert/v2ray.ca.crt/` 和 `/usr/local/etc/v2ray/cert/v2ray.ca.crt/` Please note the permission and expiration date of the certificate.

## Notice

* For now the script has only been tested on Ubuntu 20.04.5 LTS (Focal Fossa). It is expected to work on Debian 9+ / Ubuntu 18.04+ and some other distributions (maybe CentOS).
* It is recommended to run this script in brand new environment.
* Although it is a onekey management script, it is still recommended for you to understand the whole process and its mechanism.
* Please do not deploy it in productive environment unless you assure it works.

## Acknowledgements

* This script is inspired by [wulabing](https://github.com/wulabing/V2Ray_ws-tls_bash_onekey) and [misaka-blog](https://github.com/misaka-gh/Xray-script) (The original repository has been removed due to author's personal reason, this is only a archive repository.)
* This script relies on [V2Ray official installlation script](https://github.com/v2fly/fhs-install-v2ray)


