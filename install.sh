#!/bin/bash

#fonts color
Green="\033[32m"
Red="\033[31m"
Yellow="\033[33m"
BLUE="\033[36m"
Plain="\033[0m"
red() {
	echo -e "\033[31m\033[01m$1\033[0m"
}

green() {
	echo -e "\033[32m\033[01m$1\033[0m"
}

yellow() {
	echo -e "\033[33m\033[01m$1\033[0m"
}

v2ray_conf_dir="/usr/local/etc/v2ray"

#v2ray_info_dir="$HOME/v2ray"
#v2ray_info_file="$v2ray_info_dir/v2ray_info.inf"
#v2ray_config_file="$v2ray_info_dir/01_vless_tcp_tls_fallback.json"
v2ray_log_dir="/var/log/v2ray"
v2ray_cert_dir="$v2ray_conf_dir/cert"
v2ray_bin_dir="/usr/local/bin/v2ray"
v2ctl_bin_dir="/usr/local/bin/v2ctl"
v2ray_access_log="/var/log/v2ray/access.log"
v2ray_error_log="/var/log/v2ray/error.log"
v2ray_systemd_file="/etc/systemd/system/v2ray.service"

judge() {
    if [[ 0 -eq $? ]]; then
        green "$1 完成 "
        sleep 1
    else
        red "$1 失败"
        exit 1
    fi
}

is_root() {
    if [ 0 == $UID ]; then
        green "当前用户是root用户，进入安装流程 "
        sleep 3
    else
        red "当前用户不是root用户，请切换到root用户后重新执行脚本 "
        exit 1
    fi
}

check_system() {
    source '/etc/os-release'    
    if [[ "${ID}" == "centos" && ${VERSION_ID} -ge 7 ]]; then
        green "当前系统为 Centos ${VERSION_ID} ${VERSION} "
        INS="yum"
    elif [[ "${ID}" == "debian" && ${VERSION_ID} -ge 8 ]]; then
        green "当前系统为 Debian ${VERSION_ID} ${VERSION} "
        INS="apt"
        $INS update
        ## 添加 Nginx apt源
    elif [[ "${ID}" == "ubuntu" && $(echo "${VERSION_ID}" | cut -d '.' -f1) -ge 16 ]]; then
        green "当前系统为 Ubuntu ${VERSION_ID} ${UBUNTU_CODENAME} "
        INS="apt"
        rm /var/lib/dpkg/lock
        dpkg --configure -a
        rm /var/lib/apt/lists/lock
        rm /var/cache/apt/archives/lock
        $INS update
    else
        red "当前系统为 ${ID} ${VERSION_ID} 不在支持的系统列表内，安装中断 "
        exit 1
    fi

    $INS install dbus

    systemctl stop firewalld
    systemctl disable firewalld
    green "firewalld 已关闭 "

    systemctl stop ufw
    systemctl disable ufw
    green "ufw 已关闭 "
}

open_bbr() {
    sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
    sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control = bbr" >>/etc/sysctl.conf
    echo "net.core.default_qdisc = fq" >>/etc/sysctl.conf
    sysctl -p >/dev/null 2>&1
}

v2ray_install() {
    if [[ -d /tmp/v2ray ]]; then
        rm -rf /tmp/v2ray
    fi
    if [[ -d /etc/v2ray ]]; then
        rm -rf /etc/v2ray
    fi
    mkdir -p /tmp/v2ray
    cd /tmp/v2ray || exit
    wget -N --no-check-certificate https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh -O v2ray.sh

    if [[ -f v2ray.sh ]]; then
        # JSONS_PATH='/usr/local/etc/v2ray'
        # multiple json config
        # source v2ray.sh --force
        # we need get the JSONS_PATH variable
        # Variables conflict
        bash v2ray.sh --force
        judge "安装 v2ray"
    else
        red "v2ray 安装文件下载失败，请检查下载地址是否可用 "
        exit 4
    fi
    # 清除临时文件
    rm -rf /tmp/v2ray
}

port_exist_check() {
    if [[ 0 -eq $(lsof -i:"$1" | grep -i -c "listen") ]]; then
        green " $1 端口未被占用 "
        sleep 1
    else
        red " 检测到 $1 端口被占用，以下为 $1 端口占用信息 "
        lsof -i:"$1"
        green " 5s 后将尝试自动 kill 占用进程 "
        sleep 5
        lsof -i:"$1" | awk '{print $2}' | grep -v "PID" | xargs kill -9
        green " kill 完成 "
        sleep 1
    fi
}

get_config() {
    read -p "请输入v2ray监听端口（默认443）：" PORT
    [[ -z "${PORT}" ]] && PORT=443
    if [[ "${PORT:0:1}" == "0" ]]; then
	red "端口不能以0开头"
	exit 1
    fi
    yellow "v2ray端口：$PORT"

    read -p "请输入v2ray回落地址（默认80）：" FALLBACK_DEST
    [[ -z "${FALLBACK_DEST}" ]] && FALLBACK_DEST=80
    if [[ "${FALLBACK_DEST:0:1}" == "0" ]]; then
	red "地址不能以0开头"
	exit 1
    fi
    yellow "v2ray默认回落：$FALLBACK_DEST"
    yellow "如果回落设置为本地端口，请自行设置Web服务器"
    yellow "可以自行在配置文件中添加其他回落"
    #echo $tls_mode
    if [[ "${tls_mode}" == "self" ]]; then
        mkdir -p $v2ray_cert_dir
        read -p "请输入证书域名（自签证书，默认www.apple.com）：" CERT_DOMAIN
        [[ -z "${CERT_DOMAIN}" ]] && CERT_DOMAIN="www.apple.com"        
    else # [["${tls_mode}"=="acme"]]
        get_acme_cert
    fi
    yellow "证书域名(host)：$CERT_DOMAIN"

    read -p "请输入v2ray生成链接描述（默认无描述）" DESCRIPTION
    [[ -z "${DESCRIPTION}" ]] && DESCRIPTION=""
}

get_self_cert() {
    $INS install openssl
    openssl genrsa -out $v2ray_cert_dir/v2ray.ca.self.key 2048
    # 生成CA证书
    openssl req -new -x509 -days 3650 -key $v2ray_cert_dir/v2ray.ca.key -subj "/C=US/O=DigiCert Inc. /CN=DigiCert Local Root CA" -out $v2ray_cert_dir/v2ray.ca.self.crt
    chown -R nobody:nogroup $v2ray_cert_dir
}

#deprecated
get_self_cert_by_v2ctl() {
    local SELF_CA=$(v2ctl cert --ca --expire=87600h)
    SELF_CA=${SELF_CA:1}
    SELF_CA=${SELF_CA%\}*}
    SELF_CA_CERT=${SELF_CA%*"\],"}
    # This two steps are intended to remove two {} brackets
    local SELF_CA_CERT=${SELF_CA%\],*}
    # Get CA CERT and output plain text
    SELF_CA_CERT=${SELF_CA_CERT#*\[}
    SELF_CA_CERT=${SELF_CA_CERT//\"}
    SELF_CA_CERT=${SELF_CA_CERT//\ }
    SELF_CA_CERT=${SELF_CA_CERT//,}
    # write in the file
    cat >$v2ray_cert_dir/v2ray.ca.crt <<-EOF
$SELF_CA_CERT
EOF
    # Get CA Key
    local SELF_CA_KEY=${SELF_CA#*\],}
    SELF_CA_KEY=${SELF_CA_KEY#*\[}
    SELF_CA_KEY=${SELF_CA_KEY%\]*}
    SELF_CA_KEY=${SELF_CA_KEY//\"}
    SELF_CA_KEY=${SELF_CA_KEY//\ }
    SELF_CA_KEY=${SELF_CA_KEY//,}
    # write in the file
    cat >$v2ray_cert_dir/v2ray.ca.key <<-EOF
$SELF_CA_KEY
EOF
    chown -R nobody:nogroup $v2ray_cert_dir
    # chmod 644 $v2ray_cert_dir/v2ray.ca.key
    # The key shouldn't be readable to others
}

v2ray_conf_add() {
	local uuid="$(cat '/proc/sys/kernel/random/uuid')"
	cat >$v2ray_conf_dir/config.json <<-EOF
		{
		  "inbounds": [{
		    "port": $PORT,
		    "protocol": "vless",
		    "settings": {
		      "clients": [
		        {
		          "id": "$uuid",
		          "level": 0
		        }
		      ],
		      "decryption": "none",
		      "fallbacks": [
		          {
		              "dest": "$FALLBACK_DEST"
		          }
		      ]
		    },
		    "streamSettings": {
		        "network": "tcp",
		        "security": "tls",
		        "tlsSettings": {
		            "serverName": "$CERT_DOMAIN",
		            "certificates": [
		                {
                                   "usage": "issue",
                                   "cert_type": "$tls_mode",
                                   "certificateFile": "$v2ray_cert_dir/v2ray.ca.crt",
                                   "keyFile": "$v2ray_cert_dir/v2ray.ca.key"
		                }
		            ]
		        }
		    }
		  }],
                  "outbounds": [{
	              "protocol": "freedom",
	              "settings": {}
	            },{
	              "protocol": "blackhole",
	              "settings": {},
	              "tag": "blocked"
	            }],
                  "log": {
                         "loglevel": "warning",
                         "error": "/var/log/v2ray/error.log",
                         "access": "/var/log/v2ray/access.log"
                  }
		}
EOF
        chown -R nobody:nogroup $v2ray_log_dir
}

get_info() {
    CONFIG_FILE="$v2ray_conf_dir/config.json"
    uid=$(grep id $CONFIG_FILE | head -n1 | cut -d: -f2 | tr -d \",' ')
    network="tcp"
    sni=$(grep serverName $CONFIG_FILE | cut -d: -f2 | tr -d \",' ')
    security="tls"
    encryption="none"
    remote_port=$(grep port $CONFIG_FILE | cut -d: -f2 | tr -d \",' ')
    cert_type=$(grep cert_type $CONFIG_FILE | cut -d: -f2 | tr -d \",' ')
    cert_path=$(grep certificateFile $CONFIG_FILE | cut -d: -f2 | tr -d \",' ')
    local_ipv4=$(curl -s4m8 https://ip.gs)
    local_ipv6=$(curl -s6m8 https://ip.gs)
    if [[ -z ${local_ipv4} && -n ${local_ipv6} ]]; then
        ip=$local_ipv6
    else
        ip=$local_ipv4
    fi        
    if [[ "$cert_type" == "self" ]]; then
        remote_host=$ip
    else
        remote_host=$sni
    fi
}

VLESS_link_share() {
    link="${uid}@${remote_host}:${remote_port}?sni=${sni}&security=${security}&type=${network}&encryption=${encryption}#${DESCRIPTION}"
    link="vless://"$link
	echo -e "   ${BLUE}IP(address): ${PLAIN} ${RED}${remote_host}${PLAIN}"
	echo -e "   ${BLUE}端口(port)：${PLAIN}${RED}${remote_port}${PLAIN}"
	echo -e "   ${BLUE}id(uuid)：${PLAIN}${RED}${uid}${PLAIN}"
	echo -e "   ${BLUE}加密方式(security)：${PLAIN} ${RED}${security}${PLAIN}"
	echo -e "   ${BLUE}传输协议(network)：${PLAIN} ${RED}${network}${PLAIN}"
        echo -e "   ${BLUE}证书域名(sni)：${PLAIN}${RED}${sni}${PLAIN}"
	echo -e "   ${BLUE}VLESS链接:${PLAIN} $RED${link}$PLAIN"
        green "   由于官方目前不支持VLESS分享，若链接无效，请手动输入相关信息"
        if [[ "$cert_type" == "self" ]]; then
            echo -e " 自签名证书，请将证书填入或导入客户端 "
            cat $cert_path
        fi
}
start_process_systemd() {
    systemctl daemon-reload
    #chown -R nobody:nogroup /var/log/v2ray
    systemctl restart v2ray
    judge "v2ray 启动"
}

enable_process_systemd() {
    systemctl enable v2ray
    judge "设置 v2ray 开机自启"
}

stop_process_systemd() {
    systemctl stop v2ray
}

show_access_log() {
    [ -f ${v2ray_access_log} ] && tail -f ${v2ray_access_log} || red "访问文件不存在"
}

show_error_log() {
    [ -f ${v2ray_error_log} ] && tail -f ${v2ray_error_log} || red "错误日志文件不存在"
}
install_v2ray_tcp_tls_acme() {
    is_root
    check_system
    open_bbr
    get_config
    v2ray_install
    port_exist_check "${port}"
    v2ray_conf_add
    get_info
    VLESS_link_share    
    start_process_systemd
    enable_process_systemd
}


install_v2ray_tcp_tls() {
    is_root
    check_system
    open_bbr
    get_config
    v2ray_install
    get_self_cert
    port_exist_check "${PORT}"
    v2ray_conf_add
    get_info
    VLESS_link_share
    #show_information
    start_process_systemd
    enable_process_systemd
}

uninstall() {
    wget -N --no-check-certificate https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh -O v2ray.sh
    bash v2ray.sh --remove

    green " 是否删除v2ray自签名证书文件[Y/N]?"
    read -r delete_config
    case $delete_config in
    [yY][eE][sS] | [yY])
            rm -r $v2ray_cert_dir/*
            ;;
    *) ;;
    
    esac

    systemctl daemon-reload
    green " 已卸载 "
}

menu() {
    #update_sh
    echo -e "\t v2ray 安装管理脚本 "
    echo -e "\t---authored by jose-C2OaWi---"
    echo -e "\thttps://github.com/jose-C2OaWi\n"
    echo -e "—————————————— 安装向导 ——————————————"""
    echo -e "${Green}0.${Plain}  升级 脚本"
    echo -e "${Green}1.${Plain}  安装 v2ray (tcp+tls) acme证书（开发中） "    
    echo -e "${Green}2.${Plain}  安装 v2ray (tcp+tls) 自签证书 "
    echo -e "${Green}3.${Plain}  升级 v2ray core"
    echo -e "—————————————— 查看信息 ——————————————"
    echo -e "${Green}4.${Plain}  查看 实时访问日志"
    echo -e "${Green}5.${Plain}  查看 实时错误日志"
    echo -e "${Green}6.${Plain}  查看 v2ray 配置信息"
    echo -e "—————————————— 其他选项 ——————————————"
    echo -e "${Green}7.${Plain} 卸载 v2ray"
    echo -e "${Green}8.${Plain} 退出 \n"

    read -rp "请输入数字：" menu_num
    case $menu_num in
    0)
        update_sh
        ;;
    1)
        tls_mode="acme"
        install_v2ray_tcp_tls_acme
        ;;
    2)
        tls_mode="self"
        install_v2ray_tcp_tls
        ;;
    3)
        bash <(curl -L -s https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)
        ;;
    4)
        show_access_log
        ;;
    5)
        show_error_log
        ;;
    6)
        get_info
        VLESS_link_share
        ;;
    7)
        source '/etc/os-release'
        uninstall
        ;;
    8)
        exit 0
        ;;
    
    *)
        red "请输入正确的数字"
        ;;
    esac
}    

menu
