-module(avz). 
-author('Maxim Sokhatsky').
-compile(export_all).
-include_lib("avz/include/avz.hrl").
-include_lib("n2o/include/n2o.hrl").
-include_lib("kvs/include/metainfo.hrl").

sha(Pass) -> crypto:hmac(wf:config(n2o,hmac,sha256),n2o_secret:secret(),wf:to_binary(Pass)).
update({K,V},P) -> wf:setkey(K,1,case P of undefined -> []; _P -> _P end,{K,V}).

coalesce(X,undefined) -> X;
coalesce(_,Y) -> Y.
merge(A,B) -> list_to_tuple([ coalesce(X,Y) || {X,Y} <- lists:zip(tuple_to_list(A),tuple_to_list(B)) ]).

callbacks(Methods) -> [ M:callback()     || M <- Methods].
sdk(Methods)       -> [ M:sdk()          || M <- Methods].
buttons(Methods)   -> [ M:login_button() || M <- Methods].

event(init) -> [];
event(logout) -> wf:user(undefined), wf:redirect(?LOGIN_PAGE);
event(to_login) -> wf:redirect(?LOGIN_PAGE);
event({register, #user{}=U}) -> {ok,U1} = users:add(U#user{id=kvs:seq(user, 1)}), login_user(U1); % sample
event({login, #user{}=U, N}) -> %Updated = merge(U,N), ok = users:put(Updated),
				login_user(U); % sample
event({error, E}) -> ((get(context))#cx.module):event({login_failed, E});
event({Method,Event}) -> Method:event({Method,Event});
event(Ev) ->  wf:info(?MODULE,"Page Event ~p",[Ev]).

api_event(gLogin, Args, Term) -> google:api_event(gLogin, Args, Term);
api_event(gLoginFail, Args, Term) -> google:api_event(gLoginFail, Args, Term);
api_event(fbLogin, Args, Term)   -> facebook:api_event(fbLogin, Args, Term);
api_event(winLogin, Args, Term)  -> microsoft:api_event(winLogin, Args, Term);
api_event(Name, Args, Term)      -> wf:info(?MODULE,"Unknown API event: ~p ~p ~p",[Name, Args, Term]).

login_user(User) -> n2o:user(User), wf:redirect(?AFTER_LOGIN).
login(_Key, [{error, E}|_Rest])-> toastr_message:error("Authentication Error."), wf:info(?MODULE,"Auth Error: ~p", [E]);
login(Key, Args) ->
  LoginFun = fun(K) ->
    Index = proplists:get_value(Key:index(K), Args),
    case kvs:index(user, K, Index) of
      [Exists|_] ->
	    Diff = tuple_size(Exists) - tuple_size(#user{}),
	    {It, UsrExt} = lists:split(tuple_size(#iterator{}), tuple_to_list(Exists)),
	    {_,Usr} = lists:split(Diff, UsrExt),

	    RegData = Key:registration_data(Args, Key, list_to_tuple(lists:append([It,Usr]))),
	    ((get(context))#cx.module):event({login, Exists, RegData}),
	    true;
      _ -> false end end,

  Keys = [K || M<-kvs:modules(),T<-(M:metainfo())#schema.tables, T#table.name==user, K<-T#table.keys],

  LoggedIn = lists:any(LoginFun, Keys),

  if (LoggedIn =:= true) -> true; true ->
          RegData = Key:registration_data(Args, Key, #user{}),
          ((get(context))#cx.module):event({register, RegData})
  end.

version() -> proplists:get_value(vsn,element(2,application:get_all_key(?MODULE))).
