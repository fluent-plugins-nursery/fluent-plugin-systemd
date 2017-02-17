FROM ubuntu:16.04

RUN apt-get update -q && apt-get install -qy --no-install-recommends \
        build-essential \
        ruby \
        ruby-bundler \
        ruby-dev \
        libsystemd0 \
      && apt-get clean \
      && rm -rf /var/lib/apt/lists/* \
      && truncate -s 0 /var/log/*log

WORKDIR /usr/local/src

COPY Gemfile ./
COPY fluent-plugin-systemd.gemspec ./
RUN bundle install -j4 -r3
COPY . .
RUN bundle exec rake test TESTOPTS="-v"
