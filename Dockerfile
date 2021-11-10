FROM ruby:2.7.2

ARG GITHUB_TOKEN
ARG GITHUB_USERNAME
ENV BUNDLE_RUBYGEMS__PKG__GITHUB__COM=$GITHUB_USERNAME:$GITHUB_TOKEN

WORKDIR /var/app
COPY . .

RUN gem install bundler -v 2.1.4 && \
    bundle config set https://rubygems.pkg.github.com/paywith $GITHUB_USERNAME:$GITHUB_TOKEN && \
    bundle install -j$(nproc)
