-module(pass_no_boolean_in_comparison).

-export [my_fun/2, my_fun/3.

my_fun(P1, P2) ->
    case (not do:something(P1)) orelse (not do:something(P2)) of
        true -> "There is a false";
        false -> "All true"
    end.

%% … or even …

my_fun(P1, P2, _) ->
    case do:something(P1) andalso do:something(P2) of
        true -> "All true";
        false -> "There is a false"
    end.
