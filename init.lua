local mod_storage = minetest.get_mod_storage()

local function mod_storage_get_bool(name, default)
   local value = mod_storage:get_string(name)
   if value == ''
      then return default
   else
      return value == 'true'
   end
end

local function mod_storage_set_bool(name, value)
   if value == true then
      value = 'true'
   else
      value = 'false'
   end
   return mod_storage:set_string(name, value)
end

verification = {}
verification.on = mod_storage_get_bool('on', true)
verification.default_privs = {interact = true, shout = true, home = true, tp=true, instruments=true}
verification.unverified_privs = {unverified = true, shout = true}
verification.release_location = {x = 111, y = 13, z = -507}
verification.holding_location = {x = 172, y = 29, z = -477}
verification.message = "Advanced server security is enabled.  Please wait for a moderator to verify you. | " ..
"Erweiterte Server sicherheit ist aktiviert. Bitte warten Sie, bis ein Moderator Sie bestätigt hat. | " ..
"La sécurité avancée du serveur est activée. S'il vous plaît attendre un modérateur pour vérifier que vous."
verification.announced = {}

local function announce_player(name)
   local umsg = "Player " .. name .. " is unverified."
   minetest.chat_send_all(umsg)
   if minetest.get_modpath("irc") then irc:say(umsg) end
   if minetest.get_modpath("irc2") then irc2:say(umsg) end
   minetest.chat_send_player(name, verification.message)
end

verification.verify = function(name)
   local player = minetest.get_player_by_name(name)
   if player == nil then return false, name .. " is not connected." end
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
      minetest.set_player_privs(name, verification.unverified_privs)
      minetest.after(1, function ()
         if minetest.get_player_by_name(name) == nil then return end
         announce_player(name)
         player:set_pos(verification.holding_location)
      end)
   else
      minetest.set_player_privs(name, verification.default_privs)
   end
end)

minetest.register_on_joinplayer(function(player)
   local name = player:get_player_name()
   if verification.on then
      minetest.after(1, function()
         -- If the player is already announced, do nothing
         if verification.announced[name] then
            verification.announced[name] = nil
            return
         end
         -- If the player quit, do nothing
         if minetest.get_player_by_name(name) == nil then return end
         -- If the player is verified, do nothing
         if not minetest.check_player_privs(name, {unverified = true}) then return end
         -- Announce the player
         announce_player(name)
      end)
   else
      if minetest.check_player_privs(name, {unverified = true}) then
         -- if an unverified player joins while verification is off, verify them.
         verification.verify(name)
      end
   end
end)

-- Send messages sent by unverified users to only moderators and admins
minetest.register_on_chat_message(function(name, message)
   if minetest.check_player_privs(name, {unverified = true}) then
      local cmsg = "[unverified] <" .. name .. "> " .. message
      for _, player in ipairs(minetest.get_connected_players()) do
         local name = player:get_player_name()
         if minetest.check_player_privs(name, {basic_privs = true}) then
            minetest.chat_send_player(name, minetest.colorize("red", cmsg))
         end
      end
      minetest.chat_send_player(name, cmsg)
      return true
   end
   return false
end)


local function override_cmd(cmd)
   local olddef = minetest.registered_chatcommands[cmd]
   if olddef then
      minetest.override_chatcommand(cmd, {
         description = olddef.description,
         params = olddef.params,
         privs = olddef.privs,
         func = function(name, param)
            if minetest.check_player_privs(name, {unverified = true}) then
               return false, "Only verified users can use /" .. cmd
            else
               return olddef.func(name, param)
            end
         end
      })
   end
end

-- disable these commands
override_cmd("me")
override_cmd("msg")
override_cmd("tell")
override_cmd("killme")
override_cmd("irc_msg")
override_cmd("irc2_msg")

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
      mod_storage_set_bool('on', verification.on)
      local status = verification.on and "on" or "off"
      return true, "Player verification is now " .. status
   end
})
