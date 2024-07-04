.PHONY: clean

clean:
	@read -p "Are you sure you want to delete all .terraform.lock.hcl files and .terraform directories? (y/n) " confirm; \
	if [ "$$confirm" = "y" ]; then \
		find . -name '.terraform.lock.hcl' -exec rm -f {} \; && \
		find . -type d -name '.terraform' -exec rm -rf {} +; \
	else \
		echo "Clean operation aborted."; \
	fi
