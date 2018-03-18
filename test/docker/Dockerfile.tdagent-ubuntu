FROM ubuntu:16.04

RUN apt-get update -q \
      && apt-get install -qy --no-install-recommends \
        build-essential \
        curl \
        ca-certificates \
        libsystemd0 \
      && curl https://packages.treasuredata.com/GPG-KEY-td-agent | apt-key add - \
      && echo "deb http://packages.treasuredata.com/3/ubuntu/xenial/ xenial contrib" > /etc/apt/sources.list.d/treasure-data.list \
      && apt-get update \
      && apt-get install -y td-agent \
      && apt-get clean \
      && rm -rf /var/lib/apt/lists/* \
      && truncate -s 0 /var/log/*log

ENV PATH /opt/td-agent/embedded/bin/:$PATH

RUN fluent-gem install bundler
WORKDIR /usr/local/src
COPY Gemfile ./
COPY fluent-plugin-systemd.gemspec ./
RUN bundle check || bundle install
COPY . .
RUN bundle exec rake test TESTOPTS="-v"
