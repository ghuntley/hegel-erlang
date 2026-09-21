-ifndef(HEGEL_HRL).
-define(HEGEL_HRL, true).
-define(DRAW(Pattern, Generator),
    Pattern = hegel:draw(hegel:current_test_case(), ??Pattern, Generator)).
-define(DRAW_SILENT(Pattern, Generator),
    Pattern = hegel:draw_silent(hegel:current_test_case(), Generator)).
-endif.
