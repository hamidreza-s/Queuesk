all: build

build: deps
	rebar compile

deps:
	rebar get-deps

clean:
	rm -rf ./Mnesia.nonode@nohost
	rm -rf ./ebin/*

debug: build
	erl -pa ebin deps/*/ebin -s queuesk -boot start_sasl

live: build
	erl -pa ebin deps/*/ebin -s queuesk

todo:
	@grep -ir "@todo" ./src
