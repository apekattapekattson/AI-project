--[[
	luau_shim
	---------
	Lets Luau-typed modules be require()'d from plain Lua 5.4 so the test
	suite can run in CI without Roblox.

	Strips Luau-only syntax (type annotations, `export type`, `::` casts,
	`--!strict`). The production module keeps its real Luau types — we do NOT
	dumb down shipping code to satisfy the test runner.

	Only handles the subset of Luau syntax actually used in this repo.
]]

local M = {}

local function stripTypes(src)
	local out = {}

	for line in (src .. "\n"):gmatch("(.-)\n") do
		-- Drop Luau-only lines wholesale.
		if line:match("^%s*%-%-!") then
			line = ""
		elseif line:match("^%s*export%s+type%s") or line:match("^%s*type%s+[%w_]+%s*=") then
			line = ""
		else
			-- `expr :: Type` casts  ->  `expr`
			line = line:gsub("%s*::%s*[%w_%.]+%s*%b()", "")
			line = line:gsub("%s*::%s*%b{}", "")
			line = line:gsub("%s*::%s*[%w_%.]+%??", "")

			-- Return type on a function signature:  ): Type  ->  )
			line = line:gsub("%)%s*:%s*%b()%s*$", ")")
			line = line:gsub("%)%s*:%s*[%w_%.%?]+%s*$", ")")

			-- Parameter annotations inside a function signature.
			if line:match("^%s*function%s") or line:match("^%s*local%s+function%s") then
				local head, params, tail = line:match("^(.-%()(.*)(%).*)$")
				if params then
					params = params
						:gsub("%s*:%s*[%w_%.]+%s*%b{}%s*", "")
						:gsub("%s*:%s*[%w_%.]+%b()%s*", "")
						:gsub("%s*:%s*[%w_%.%?]+%s*", "")
					line = head .. params .. tail
				end
			end
		end

		out[#out + 1] = line
	end

	return table.concat(out, "\n")
end

M.stripTypes = stripTypes

function M.requireLuau(path)
	local f = assert(io.open(path, "r"), "cannot open " .. path)
	local src = f:read("*a")
	f:close()

	local stripped = stripTypes(src)
	local chunk, err = load(stripped, "@" .. path)
	if not chunk then
		error(("failed to load %s after type-strip: %s"):format(path, err), 0)
	end
	return chunk()
end

return M
