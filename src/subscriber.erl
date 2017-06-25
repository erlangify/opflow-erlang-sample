#!/usr/bin/env escript
%%! -pz ./deps/amqp_client ./deps/rabbit_common ./deps/amqp_client/ebin ./deps/rabbit_common/ebin

-include_lib("amqp_client/include/amqp_client.hrl").

main(Argv) ->
    V_host = os:getenv("OPFLOW_TDD_HOST"),
    V_username = os:getenv("OPFLOW_TDD_USERNAME"),
    V_password = os:getenv("OPFLOW_TDD_PASSWORD"),
    {ok, Connection} = amqp_connection:start(#amqp_params_network{
          host = V_host,
          username = list_to_binary(V_username),
          password = list_to_binary(V_password)
    }),
    {ok, Channel} = amqp_connection:open_channel(Connection),

    amqp_channel:call(Channel, #'exchange.declare'{
            exchange = <<"opflow-erlang-publisher">>,
            type = <<"direct">>}),

    #'queue.declare_ok'{queue = Queue} = 
        amqp_channel:call(Channel, #'queue.declare'{exclusive = true}),

    [
        amqp_channel:call(Channel, #'queue.bind'{
            exchange = <<"opflow-erlang-publisher">>,
            routing_key = list_to_binary(Severity),
            queue = Queue
        }) || Severity <- Argv
    ],

    io:format(" [*] Waiting for messages. To exit press CTRL+C~n"),

    amqp_channel:subscribe(Channel, #'basic.consume'{queue = Queue, no_ack = true}, self()),
    receive
        #'basic.consume_ok'{} -> ok
    end,
    loop(Channel).

loop(Channel) ->
    receive
        {#'basic.deliver'{routing_key = RoutingKey}, #amqp_msg{payload = Body}} ->
            io:format(" [x] ~p:~p~n", [RoutingKey, Body]),
            loop(Channel)
    end.
