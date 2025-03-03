.PHONY: test lint

test:
	@echo "Running tests..."
	docker run -v ".:/plugin:ro" buildkite/plugin-tester:v4.1.1

lint:
	@echo "Running linter..."
	docker run -v "$(PWD):/plugin:ro" buildkite/plugin-linter:v2.1.0 --id pulumi-oidc