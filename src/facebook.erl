-module(facebook).
-author('Andrii Zadorozhnii').
-include_lib("avz/include/avz.hrl").
-include_lib("nitro/include/nitro.hrl").
-include_lib("nitro/include/event.hrl").
-include_lib("n2o/include/n2o.hrl").

-compile(export_all).
-export(?API).

-define(FB_APP_ID,    application:get_env(avz, fb_id,        [])).

callback() -> ok.
event({facebook,_Event}) -> wf:wire("window.fb_login();"), ok. 
api_event(fbLogin, Args, _Term) -> JSArgs = ?AVZ_JSON:decode(list_to_binary(Args),[{object_format, proplist}]), avz:login(facebook, JSArgs).

registration_data(Props, facebook, Ori)->
    Id = proplists:get_value(<<"id">>, Props),
    BirthDay = case proplists:get_value(<<"birthday">>, Props) of
        undefined -> {1, 1, 1970};
        BD -> list_to_tuple([list_to_integer(X) || X <- string:tokens(binary_to_list(BD), "/")]) end,
    Email = proplists:get_value(<<"email">>, Props),
    [UserName|_] = string:tokens(binary_to_list(Email),"@"),
    Cover = case proplists:get_value(<<"cover">>,Props) of undefined -> ""; {P} -> case proplists:get_value(<<"source">>,P) of undefined -> ""; C -> binary_to_list(C) end end,
    Ori#user{   display_name = UserName,
                avatar = "https://graph.facebook.com/" ++ binary_to_list(Id) ++ "/picture?type=large",
                email = Email,
                names = [proplists:get_value(<<"first_name">>, Props, [])],
                surnames = [proplists:get_value(<<"last_name">>, Props, [])],
                tokens = avz:update({facebook,Id},Ori#user.tokens),
                birth = {element(3, BirthDay), element(1, BirthDay), element(2, BirthDay)},
                register_date = os:timestamp()}.

index(K) -> wf:to_binary(K).
email_prop(Props, _) -> proplists:get_value(<<"email">>, Props, []).

login_button() -> 
    [#link{id=loginfb, body=[<<"Sign in with Facebook">>]}, 
     #script{body=#event{target=loginfb, type=click, postback={facebook,loginClick}}}]. 

sdk() ->
    wf:wire(#api{name=fbLogin, tag=fb}),
    [ #dtl{bind_script=false, file="facebook_sdk", ext="dtl", folder="priv/static/js",
	   bindings=[{appid, ?FB_APP_ID}] } ].
