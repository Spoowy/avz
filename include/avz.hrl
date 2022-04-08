-record(struct, {lst=[]}).
-define(AFTER_LOGIN, wf:config(avz,after_login_page,"/account")).
-define(LOGIN_PAGE, wf:config(avz,login_page,"/login")).
-define(METHODS, [facebook,google,github,twitter,microsoft]).
-define(API,[sdk/0,               % JavaScript for page embedding for JavaScript based login methods
             login_button/0,      % HTML Button for page embedding
             event/1,             % Page Event for HTTP redirect based login methods
             api_event/3,         % Page Event for JavaScript based login methods
             email_prop/2,
             callback/0,          % Callback part of HTTP redirect based login methods
             registration_data/3  % Process Parameters
            ]).
-ifndef(AVZ_JSON).
-define(AVZ_JSON, (application:get_env(avz,json,jsone))).
-endif.

-ifndef(USER_HRL).
-define(USER_HRL, true).

%% -include_lib("kvs/include/metainfo.hrl").

-record(iterator,   { id    = []::[] | integer()} ).

-ifndef(USER_EXT).
-define(USER_EXT,
        avatar=[],
        company=[],
        address=[],
        country=[],
        state=[],
        city=[],
        zip=[],
        phone=[],
        email=[],
        payment_plan=[],
        payment_vendor=[],
        ext_id=[],
        language=en).
-endif.

-record(user, {id=[], 
	       ?USER_EXT,
               username=[],
               password=[],
               display_name=[],
               register_date=[],
               tokens = [],
               images=[],
               names=[],
               surnames=[],
               birth=[],
               sex=[],
               date=[],
               status=[],
               zone=[], % what is zone? what is type?
               type=[] % type admin?
              }).

-record(user2, {id=[], % version 2
                everyting_getting_small,
                email,
                username,
                password,
                zone,
                type }).

-endif.

