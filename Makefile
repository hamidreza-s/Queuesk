all: build

build: deps
	rebar compile

deps:
	rebar get-deps

clean:
	rm -rf ./Mnesia.nonode@nohost
	rm -rf ./ebin/*

live: build
	erl -pa ebin deps/*/ebin -s queuesk
