#!/bin/bash

ROLES_DETAIL=()

analyze_ssh() {
    local since="24 hours ago"
    if systemctl is-active --quiet ssh || systemctl is-active --quiet sshd; then
        local success=$(journalctl _SYSTEMD_UNIT=ssh.service --since "$since" 2>/dev/null | grep "Accepted password" | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | sort | uniq | wc -l)
        local failed_count=$(journalctl _SYSTEMD_UNIT=ssh.service --since "$since" 2>/dev/null | grep "Failed password" | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | sort | uniq | wc -l)
        local top_failed=$(journalctl _SYSTEMD_UNIT=ssh.service --since "$since" 2>/dev/null | grep "Failed password" | sed -n 's/.*for \(invalid user \)\?\([^ ]*\) from.*/\2/p' | sort | uniq -c | sort -nr | head -n 3 | awk '{print $2"("$1")"}' | xargs | tr ' ' ',')
        local recent_user=$(journalctl _SYSTEMD_UNIT=ssh.service --since "$since" 2>/dev/null | grep "session opened for user" | tail -n 1 | sed -n 's/.*session opened for user \([^ (]*\).*/\1/p')
        ROLES_DETAIL+=("SSH[Success_IPs:${success:-0}, Failed_IPs:${failed_count:-0}, Hedefler:${top_failed:-Yok}, Son_Giriş:${recent_user:-Yok}]")
    fi
}

analyze_web() {
    if systemctl is-active --quiet nginx; then
        local nginx_data=""
        for conf in /etc/nginx/sites-enabled/*; do
            [ -f "$conf" ] || continue
            local domain=$(grep -oP 'server_name\s+\K[^; ]+' "$conf" | head -1)
            [ -z "$domain" ] || [ "$domain" == "_" ] && domain="default_site"
            local log_file=$(grep -oP 'access_log\s+\K[^; ]+' "$conf" | head -1)
            [ -z "$log_file" ] && log_file="/var/log/nginx/access.log"
            if [ -f "$log_file" ]; then
                local sample=$(tail -n 1000 "$log_file" 2>/dev/null)
                local hits=$(echo "$sample" | awk '{print $1}' | sort | uniq | wc -l)
                local e4xx=$(echo "$sample" | awk '$9 >= 400 && $9 < 500' | wc -l)
                local e5xx=$(echo "$sample" | awk '$9 >= 500' | wc -l)
                # for clean format
		nginx_data+="${domain}:H-${hits}_E4-${e4xx}_E5-${e5xx} "
            fi
        done
        [ -n "$nginx_data" ] && ROLES_DETAIL+=("Nginx[${nginx_data% }]")
    fi
    # Apache
    if systemctl is-active --quiet apache2 || systemctl is-active --quiet httpd; then
        local apache_vhosts=$(apache2ctl -S 2>/dev/null | grep "namevhost" | awk '{print $4}' | xargs | tr ' ' ',')
        [ -z "$apache_vhosts" ] && apache_vhosts=$(httpd -S 2>/dev/null | grep "namevhost" | awk '{print $4}' | xargs | tr ' ' ',')
        ROLES_DETAIL+=("Apache[VHosts:${apache_vhosts:-Active}]")
    fi
    # Tomcat
    if systemctl is-active --quiet tomcat*; then
        local tomcat_version=$(/usr/share/tomcat*/bin/version.sh 2>/dev/null | grep "Server number" | cut -d: -f2 | xargs)
        local tomcat_ports=$(ss -tlpn | grep -oE ':[0-9]+' | grep -E ':8080|:8443|:8009' | tr -d ':' | xargs | tr ' ' ',')
        local apps=$(ls /var/lib/tomcat*/webapps 2>/dev/null | xargs | tr ' ' ',')
        ROLES_DETAIL+=("Tomcat[Ver:${tomcat_version:-Detect}, Ports:${tomcat_ports:-8080}, Apps:${apps:-Yok}]")
    fi
}

analyze_docker() {
    if systemctl is-active --quiet docker; then
        local names=$(docker ps --format "{{.Names}}" | xargs | tr ' ' ',')
        local count=$(docker ps -q | wc -l)
        ROLES_DETAIL+=("Docker[Active:${count}, Names:${names:-Yok}]")
    fi
}

analyze_storage() {
    # FTP
    if systemctl is-active --quiet vsftpd || systemctl is-active --quiet proftpd; then
        local users=$(grep -v '^#' /etc/passwd | awk -F: '$3 >= 1000 {print $1}' | xargs | tr ' ' ',')
        local ftp_paths=$(grep -i "local_root" /etc/vsftpd.conf 2>/dev/null | cut -d= -f2)
        if [ -z "$ftp_paths" ]; then
            ftp_paths=$(grep -E "ftp|bimmagaza|testuser" /etc/passwd | head -n 3 | cut -d: -f6 | xargs | tr ' ' ',')
        fi
        ROLES_DETAIL+=("FTP[Users:${users:-Sistem}, Paths:${ftp_paths:-/home}]")
    fi

    # NFS
    if systemctl is-active --quiet nfs-server || systemctl is-active --quiet nfs-kernel-server; then
        local exports=$(exportfs -v | awk '{print $1"->"$2}' | xargs | tr ' ' ',')
        ROLES_DETAIL+=("NFS[Exports:${exports:-Yok}]")
    fi
}

analyze_db() {
    # MariaDB/MySQL
    if systemctl is-active --quiet mariadb || systemctl is-active --quiet mysql; then
        local mysql_info=$(mysql -u root -e "SELECT table_schema AS 'DB', ROUND(SUM(data_length + index_length) / 1024 / 1024, 1) AS 'MB' FROM information_schema.tables GROUP BY table_schema;" 2>/dev/null | grep -v "information_schema\|performance_schema\|sys\|DB" | awk '{print $1"("$2"MB)"}' | xargs | tr ' ' ',')
        ROLES_DETAIL+=("MariaDB[List:${mysql_info:-Erişim Yok}]")
    fi
    # PostgreSQL
    if systemctl is-active --quiet postgresql; then
        local pg_info=$(sudo -u postgres psql -t -A -F ' ' -c "SELECT datname, pg_size_pretty(pg_database_size(datname)) FROM pg_database WHERE datistemplate = false;" 2>/dev/null | awk '{print $1"("$2")"}' | xargs | tr ' ' ',')
        ROLES_DETAIL+=("PostgreSQL[List:${pg_info:-Erişim Yok}]")
    fi
}

analyze_ssh
analyze_web
analyze_docker
analyze_storage
analyze_db

ROLE_STRING=$(printf "%s;" "${ROLES_DETAIL[@]}" | sed 's/;$//')
jq -c -n --arg org "system_info_roles" --arg hn "$(hostname)" --arg data "$ROLE_STRING" '{origin: $org, hostname: $hn, info_data: $data}'

