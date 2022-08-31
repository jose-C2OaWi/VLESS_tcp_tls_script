# V2Ray, VLESS+tcp+tls（自签名证书）带回落配置的一键安装脚本

> To view the English Introduction, please visit [README.en-US.md](README.en-US.md)

## 准备工作

* [V2Ray](https://www.v2fly.com/)官方网站提供关于V2Ray和TLS的一些基本知识。
* 了解 Linux 基础以及计算机网络部分知识和某些常用文本编辑器的操作（如vim, nano等）

## 安装/更新

```
wget -N --no-check-certificate -q -O install.sh "https://raw.githubusercontent.com/jose-C2OaWi/VLESS_tcp_tls_script/master/install.sh" && chmod +x install.sh && bash install.sh 
```

## V2Ray 简介

* V2Ray是一个优秀的开源网络代理工具，可用于（规避审查）访问互联网。它具有跨平台、多协议支持和高度可定制化的众多特性。
* V2Ray（以及 Shadowsocks 等许多代理工具）的基本理念是在服务器（通常是未被封锁的虚拟主机）上架设程序，使得客户端可以通过服务器连接到未受审查的互联网。

## 为什么使用 VLESS+TCP+TLS（自签名证书）？

* VLESS 是一个轻量传输协议。VLESS 被设计工作在正确配置的加密 TLS 隧道中，因为它没有自带加密。 与VMess 相比，这样减少了加密和解密的开销。
* 常见的VMess+WebSocket+TLS+Web 或VMess+H2+TLS+Web 的配置使用网页服务器（nginx, caddy等）转发流量。由于这些软件并不是专门为此设计的，这样的配置可能不是最有效率的配置。
* Trojan 运用类似的理念。它运用TLS加密并使用本地的网页服务器作为伪装。
* 然而，所有这些方法都需要一个域名，一个可能并不便宜的域名。这个成本对仅仅用于突破互联网审查而言是否过于昂贵？此外，使用Let's Encrypt 或其他类似的SSL证书申请工具来获取SSL证书用于突破互联网审查也可能对正常的网站带来麻烦。
* 通常而言，单纯使用 WebSocket 会比 TCP 性能[略差](https://guide.v2fly.org/advanced/not_recommend.html)。使用 WebSocket 是因为搭配 Nginx/Caddy/Apache 只能用 WebSocket，使用 TLS 是因为可以流量加密，看起来更像 HTTPS。这是[官方文档](https://guide.v2fly.org/advanced/wss_and_web.html)的说法。
* 自从V2Ray 4.27.2 版本，VLESS 协议设计了fallbacks 数组，能够转发TLS解密后的TCP流量，这意味着V2Ray 能够将流量转发到本地伪装网站，或者将其他H2或WebSocket流量转发到指定地址。

## 相关文件目录

V2Ray 服务端配置： `/usr/local/etc/v2ray/config.json`

自签CA证书文件： `/usr/local/etc/v2ray/cert/v2ray.ca.crt/` 和 `/usr/local/etc/v2ray/cert/v2ray.ca.crt/` 请注意证书文件权限及证书有效期。

## 注意事项

* 目前，该脚本仅在 Ubuntu 20.04.5 LTS (Focal Fossa)上测试通过。预期能在Debian 9+ / Ubuntu 18.04+ 和其他一些发行版上正常工作（也许是CentOS）
* 推荐在纯净环境下使用本脚本。
* 虽然本脚本为一键配置脚本，我们仍然建议你全方面地了解程序的工作流程及原理。
* 在确认本脚本可用前，请不要将本程序应用于生产环境中。

## 致谢

* 本脚本受[wulabing](https://github.com/wulabing/V2Ray_ws-tls_bash_onekey) 和 [misaka-blog](https://github.com/misaka-gh/Xray-script) （原始库已经由于作者个人原因删除了，这只是一个存档。）
* 本脚本依赖[V2Ray 官方安装脚本](https://github.com/v2fly/fhs-install-v2ray)
