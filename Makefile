prefix ?= /usr/local
bindir = $(prefix)/bin

build:
	swift build -c release --disable-sandbox

install: build
	install ".build/release/sskeys" "$(bindir)"

uninstall:
	rm -rf "$(bindir)/sskeys"

clean:
	rm -rf .swiftspm
	rm -rf .build
	rm -rf *.xcodeproj

project:
	swift package generate-xcodeproj
	open *.xcodeproj

.PHONY: build install uninstall clean