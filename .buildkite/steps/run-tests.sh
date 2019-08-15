#!/usr/bin/env bash

set -euo pipefail

docker run -it --rm -v "$PWD":/usr/src -w /usr/src ruby:2.3.8-stretch sh -c "bundle ; bundle exec rake test"
