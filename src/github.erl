-module(github).
-author('Andrii Zadorozhnii').
-include_lib("nitro/include/nitro.hrl").
-include_lib("nitro/include/event.hrl").
-include_lib("n2o/include/n2o.hrl").
-include_lib("avz/include/avz.hrl").
-compile(export_all).
-export(?API).

-define(CLIENT_ID,        application:get_env(avz, github_client_id,     [])).
-define(CLIENT_SECRET,    application:get_env(avz, github_client_secret, [])).
-define(OAUTH_URI,        "https://github.com/login/oauth").
-define(AUTHORIZE_URI,    ?OAUTH_URI ++ "/authorize").
-define(ACCESS_TOKEN_URI, ?OAUTH_URI ++ "/access_token").
-define(API_URI,          "https://api.github.com").
-define(REQ_HEADER,       [{"User-Agent", "Erlang PaaS"}]).

user(Props) -> D =  api_call("/user", Props).

authorize_url() -> oauth:uri(?AUTHORIZE_URI, [{"client_id", ?CLIENT_ID}, {"state", "state"}, {"redirect_uri", wf:config(n2o, url) ++ "/" ++ wf:config(avz, login_page)}]).

get_access_token(Code) ->
    ReqParams = [{"client_id", ?CLIENT_ID}, {"client_secret", ?CLIENT_SECRET}, {"code", binary_to_list(Code)}],
    HttpOptions = [{autoredirect, false}],
    case httpc:request(post, {oauth:uri(?ACCESS_TOKEN_URI, ReqParams), [], "", []}, HttpOptions, []) of
        {error, _} -> not_authorized;
        {ok, {{"HTTP/1.1",200,"OK"}, Headers, Body}} ->
          Params = lists:append(Headers,
            [list_to_tuple(string:tokens(P1, "=")) || P1 <- string:tokens(Body, "&")]),
          case proplists:get_value(<<"error">>, Params, undefined) of undefined -> Params; _E -> not_authorized end;
        {ok, _} -> not_authorized end.

api_call(Name, Props) ->
    Token = [{"access_token", proplists:get_value("access_token", Props)}],
    case httpc:request(get, {oauth:uri(?API_URI++Name, Token), ?REQ_HEADER}, [], []) of
         {error, reason} -> api_error;
         {ok, {HttpResponse, _, Body}} -> 
                case HttpResponse of {"HTTP/1.1", 200, "OK"} -> Res = ?AVZ_JSON:decode(list_to_binary(Body), [{object_format, proplist}]), Res; _ -> error end;
         {ok, _} -> api_error end.

sdk() -> [].
callback() ->
    Code = wf:q(code),
    State = wf:q(state),
    case wf:user() of [] when Code =/= [] andalso State == <<"state">> ->
            case github:get_access_token(Code) of
                 not_authorized -> skip;
                 Props -> UserData = github:user(Props), avz:login(github, UserData) end; 
         _ -> skip end.

clean_prop(null)-> [];
clean_prop(V) -> V.

registration_data(Props, github, Ori) ->
    Id = proplists:get_value(<<"id">>, Props, undefined),
    Name = proplists:get_value(<<"name">>, Props, <<>>),
    Email = email_prop(Props, github),
    Avatar = proplists:get_value(<<"avatar_url">>, Props, <<>>),
    Ori#user{   %%username = binary_to_list(proplists:get_value(<<"login">>, Props, <<>>)),
		ext_id = Id,
                %%display_name = clean_prop(Name),
                avatar = clean_prop(Avatar),
                email = clean_prop(Email),
                names  = [clean_prop(Name)],
                surnames = [],
                tokens = avz:update({github,Id},Ori#user.tokens),
                register_date = erlang:localtime()%%os:timestamp(),
     }.

index(K) -> <<"id">>.%wf:to_binary(K).
email_prop(Props, github) ->
    Mail = proplists:get_value(<<"email">>, Props, []),
    L = wf:to_list(Mail),
    case avz_validator:is_email(L) of
        true -> Mail;
        false -> binary_to_list(proplists:get_value(<<"login">>, Props, [])) ++ "@github"
    end.

login_button() -> 
    [#link{id=github_btn, body=[<<"Sign in with Github">>]},
     #script{body=#event{target=github_btn, type=click, postback={github,logingithub}}}].

api_event(_,_,_) -> ok.
event({github,logingithub}) -> wf:redirect(github:authorize_url()).
