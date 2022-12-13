--[[
	https://github.com/awesomeusername69420/miscellaneous-gmod-stuff
]]

function Switch(TestValue, ...)
	local Default

	for _, v in ipairs({...}) do
		if v.Default then
			Default = v.Function
			continue
		end

		if TestValue == v.Value then
			v.Function()
			return
		end
	end

	if type(Default) == "function" then
		Default()
	end
end

function Case(TestValue, Function)
	return {
		Value = TestValue,
		Function = Function
	}
end

function Default(Function)
	return {
		Default = true,
		Function = Function
	}
end

Switch("sup", -- "What's up dog?"
	Case("sup", function() print("What's up dog?") end),
	Case("ur mom", function() print("fat") end),
	Default(function() print("What are you, fuckin' gay?") end)
)

Switch("ur mom", -- "fat"
	Case("sup", function() print("What's up dog?") end),
	Case("ur mom", function() print("fat") end),
	Default(function() print("What are you, fuckin' gay?") end)
)

Switch("wegwegwegew", -- "What are you, fuckin' gay?"
	Case("sup", function() print("What's up dog?") end),
	Case("ur mom", function() print("fat") end),
	Default(function() print("What are you, fuckin' gay?") end)
)
