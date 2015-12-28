all: build

build: deps
	./rebar compile

deps:
	./rebar get-deps

clean:
	rm -rf ./Mnesia.nonode@nohost
	rm -rf ./ebin/*

test: build
	@mkdir -p ./test/logs
	@exec ct_run \
		-dir ./test \
		-include ./include \
		-pa ./ebin \
		-logdir ./test/logs

debug: build
	erl -pa ebin deps/*/ebin -s queuesk -boot start_sasl

live: build
	erl -pa ebin deps/*/ebin -s queuesk

todo:
	@echo "[+] TODOs in general:"
	@echo "---------------------"
	@cat ./TODO.md
	@echo
	@echo "[+] TODOs in source:"
	@echo "--------------------"
	@grep -ir "@todo" ./src
