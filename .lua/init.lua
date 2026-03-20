local fm = require "fullmoon"

fm.set_route("/", function()
  return "Redcap CMS is active."
end)

fm.run()
