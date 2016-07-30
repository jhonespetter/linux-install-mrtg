#!/bin/bash
#
#===============================================================================#
#  NOTA DE LICENÇA                                                              #
#                                                                               #
#  Este trabalho esta licenciado sob uma Licença Creative Commons               #
#  Atribuição: Compartilhamento pela mesma Licença 3.0 Brasil. Para ver uma     #
# copia desta licença, visite http://creativecommons.org/licenses/by/3.0/br/    #
# ou envie uma carta para Creative Commons, 171 Second Street, Suite 300,       #
# San Francisco, California 94105, USA.                                         #
# ----------------------------------------------------------------------------  #
#  Autor: Jhones Petter | jhones.petter@gmail.com em 21/04/2016                 #
#  Descrição: Instalacao e configuracao do MRTG no CentOS 7						#
#  Data criação: 31/01/2015                                                     #
#  Versao: 1.0 - (./install_mrtg.sh)                                            #
# ----------------------------------------------------------------------------- #
#
#

os=$(egrep "^NAME|^VERSION" /etc/*release | sed 's/"//g' | cut -d= -f2 | cut -d" " -f1 | head -2 | tr '\n' ' ' | sed 's/ //g')
if [ $os != "CentOS7" ]; then
        echo " 	===========================================	"
		echo " "
		echo " "
		echo " "
		echo "		Esse sistema nao e CentOS7!"
		echo " "
		echo " "
		sleep 10
else

echo " 	===========================================	"
echo " "
echo " "
echo " "
echo "		Sera instalado os pacotes base, iniciar e habilitar servicos, e compilar o MRTG . . ."
echo " "
echo " "
sleep 10

# Instalar pacotes base
yum -y update && yum -y install epel-release && yum -y update && yum -y install net-snmp-utils net-snmp wget httpd vim gd-devel gd zlib libpng && yum -y groupinstall "Ferramentas de Desenvolvimento"

# Inicia e habilita Apache e Snmp
systemctl start snmpd httpd && systemctl enable snmpd httpd

# Baixar pacote MRTG e descompactar
cd /tmp/ && wget http://oss.oetiker.ch/mrtg/pub/mrtg-2.17.4.tar.gz && tar -zxvf mrtg-2.17.4.tar.gz && cd mrtg-2.17.4

# Compila MRTG
./configure && make && make install

echo " 	===========================================	"
echo " "
echo " "
echo " "
echo "		Sera configurado o SNMP e reiniciado o servico . . ."
echo " "
echo " "
sleep 10
# Configura SNMP
cp -Rfv /etc/snmp/snmpd.conf /etc/snmp/snmpd.conf.bkp
cat <<EOF > /etc/snmp/snmpd.conf
com2sec local      localhost       public
com2sec mynetwork  192.168.1.0/24  public
group  grp1 v1     local
group  grp1 v2c    local
group  grp2 v1     mynetwork
group  grp2 v2c    mynetwork
view    systemview    included   .1.3.6.1.2.1.1
view    systemview    included   .1.3.6.1.2.1.25.1.1
access  grp1 ""      any       noauth    exact  all none none
access  grp2 ""      any       noauth    exact  all all none
view all    included  .1                               80
syslocation Linux CentOS7, Local
syscontact Sysadmin <root@localhost>
dontLogTCPWrappersConnects yes
disk /
disk /boot
EOF

systemctl restart snmpd

echo " 	===========================================	"
echo " "
echo " "
echo " "
echo "		Sera criado os diretorios do MRTG e configurado os arquivos CFGs e gerado o INDEX . . ."
echo " "
echo " "
sleep 10
# Cria diretorios Apache e Etc
mkdir /etc/mrtg/ && mkdir /var/www/html/mrtg
chown apache:apache /var/www/html/mrtg && chmod -R 755 /var/www/html/mrtg
systemctl restart httpd

# Gera CFG do MRTG
/usr/local/mrtg-2/bin/cfgmaker --output=/etc/mrtg/mrtg.cfg --global "workdir: /var/www/html/mrtg" -ifref=ip --global 'options[_]: growright,bits' public@localhost

# Configura Server Stats
cat <<EOF > /etc/mrtg/server-stats.cfg
# Define global options
LoadMIBs: /usr/share/snmp/mibs/UCD-SNMP-MIB.txt,/usr/share/snmp/mibs/TCP-MIB.txt
workdir: /var/www/html/mrtg/

# CPU Monitoring
# (Scaled so that the sum of all three values doesn't exceed 100)
#
Target[server.cpu]:ssCpuRawUser.0&ssCpuRawUser.0:public@localhost + ssCpuRawSystem.0&ssCpuRawSystem.0:public@localhost + ssCpuRawNice.0&ssCpuRawNice.0:public@localhost
Title[server.cpu]: Server CPU Load
PageTop[server.cpu]: <H1>CPU Load - System, User and Nice Processes</H1>
MaxBytes[server.cpu]: 100
ShortLegend[server.cpu]: %
YLegend[server.cpu]: CPU Utilization
Legend1[server.cpu]: Current CPU percentage load
LegendI[server.cpu]: Used
LegendO[server.cpu]:
Options[server.cpu]: growright,nopercent
Unscaled[server.cpu]: ymwd

# Memory Monitoring (Total Versus Available Memory)
#
Target[server.memory]: memAvailReal.0&memTotalReal.0:public@localhost
Title[server.memory]: Free Memory
PageTop[server.memory]: <H1>Free Memory</H1>
MaxBytes[server.memory]: 100000000000
ShortLegend[server.memory]: B
YLegend[server.memory]: Bytes
LegendI[server.memory]: Free
LegendO[server.memory]: Total
Legend1[server.memory]: Free memory, not including swap, in bytes
Legend2[server.memory]: Total memory
Options[server.memory]: gauge,growright,nopercent
kMG[server.memory]: k,M,G,T,P,X

# Memory Monitoring (Percentage usage)
#
Title[server.mempercent]: Percentage Free Memory
PageTop[server.mempercent]: <H1>Percentage Free Memory</H1>
Target[server.mempercent]: ( memAvailReal.0&memAvailReal.0:public@localhost ) * 100 / ( memTotalReal.0&memTotalReal.0:public@localhost )
options[server.mempercent]: growright,gauge,transparent,nopercent
Unscaled[server.mempercent]: ymwd
MaxBytes[server.mempercent]: 100
YLegend[server.mempercent]: Memory %
ShortLegend[server.mempercent]: Percent
LegendI[server.mempercent]: Free
LegendO[server.mempercent]: Free
Legend1[server.mempercent]: Percentage Free Memory
Legend2[server.mempercent]: Percentage Free Memory

# Disk
#
Target[server.root]:dskPercent.1&dskPercent.2:public@localhost
RouterUptime[server.root]: public@localhost
MaxBytes[server.root]: 100
Title[server.root]: DISK USAGE
PageTop[server.root]: <H1>DISK / and /boot Usage %</H1>
Unscaled[server.root]: ymwd
ShortLegend[server.root]: %
YLegend[server.root]: DISK Utilization
Legend1[server.root]: Root disk
Legend2[server.root]: /boot disk
Legend3[server.root]:
Legend4[server.root]:
LegendI[server.root]:  Root disk
LegendO[server.root]:  /boot disk
Options[server.root]: growright,gauge,nopercent
EOF

# Gera Index do MRTG
/usr/local/mrtg-2/bin/indexmaker --output=/var/www/html/mrtg/index.html /etc/mrtg/mrtg.cfg /etc/mrtg/server-stats.cfg

echo " 	===========================================	"
echo " "
echo " "
echo " "
echo "		Sera criado o Shell Script de execucao do MRTG . . ."
echo " "
echo " "
sleep 10
# Cria Shell Script para execucao do MRTG
cat <<EOF > /etc/mrtg/mrtg.sh
#!/bin/bash
# Executa MRTG
env LANG=C /usr/local/mrtg-2/bin/mrtg /etc/mrtg/mrtg.cfg --logging /var/log/mrtg.log
env LANG=C /usr/local/mrtg-2/bin/mrtg /etc/mrtg/server-stats.cfg --logging /var/log/mrtg.log
EOF

chmod +x /etc/mrtg/mrtg.sh
/etc/mrtg/mrtg.sh

echo " 	===========================================	"
echo " "
echo " "
echo " "
echo "		Sera configurado o Cron para execucao do MRTG a cada 5 minutos e o Logrotate dos logs do MRTG . . ."
echo " "
echo " "
sleep 10
# Configura Cron para execucao a cada 5 minutos
cat <<EOF > /etc/cron.d/mrtg
# Run the hourly jobs
SHELL=/bin/bash
PATH=/sbin:/bin:/usr/sbin:/usr/bin
MAILTO=root
*/5 * * * * root /etc/mrtg/mrtg.sh
EOF

# Configura Logrotate do Log
cat <<EOF > /etc/logrotate.d/mrtg
/var/log/mrtg.log {
    missingok
    copytruncate
    compress
    size 5M
    weekly
}
EOF

echo " 	===========================================	"
echo " "
echo " "
echo " "
echo "		Acesse: http://ip-servidor/mrtg/"
fi