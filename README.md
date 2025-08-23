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
        -- If not planning to use the right deletion don't assign that key, use the default <del> behavior.
        vim.keymap.set("i", "<del>", delite.next)

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

`delete.previous_word`
word_word| -> word_|
word-word| -> word_|
WordWord| -> Word|
WordWORD| -> Word|
WordWord1| -> Word|

|word_word -> |_word
|word-word -> |-word
|WordWord -> |Word
|WordWORD -> |WORD
|WordWord1  -> |Word1

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

Hex number patter:
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

-- Edit `default_pairs` or replace the default ones in the config.
delite.edit_default_pairs("'", { not_filetypes = { "ocaml", "rust" } })

-- Create rules that only works in the filetypes specified.
-- Rule for: %{}
delite.insert_rule({ left = "%%{", right = "}", { filetypes = { "elixir" } } })
-- Rule for: ~H""" """ and any other uppercase.
delite.insert_rule({ left = '~%u"""', right = '"""', { filetypes = { "elixir" } } })
-- Rule for: __MODULE__, __struct__, and any other pattern that has this behavior in elixir.
delite.insert_pattern({ pattern = "__[%u%l]+__" }, { filetypes = { "elixir" } })

delite.insert_rule({ left = "```%w*", right = "```", { filetypes = { "markdown" } } })

-- Create a global rule and ignores when the filetype is `html`
delite.insert_rule({ left = "<>", right = "</>", { not_filetypes = { "html" } } })


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
