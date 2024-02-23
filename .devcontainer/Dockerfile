FROM ubuntu:latest

RUN apt-get update

RUN apt-get install -y mysql-client git

RUN apt-get install -y build-essential libpq-dev libmysqlclient-dev curl gnupg2 dirmngr wget

RUN apt-get -y install curl g++ gcc autoconf automake bison libc6-dev libffi-dev libgdbm-dev libncurses5-dev libsqlite3-dev libtool libyaml-dev make pkg-config sqlite3 zlib1g-dev libgmp-dev libreadline-dev libssl-dev

RUN DEBIAN_FRONTEND=noninteractive apt-get install -y tzdata

RUN ln -fs /usr/share/zoneinfo/Africa/Blantyre /etc/localtime && dpkg-reconfigure -f noninteractive tzdata