local M = {}

local utils = {
	bufnr = 0,
	keys = {
		bs = "<bs>",
		del = "<del>",
		x = "x",
	},
	direction = {
		left = "left",
		right = "right",
	},
	opposite = {
		left = "right",
		right = "left",
	},
	direction_step = {
		left = -1,
		right = 1,
	},
	seek_spaces = {
		left = "%s*$",
		right = "^%s*",
	},
	seek_punctuation = {
		left = "%p$",
		right = "^%p",
	},
}

local store = {
	pairs = {
		ft = {},
		default = {},
	},
	rules = {
		ft = {},
		default = {},
	},
	patterns = {
		ft = {},
		default = {},
	},
	filetypes = {},
}

M.config = {
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

M.setup = function(config)
	M.config = vim.tbl_deep_extend("force", vim.deepcopy(M.config), config or {})
	if M.config.default_pairs then
		for _, pair in ipairs(M.config.default_pairs) do
			pair.filetypes = pair.filetypes or nil
			pair.not_filetypes = pair.not_filetypes or nil

			M.insert_pair({
				left = pair.left,
				right = pair.right,
				disable_right = pair.disable_right or M.config.disable_right_default_pairs or false,
			}, { filetypes = pair.filetypes, not_filetypes = pair.not_filetypes })
		end
	end
	M.config.default_pairs = nil
end

local function insert_undo()
	if not M.config.disable_undo and vim.fn.mode() == "i" then
		local mark = vim.api.nvim_replace_termcodes("<c-g>u", true, false, true)
		vim.api.nvim_feedkeys(mark, "n", false)
	end
end

local function get_or_create_filetype(filetype)
	local ft = store.filetypes[filetype]

	if not ft then
		ft = {
			index = #store.filetypes + 1,
			pairs = {},
			patterns = {},
			rules = {},
		}
		store.filetypes[filetype] = ft
	end

	return ft
end

local function insert_into(context, elem)
	if context.filetypes then
		local store_ft_index = #context.ft_store + 1
		for _, filetype in ipairs(context.filetypes) do
			local ft = get_or_create_filetype(filetype)
			local ft_list = ft[context.ft_list]
			table.insert(ft_list, store_ft_index)
		end
		table.insert(context.ft_store, elem)
		return
	end

	if context.not_filetypes then
		elem.not_filetypes = {}
		for _, filetype in ipairs(context.not_filetypes) do
			local _ = get_or_create_filetype(filetype)
			elem.not_filetypes[filetype] = true
		end
	end
	table.insert(context.default, elem)
end

local function escape_pattern(text)
	return text:gsub("([%p])", "%%%1")
end

M.insert_pair_rule = function(config, context)
	local pair = {
		pattern = {
			left = config.left .. "$",
			right = "^" .. config.right,
		},
		disable_right = config.disable_right or false,
		not_filetypes = nil,
	}

	insert_into(context, pair)
end

---@param config { left: string, right: string, disable_right?: boolean }
---@param opts? { filetypes: string[], not_filetypes: string[] }
M.insert_pair = function(config, opts)
	if not config or not config.left and config.right then
		return
	end

	opts = opts or {}
	local context = {
		default = store.pairs.default,
		ft_store = store.pairs.ft,
		ft_list = "pairs",
		filetypes = opts.filetypes or nil,
		not_filetypes = opts.not_filetypes or nil,
	}

	config.left = escape_pattern(config.left)
	config.right = escape_pattern(config.right)

	M.insert_pair_rule(config, context)
end

---@param config { left: string, right: string, disable_right?: boolean }
---@param opts? {  not_filetypes?: string[] }
M.insert_default_pairs_priority = function(config, opts)
	if not config or not config.left and config.right then
		return
	end

	opts = opts or {}

	config.left = escape_pattern(config.left)
	config.right = escape_pattern(config.right)

	local pair = {
		pattern = {
			left = config.left .. "$",
			right = "^" .. config.right,
		},
		disable_right = config.disable_right or false,
		not_filetypes = nil,
	}

	if opts.not_filetypes then
		pair.not_filetypes = {}
		for _, filetype in ipairs(opts.not_filetypes) do
			local _ = get_or_create_filetype(filetype)
			pair.not_filetypes[filetype] = true
		end
	end

	table.insert(store.pairs.default, 1, pair)
end

---@param config { left: string, right: string, disable_right?: boolean }
---@param opts? { filetypes?: string[], not_filetypes?: string[] }
M.insert_rule = function(config, opts)
	if not config or not config.left and config.right then
		return
	end

	opts = opts or {}
	local context = {
		default = store.rules.default,
		ft_store = store.rules.ft,
		ft_list = "rules",
		filetypes = opts.filetypes or nil,
		not_filetypes = opts.not_filetypes or nil,
	}

	M.insert_pair_rule(config, context)
end

---@param config { pattern: string, prefix?: string, suffix?: string, disable_right?: boolean }
---@param opts? { filetypes?: string[], not_filetypes?: string[] }
M.insert_pattern = function(config, opts)
	if not config or not config.pattern then
		return
	end

	opts = opts or {}
	local context = {
		default = store.patterns.default,
		ft_store = store.patterns.ft,
		ft_list = "patterns",
		filetypes = opts.filetypes or nil,
		not_filetypes = opts.not_filetypes or nil,
	}

	-- Adds wildcards in the pattern and aditional rules.
	-- Right: "^(pattern)item.suffix"
	-- Left: "item.prefix(pattern)$"
	local config_pattern = "(" .. config.pattern .. ")"
	local pattern = {
		pattern = {
			left = (config.prefix or "") .. config_pattern .. "$",
			right = "^" .. config_pattern .. (config.suffix or ""),
		},
		disable_right = config.disable_right or false,
		not_filetypes = nil,
	}

	insert_into(context, pattern)
end

---@param pattern string
---@param config { left: string, right?: string, disable_right?: boolean, not_filetypes?: string[] }
M.edit_default_pairs = function(pattern, config)
	if not config then
		return
	end

	local left = config.left or nil
	local right = config.right or nil
	local disable_right = config.disable_right or nil
	local not_filetypes = config.not_filetypes or nil

	pattern = escape_pattern(pattern) .. "$"

	local default_pairs = store.pairs.default
	for _, pair in ipairs(default_pairs) do
		if pair.pattern.left == pattern then
			if left then
				pair.pattern.left = left
			end

			if right then
				pair.pattern.right = right
			end

			if disable_right then
				pair.disable_right = disable_right
			end

			if not_filetypes then
				pair.not_filetypes = pair.not_filetypes or {}
				for _, filetype in ipairs(not_filetypes) do
					local _ = get_or_create_filetype(filetype)
					pair.not_filetypes[filetype] = true
				end
			end

			break
		end
	end
end

---@param pattern string
M.remove_pattern_from_default_pairs = function(pattern)
	if pattern == "" then
		return
	end

	pattern = escape_pattern(pattern) .. "$"

	local default_pairs = store.pairs.default
	for i, pair in ipairs(default_pairs) do
		if pair.pattern.left == pattern then
			table.remove(default_pairs, i)
			break
		end
	end
end

local function in_ignore_list(item, filetype)
	return item.not_filetypes and item.not_filetypes[filetype]
end

local function count_pattern(line, pattern)
	local match = line:match(pattern)
	return (match and #match) or 0
end

local function get_range_line(col, len, direction)
	if direction == utils.direction.left then
		return 1, col
	end
	return col, len
end

local function get_range_lines(left_row, left_col, right_row, right_col, direction)
	if direction == utils.direction.left then
		return right_row, right_col, left_row, left_col
	end
	return left_row, left_col, right_row, right_col
end

local function calc_col(col, len, direction)
	if direction == utils.direction.left then
		return col - len, col
	end
	return col - 1, col + len - 1
end

---@param slice string
---@param col integer
---@param direction any
---@return string
---@return integer
local function seek_spaces(slice, col, direction)
	local match = slice:match(utils.seek_spaces[direction])
	if direction == utils.direction.left then
		return slice:sub(1, #slice - #match), col - #match
	end
	return slice:sub(#match + 1), col + #match
end

local function seek_line(row, direction)
	row = row + utils.direction_step[direction]
	local line = vim.api.nvim_buf_get_lines(utils.bufnr, row, row + 1, false)[1] or ""
	local col = (direction == utils.direction.left and #line) or 1
	return line, row, col
end

---@param text string
---@param row integer
---@param col integer
---@param direction any
---@return string|nil
---@return integer
---@return integer
local function eat_empty_lines(text, row, col, direction)
	local rows = vim.api.nvim_buf_line_count(0)
	if (col <= 0 and row <= 0) or (col > #text and row + 1 >= rows) then
		return nil, row, col
	end

	local start_col, end_col = get_range_line(col, #text, direction)
	local slice = text:sub(start_col, end_col)
	slice, col = seek_spaces(slice, col, direction)

	if col > 0 and col <= #text then
		return slice, row, col
	end

	while row >= 0 and row <= rows do
		text, row, col = seek_line(row, direction)
		if not text:match("^%s*$") then
			break
		end
	end

	start_col, end_col = get_range_line(col, #text, direction)
	slice = text:sub(start_col, end_col)
	slice, col = seek_spaces(slice, col, direction)
	row = math.min(rows - 1, math.max(row, 0))
	return slice, row, col
end

local function consume_spaces_and_lines(text, row, col, direction, separator)
	local line, new_row, new_col = eat_empty_lines(text, row, col, direction)

	if not line then
		return -1, -1
	end

	local left_row, left_col, right_row, right_col = get_range_lines(row, col, new_row, new_col, direction)

	if direction == utils.direction.right then
		left_col = left_col - 1
		right_col = right_col - 1
	end

	vim.api.nvim_buf_set_text(utils.bufnr, left_row, left_col, right_row, right_col, { separator })

	return left_row, left_col
end

---@param opts table
local function join_line(row, opts)
	opts = opts or {}
	opts.separator = opts.separator or M.config.join_line.separator or ""
	opts.times = opts.times or M.config.join_line.times or 1

	local line = vim.api.nvim_get_current_line()
	local separator = string.rep(opts.separator, opts.times)
	consume_spaces_and_lines(line, row, #line + 1, utils.direction.right, separator)
end

---@param context table
---@param pattern string
---@return boolean
local function delete_pattern(context, pattern)
	local count = count_pattern(context.line.slice, pattern)

	if count > 0 then
		local start_col, end_col = calc_col(context.line.col, count, context.direction)

		context.line.col = start_col

		insert_undo()
		vim.api.nvim_buf_set_text(utils.bufnr, context.line.row, start_col, context.line.row, end_col, {})
		return true
	end

	return false
end

---@param context table
---@param left string
---@param right string
---@return boolean
local function delete_pairs(context, left, right)
	local left_pattern, right_pattern = left, right
	if context.direction == utils.direction.right then
		left_pattern, right_pattern = right, left
	end

	local left_count = count_pattern(context.line.slice, left_pattern)

	if left_count > 0 then
		if not context.lookup_line.slice then
			local col = context.line.col + utils.direction_step[utils.opposite[context.direction]]
			local slice = nil
			local row = 0

			slice, row, col =
				eat_empty_lines(context.line.text, context.line.row, col, utils.opposite[context.direction])

			if not slice then
				context.lookup_line.valid = false
				return false
			end

			context.lookup_line.slice = slice
			context.lookup_line.row = row
			context.lookup_line.col = col
		end

		local right_count = count_pattern(context.lookup_line.slice, right_pattern)

		if right_count > 0 then
			local left_row, left_col, right_row, right_col = get_range_lines(
				context.line.row,
				context.line.col,
				context.lookup_line.row,
				context.lookup_line.col,
				utils.opposite[context.direction]
			)

			if context.direction == utils.direction.left then
				left_col = left_col - left_count
				right_col = right_col + right_count - 1
			elseif context.direction == utils.direction.right then
				left_col = left_col - right_count
				right_col = right_col + left_count - 1
			end

			context.line.row = left_row
			context.line.col = left_col

			insert_undo()
			vim.api.nvim_buf_set_text(utils.bufnr, left_row, left_col, right_row, right_col, {})
		end

		return left_count > 0 and right_count > 0
	end

	return false
end

---@param row integer
---@param col integer
---@param direction string
---@return  { [1]: number, [2]: number }?
local function delete_word(row, col, direction)
	local line = vim.api.nvim_get_current_line()
	local start_col, end_col = get_range_line(col, #line, direction)

	local context = {
		direction = direction,
		line = {
			text = line,
			slice = line:sub(start_col, end_col),
			row = row,
			col = col,
		},
		lookup_line = {
			valid = true,
		},
	}

	if col == 0 or col > #line then
		if M.config.delete_blank_lines_until_non_whitespace then
			insert_undo()
			row, col = consume_spaces_and_lines(line, row, col, direction, "")
			return { row, col }
		else
			local key = (direction == utils.direction.left and utils.keys.bs) or utils.keys.del
			vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(key, true, false, true), "n", false)
		end
		return nil
	end

	if delete_pattern(context, utils.seek_spaces[direction]) then
		return { context.line.row, context.line.col }
	end

	local bufnr = vim.api.nvim_get_current_buf()
	local filetype = vim.bo[bufnr].filetype
	local config_filetype = store.filetypes[filetype]

	local is_punctuation = line:sub(col, col):match("%p")
	local is_right = direction == utils.direction.right
	local ignore_right = M.config.disable_right and is_right

	if config_filetype then
		if not ignore_right then
			for _, index in ipairs(config_filetype.rules) do
				if not context.lookup_line.valid then
					break
				end
				local item = store.rules.ft[index]
				if
					not (item.disable_right and is_right)
					and delete_pairs(context, item.pattern.left, item.pattern.right)
				then
					return { context.line.row, context.line.col }
				end
			end
		end

		for _, index in ipairs(config_filetype.patterns) do
			local item = store.patterns.ft[index]
			if not (item.disable_right and is_right) and delete_pattern(context, item.pattern[direction]) then
				return { context.line.row, context.line.col }
			end
		end

		if not ignore_right and is_punctuation then
			for _, index in ipairs(config_filetype.pairs) do
				if not context.lookup_line.valid then
					break
				end
				local item = store.pairs.ft[index]
				if
					not (item.disable_right and is_right)
					and delete_pairs(context, item.pattern.left, item.pattern.right)
				then
					return { context.line.row, context.line.col }
				end
			end
		end
	end

	if not ignore_right then
		for _, item in ipairs(store.rules.default) do
			if not context.lookup_line.valid then
				break
			end
			if not (item.disable_right and is_right) and not in_ignore_list(item, filetype) then
				if delete_pairs(context, item.pattern.left, item.pattern.right) then
					return { context.line.row, context.line.col }
				end
			end
		end
	end

	for _, item in ipairs(store.patterns.default) do
		if not (item.disable_right and is_right) and not in_ignore_list(item, filetype) then
			if delete_pattern(context, item.pattern[direction]) then
				return { context.line.row, context.line.col }
			end
		end
	end

	if not ignore_right and is_punctuation then
		for _, item in ipairs(store.pairs.default) do
			if not context.lookup_line.valid then
				break
			end
			if not (item.disable_right and is_right) and not in_ignore_list(item, filetype) then
				if delete_pairs(context, item.pattern.left, item.pattern.right) then
					return { context.line.row, context.line.col }
				end
			end
		end
	end

	if is_punctuation then
		if M.config.multi_punctuation then
			if delete_pattern(context, M.config.allowed_multi_punctuation[direction]) then
				return { context.line.row, context.line.col }
			end
		end
		if delete_pattern(context, utils.seek_punctuation[direction]) then
			return { context.line.row, context.line.col }
		end
	end

	for _, default in pairs(M.config.defaults) do
		if delete_pattern(context, default[direction]) then
			return { context.line.row, context.line.col }
		end
	end
end

---@param row integer
---@param col integer
---@param direction string
local function delete(key, row, col, direction)
	local line = vim.api.nvim_get_current_line()
	local char = line:sub(col, col)
	local found = true

	if char:match("%p") then
		local bufnr = vim.api.nvim_get_current_buf()
		local filetype = vim.bo[bufnr].filetype
		local config_filetype = store.filetypes[filetype]

		local start_col, end_col = get_range_line(col, #line, direction)

		local context = {
			direction = direction,
			line = {
				text = line,
				slice = line:sub(start_col, end_col),
				row = row,
				col = col,
			},
			lookup_line = {
				valid = true,
			},
		}

		if config_filetype then
			for _, index in ipairs(config_filetype.pairs) do
				if not context.lookup_line.valid then
					break
				end
				local item = store.pairs.ft[index]
				if delete_pairs(context, item.pattern.left, item.pattern.right) then
					return found
				end
			end
		end

		for _, item in ipairs(store.pairs.default) do
			if not context.lookup_line.valid then
				break
			end
			if not in_ignore_list(item, filetype) then
				if delete_pairs(context, item.pattern.left, item.pattern.right) then
					return found
				end
			end
		end
	end

	if vim.fn.mode() == "i" then
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(key, true, false, true), "n", true)
		return found
	end

	return not found
end

M.previous_word = function()
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	_ = delete_word(row - 1, col, utils.direction.left)
end

M.next_word = function()
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	_ = delete_word(row - 1, col + 1, utils.direction.right)
end

M.previous = function()
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	_ = delete(utils.keys.bs, row - 1, col, utils.direction.left)
end

M.next = function()
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	_ = delete(utils.keys.del, row - 1, col + 1, utils.direction.right)
end

M.previous_word_normal_mode = function()
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	col = (col + 1 == 1 and 0) or col + 1
	local new_pos = delete_word(row - 1, col, utils.direction.left)

	if new_pos then
		row, col = new_pos[1], new_pos[2]
		if col > 0 then
			vim.api.nvim_win_set_cursor(0, { row + 1, col - 1 })
		end
	end
end

M.next_word_normal_mode = function()
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	local line_len = #vim.api.nvim_get_current_line()
	col = col + 1
	col = (col == line_len and col + 1) or col

	local new_pos = delete_word(row - 1, col, utils.direction.right)

	if new_pos then
		row, col = new_pos[1], new_pos[2]
		if col > 0 and col < #vim.api.nvim_get_current_line() then
			vim.api.nvim_win_set_cursor(0, { row + 1, col })
		end
	end
end

M.previous_normal_mode = function()
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	if delete(utils.keys.bs, row - 1, col + 1, utils.direction.left) then
		return
	end

	if col > 0 then
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(utils.keys.x, true, false, true), "n", true)
		vim.api.nvim_win_set_cursor(0, { row, col - 1 })
	end
end

M.next_normal_mode = function()
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	if delete(utils.keys.del, row - 1, col + 1, utils.direction.right) then
		return
	end
	if col + 1 < #vim.api.nvim_get_current_line() then
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(utils.keys.x, true, false, true), "n", true)
	end
end

M.join = function(opts)
	local row, _ = unpack(vim.api.nvim_win_get_cursor(0))
	join_line(row - 1, opts)
end

return M
