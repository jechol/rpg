![mix test](https://github.com/jechol/rpg/workflows/mix%20test/badge.svg)
# Rpg (Re-impl of Erlang/OTP pg)

This is re-implementation of Erlang/OTP pg module in Elixir for learning purpose.

Major differences are summarized below.

|                            	| pg                          	| Rpg                      	|
|----------------------------	|-----------------------------	|--------------------------	|
| Language                   	| Erlang                      	| Elixir                   	|
| Component                  	| gen_server + ets (scalable) 	| GenServer (limited)     	|
| Goal                  	    | Performance 	                | Simplicity                |
| Code size (except comment) 	| 349 lines                   	| 215 lines                	|
| Production ready           	| Absolutely                  	| Definitely no            	|