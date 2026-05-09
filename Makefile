# Makefile for gha-arbitrary-repo-timeline.
# Run `make help` to see all available recipes.
#
# Requires GNU Make >= 3.82 for .ONESHELL.
# macOS ships 3.81 (Apple avoids GPLv3): brew install make → use gmake.
ifeq ($(filter oneshell,$(.FEATURES)),)
$(error GNU Make >= 3.82 required. macOS: brew install make, then use gmake)
endif

.SILENT:
.ONESHELL:
.PHONY: setup_dev setup_shellcheck setup_shfmt lint_sh format_sh format_sh_check test validate help
.DEFAULT_GOAL := help


# -- paths --
SH_SOURCES := scripts/*.sh .github/scripts/*.sh
SHFMT_FLAGS := -i 4 -ci


# Detect OS and package manager — use in recipes via $(DETECT_PKG_MGR)
# Sets: PKG_MGR (dnf|apt|pacman|brew|unknown), HOST_OS (linux|darwin), HOST_ARCH
define DETECT_PKG_MGR
HOST_OS=$$(uname -s | tr '[:upper:]' '[:lower:]')
HOST_ARCH=$$(uname -m)
if command -v dnf > /dev/null 2>&1; then PKG_MGR=dnf
elif command -v apt-get > /dev/null 2>&1; then PKG_MGR=apt
elif command -v pacman > /dev/null 2>&1; then PKG_MGR=pacman
elif command -v brew > /dev/null 2>&1; then PKG_MGR=brew
else PKG_MGR=unknown
fi
endef


# MARK: SETUP


setup_dev:  ## Install all local dev tools (bats, shellcheck, shfmt, jq, gh)
	echo "Installing dev tools ..."
	$(MAKE) -s setup_shellcheck
	$(MAKE) -s setup_shfmt
	$(DETECT_PKG_MGR)
	echo "Installing bats, jq, gh ($$PKG_MGR on $$HOST_OS) ..."
	case "$$PKG_MGR" in
		dnf) sudo dnf install -y bats jq gh ;;
		apt) sudo apt-get update -qq && sudo apt-get install -y -qq bats jq gh ;;
		pacman) sudo pacman -S --noconfirm bash-bats jq github-cli ;;
		brew) brew install bats-core jq gh ;;
		*) echo "ERROR: unsupported package manager — install bats, jq, gh manually"; exit 1 ;;
	esac

setup_shellcheck:  ## Install shellcheck (apt / dnf / pacman / brew)
	if command -v shellcheck > /dev/null 2>&1; then
		echo "shellcheck already installed: $$(shellcheck --version | awk '/^version:/ {print $$2}')"
	else
		$(DETECT_PKG_MGR)
		echo "Installing shellcheck ($$PKG_MGR on $$HOST_OS) ..."
		case "$$PKG_MGR" in
			dnf) sudo dnf install -y ShellCheck ;;
			apt) sudo apt-get update -qq && sudo apt-get install -y -qq shellcheck ;;
			pacman) sudo pacman -S --noconfirm shellcheck ;;
			brew) brew install shellcheck ;;
			*) echo "ERROR: unsupported package manager — see https://www.shellcheck.net/"; exit 1 ;;
		esac
	fi

setup_shfmt:  ## Install shfmt (apt / dnf / pacman / brew)
	if command -v shfmt > /dev/null 2>&1; then
		echo "shfmt already installed: $$(shfmt --version)"
	else
		$(DETECT_PKG_MGR)
		echo "Installing shfmt ($$PKG_MGR on $$HOST_OS) ..."
		case "$$PKG_MGR" in
			dnf) sudo dnf install -y shfmt ;;
			apt) sudo apt-get update -qq && sudo apt-get install -y -qq shfmt ;;
			pacman) sudo pacman -S --noconfirm shfmt ;;
			brew) brew install shfmt ;;
			*) echo "ERROR: unsupported package manager — see https://github.com/mvdan/sh"; exit 1 ;;
		esac
	fi


# MARK: QUALITY


lint_sh:  ## Run shellcheck on scripts/ and .github/scripts/
	echo "--- lint_sh"
	shellcheck -e SC1091 $(SH_SOURCES)

format_sh:  ## Format shell scripts in place with shfmt
	echo "--- format_sh"
	shfmt $(SHFMT_FLAGS) -w $(SH_SOURCES)

format_sh_check:  ## Check formatting with shfmt (CI-friendly, non-mutating)
	echo "--- format_sh_check"
	shfmt $(SHFMT_FLAGS) -d $(SH_SOURCES)


# MARK: TEST


test:  ## Run BATS tests
	echo "--- test"
	bats -r tests/

validate:  ## Run lint_sh + format_sh_check + test
	set -e
	$(MAKE) -s lint_sh
	$(MAKE) -s format_sh_check
	$(MAKE) -s test
	echo "=== validate: all passed ==="


# MARK: HELP


help:  ## Show available recipes grouped by section
	@echo "Usage: make [recipe]"
	@echo ""
	@awk '/^# MARK:/ { \
		section = substr($$0, index($$0, ":")+2); \
		printf "\n\033[1m%s\033[0m\n", section \
	} \
	/^[a-zA-Z0-9_-]+:.*?##/ { \
		helpMessage = match($$0, /## (.*)/); \
		if (helpMessage) { \
			recipe = $$1; \
			sub(/:/, "", recipe); \
			printf "  \033[36m%-22s\033[0m %s\n", recipe, substr($$0, RSTART + 3, RLENGTH) \
		} \
	}' $(MAKEFILE_LIST)
