--!strict
local Test = require("../../tests/lib/Test")
return Test.suite("Demo/Broken", function(t)
	t.it("never loads" function() end) -- syntax error on purpose
end)
