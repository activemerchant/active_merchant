build:
	docker build -t paywith-activemerchant-gem .

release:
	docker run -v $$PWD:/var/gem --rm  -w /var/gem --entrypoint ./scripts/release paywith-activemerchant-gem $$GITHUB_TOKEN