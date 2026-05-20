TEST_EXEC := testrun
BUILD_DIR := ./build

SRCS := $(shell find . -maxdepth 1 -name '*.c3')
EXAMPLES := $(shell find ./examples -name '*.c3' \
			| sort \
			| xargs -I {} sh -c "printf 'build/' && basename -s .c3 {}")

.PHONY: examples
examples: $(EXAMPLES)

$(BUILD_DIR)/%: ./examples/%.c3 $(SRCS)
	c3c compile $^ -o $@ $(CFLAGS)

$(BUILD_DIR)/$(TEST_EXEC): $(SRCS)
	c3c compile-test --suppress-run $(SRCS) -o $@ $(CFLAGS)

.PHONY: clean
clean:
	rm -r ./build

.PHONY: test
test: $(BUILD_DIR)/$(TEST_EXEC)
	$(BUILD_DIR)/$(TEST_EXEC)
