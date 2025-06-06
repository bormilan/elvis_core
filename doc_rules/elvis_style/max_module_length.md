# Max Module Length

The number of lines in a module should be limited to a defined maximum.

Lines containing only comments or whitespace may be either included or excluded from the line
count, depending on the configuration

## Rationale

Limiting the number of lines in a module improves readability and maintainability.
Modules with too many lines tend to become more complex and harder to understand,
increasing the likelihood of introducing bugs. Keeping modules concise encourages clear,
focused logic and makes it easier to navigate the codebase.

## Options

- `max_length :: non_neg_integer()`
  - default: `500`
- `count_comments :: boolean()`
  - default: `false`
- `count_whitespace :: boolean()`
  - default: `false`
- `count_docs :: boolean()` [![](https://img.shields.io/badge/since-4.0.0-blue)](https://github.com/inaka/elvis_core/releases/tag/4.0.0)
  - default: `false`

## Example configuration

```erlang
{elvis_style, max_module_length, #{ max_length => 500
                                  , count_comments => false
                                  , count_whitespace => false
                                  , count_docs => false
                                  }}
```
