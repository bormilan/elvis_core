-module(elvis_project).
-behaviour(elvis_ruleset).

-export([default/1, no_branch_deps/3, protocol_for_deps/3, old_configuration_format/3]).

-export_type([protocol_for_deps_config/0]).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Default values
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

-spec default(RuleName :: atom()) -> DefaultRuleConfig :: #{atom() := term()}.
default(no_branch_deps) ->
    #{ignore => []};
default(protocol_for_deps) ->
    #{ignore => [], regex => "^(https://|git://|\\d+(\\.\\d+)*)"};
default(old_configuration_format) ->
    #{}.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Rules
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

-type protocol_for_deps_config() :: #{ignore => [module()], regex => string()}.

-spec protocol_for_deps(
    elvis_config:config(),
    elvis_file:file(),
    protocol_for_deps_config()
) ->
    [elvis_result:item()].
protocol_for_deps(_Config, Target, RuleConfig) ->
    IgnoreDeps = option(ignore, RuleConfig, protocol_for_deps),
    Regex = option(regex, RuleConfig, protocol_for_deps),
    Deps = get_deps(Target),
    NoHexDeps = lists:filter(fun(Dep) -> not is_hex_dep(Dep) end, Deps),
    BadDeps = lists:filter(fun(Dep) -> is_not_git_dep(Dep, Regex) end, NoHexDeps),
    lists:filtermap(
        fun(Line) ->
            AppName = appname_from_line(Line),

            case lists:member(AppName, IgnoreDeps) of
                true ->
                    false;
                false ->
                    {true,
                        elvis_result:new_item(
                            "Dependency '~s' is not using appropriate protocol; prefer "
                            "respecting regular expression '~s'",
                            [AppName, Regex]
                        )}
            end
        end,
        BadDeps
    ).

appname_from_line({AppName, _}) ->
    AppName;
appname_from_line({AppName, _, _GitInfo}) ->
    AppName;
appname_from_line({AppName, _Vsn, _GitInfo, _Opts}) ->
    AppName.

-spec no_branch_deps(
    elvis_config:config(),
    elvis_file:file(),
    elvis_style:empty_rule_config()
) ->
    [elvis_result:item()].
no_branch_deps(_Config, Target, RuleConfig) ->
    IgnoreDeps = option(ignore, RuleConfig, no_branch_deps),
    Deps = get_deps(Target),
    BadDeps = lists:filter(fun is_branch_dep/1, Deps),
    lists:filtermap(
        fun(Line) ->
            AppName = appname_from_line(Line),

            case lists:member(AppName, IgnoreDeps) of
                true ->
                    false;
                false ->
                    {true, [
                        elvis_result:new_item(
                            "Dependency '~s' uses a branch; prefer a tag or a specific commit",
                            [AppName]
                        )
                    ]}
            end
        end,
        BadDeps
    ).

-spec old_configuration_format(
    elvis_config:config(),
    elvis_file:file(),
    elvis_style:empty_rule_config()
) ->
    [elvis_result:item()].
old_configuration_format(_Config, Target, _RuleConfig) ->
    {Content, _} = elvis_file:src(Target),
    [AllConfig] = ktn_code:consult(Content),
    case proplists:get_value(elvis, AllConfig) of
        undefined ->
            [];
        ElvisConfig ->
            case is_old_config(ElvisConfig) of
                false ->
                    [];
                true ->
                    [
                        elvis_result:new_item(
                            "The current Elvis configuration file has an outdated format. "
                            "Please check Elvis's GitHub repository to find out what the "
                            "new format is"
                        )
                    ]
            end
    end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Private
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%% Rebar

get_deps(File) ->
    {Src, _} = elvis_file:src(File),
    Terms = ktn_code:consult(Src),
    IsDepsTerm =
        fun
            ({deps, _}) ->
                true;
            (_) ->
                false
        end,
    case lists:filter(IsDepsTerm, Terms) of
        [] ->
            [];
        [{deps, Deps}] ->
            Deps
    end.

%% Rebar3
is_branch_dep({_AppName, {_SCM, _Location, {branch, _}}}) ->
    true;
is_branch_dep({_AppName, {git_subdir, _Url, {branch, _}, _SubDir}}) ->
    true;
%% Specific to plugin rebar_raw_resource
is_branch_dep({AppName, {raw, DepResourceSpecification}}) ->
    is_branch_dep({AppName, DepResourceSpecification});
%% Rebar2
is_branch_dep({_AppName, _Vsn, {_SCM, _Location, {branch, _}}}) ->
    true;
is_branch_dep(_) ->
    false.

is_hex_dep(_AppName) when is_atom(_AppName) ->
    true;
is_hex_dep({_AppName, _Vsn, {pkg, _PackageName}}) when
    is_atom(_AppName), is_list(_Vsn), is_atom(_PackageName)
->
    true;
is_hex_dep({_AppName, {pkg, _OtherName}}) when is_atom(_AppName), is_atom(_OtherName) ->
    true;
is_hex_dep({_AppName, _Vsn}) when is_atom(_AppName), is_list(_Vsn) ->
    true;
is_hex_dep(_) ->
    false.

is_not_git_dep({_AppName, {_SCM, Url, _Branch}}, Regex) ->
    nomatch == re:run(Url, Regex, []);
is_not_git_dep(
    {_AppName, {git_subdir, Url, {BranchTagOrRefType, _BranchTagOrRef}, _SubDir}},
    Regex
) when
    BranchTagOrRefType =:= branch;
    BranchTagOrRefType =:= tag;
    BranchTagOrRefType =:= ref
->
    nomatch == re:run(Url, Regex, []);
%% Specific to plugin rebar_raw_resource
is_not_git_dep({AppName, {raw, DepResourceSpecification}}, Regex) ->
    is_not_git_dep({AppName, DepResourceSpecification}, Regex);
%% Alternative formats, backwards compatible declarations
is_not_git_dep({_AppName, {_SCM, Url}}, Regex) ->
    nomatch == re:run(Url, Regex, []);
is_not_git_dep({_AppName, _Vsn, {_SCM, Url}}, Regex) ->
    nomatch == re:run(Url, Regex, []);
is_not_git_dep({_AppName, _Vsn, {_SCM, Url, _Branch}}, Regex) ->
    nomatch == re:run(Url, Regex, []);
is_not_git_dep({_AppName, _Vsn, {_SCM, Url, {BranchTagOrRefType, _Branch}}, _Opts}, Regex) when
    BranchTagOrRefType =:= branch;
    BranchTagOrRefType =:= tag;
    BranchTagOrRefType =:= ref
->
    nomatch == re:run(Url, Regex, []).

%% Old config

is_old_config(ElvisConfig) ->
    case proplists:get_value(config, ElvisConfig) of
        undefined ->
            false;
        Config when is_map(Config) ->
            true;
        Config when is_list(Config) ->
            SrcDirsIsKey =
                fun(RuleGroup) ->
                    maps:is_key(src_dirs, RuleGroup) orelse exists_old_rule(RuleGroup)
                end,
            lists:filter(SrcDirsIsKey, Config) /= []
    end.

exists_old_rule(#{rules := Rules}) ->
    Filter =
        fun
            ({_, _, Args}) when is_list(Args) ->
                true;
            (_) ->
                false
        end,
    lists:filter(Filter, Rules) /= [];
exists_old_rule(_) ->
    false.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Internal Function Definitions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

-spec option(OptionName, RuleConfig, Rule) -> OptionValue when
    OptionName :: atom(),
    RuleConfig :: elvis_config:config(),
    Rule :: atom(),
    OptionValue :: term().
option(OptionName, RuleConfig, Rule) ->
    maybe_default_option(maps:get(OptionName, RuleConfig, undefined), OptionName, Rule).

-spec maybe_default_option(UserDefinedOptionValue, OptionName, Rule) -> OptionValue when
    UserDefinedOptionValue :: undefined | term(),
    OptionName :: atom(),
    Rule :: atom(),
    OptionValue :: term().
maybe_default_option(undefined = _UserDefinedOptionValue, OptionName, Rule) ->
    maps:get(OptionName, default(Rule));
maybe_default_option(UserDefinedOptionValue, _OptionName, _Rule) ->
    UserDefinedOptionValue.
