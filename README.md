# Delite.nvim

Enhance deletion in insert mode for words of any case style: `camelCase`, `PascalCase`, `snake_case`, `kebab-case`,
pairs and custom patterns of `words` and `pairs` (rules).

install lazy:
```lua
return {
    "vallahor/delite.nvim",
    config = function()
        local delite = require("delite")
        delite.setup()

        vim.keymap.set("i", "<c-bs>", delite.previous_word)
        vim.keymap.set("i", "<c-del>", delite.next_word)

        vim.keymap.set("i", "<bs>", delite.previous)
        vim.keymap.set("i", "<del>", delite.next)

        -- Word deletion at the current cursor position
        -- Seeks previous non-whitespace when at beginning of line
        vim.keymap.set("n", "<c-bs>", delite.previous_word_normal_mode)
        -- Deletes newline(s) and following whitespaces when at end of line (acting like a join line)
        -- and positions the cursor at the next non-whitespace char.
        vim.keymap.set("n", "<c-del>", delite.next_word_normal_mode)

        -- Works like insert mode <BS>/<Del> but matches pairs:
        -- <bs> delete current char / match opening pair
        -- <del> delete current char / match closing pair
        vim.keymap.set("n", "<bs>", delite.previous_normal_mode)
        vim.keymap.set("n", "<del>", delite.next_normal_mode)

        -- Join without moving the cursor
        vim.keymap.set("i", "<c-j>", delite.join)

        vim.keymap.set("n", "J", delite.join)

        vim.keymap.set("n", "<c-s-j>", function() 
            delite.join({ separator = " -- ", times = 2 })
        end)
    end
}
```

## Examples
```
The `|` is representing the cursor position.

delete.previous_word
word_word| -> word_|
word-word| -> word-|
WordWord| -> Word|
WordWORD| -> Word|
WordWord1| -> Word|
WordWord12345| -> WordWord|
Word         | -> Word|

delete.next_word
|word_word -> |_word
|word-word -> |-word
|WordWord -> |Word
|WordWORD -> |WORD
|WordWord1  -> |Word1
|12345Word -> |Word
|     Word -> |Word

===| -> |
!==| -> |
......| -> |
----| -> |
)))| -> ))|

{([<"'|'">])} -> {([<"|">])}
{([<"|">])} -> {([<|>])}
{([<|>])} -> {([|])}
{([|])} -> {(|)}
{(|)} -> {(|)}
{(|)} -> {|}
{|} -> |

Hex number pattern:
0x12ab12| -> 0x12ab|

delite.insert_pattern({ pattern = "%x%x%x%x%x%x", prefix = "0x" })
0x12ab12| -> 0x|

Before: <c-bs> (delite.previous_word) | After:
value_list = [%{|                     | value_list = [|, %{}]
                                      | 
}, %{}]                               | 

Before: <c-del> (delite.next_word) | After:
value_list = [%{                   |   value_list = [|, %{}]
                                   |    
|}, %{}]                           |     


delite.insert_rule({ left = '~%u"""', right = '"""', { filetypes = { "elixir" } } })
Before: <c-bs> (delite.previous_word) | After:
def render(assigns) do                | def render(assigns) do 
  ~H"""|                              |   |    
                                      | end
  """                                 |      
end                                   |  

Before: <c-bs> (delite.next_word) | After:
def render(assigns) do                | def render(assigns) do 
  ~H"""                               |   |    
                                      | end
  |"""                                |      
end                                   |  

Before: <c-del> (delite.previous_word) | After: begin of the line | Delete blank lines until non whitespace
value = %{                             | value = %{               | value_list = [|, %{}]
                                       |                          |                    
  |,                                   | | ,                      |          
  "a" => "b"                           |   "a" => "b"             |               
  }                                    | }                        |              

Before: <c-del> (delite.next_word) | After: Delete blank lines until non whitespace
value = %{|                        | value_list = [|, %{}]               
                                   |                                              
  ,                                |                                    
  "a" => "b"                       |                                         
  }                                |                                        
```

`Delite` adds wildcards in the patterns.


Right: `"^(pattern)item.suffix"` (delite.next_word)
Left: `"item.prefix(pattern)$"` (delite.previous_word)


The `prefix` and `suffix` will not be deleted it serves as a delimiter beyond
the regex.

Creating `Rules` and `Patterns`:
```lua

-- Precedence matters!
-- Execution order:
-- Filetype-specific:
--   1. Filetype Rules
--   2. Filetype Patterns
--   3. Filetype Pairs
-- Global:
--   4. Rules
--   5. Patterns
--   6. Pairs (defaults first, then custom)
-- Defaults are applied in the order they’re defined:
--   Digits → Uppercase → Word

-- `Default Pairs`. Note: only punctuation allowed, anything other than
-- punctuation should be added as a rule.

--- If `filetypes` is omitted, the pattern is global.
--- `not_filetypes` only applies to global patterns.

--- insert_pair
--- Only punctuation characters are allowed, and the patterns are automatically escaped.
---@param config { left: string, right: string, disable_right?: boolean }
---@param opts? { filetypes?: string[], not_filetypes?: string[] }
delite.insert_pair({ left = "--", right = "--", disable_right = true })

--- edit_default_pairs
---@param pattern string
---@param config { left: string, right?: string, disable_right?: boolean, not_filetypes?: string[] }

-- Edit `default_pairs` or replace the default ones in the config.
delite.edit_default_pairs("'", { not_filetypes = { "ocaml", "rust" } })

--- remove_pattern_from_default_pairs
-- Remove some default pattern in case you don't want to copy all the patterns
-- and paste them in your config.
---@param pattern string

delite.remove_pattern_from_default_pairs("<")

--- insert_default_pairs_priority
--- Will be inserted before the default patterns 
--- Only punctuation characters are allowed, and the patterns are automatically escaped.
---@param config { left: string, right: string, disable_right?: boolean }
---@param opts? {  not_filetypes?: string[] }
delite.insert_default_pairs_priority({ left = "%{", right = "}" })


--- insert_rule
---@param config { left: string, right: string, disable_right?: boolean }
---@param opts? { filetypes?: string[], not_filetypes?: string[] }

-- Create rules that only works in the filetypes specified.
-- Rule for: %{}
delite.insert_rule({ left = "%%{", right = "}", { filetypes = { "elixir" } } })
-- Rule for: ~H""" """ and any other uppercase.
delite.insert_rule({ left = '~%u"""', right = '"""', { filetypes = { "elixir" } } })
-- Rule for: markdown
delite.insert_rule({ left = "```%w*", right = "```", { filetypes = { "markdown" } } })
-- Create a global rule and ignores when the filetype is `html`
delite.insert_rule({ left = "<>", right = "</>", { not_filetypes = { "html" } } })

--- insert_pattern
---@param config { pattern: string, prefix?: string, suffix?: string, disable_right?: boolean }
---@param opts? { filetypes?: string[], not_filetypes?: string[] }

-- Rule for: __MODULE__, __struct__, and any other pattern that has this behavior in elixir.
delite.insert_pattern({ pattern = "__[%u%l]+__" }, { filetypes = { "elixir" } })
-- Hex numbers: Delete til `0x`. Before: 0x12ab3c| `press <c-bs>` After: 0x|
delite.insert_pattern({ pattern = "%x%x%x%x%x%x", prefix = "0x" })
```

setup:
```lua
{
  delete_blank_lines_until_non_whitespace = true, -- Deletes all blank lines, spaces, and tabs until a non-whitespace character or EOF.
  multi_punctuation = true, -- Matches repeated punctuation sequences like `!==`, `...`, `++`, `===`. See `allowed_multi_punctuation`.
  disable_undo = false, -- Prevents grouping edits into a single undo step; each deletion starts a new undo chunk.
  disable_right = false, -- Disables all pairs and rules for the right side.
  disable_right_default_pairs = false, -- Disables right-side behavior only for the default pairs.
  join_line = {
    separator = " ",
    times = 1,
  },
  -- NOTE: The patterns defined here will be escaped in the config.
  default_pairs = {
    { left = "(", right = ")", not_filetypes = nil },
    { left = "{", right = "}", not_filetypes = nil },
    { left = "[", right = "]", not_filetypes = nil },
    { left = "'", right = "'", not_filetypes = nil },
    { left = '"', right = '"', not_filetypes = nil },
    { left = "`", right = "`", not_filetypes = nil },
    { left = "<", right = ">", not_filetypes = nil },
  },
  defaults = {
    -- One or more digits.
    {
      left = "%d%d+$",
      right = "^%d%d+",
    },
    -- One or more uppercases.
    {
      left = "%u%u+$",
      right = "^%u%u+",
    },
    -- Word deletion.
    {
      left = "%u?%l*[%d%u]?$",
      right = "^%u?%l*%d?",
    },
  },
  allowed_multi_punctuation = {
    left = "[%.%,%!%?%:%;%-%/%@%#%$%%%^%&%*%_%+%=%~%|%\\]*$",
    right = "^[%.%,%!%?%:%;%-%/%@%#%$%%%^%&%*%_%+%=%~%|%\\]*",
  },
}
```
