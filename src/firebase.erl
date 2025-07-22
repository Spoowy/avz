-module(firebase).
-include("avz.hrl").
-include_lib("nitro/include/nitro.hrl").
-include_lib("nitro/include/event.hrl").
-include_lib("n2o/include/n2o.hrl").
-compile(export_all).
-export(?API).

%% Configuration for Firebase Authentication
-define(FIREBASE_CONFIG,     application:get_env(avz, firebase_config, #{})).
-define(FIREBASE_API_KEY,    application:get_env(avz, firebase_api_key, "")).
-define(FIREBASE_AUTH_DOMAIN, application:get_env(avz, firebase_auth_domain, "")).
-define(FIREBASE_PROJECT_ID, application:get_env(avz, firebase_project_id, "")).
-define(FIREBASE_STORAGE_BUCKET, application:get_env(avz, firebase_storage_bucket, "")).
-define(FIREBASE_MESSAGING_SENDER_ID, application:get_env(avz, firebase_messaging_sender_id, "")).
-define(FIREBASE_APP_ID,     application:get_env(avz, firebase_app_id, "")).

%% Google OAuth Configuration
-define(GOOGLE_CLIENT_ID,    application:get_env(avz, google_client_id, "")).

%% Microsoft OAuth Configuration
-define(MICROSOFT_CLIENT_ID, application:get_env(avz, microsoft_client_id, "")).

%% LinkedIn OAuth Configuration
-define(LINKEDIN_CLIENT_ID,  application:get_env(avz, linkedin_client_id, "")).
-define(LINKEDIN_REDIRECT_URI, application:get_env(avz, linkedin_redirect_uri, "")).

%% Button Configuration
-define(FB_BTN_ID,           application:get_env(avz, fb_btn_id, "firebasebtn")).
-define(FB_BTN_STYLE,        application:get_env(avz, fb_btn_style, "primary")).

%% User data field mappings for Firebase Auth
-define(FIREBASE_USER_ATTS, #{
    email => <<"email">>,
    name => <<"displayName">>,
    id => <<"uid">>,
    image => <<"photoURL">>,
    phone => <<"phoneNumber">>,
    provider => <<"providerId">>,
    email_verified => <<"emailVerified">>,
    metadata => <<"metadata">>,
    provider_data => <<"providerData">>
}).

%% API event handlers for Firebase Authentication
api_event(firebaseLogin, Args, _) ->
    case ?AVZ_JSON:decode(list_to_binary(Args), [{object_format, proplist}]) of
        {ok, JSArgs} ->
            case proplists:get_value(<<"user">>, JSArgs) of
                undefined ->
                    wf:error(?MODULE, "No user data in Firebase response~n", []),
                    {error, no_user_data};
                UserData when is_list(UserData) ->
                    %% Extract provider information
                    Provider = extract_provider(UserData),
                    ProcessedData = process_firebase_user(UserData, Provider),
                    avz:login(firebase, ProcessedData);
                _ ->
                    wf:error(?MODULE, "Invalid user data format~n", []),
                    {error, invalid_user_data}
            end;
        Error ->
            wf:error(?MODULE, "Failed to decode Firebase login args: ~p~n", [Error]),
            {error, decode_failed}
    end;

api_event(firebaseLoginFail, Args, _) ->
    wf:info(?MODULE, "Firebase login failed ~p~n", [Args]),
    case ?AVZ_JSON:decode(list_to_binary(Args), [{object_format, proplist}]) of
        {ok, JSArgs} ->
            ErrorCode = proplists:get_value(<<"code">>, JSArgs, <<"unknown">>),
            ErrorMessage = proplists:get_value(<<"message">>, JSArgs, <<"Unknown error">>),
            wf:error(?MODULE, "Firebase Auth Error - Code: ~p, Message: ~p~n", [ErrorCode, ErrorMessage]),
            {error, {firebase_auth_error, ErrorCode, ErrorMessage}};
        _ ->
            {error, unknown_error}
    end;

api_event(Event, Args, Term) ->
    wf:info(?MODULE, "Unknown Firebase API event: ~p ~p ~p~n", [Event, Args, Term]).

%% Extract provider from Firebase user data
extract_provider(UserData) ->
    case proplists:get_value(maps:get(provider_data, ?FIREBASE_USER_ATTS), UserData) of
        [ProviderInfo|_] when is_list(ProviderInfo) ->
            case proplists:get_value(maps:get(provider, ?FIREBASE_USER_ATTS), ProviderInfo) of
                <<"google.com">> -> google;
                <<"microsoft.com">> -> microsoft;
                <<"linkedin.com">> -> linkedin;
                <<"facebook.com">> -> facebook;
                Other ->
                    wf:info(?MODULE, "Unknown provider: ~p~n", [Other]),
                    firebase
            end;
        _ -> firebase
    end.

%% Process Firebase user data based on provider
process_firebase_user(UserData, Provider) ->
    BaseData = [
        {firebase_uid, proplists:get_value(maps:get(id, ?FIREBASE_USER_ATTS), UserData)},
        {provider, atom_to_binary(Provider, utf8)},
        {email, proplists:get_value(maps:get(email, ?FIREBASE_USER_ATTS), UserData)},
        {name, proplists:get_value(maps:get(name, ?FIREBASE_USER_ATTS), UserData)},
        {image, proplists:get_value(maps:get(image, ?FIREBASE_USER_ATTS), UserData)},
        {phone, proplists:get_value(maps:get(phone, ?FIREBASE_USER_ATTS), UserData)},
        {email_verified, proplists:get_value(maps:get(email_verified, ?FIREBASE_USER_ATTS), UserData, false)}
    ],

    %% Add provider-specific data
    ProviderData = case Provider of
        google -> extract_google_data(UserData);
        microsoft -> extract_microsoft_data(UserData);
        linkedin -> extract_linkedin_data(UserData);
        _ -> []
    end,

    BaseData ++ ProviderData.

%% Extract Google-specific data from provider data
extract_google_data(UserData) ->
    case proplists:get_value(maps:get(provider_data, ?FIREBASE_USER_ATTS), UserData) of
        [ProviderInfo|_] when is_list(ProviderInfo) ->
            [
                {given_name, proplists:get_value(<<"given_name">>, ProviderInfo)},
                {family_name, proplists:get_value(<<"family_name">>, ProviderInfo)},
                {google_id, proplists:get_value(<<"uid">>, ProviderInfo)}
            ];
        _ -> []
    end.

%% Extract Microsoft-specific data from provider data
extract_microsoft_data(UserData) ->
    case proplists:get_value(maps:get(provider_data, ?FIREBASE_USER_ATTS), UserData) of
        [ProviderInfo|_] when is_list(ProviderInfo) ->
            [
                {given_name, proplists:get_value(<<"given_name">>, ProviderInfo)},
                {family_name, proplists:get_value(<<"family_name">>, ProviderInfo)},
                {microsoft_id, proplists:get_value(<<"uid">>, ProviderInfo)}
            ];
        _ -> []
    end.

%% Extract LinkedIn-specific data from provider data
extract_linkedin_data(UserData) ->
    case proplists:get_value(maps:get(provider_data, ?FIREBASE_USER_ATTS), UserData) of
        [ProviderInfo|_] when is_list(ProviderInfo) ->
            [
                {given_name, proplists:get_value(<<"given_name">>, ProviderInfo)},
                {family_name, proplists:get_value(<<"family_name">>, ProviderInfo)},
                {linkedin_id, proplists:get_value(<<"uid">>, ProviderInfo)}
            ];
        _ -> []
    end.

%% Registration data function for Firebase users
registration_data(Props, firebase, Ori) ->
    FirebaseUid = proplists:get_value(firebase_uid, Props),
    Provider = proplists:get_value(provider, Props, <<"firebase">>),
    Email = proplists:get_value(email, Props),
    Name = proplists:get_value(name, Props),
    Image = proplists:get_value(image, Props),
    Phone = proplists:get_value(phone, Props),
    EmailVerified = proplists:get_value(email_verified, Props, false),

    %% Extract names
    GivenName = proplists:get_value(given_name, Props),
    FamilyName = proplists:get_value(family_name, Props),

    %% If no separate given/family names, try to split display name
    {Names, Surnames} = case {GivenName, FamilyName} of
        {undefined, undefined} when Name =/= undefined ->
            split_display_name(Name);
        {G, F} ->
            {[G || G =/= undefined], [F || F =/= undefined]}
    end,

    %% Handle tokens
    Tokens = case Ori#user.tokens of
        <<>> -> [];
        {binary, _, <<131,_/binary>> = B} -> binary_to_term(B);
        T1 -> T1
    end,
    Tokens1 = case Tokens of <<>> -> []; T -> T end,

    %% Create composite key with provider and Firebase UID
    TokenKey = {firebase, binary_to_list(Provider) ++ ":" ++ binary_to_list(FirebaseUid)},
    Tokens2 = avz:update(TokenKey, Tokens1),

    Ori#user{
        avatar = Image,
        email = Email,
        names = Names,
        surnames = Surnames,
        tokens = Tokens2,
        register_date = erlang:localtime(),
        status = case EmailVerified of true -> ok; _ -> email_not_verified end
    }.

%% Split display name into given and family names
split_display_name(Name) when is_binary(Name) ->
    split_display_name(binary_to_list(Name));
split_display_name(Name) when is_list(Name) ->
    Parts = string:tokens(Name, " "),
    case Parts of
        [] -> {[], []};
        [Single] -> {[Single], []};
        [First|Rest] -> {[First], Rest}
    end.

%% Index function for field mapping
index(K) -> maps:get(K, ?FIREBASE_USER_ATTS, K).

%% Email property extraction
email_prop(Props, firebase) ->
    proplists:get_value(email, Props).

%% Create Firebase login button container
login_button() ->
    AuthProviders = auth_providers(),
    Buttons = [#panel{
                  id = atom_to_list(K) ++ "-login-btn",
                  class = "auth-provider-btn " ++ atom_to_list(K) ++ "-btn",
                  body = "Sign in with " ++ atom_to_list(K)
                 } || {K, _} <- maps:to_list(AuthProviders)],
    #panel{id = ?FB_BTN_ID, class = "firebase-auth-container", body = Buttons}.

%% Event handler
event(_E) ->
    io:format("log ~p ~p: ~p ~n", [?MODULE, ?LINE, _E]),
    ok.

%% Callback function
callback() ->
    io:format("log ~p ~p: ~p ~n", [?MODULE, ?LINE, callback]),
    ok.

%% Generate Firebase Authentication SDK
sdk() ->
    wf:wire(#api{name=firebaseLogin, tag=firebase}),
    wf:wire(#api{name=firebaseLoginFail, tag=firebase}),
    #dtl{
       bind_script = false,
       file = "firebase_sdk",
       ext = "dtl",
       folder = "priv/static/js",
       bindings = [{firebase_config, ?AVZ_JSON:encode(firebase_config_json())},
                   {container_id, ?FB_BTN_ID},
                   {auth_providers, ?AVZ_JSON:encode(auth_providers())}

                  ]
    }.

%% Generate Firebase configuration as JSON
firebase_config_json() ->
    #{
        apiKey => list_to_binary(?FIREBASE_API_KEY),
        authDomain => list_to_binary(?FIREBASE_AUTH_DOMAIN),
        projectId => list_to_binary(?FIREBASE_PROJECT_ID),
        storageBucket => list_to_binary(?FIREBASE_STORAGE_BUCKET),
        messagingSenderId => list_to_binary(?FIREBASE_MESSAGING_SENDER_ID),
        appId => list_to_binary(?FIREBASE_APP_ID)
    }.

auth_providers()->
    #{email =>
          #{ providerId => <<"password">> },
      phone =>
          #{ providerId => <<"phone">> },
      google =>
          #{providerId => <<"google.com">>,
            scopes => [<<"email">>, <<"profile">>],
            customParams => #{ prompt => <<"select_account">> }},
      microsoft =>
           #{providerId => <<"microsoft.com">>,
             scopes => [<<"email">>, <<"profile">>]}
      %% linkedin =>
      %%     #{providerId => <<"linkedin.com">>,
      %%       scopes => [<<"r_liteprofile">>, <<"r_emailaddress">>]}
     }.
