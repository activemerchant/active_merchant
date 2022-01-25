#!/bin/bash
set -xe

[ -z "$GEMFURY_PYPI_PUSH_TOKEN" ] && echo "Gemfury token is missing" && exit 1
[ -z "$PACKAGE_VERSION" ] && echo "Version is missing" && exit 1

gem build activemerchant.gemspec --output activemerchant-$PACKAGE_VERSION.gem

## Deploy
curl -F package=@activemerchant-$PACKAGE_VERSION.gem https://$GEMFURY_PYPI_PUSH_TOKEN@push.fury.io/vgs/

