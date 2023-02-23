build:
	docker-compose build gem

bash:
	docker-compose run --rm gem bash

brakeman:
	docker-compose run --rm gem bundle exec brakeman --no-pager --path lib --force -i config/brakeman.ignore

bundle-audit:
	docker-compose run --rm gem bundle exec bundle audit check --update

release:
	docker run -v $$PWD:/var/gem --rm  -w /var/gem --entrypoint ./scripts/release paywith-activemerchant-gem $$GITHUB_TOKEN

rubocop:
	docker-compose run --rm gem rubocop
