.PHONY: build test app dmg clean

build:
	swift build

test:
	swift test

app:
	./scripts/build-app.sh

dmg: app
	./scripts/make-dmg.sh

clean:
	rm -rf .build dist
