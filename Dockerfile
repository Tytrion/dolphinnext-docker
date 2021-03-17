FROM ubuntu:xenial
MAINTAINER Richard J. Acton <racton@uni-koeln.de>

RUN echo "start" && \

# Update
RUN echo "OS package updates" && \
    apt-get update && \
    apt-get -y upgrade && \
    apt-get dist-upgrade

# Web server setup

## Web server package installs
RUN echo "OS package installs" && \
### Install apache, PHP, and supplimentary programs. curl and lynx-cur are for debugging the container.
  DEBIAN_FRONTEND=noninteractive apt-get -y install apache2 \
                    curl mysql-server libreadline-dev libsqlite3-dev libbz2-dev libssl-dev python python-dev \
                    libmysqlclient-dev python-pip git expect default-jre default-jdk \
                    libxml2-dev software-properties-common gdebi-core wget \
                    tree vim libv8-dev subversion g++ gcc gfortran zlib1g-dev libreadline-dev \
                    libx11-dev xorg-dev libbz2-dev liblzma-dev libpcre3-dev libcurl4-openssl-dev \
                    bzip2 ca-certificates libglib2.0-0 libxext6 libsm6 libxrender1 sendmail \
                    mercurial subversion libarchive-dev uuid-dev squashfs-tools build-essential \
                    libgpgme11-dev libseccomp-dev pkg-config &&\


  	apt-get clean &&\
    pip install simple-crypt mysql-connector &&\
    add-apt-repository -y ppa:opencpu/opencpu-2.1 &&\
    LC_ALL=C.UTF-8 apt-add-repository ppa:ondrej/php &&\
    apt-get update &&\
    apt-get -y install php7.2 ssh openssh-server \
    php-pear php7.2-curl php7.2-dev php7.2-gd php7.2-mbstring php7.2-zip php7.2-mysql \ 
    php7.2-xml php7.2-ldap s3cmd

RUN echo "Apache server setup" &&\
## Enable apache mods.
    a2enmod rewrite &&\

## Update the PHP.ini file, enable <? ?> tags and quieten logging.
    sed -i "s/short_open_tag = Off/short_open_tag = On/" /etc/php/7.2/apache2/php.ini &&\
    sed -i "s/error_reporting = .*$/error_reporting = E_ERROR | E_WARNING | E_PARSE/" /etc/php/7.2/apache2/php.ini
 
## Manually set up the apache environment variables
ENV APACHE_RUN_USER www-data
ENV APACHE_RUN_GROUP www-data
ENV APACHE_LOG_DIR /var/log/apache2
ENV APACHE_LOCK_DIR /var/lock/apache2
ENV APACHE_PID_FILE /var/run/apache2.pid

## Update the default apache site with the config we created.
ADD apache-config.conf /etc/apache2/sites-enabled/000-default.conf

RUN echo "ServerName localhost" | tee /etc/apache2/conf-available/fqdn.conf &&\
    a2enconf fqdn &&\

    echo "locale-gen en_US.UTF-8" &&\
    echo "dpkg-reconfigure locales" &&\

    echo "PHPmyadmin" &&\
    find /var/lib/mysql -type f -exec touch {} \; && service mysql start && \ 
    service apache2 start && \
    DEBIAN_FRONTEND=noninteractive apt-get -y install phpmyadmin php-mbstring php-gettext && \ 
    zcat /usr/share/doc/phpmyadmin/examples/create_tables.sql.gz|mysql -uroot 

RUN usermod -d /var/lib/mysql/ mysql &&\

    sed -i "s#// \$cfg\['Servers'\]\[\$i\]\['AllowNoPassword'\] = TRUE;#\$cfg\['Servers'\]\[\$i\]\['AllowNoPassword'\] = TRUE;#g" /etc/phpmyadmin/config.inc.php &&\
    ln -s /etc/phpmyadmin/apache.conf /etc/apache2/conf-enabled/phpmyadmin.conf &&\

    sed -i "s/|\s*\((count(\$analyzed_sql_results\['select_expr'\]\)/| (\1)/g" /usr/share/phpmyadmin/libraries/sql.lib.php &&\

    apt-get -y autoremove &&\

# R markown support
    echo "Rmarkdown support" &&\

## OS package installs
    echo "R OS package installs" &&\
    add-apt-repository ppa:ubuntugis/ubuntugis-unstable &&\
    apt-get update &&\
    gpg --keyserver hkp://keyserver.ubuntu.com:80  --recv-key E084DAB9 &&\
    gpg -a --export E084DAB9 | apt-key add - &&\
    add-apt-repository 'deb https://ftp.ussg.iu.edu/CRAN/bin/linux/ubuntu xenial/' &&\
    apt-get -y install r-base r-base-dev opencpu-server rstudio-server \
    libudunits2-dev pandoc libmariadb-client-lgpl-dev texlive texlive-latex-extra &&\

## R package installs
    echo "R package installs" &&\
    R -e 'install.packages(c("devtools", "knitr", "RCurl", "plotly", "webshot", "rmarkdown"))' &&\
    R -e 'devtools::install_github("umms-biocore/markdownapp")' &&\
    R -e 'webshot::install_phantomjs()' &&\
    mv /root/bin/phantomjs /usr/bin/. &&\

## R opencpu variables

    echo "R opencpu variables" &&\
    sed -i "s|\"rlimit.as\": 4e9|\"rlimit.as\": 12e9|" /etc/opencpu/server.conf &&\
    sed -i "s|\"rlimit.fsize\": 1e9|\"rlimit.fsize\": 8e9|" /etc/opencpu/server.conf &&\
    sed -i "s|\"timelimit.get\": 60|\"timelimit.get\": 900|" /etc/opencpu/server.conf &&\
    sed -i "s|\"timelimit.post\": 90|\"timelimit.post\": 900|" /etc/opencpu/server.conf

# Download based installs

## Define working directory.
RUN echo "Creating data directory"
WORKDIR /data

RUN echo "Installing nextflow" &&\
## Nextflow
    curl -s https://get.nextflow.io | bash  &&\
    mv /data/nextflow /usr/bin/. &&\
    chmod 755 /usr/bin/nextflow &&\
    mkdir /.nextflow &&\
    chmod 777 /.nextflow 

## PHP unit testing
RUN echo "Installing PHP unit testing framework" &&\
    wget https://phar.phpunit.de/phpunit-7.0.2.phar &&\
    chmod +x phpunit-7.0.2.phar &&\
    mv phpunit-7.0.2.phar /usr/local/bin/phpunit 

## Locale
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8

## Dolphinnext
RUN echo "Installing dolphinnext"
ENV GITUSER=UMMS-Biocore
RUN git clone https://github.com/${GITUSER}/dolphinnext.git /var/www/html/dolphinnext

RUN chown -R ${APACHE_RUN_USER}:${APACHE_RUN_GROUP} /var/www/html/dolphinnext

## Create Database
RUN echo "Creating dolphinnext database" &&\
    find /var/lib/mysql -type f -exec touch {} \; && service mysql start && \ 
    mysql -u root -e 'CREATE DATABASE dolphinnext;' && \
    cat /var/www/html/dolphinnext/db/dolphinnext.sql|mysql -uroot dolphinnext && \
    python /var/www/html/dolphinnext/scripts/updateDN.py

## Entrez database access tool setup
RUN echo "Installing entrez direct" &&\
    cd /usr/local/share && wget https://ftp.ncbi.nlm.nih.gov/entrez/entrezdirect/edirect.tar.gz && \
    tar xvfz edirect.tar.gz && \
    rm edirect.tar.gz && \
    cd edirect && ./setup.sh &&\
    mv /usr/local/share/edirect/* /usr/local/sbin/.

## GO
RUN echo "Installing GO" &&\
    DEBIAN_FRONTEND=noninteractive apt-get install -y cryptsetup &&\

    export VERSION=1.13 OS=linux ARCH=amd64 && \
    wget https://dl.google.com/go/go$VERSION.$OS-$ARCH.tar.gz && \
    tar -C /usr/local -xzvf go$VERSION.$OS-$ARCH.tar.gz && \
    rm go$VERSION.$OS-$ARCH.tar.gz && \
    export PATH=$PATH:/usr/local/go/bin && \ 
    export VERSION=3.6.4 && \
    wget https://github.com/sylabs/singularity/releases/download/v${VERSION}/singularity-${VERSION}.tar.gz && \
    tar -xzf singularity-${VERSION}.tar.gz && \
    cd singularity && ./mconfig && make -C ./builddir && make -C ./builddir install

ADD bin /usr/local/bin


# Downloading gcloud package
RUN curl https://dl.google.com/dl/cloudsdk/release/google-cloud-sdk.tar.gz > /tmp/google-cloud-sdk.tar.gz &&\
    mkdir -p /usr/local/gcloud \
  && tar -C /usr/local/gcloud -xvf /tmp/google-cloud-sdk.tar.gz \
  && /usr/local/gcloud/google-cloud-sdk/install.sh
ENV PATH $PATH:/usr/local/gcloud/google-cloud-sdk/bin

RUN echo "DONE!"

