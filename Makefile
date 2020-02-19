prefix ?= /usr/local
bindir = $(prefix)/bin
libdir = $(prefix)/lib

build:
	swift build -c release --disable-sandbox

install: build
	install ".build/release/SecretsSwift" "$(bindir)"

uninstall:
	rm -rf "$(bindir)/SecretsSwift"

clean:
	rm -rf .build

.PHONY: build install uninstall clean