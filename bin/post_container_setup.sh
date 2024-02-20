#!/bin/bash

gpg2 --keyserver hkp://keyserver.ubuntu.com --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB

curl -sSL https://get.rvm.io | bash -s stable

source /etc/profile.d/rvm.sh

# we need to add the user to the rvm group
usermod -a -G rvm root

# add to the user's bash so that rvm is available in the shell
echo 'source /usr/local/rvm/scripts/rvm' >> ~/.bashrc

source ~/.bashrc

# install ruby 3.2.0
rvm install 3.2.0

# set the default ruby version
rvm use 3.2.0 --default

gem update --system 3.5.6

gem install bundler

gem install rails:7.0.8

gem install solargraph
gem install rubocop