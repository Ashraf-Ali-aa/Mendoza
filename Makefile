prefix ?= /usr/local
bindir = $(prefix)/bin
bin_name = Mendoza

MENDOZA_TEST_LOCATION ?= ./SandboxProject
deps:
	./install_deps.sh

build:
	make deps
	swift build -c release --disable-sandbox

install: build
	install ".build/release/$(bin_name)" "$(bindir)"

uninstall:
	rm -rf "$(bindir)/$(bin_name)"

clean:
	rm -rf .build

rebuild:
	make uninstall build install
	mendoza configuration authentication ${MENDOZA_TEST_LOCATION}/mendoza.json --adminPassword="$(ADMIN_PASS)"

.PHONY: build install uninstall clean
