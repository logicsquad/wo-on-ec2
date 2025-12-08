#!/bin/bash

# This script builds a combination web and application server from
# scratch on an Amazon Linux instance.

#
# Variables
#

EC2_USERNAME=ec2-user
EC2_GROUPNAME=ec2-user
ARTEFACTS_DIR=/home/$EC2_USERNAME/artefacts

EC2_HOME=/home/$EC2_USERNAME

WO_USER=appserver
WO_GROUP=appserveradm
WO_USER_HOME=/home/$WO_USER
WO_APPS_DIR=/opt/WOApplications
WO_WSR_DIR=/opt/WOWebServerResources
WO_DEPLOY_DIR=/opt/WODeployment
WO_LOG_DIR=/var/log/webobjects

HTTPD_MODULES_DIR=/usr/lib64/httpd/modules
HTTPD_MAIN_CONF_DIR=/etc/httpd/conf
HTTPD_EXTRA_CONF_DIR=/etc/httpd/conf.d
CGI_BIN_ALT=Apps

JAVA_INSTALL="yum -y install java-21-amazon-corretto-headless"
JVM_OPTIONS=--add-exports=java.base/sun.security.action=ALL-UNNAMED

JAVA_MONITOR_URL=https://jenkins.wocommunity.org/job/Wonder7/8889/artifact/Root/Roots/JavaMonitor.tar.gz
WOTASKD_URL=https://jenkins.wocommunity.org/job/Wonder7/8889/artifact/Root/Roots/wotaskd.tar.gz

#
# 1. Updates, directories and certificates
#

# Update system
yum -y update

# Create directories
mkdir $ARTEFACTS_DIR

# Install Java
$JAVA_INSTALL

# Add user and group
groupadd $WO_GROUP
useradd -g $WO_GROUP $WO_USER

#
# 2. Download artefacts
#

curl -o $ARTEFACTS_DIR/JavaMonitor.woa.tar.gz $JAVA_MONITOR_URL
curl -o $ARTEFACTS_DIR/wotaskd.woa.tar.gz $WOTASKD_URL

#
# 3. Web server
#

# Install Apache and mod_ssl
yum -y install httpd
yum -y install mod_ssl

# Install the WebObjects adaptor
cp $ARTEFACTS_DIR/mod_WebObjects.so $HTTPD_MODULES_DIR/mod_WebObjects.so
chmod 755 $HTTPD_MODULES_DIR/mod_WebObjects.so
cp $ARTEFACTS_DIR/webobjects.conf $HTTPD_EXTRA_CONF_DIR/webobjects.conf

# Add WO stuff to httpd.conf
cat >> $HTTPD_MAIN_CONF_DIR/httpd.conf << END
Alias /WebObjects "$WO_WSR_DIR/WebObjects"

<Directory "$WO_WSR_DIR/WebObjects">
    Require all granted
</Directory>

<LocationMatch /$CGI_BIN_ALT/WebObjects/.*>
    Require all granted
</LocationMatch>
END

# Apache configuration
cp $ARTEFACTS_DIR/vhosts.conf.proto $HTTPD_EXTRA_CONF_DIR/vhosts.conf.proto
cp $ARTEFACTS_DIR/ssl.conf.proto $HTTPD_EXTRA_CONF_DIR/ssl.conf.proto

if [ -n "$SERVER_NAME" ]
then
    mkdir /var/www/html/$SERVER_NAME
fi

# Boot Apache
systemctl enable httpd.service
systemctl start httpd.service

#
# 4. Application server
#

# Make require dirs
mkdir $WO_APPS_DIR
mkdir $WO_WSR_DIR
mkdir $WO_WSR_DIR/WebObjects
mkdir $WO_DEPLOY_DIR
mkdir $WO_DEPLOY_DIR/Configuration
mkdir $WO_LOG_DIR

cp $ARTEFACTS_DIR/SiteConfig.xml $WO_DEPLOY_DIR/Configuration/SiteConfig.xml

# Get fully-embedded JavaMonitor and wotaskd
cp $ARTEFACTS_DIR/JavaMonitor.woa.tar.gz $WO_DEPLOY_DIR
tar -zxf $WO_DEPLOY_DIR/JavaMonitor.woa.tar.gz -C $WO_DEPLOY_DIR/
rm $WO_DEPLOY_DIR/JavaMonitor.woa.tar.gz
cp $ARTEFACTS_DIR/wotaskd.woa.tar.gz $WO_DEPLOY_DIR
tar -zxf $WO_DEPLOY_DIR/wotaskd.woa.tar.gz -C $WO_DEPLOY_DIR/
rm $WO_DEPLOY_DIR/wotaskd.woa.tar.gz

# Modify JavaMonitor and wotaskd properties to use our custom layout
cat >> $WO_DEPLOY_DIR/JavaMonitor.woa/Contents/Resources/Properties << END


WODeploymentConfigurationDirectory=$WO_DEPLOY_DIR/Configuration
WOLocalRootDirectory=/opt
END
cat >> $WO_DEPLOY_DIR/wotaskd.woa/Contents/Resources/Properties << END


WODeploymentConfigurationDirectory=$WO_DEPLOY_DIR/Configuration
WOLocalRootDirectory=/opt
END

# Fix user and group
chown -R $WO_USER:$WO_GROUP $WO_APPS_DIR
chown -R $WO_USER:$WO_GROUP $WO_WSR_DIR
chown -R $WO_USER:$WO_GROUP $WO_DEPLOY_DIR
chown -R $WO_USER:$WO_GROUP $WO_LOG_DIR

# Fix permissions
chmod 750 $WO_DEPLOY_DIR/JavaMonitor.woa/JavaMonitor
chmod 750 $WO_DEPLOY_DIR/wotaskd.woa/Contents/Resources/SpawnOfWotaskd.sh
chmod 750 $WO_DEPLOY_DIR/wotaskd.woa/wotaskd

# Add JVM options
if [ -n $JVM_OPTIONS ]
then
   sed -i "/# JVMOptions.*/c\# JVMOptions       == $JVM_OPTIONS" $WO_DEPLOY_DIR/JavaMonitor.woa/Contents/UNIX/UNIXClassPath.txt
   sed -i "/# JVMOptions.*/c\# JVMOptions       == $JVM_OPTIONS" $WO_DEPLOY_DIR/wotaskd.woa/Contents/UNIX/UNIXClassPath.txt
fi

# Set required environment variables
touch /home/$WO_USER/.bash_profile
cat >> /home/$WO_USER/.bash_profile << END
NEXT_ROOT=/opt; export NEXT_ROOT
WOROOT=/opt; export WOROOT
END

# Add a boot script for WO Deployment
cp $ARTEFACTS_DIR/webobjects.initd /etc/init.d/webobjects

# Fix the permissions
chmod 755 /etc/init.d/webobjects

# Add the service and switch it on
chkconfig --add webobjects
chkconfig webobjects on

# Boot the WO deployment tools
/etc/init.d/webobjects start

#
# 5. Clean up
#

rm -r $ARTEFACTS_DIR
# Delete self
rm `basename $0`
