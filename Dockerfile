FROM ruby:2.7.2

WORKDIR /var/app
COPY . .

RUN gem install bundler
RUN bundle install -j4
