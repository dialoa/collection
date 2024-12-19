# Settings
SRC_DIR = src
SRC_NAME = collection

#
# Internal variables
#
#
LUACC = luacc
# Find src file and modules
SRC_FILE = $(SRC_DIR)/$(SRC_NAME).lua
define FIND_SRC_MODULES
find $(SRC_DIR) -type f -name "*.lua" -and ! -path "$(SRC_FILE)"
endef
SRC_MODULES_FILES := $(shell $(FIND_SRC_MODULES))
SRC_MODULES := $(SRC_MODULES_FILES:$(SRC_DIR)/%.lua=%)
BUILT_FILE := $(SRC_NAME).lua
#
# Error messages
define ERROR_LUACC_MISSING
[ERROR] LuaCC not found. LuaCC is needed to build the filter from
multiple source files. Available from LuaRocks [1]. You may also
adjust the variable `LUACC` in this Makefile. Otherwise make
your source a single .lua file.

[1] https://luarocks.org/modules/mihacooper/luacc

endef
export ERROR_LUACC_MISSING

## Help
.PHONY: help
help:
	@echo See Makefile for available targets.
	@echo Use subfolder makefiles to run tests.

## 
.PHONY: build
build: $(BUILT_FILE)

ifneq "$(SRC_DIR)" ""
$(BUILT_FILE): $(SRC_FILE) $(SRC_MODULES_FILES)
# If compiling, check that LuaCC is present
	@if [ "$(SRC_MODULES)" != "" ]; then \
		if f! command -v $(LUACC) &> /dev/null ; then \
			echo "$$ERROR_LUACC_MISSING"; \
			exit 1; \
		fi; \
	fi
# Building process. Single shell block to keep the variable.
#   - copy or compile (if there are modules in src fodler)
#	- if created in Quarto ext folder, link
	@if [ "$(SRC_MODULES)" = "" ]; then \
		echo "Copying $(SRC_FILE) to $(BUILT_FILE)"; \
		cp $(SRC_FILE) $(BUILT_FILE); \
	else \
		echo "Compiling $(SRC_FILE) to $(BUILT_FILE)"; \
		$(LUACC) -o $(BUILT_FILE) -i $(SRC_DIR) \
			$(SRC_DIR)/$(SRC_NAME) $(SRC_MODULES); \
	fi
endif

