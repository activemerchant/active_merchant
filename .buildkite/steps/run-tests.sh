#!/usr/bin/env bash

set -euo pipefail

readonly RAILS_VERSIONS=(60 60 60 master)
readonly RUBY_VERSIONS=(2.6.3 2.6.6 2.7 2.7)
readonly RAILS_VERSION=${RAILS_VERSIONS[$BUILDKITE_PARALLEL_JOB]}
readonly RUBY_VERSION=${RUBY_VERSIONS[$BUILDKITE_PARALLEL_JOB]}

echo -e "+++ :llama: Testing with :ruby: ${RUBY_VERSION} | :rails: ${RAILS_VERSION}"

docker run -it --rm -v "$PWD":/usr/src -w /usr/src ruby:${RUBY_VERSION}-slim-stretch sh -c "apt-get -qqy update && \
    apt-get install -qy build-essential git-core ; bundle check --path=vendor/bundle_${RAILS_VERSION} \
    --gemfile gemfiles/Gemfile.rails${RAILS_VERSION} || bundle install --jobs=4 --retry=3 --gemfile gemfiles/Gemfile.rails${RAILS_VERSION} --path=vendor/bundle_${RAILS_VERSION} ; \
    BUNDLE_GEMFILE=gemfiles/Gemfile.rails${RAILS_VERSION} bundle exec rake test:units"
