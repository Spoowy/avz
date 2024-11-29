-module(google).
-author('Andrii Zadorozhnii').
-include_lib("avz/include/avz.hrl").
-include_lib("nitro/include/nitro.hrl").
-include_lib("nitro/include/event.hrl").
-include_lib("n2o/include/n2o.hrl").
-compile(export_all).
-export(?API).

-define(G_CLIENT_ID,     application:get_env(avz, g_client_id,    [])).
-define(G_COOKIE_POLICY, application:get_env(avz, g_cookiepolicy, [])).
-define(G_BTN_ID,        application:get_env(avz, g_btn_id, "gloginbtn")).
-define(G_BTN_HEIGHT,    application:get_env(avz, g_btn_height, 50)).
-define(G_BTN_WIDTH,     application:get_env(avz, g_btn_width, 240)).
-define(G_BTN_THEME,     application:get_env(avz, g_btn_theme, "light")).
-define(G_BTN_LONGTITLE, application:get_env(avz, g_btn_longtitle, true)).

-define(ATTS, #{email => <<"Ny">>, name => <<"jh">>, id => <<"a8">>, image => <<"lU">>, given_name => <<"w9">>, family_name => <<"D7">>}).

api_event(gLogin, Args, _) ->
    JSArgs = ?AVZ_JSON:decode(list_to_binary(Args), [{object_format, proplist}]),
    avz:login(google, JSArgs);
api_event(gLoginFail, Args, _) ->
    wf:info(?MODULE, "Login failed ~p~n", [Args]).

%% deprecated
registration_data(Props, google, Ori)->
    Id = proplists:get_value(maps:get(id,?ATTS), Props),
    Name = proplists:get_value(maps:get(name, ?ATTS), Props),
    Image = proplists:get_value(maps:get(image,?ATTS), Props),
    GivenName = proplists:get_value(maps:get(given_name,?ATTS), Props),
    FamilyName = proplists:get_value(maps:get(family_name,?ATTS), Props),
    Email = email_prop(Props,google),
    Tokens = case Ori#user.tokens of <<>> -> []; {binary, _, <<131,_/binary>> = B} -> binary_to_term(B); T1 -> T1 end,
    Tokens1 = case Tokens of <<>> -> []; T -> T end,
    Tokens2 = avz:update({google,Id},Tokens1),
    Ori#user{
                %% display_name = Name,
                avatar = Image,
                email = Email,
                names = [GivenName],
                surnames = [FamilyName],
                tokens = Tokens2,
                register_date = erlang:localtime(),%%os:timestamp(),
                % sex = proplists:get_value(<<"gender">>, Props),
                status = ok }.

index(K) -> maps:get(K, ?ATTS, K).
email_prop(Props, _) -> proplists:get_value(maps:get(email,?ATTS), Props).

login_button()-> #panel{id=?G_BTN_ID, body=[]}.

event(_) -> ok.
callback() -> ok.
sdk() ->
    wf:wire(#api{name=gLogin, tag=plus}),
    wf:wire(#api{name=gLoginFail, tag=plus}),
    #dtl{bind_script=false, file="google_sdk", ext="dtl", folder="priv/static/js",
        bindings=[{loginbtnid, ?G_BTN_ID},
          {clientid,    ?G_CLIENT_ID},
          {cookiepolicy,?G_COOKIE_POLICY}, 
          {height,      ?G_BTN_HEIGHT},
          {width,       ?G_BTN_WIDTH},
          {theme,       ?G_BTN_THEME}, 
          {longtitle,   ?G_BTN_LONGTITLE} ]}. 
