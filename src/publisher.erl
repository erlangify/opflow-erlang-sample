#!/usr/bin/env escript
%%! -pz ./deps/amqp_client ./deps/rabbit_common ./deps/amqp_client/ebin ./deps/rabbit_common/ebin

-include_lib("amqp_client/include/amqp_client.hrl").

main(Argv) ->
    {Severity, Message} = case Argv of
        [] -> {<<"info">>, <<"Hello Opflow!">>};
        [S] -> {list_to_binary(S), <<"Hello Opflow!">>};
        [S | Msg] -> {list_to_binary(S), list_to_binary(string:join(Msg, " "))}
    end,

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
      type = <<"direct">>
    }),

    amqp_channel:cast(Channel,
        #'basic.publish'{
            exchange = <<"opflow-erlang-publisher">>,
            routing_key = Severity},
        #amqp_msg{payload = Message}),
    io:format(" [x] Sent ~p:~p~n", [Severity, Message]),
    ok = amqp_channel:close(Channel),
    ok = amqp_connection:close(Connection),
    ok.
