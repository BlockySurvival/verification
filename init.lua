verification = {}
verification.on = true
verification.default_privs = {interact = true, shout = true, home = true}
verification.release_location = {x = 111, y = 13, z = -507}
verification.holding_location = {x = 172, y = 29, z = -477}
verification.message = "Advanced server security is enabled.  Please wait for a moderator to verify you. | " ..
"Erweiterte Server sicherheit ist aktiviert. Bitte warten Sie, bis ein Moderator Sie bestätigt hat. | " ..
"La sécurité avancée du serveur est activée. S'il vous plaît attendre un modérateur pour vérifier que vous."
verification.announced = {}

local function announce_player(player, name)
   local umsg = "Player " .. name .. " is unverified."
   minetest.chat_send_all(umsg)
   if minetest.get_modpath("irc") then irc:say(umsg) end
   if minetest.get_modpath("irc2") then irc2:say(umsg) end
   minetest.chat_send_player(name, verification.message)
end

verification.verify = function(name)
   local player = minetest.get_player_by_name(name)
   if player == nil then return false, name .. " is not a valid player." end
   if not minetest.check_player_privs(name, {unverified = true}) then return false, name .. " is already verified."  end
   minetest.set_player_privs(name, verification.default_privs)
   minetest.chat_send_player(name, "You've been verified! Welcome to Blocky Survival! :D")
   player:set_pos(verification.release_location)
   return true, "Verified " .. name
end

minetest.register_on_newplayer(function(player)
   local name = player:get_player_name()
   if verification.on then
      verification.announced[name] = true
      minetest.set_player_privs(name, {unverified = true, shout = true})
      minetest.after(1, function ()
         if minetest.get_player_by_name(name) == nil then return end
         announce_player(player, name)
         player:set_pos(verification.holding_location)
      end)
   else
      minetest.set_player_privs(name, verification.default_privs)
   end
end)

minetest.register_on_joinplayer(function(player)
   if verification.on then
      local n = player:get_player_name()
      minetest.after(1, function()
         -- If the player is already announced, do nothing
         if verification.announced[n] then
            verification.announced[n] = nil
            return
         end
         -- If the player quit, do nothing
         if minetest.get_player_by_name(n) == nil then return end
         -- If the player is verified, do nothing
         if not minetest.check_player_privs(n, {unverified = true}) then return end
         -- Announce the player
         announce_player(player, n)
      end)
   else
      local n = player:get_player_name()
      if minetest.check_player_privs(n, {unverified = true}) then
         -- if an unverified player joins while verification is off, verify them.
         verification.verify(n)
      end
   end
end)

-- Send messages sent by unverified users to only moderators and admins
minetest.register_on_chat_message(function(name, message)
   local p = minetest.get_player_privs(name)
   if minetest.check_player_privs(name, {unverified = true}) then
      local cmsg = "[unverified] <" .. name .. "> " .. message
      for _, player in ipairs(minetest.get_connected_players()) do
         local n = player:get_player_name()
         if minetest.check_player_privs(n, {basic_privs = true}) then
            minetest.chat_send_player(n, minetest.colorize("red", cmsg))
         end
      end
      minetest.chat_send_player(name, cmsg)
      return true
   end
   return false
end)

-- Disable the use of /me for unverified users
local oldme = minetest.registered_chatcommands["me"]
local oldmefunc = minetest.registered_chatcommands["me"].func
minetest.override_chatcommand("me", {
   params = oldme.params,
   privs = oldme.privs,
   func = function(name, param)
      local p = minetest.get_player_privs(name)
      if p.unverified == nil then
         return oldmefunc(name, param)
      else
         return false, "Only verified users can use /me"
      end
   end
})

-- Disable PMs from unverified users
local olddef = minetest.registered_chatcommands["msg"]
local oldfunc = minetest.registered_chatcommands["msg"].func
minetest.override_chatcommand("msg", {
   params = olddef.params,
   privs = olddef.privs,
   func = function(name, param)
      local p = minetest.get_player_privs(name)
      if p.unverified == nil then
         return oldfunc(name, param)
      else
         return false, "Only verified users can send private messages"
      end
   end
})

-- Verify command
minetest.register_chatcommand("verify", {
   params = "<name>",
   description = "Verify player",
   privs = {basic_privs = true},
   func = function(name, param)
      return verification.verify(param)
   end
})

-- Toggle verification command
minetest.register_chatcommand("toggle_verification", {
   params = "",
   description = "Enable / disable player verification",
   privs = {server = true},
   func = function(_, _)
      verification.on = not verification.on
      local status = verification.on and "on" or "off"
      return true, "Player verification is now " .. status
   end
})
