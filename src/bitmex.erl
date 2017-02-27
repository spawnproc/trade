-module(bitmex).
-behaviour(rest).
-behaviour(websocket_client_handler).
-include("bitmex.hrl").
-include("core.hrl").
-compile(export_all).
-export([init/2,websocket_handle/3,websocket_info/3,websocket_terminate/3]).
-compile({parse_transform, rest}).
-rest_record(bitmex).

name("XBTUSD")  -> btc_usd;
name(X)         -> [].

route(#bitmex{table="trade",action=Ac,data=D}=B,M) ->
    lists:foldl(fun (X,A) -> action(trade,B,Ac,X,M) end, [], [X||X<-D]);

route(#bitmex{table=T,action=Ac,data=D}=B,M) ->
    lists:foldl(fun (X,A) -> action(order,B,Ac,X,M) end, [], [X||X<-D]).

action(Stream,T,A,#sym{symbol=Sym,side=Side,size=S,price=P,timestamp=TS,trdMatchID=OID},Debug) ->
    trade:trace(?MODULE,[Stream,A,Sym,S,P,Side,Debug,TS,OID]).

trade(Sym,A,"Buy",S,P,M,O)    -> [trade,P,trade:nn(S)];
trade(Sym,A,"Sell",S,P,M,O)   -> [trade,P,-trade:nn(S)].

order(Sym,_,_,_,[],M,O)       -> book:del(#tick{sym=name(Sym),id=O});
order(Sym,"delete",_,S,P,M,O) -> book:del(#tick{sym=name(Sym),id=O,price=P});
order(Sym,_,"Buy",S,P,M,O)    -> book:add(#tick{sym=name(Sym),id=O,price=P,size=  trade:nn(S), side=bid});
order(Sym,_,"Sell",S,P,M,O)   -> book:add(#tick{sym=name(Sym),id=O,price=P,size=- trade:nn(S), side=ask}).

state(State)      -> State + 1.
print(Msg)        -> route(post(jsone:decode(Msg),#ctx{}),Msg).
instance()        -> #bitmex{}.
post({Data}, Ctx) -> Bitmex=from_json(Data, instance()),
                     Bitmex#bitmex{data=[ sym:post(I, Ctx) || I <- Bitmex#bitmex.data]}.
subscribe()       -> websocket_client:cast(self(), {text, jsone:encode([{op,subscribe},{args,['trade:XBT24H',
                                                                                              'orderBook10:XBT24H',
                                                                                              'instrument:XBT24H']}])}).

init([], _)                               -> subscribe(), {ok, 1, 100}.
websocket_info(start, _, State)           -> {reply, <<>>, State}.
websocket_terminate(_, _, _)              -> kvs:info(?MODULE,"terminated",[]), ok.
websocket_handle({pong, _}, _, State)     -> {ok, State};
websocket_handle({text, Msg}, _, State)   -> print(Msg), {ok, state(State)};
websocket_handle(Msg, _Conn, State)       -> print(Msg), {noreply, state(State)}.

