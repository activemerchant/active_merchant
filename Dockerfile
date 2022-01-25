FROM ruby:2.7-alpine

RUN apk update && apk add --no-cache build-base libxml2-dev curl

WORKDIR active_merchant
ADD lib lib
ADD test test
ADD Gemfile .
ADD Gemfile.lock .
ADD activemerchant.gemspec .
ADD deploy.sh .
ADD Rakefile .


RUN gem update --system            \
    && gem install bundler          \
    && bundle install

ADD lib lib