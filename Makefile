.PHONY: clean check-amtool test-slack test-pagerduty

clean:
	@read -p "Are you sure you want to delete all .terraform.lock.hcl files and .terraform directories? (y/n) " confirm; \
	if [ "$$confirm" = "y" ]; then \
		find . -name '.terraform.lock.hcl' -exec rm -f {} \; && \
		find . -type d -name '.terraform' -exec rm -rf {} +; \
	else \
		echo "Clean operation aborted."; \
	fi

check-amtool:
	@which amtool > /dev/null || echo "amtool is not installed. Please install it from https://github.com/prometheus/alertmanager/releases"

test-slack: check-amtool
	@echo "\n\nTesting slack title and text...\n\n"
	amtool template render --template.glob='tests/alertmanager/*.tmpl' --template.glob='files/helm/prometheus/alertmanager/templates/*.tmpl' --template.data='tests/alertmanager/_test.json'  --template.text='{{ template "slack.title" . }}{{ "\n" }}{{ template "slack.text" . }}'

test-pagerduty: check-amtool
	@echo "\n\nTesting pagerduty title and details...\n\n"
	amtool template render --template.glob='tests/alertmanager/*.tmpl' --template.glob='files/helm/prometheus/alertmanager/templates/*.tmpl' --template.data='tests/alertmanager/_test.json'  --template.text='{{ template "pagerduty.title" . }}{{ "\n" }}{{ template "pagerduty.details" . }}'

test-alertmanager-templates: test-slack test-pagerduty
	@echo "\n\nAll templates passed."
