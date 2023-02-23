#!/bin/bash

iptables -F
iptables -X

iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

# Адреса, которым доступны все порты
iptables -N ALL_ALLOWED

# Адреса, которым выделяется доступ по требованию. Для этого необходимо удалить первое правило из цепочки
# Вместо этого можно использовать -m recent --name dem_allowed_list --rcheck и править лист через echo, а не iptables
iptables -N DEM_ALLOWED

# Адреса баз данных и контейнеров, которым доступны все порты
# У меня указана подсеть, но можно использовать и iprange
iptables -N DBS_CONTAINERS

# Адреса, которым доступ выдается временно и только к опеределнным портам
iptables -N TMP_ALLOWED

# Порты, с которых можем смотреть в мир :)
iptables -N PORTS_ALLOWED

# Добавляем наши цепочки в основные цепочки
iptables -A INPUT -m comment --comment "Адреса, которым доступны все порты" -j ALL_ALLOWED
iptables -A INPUT -m comment --comment "Адреса, которым выделяется доступ по требованию" -j DEM_ALLOWED
iptables -A INPUT -m comment --comment "Адреса баз данных и контейнеров, которым доступны все порты" -j DBS_CONTAINERS
iptables -A INPUT -m comment --comment "Адреса, которым доступ выдается временно и только к опеределнным портам" -j TMP_ALLOWED
iptables -A INPUT -j LOG --log-prefix "[iptables_input] " --log-level info

iptables -A FORWARD -j LOG --log-prefix "[iptables_forward] " --log-level info

iptables -A OUTPUT -m comment --comment "Порты, с которых можем смотреть в мир" -j PORTS_ALLOWED
iptables -A OUTPUT -j LOG --log-prefix "[iptables_output] " --log-level info

# Конфигурируем кастомные цепочки
iptables -A ALL_ALLOWED -s 151.101.1.69/32 -m comment --comment "Адрес админа" -j ACCEPT

iptables -A DEM_ALLOWED -m comment --comment "Правило возвращающее тред назад при отсутствии требования доступа" -j RETURN
iptables -A DEM_ALLOWED -s 151.101.1.70/32 -m comment --comment "Доступ для клиентского технического специалиста" -j ACCEPT

iptables -A DBS_CONTAINERS -s 151.101.2.0/24 -m comment --comment "Доступ для подсети с контейнерами" -j ACCEPT
iptables -A DBS_CONTAINERS -s 151.101.3.0/24 -m comment --comment "Доступ для подсети с базами данных" -j ACCEPT

iptables -A TMP_ALLOWED -s 151.101.1.71/32 -p tcp -m multiport --dports 22,44 -m time --datestart 2023-02-21 --datestop 2023-02-22 -m comment --comment "Доступ для технического специалиста клиента к 22 и 44 портам" -j ACCEPT

iptables -A PORTS_ALLOWED -p tcp -m multiport --sports 5622,20580 -m comment --comment "Порты, с которых можем смотреть в мир" -j ACCEPT

# Настраиваем редирект логов по файлам
echo ':msg, contains, "[iptables_input] " -/var/log/iptables_input.log' > /etc/rsyslog.d/iptables_input.conf
echo ':msg, contains, "[iptables_forward] " -/var/log/iptables_forward.log' > /etc/rsyslog.d/iptables_forward.conf
echo ':msg, contains, "[iptables_output] " -/var/log/iptables_output.log' > /etc/rsyslog.d/iptables_output.conf

echo '& ~' >> /etc/rsyslog.d/iptables_input.conf
echo '& ~' >> /etc/rsyslog.d/iptables_forward.conf
echo '& ~' >> /etc/rsyslog.d/iptables_output.conf

systemctl restart rsyslog
