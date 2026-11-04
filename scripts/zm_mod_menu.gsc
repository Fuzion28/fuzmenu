#using scripts\common\utility;
#using scripts\common\weapon;
#using scripts\common\callbacks;
#using scripts\common\status_effects\effect_charm;
#using scripts\mp\zm\systems\zm_armor;
#using scripts\mp\zm\systems\agent_manager;
// hashed game scripts, same list as ProjectNexus: perks, points, overrides, bgb, round flags
#using script_3b64eb40368c1450;
#using script_4e3b2b1d9542e66b;
#using script_4fca32f463c5e4fa;
#using script_25a8fa2ac8997425;
#using script_3a9d7a7cfee99885;
#using script_2301d27669c5a079;
#using script_aa3bac81ad4fc8e;
#using script_427ce33ec0c820cf;
#using script_4f24ca7a470a5fa8;
#using script_724b8f06df0c96b1;
#using script_734dce84c468439b;
// armor (namespace armor), public game script
#using script_1f6b7243f8d72fef;
#using script_53d9b43dfecd95ed;
// doorbuy (door purchase), public game script
#using script_681a06cc8e9fcb34;
// zone manager (spawn zones), public game script
#using script_7b92812967b04687;
// ai move speed stack (walk/run/sprint by priority), public game script
#using script_6c2f6a14fa53759e;
// equipment give (lethal/tactical slots), public game script
#using script_6b0663a111030b30;
// zm_quest: main quest steps, jump-to-step used by the boss fight option
#using script_c1369b1abe9a0d1;
// lastStand: self revive count, public game script
#using script_8c8e132af264960;
// loot (namespace_952965bfef60cff8): loot ID <-> ref, used by the saved builds
#using script_1ade2fa7cae9593d;

#namespace zm_mod_menu;

// Kinds: 0 close, 1 back, 2 submenu, 4 toggle, 5 action, 6 round, 7 powerup, 8 give weapon, 9 action with a value.

autoexec init()
{
    if ( !utility::iszm() )
    {
        return;
    }
    if ( isdefined( level.zmm_initialized ) )
    {
        return;
    }
    level.zmm_initialized = 1;
    level.zmm_name = "FuzMenu";
    level.zmm_footer = "[{+speed_throw}] Up   [{+attack}] Down   [{+activate}] OK   [{+melee}] Back";
    level.zmm_hint = "[{+speed_throw}] + [{+melee}] to open";
    level.zmm_visible = 12;
    level.zmm_themes = [ ( 0, 0.6, 1 ), ( 1, 0.2, 0.2 ), ( 0.2, 1, 0.35 ), ( 0.7, 0.3, 1 ), ( 1, 0.6, 0 ), ( 1, 0.85, 0.2 ) ];
    level.zmm_theme_names = [ "blue", "red", "green", "purple", "orange", "gold" ];
    // zm_mod_menu_post.lua draws the menu from zmm_view and sets zmm_lua to "1"
    setdvar( @"zmm_view", "" );
    setdvar( @"zmm_lua", "" );
    setdvar( @"zmm_exec", "" );
    setdvar( @"zmm_recoil", "" );
    setdvar( @"zmm_hud", "" );
    setdvar( @"zmm_big", "" );
    // the Lua can only write dvars that already exist
    setdvar( @"zmm_up", "0" );
    setdvar( @"zmm_down", "0" );
    // Old School parts that are on, read by the game-wide hooks
    level.zmm_cl = [];
    menu_build_pages();
    level callback::add( #"player_spawned", &menu_on_spawned );
    level callback::add( #"player_death", &menu_on_death );
    level callback::add( #"player_disconnect", &menu_on_disconnect );
    // player damage event used by Nexus 1.3: params.var_a87b62c261a8d114 is the damage, var_f5a880abf0b199dc the means of death
    level callback::add( #"hash_652eb614ba902b3d", &menu_on_damaged );
    level callback::add( "on_zombie_ai_damaged", &menu_on_zombie_damaged );
    level thread menu_scan_players();
}

function menu_build_pages()
{
    level.zmm_pages = [];
    level.zmm_labels = [];

    menu_add_page( "Main", "MAIN MENU", [
        [ "Player", 2, "Player" ],
        [ "OP Mode", 4, "god_all" ],
        [ "Teleports", 2, "Teleports" ],
        [ "Give a weapon", 2, "WeapGive" ],
        [ "Wonder weapons", 2, "Wonder" ],
        [ "Shooting options", 2, "WeapFire" ],
        [ "Damage", 2, "WeapDmg" ],
        [ "Upgrade", 2, "WeapUp" ],
        [ "Perks", 2, "Perks" ],
        [ "Gobblegums", 2, "Gums" ],
        [ "Points & scrap", 2, "Money" ],
        [ "Zombies", 2, "Zombies" ],
        [ "Rounds", 2, "Rounds" ],
        [ "Bonus", 2, "Powerups" ],
        [ "World", 2, "World" ],
        [ "Forge", 2, "Forge" ],
        [ "Old School Zombies", 2, "OldSchool" ],
        [ "Settings", 2, "Settings" ],
        [ "Close", 0, "" ]
    ] );

    menu_add_page( "Player", "PLAYER", [
        [ "God mode", 4, "god_mode" ],
        [ "Noclip (same as N key)", 5, "noclip" ],
        [ "Cinematic mode", 4, "cinema" ],
        [ "Zombies ignore me", 4, "ignoreme" ],
        [ "Infinite points", 4, "inf_points" ],
        [ "Free purchases", 4, "free_buy" ],
        [ "Speed x1.6", 4, "speed" ],
        [ "No fall damage", 4, "no_fall" ],
        [ "No explosive self-damage", 4, "no_self_explo" ],
        [ "Restore health", 5, "health" ],
        [ "Self revives x10", 5, "full_revive" ],
        [ "Infinite tactical sprint", 4, "tacsprint" ],
        [ "Jump height", 2, "Jump" ],
        [ "Gravity", 2, "Gravity" ],
        [ "Armor", 2, "Armor" ],
        [ "Back", 1, "" ]
    ] );

    menu_add_page( "Jump", "JUMP HEIGHT", [
        [ "Jump x1.5", 9, "jump", 1.5 ],
        [ "Jump x2", 9, "jump", 2 ],
        [ "Jump x3", 9, "jump", 3 ],
        [ "Jump x4", 9, "jump", 4 ],
        [ "Normal jump", 9, "jump", 1 ],
        [ "Back", 1, "" ]
    ] );

    menu_add_page( "Gravity", "GRAVITY", [
        [ "Gravity x0.25", 9, "gravity", 0.25 ],
        [ "Gravity x0.5", 9, "gravity", 0.5 ],
        [ "Gravity x0.75", 9, "gravity", 0.75 ],
        [ "Gravity x1.5", 9, "gravity", 1.5 ],
        [ "Gravity x2", 9, "gravity", 2 ],
        [ "Normal gravity", 9, "gravity", 1 ],
        [ "Back", 1, "" ]
    ] );

    menu_add_page( "Teleports", "TELEPORTS", [
        [ "Map locations", 9, "map_list", 0 ],
        [ "Save position", 5, "save_point" ],
        [ "Load position", 5, "load_point" ],
        [ "Return to spawn", 5, "spawn_point" ],
        [ "Unstuck", 5, "unstuck" ],
        [ "Back", 1, "" ]
    ] );

    menu_add_page( "Perks", "PERKS", [
        [ "All perks", 5, "give_perks" ],
        [ "Eternal perks", 5, "eternal_perks" ],
        [ "Remove all perks", 5, "revoke_perks" ],
        [ "Pick a perk", 9, "perk_list", 0 ],
        [ "Free perks", 4, "free_perks" ],
        [ "Back", 1, "" ]
    ] );

    menu_add_page( "WeapFire", "SHOOTING OPTIONS", [
        [ "Infinite ammo", 4, "extra_ammo" ],
        [ "Rapid fire", 4, "rapid_fire" ],
        [ "Fast reload", 4, "fast_reload" ],
        [ "Free wall ammo", 4, "free_ammo" ],
        [ "No recoil", 4, "no_recoil" ],
        [ "Aimbot (while aiming)", 4, "aimbot" ],
        [ "Wallhack (zombies)", 4, "wallhack" ],
        [ "Infinite equipment", 4, "equip_inf" ],
        [ "Infinite field upgrade", 4, "upgrade_inf" ],
        [ "Unlimited weapons", 4, "no_gun_limit" ],
        [ "Refill weapons", 5, "extra_refill" ],
        [ "Back", 1, "" ]
    ] );

    menu_add_page( "WeapDmg", "DAMAGE", [
        [ "Weapon damage", 2, "DmgMult" ],
        [ "Critical damage", 2, "CritMult" ],
        [ "Melee damage", 2, "MeleeMult" ],
        [ "Ammo mods", 2, "AmmoMod" ],
        [ "Back", 1, "" ]
    ] );

    menu_add_page( "WeapUp", "UPGRADE", [
        [ "Pack-a-Punch", 2, "Pap" ],
        [ "Weapon rarity", 2, "Rarity" ],
        [ "Auto Ultra + PAP 4", 4, "firepower" ],
        [ "Random camo", 5, "random_camo" ],
        [ "Save a build", 2, "BuildSave" ],
        [ "Load a build", 2, "BuildLoad" ],
        [ "Back", 1, "" ]
    ] );

    menu_add_page( "BuildSave", "SAVE A BUILD", [
        [ "Slot 1", 9, "build_save", 1 ],
        [ "Slot 2", 9, "build_save", 2 ],
        [ "Slot 3", 9, "build_save", 3 ],
        [ "Slot 4", 9, "build_save", 4 ],
        [ "Slot 5", 9, "build_save", 5 ],
        [ "Slot 6", 9, "build_save", 6 ],
        [ "Slot 7", 9, "build_save", 7 ],
        [ "Slot 8", 9, "build_save", 8 ],
        [ "Slot 9", 9, "build_save", 9 ],
        [ "Slot 10", 9, "build_save", 10 ],
        [ "Back", 1, "" ]
    ] );

    menu_add_page( "BuildLoad", "LOAD A BUILD", [
        [ "Slot 1", 9, "build_load", 1 ],
        [ "Slot 2", 9, "build_load", 2 ],
        [ "Slot 3", 9, "build_load", 3 ],
        [ "Slot 4", 9, "build_load", 4 ],
        [ "Slot 5", 9, "build_load", 5 ],
        [ "Slot 6", 9, "build_load", 6 ],
        [ "Slot 7", 9, "build_load", 7 ],
        [ "Slot 8", 9, "build_load", 8 ],
        [ "Slot 9", 9, "build_load", 9 ],
        [ "Slot 10", 9, "build_load", 10 ],
        [ "Back", 1, "" ]
    ] );

    menu_add_page( "WeapGive", "GIVE A WEAPON", [
        [ "Give equipment", 2, "Equip" ],
        [ "My loadout primary", 9, "class_pri", 0 ],
        [ "My loadout secondary", 9, "class_sec", 0 ],
        [ "Random weapon", 5, "random_gun" ],
        [ "Remove held weapon", 5, "take_gun" ],
        [ "Assault rifles", 2, "W_ar" ],
        [ "SMGs", 2, "W_sm" ],
        [ "LMGs", 2, "W_lm" ],
        [ "Shotguns", 2, "W_sh" ],
        [ "Marksman rifles", 2, "W_dm" ],
        [ "Sniper rifles", 2, "W_sn" ],
        [ "Pistols", 2, "W_pi" ],
        [ "Launchers", 2, "W_la" ],
        [ "Melee", 2, "W_me" ],
        [ "Back", 1, "" ]
    ] );

    menu_add_page( "Pap", "PACK-A-PUNCH", [
        [ "PAP I", 9, "pap", 1 ],
        [ "PAP II", 9, "pap", 2 ],
        [ "PAP III", 9, "pap", 3 ],
        [ "PAP IV", 9, "pap", 4 ],
        [ "Free PaP", 4, "free_pap" ],
        [ "Back", 1, "" ]
    ] );

    menu_add_page( "Rarity", "WEAPON RARITY", [
        [ "Common", 9, "rarity", 0 ],
        [ "Uncommon", 9, "rarity", 1 ],
        [ "Rare", 9, "rarity", 2 ],
        [ "Epic", 9, "rarity", 3 ],
        [ "Legendary", 9, "rarity", 4 ],
        [ "Ultra", 9, "rarity", 5 ],
        [ "Back", 1, "" ]
    ] );

    menu_weapon_page( "W_ar", "ASSAULT RIFLES", "ar", [ "albatross", "condor", "eagle", "egret", "emu", "falcon", "finch", "hawk", "heron", "kite", "kiwi", "macaw", "vulture", "wren" ] );
    menu_weapon_page( "W_sm", "SMGS", "sm", [ "bear", "bengal", "civet", "cobra", "gecko", "hyena", "komodo", "mammoth", "marmot", "orca", "otter", "puma", "serval", "stoat", "zebra" ] );
    menu_weapon_page( "W_lm", "LMGS", "lm", [ "hades", "hildr", "typhon", "zeus" ] );
    menu_weapon_page( "W_sh", "SHOTGUNS", "sh", [ "akita", "corso", "husky", "shepherd", "terrier" ] );
    menu_weapon_page( "W_dm", "MARKSMAN RIFLES", "dm", [ "kara", "oman", "samar", "scotia", "solomon", "tasman" ] );
    menu_weapon_page( "W_sn", "SNIPER RIFLES", "sn", [ "aden", "baltic", "caspian", "coral", "drake" ] );
    menu_weapon_page( "W_pi", "PISTOLS", "pi", [ "alcor", "atlas", "orion", "timir" ] );
    menu_weapon_page( "W_la", "LAUNCHERS", "la", [ "fang", "polis" ] );
    menu_weapon_page( "W_me", "MELEE", "me", [ "ballisticknife", "castor", "knife", "maru", "nashira", "saiph", "shockbaton", "wasat" ] );

    menu_add_page( "Equip", "GIVE EQUIPMENT", [
        [ "Kazimir (black hole)", 9, "equip_t", "equip_blackhole_bomb" ],
        [ "Decoy", 9, "equip_t", "equip_decoy" ],
        [ "Monkey bomb", 9, "equip_t", "equip_monkey_bomb" ],
        [ "Stim", 9, "equip_t", "equip_adrenaline" ],
        [ "Stun grenade", 9, "equip_t", "equip_concussion" ],
        [ "Flash", 9, "equip_t", "equip_flash" ],
        [ "Smoke", 9, "equip_t", "equip_smoke" ],
        [ "Frag grenade", 9, "equip_l", "equip_frag" ],
        [ "Semtex", 9, "equip_l", "equip_semtex" ],
        [ "Molotov", 9, "equip_l", "equip_molotov" ],
        [ "Cluster grenade", 9, "equip_l", "equip_cluster_grenade" ],
        [ "Throwing knife", 9, "equip_l", "equip_throwing_knife" ],
        [ "Combat axe", 9, "equip_l", "equip_combataxe" ],
        [ "C4", 9, "equip_l", "equip_c4" ],
        [ "Claymore", 9, "equip_l", "equip_claymore" ],
        [ "Back", 1, "" ]
    ] );

    menu_add_page( "Wonder", "WONDER WEAPONS", [
        [ "Necrofluid", 8, "sat_ww_firefly_zm" ],
        [ "Nekomancer", 8, "sat_ww_hornet_zm" ],
        [ "Jotunn Star", 8, "sat_ww_locust_zm" ],
        [ "Blundergat", 8, "sat_ww_mantis_zm" ],
        [ "Sundergat", 8, "sundergat" ],
        [ "LGM-1", 8, "sat_ww_ruby_zm" ],
        [ "Warden's Blight", 8, "sat_ww_scarab_zm" ],
        [ "Ray Gun", 8, "sat_ww_raygun_mp" ],
        [ "Ray Gun Mk2", 8, "sat_ww_raygunmark2_mp" ],
        [ "Back", 1, "" ]
    ] );

    menu_add_page( "DmgMult", "WEAPON DAMAGE", [
        [ "Damage x2", 9, "dmg_mult", 2 ],
        [ "Damage x5", 9, "dmg_mult", 5 ],
        [ "Damage x10", 9, "dmg_mult", 10 ],
        [ "Damage x25", 9, "dmg_mult", 25 ],
        [ "Damage x100", 9, "dmg_mult", 100 ],
        [ "Normal damage", 9, "dmg_mult", 1 ],
        [ "Back", 1, "" ]
    ] );

    menu_add_page( "CritMult", "CRITICAL DAMAGE", [
        [ "Damage x2", 9, "crit_mult", 2 ],
        [ "Damage x5", 9, "crit_mult", 5 ],
        [ "Damage x10", 9, "crit_mult", 10 ],
        [ "Damage x25", 9, "crit_mult", 25 ],
        [ "Normal damage", 9, "crit_mult", 1 ],
        [ "Back", 1, "" ]
    ] );

    menu_add_page( "MeleeMult", "MELEE DAMAGE", [
        [ "Damage x2", 9, "melee_mult", 2 ],
        [ "Damage x5", 9, "melee_mult", 5 ],
        [ "Damage x10", 9, "melee_mult", 10 ],
        [ "Damage x25", 9, "melee_mult", 25 ],
        [ "Damage x100", 9, "melee_mult", 100 ],
        [ "Normal damage", 9, "melee_mult", 1 ],
        [ "Back", 1, "" ]
    ] );

    menu_add_page( "AmmoMod", "AMMO MODS", [
        [ "Brain Rot", 9, "ammo_mod", "brainrot" ],
        [ "Cryo Freeze", 9, "ammo_mod", "cryofreeze" ],
        [ "Dead Wire", 9, "ammo_mod", "deadwire" ],
        [ "Napalm Burst", 9, "ammo_mod", "napalmburst" ],
        [ "Shadow Rift", 9, "ammo_mod", "shadowvortex" ],
        [ "Shatter Blast", 9, "ammo_mod", "shatterblast" ],
        [ "Light Mend", 9, "ammo_mod", "lightray" ],
        [ "Back", 1, "" ]
    ] );

    menu_add_page( "Box", "MYSTERY BOX", [
        [ "Free mystery box", 4, "free_box" ],
        [ "Faster mystery box", 4, "fast_box" ],
        [ "Back", 1, "" ]
    ] );

    menu_add_page( "Money", "POINTS & SCRAP", [
        [ "Max points & scrap", 5, "fill_currency" ],
        [ "Points", 2, "Points" ],
        [ "Scrap", 2, "Salvage" ],
        [ "Points multiplier", 2, "PointsMult" ],
        [ "Scrap multiplier", 2, "SalvageMult" ],
        [ "Free crafting", 4, "free_craft" ],
        [ "Back", 1, "" ]
    ] );

    menu_add_page( "PointsMult", "POINTS MULTIPLIER", [
        [ "Points x2", 9, "points_mult", 2 ],
        [ "Points x5", 9, "points_mult", 5 ],
        [ "Points x10", 9, "points_mult", 10 ],
        [ "Normal points", 9, "points_mult", 1 ],
        [ "Back", 1, "" ]
    ] );

    menu_add_page( "SalvageMult", "SCRAP MULTIPLIER", [
        [ "Scrap x2", 9, "salvage_mult", 2 ],
        [ "Scrap x5", 9, "salvage_mult", 5 ],
        [ "Scrap x10", 9, "salvage_mult", 10 ],
        [ "Normal scrap", 9, "salvage_mult", 1 ],
        [ "Back", 1, "" ]
    ] );
    menu_currency_page( "Points", "POINTS", "points" );
    menu_currency_page( "Salvage", "SCRAP", "salvage" );

    menu_add_page( "Armor", "ARMOR", [
        [ "1 plate", 9, "armor", 1 ],
        [ "2 plates", 9, "armor", 2 ],
        [ "3 plates", 9, "armor", 3 ],
        [ "Golden armor", 4, "golden_armor" ],
        [ "Back shield (15 hits)", 4, "back_shield" ],
        [ "Back", 1, "" ]
    ] );

    menu_add_page( "OldSchool", "OLD SCHOOL ZOMBIES", [
        [ "Enable all", 4, "classic" ],
        [ "Old-school damage", 4, "old_school" ],
        [ "No armor", 4, "no_armor" ],
        [ "Back shield (15 hits)", 4, "back_shield" ],
        [ "OG specials & elites", 4, "og_specials" ],
        [ "Classic perk prices", 4, "cl_prices" ],
        [ "4 perks max (+1 every 20 rounds)", 4, "cl_perk_cap" ],
        [ "Random Wunderfizz", 4, "cl_fizz" ],
        [ "Quick Revive = self revive", 4, "cl_qr" ],
        [ "No super sprinters", 4, "cl_sprinters" ],
        [ "Zombie health past round 60", 4, "cl_health" ],
        [ "Classic points (traps pay 0)", 4, "cl_points" ],
        [ "No scrap", 4, "cl_salvage" ],
        [ "One-hit wonder weapons", 4, "cl_ww" ],
        [ "Back", 1, "" ]
    ] );

    menu_add_page( "Gums", "GOBBLEGUMS", [
        [ "Random gums", 5, "random_gums" ],
        [ "All gums", 9, "gum_list", 0 ],
        [ "Rares", 9, "gum_list", 1 ],
        [ "Epic", 9, "gum_list", 2 ],
        [ "Legendary", 9, "gum_list", 3 ],
        [ "Ultra", 9, "gum_list", 4 ],
        [ "Whimsical", 9, "gum_list", 5 ],
        [ "Back", 1, "" ]
    ] );

    menu_add_page( "GumAction", "GOBBLEGUM", [
        [ "Equip (free slot)", 9, "gum_equip", 0 ],
        [ "Use now", 9, "gum_equip", 1 ],
        [ "Back", 1, "" ]
    ] );

    menu_add_page( "Zombies", "ZOMBIES", [
        [ "Kill all zombies", 5, "clear_ai" ],
        [ "Leave one zombie", 5, "leave_one" ],
        [ "Despawn zombies", 4, "despawn" ],
        [ "Stop spawns", 4, "pause_spawn" ],
        [ "Zombies per round", 2, "ZombieCount" ],
        [ "Spawn rate", 2, "SpawnRate" ],
        [ "Friendly zombies", 5, "ally_bosses" ],
        [ "Tessie", 5, "tessie" ],
        [ "Zombie counter", 4, "zombie_counter" ],
        [ "Freeze zombies", 4, "freeze" ],
        [ "Zombies in a line (training)", 4, "no_spread" ],
        [ "Force spawn here", 5, "force_spawn" ],
        [ "Back", 1, "" ]
    ] );

    menu_add_page( "ZombieCount", "ZOMBIES PER ROUND", [
        [ "1 zombie", 9, "zombie_cap", 1 ],
        [ "6 zombies", 9, "zombie_cap", 6 ],
        [ "12 zombies", 9, "zombie_cap", 12 ],
        [ "24 zombies", 9, "zombie_cap", 24 ],
        [ "Normal count", 9, "zombie_cap", 0 ],
        [ "Back", 1, "" ]
    ] );

    menu_add_page( "SpawnRate", "SPAWN RATE", [
        [ "Spawns x0.5", 9, "spawn_rate", 0.5 ],
        [ "Spawns x2", 9, "spawn_rate", 2 ],
        [ "Spawns x4", 9, "spawn_rate", 4 ],
        [ "Normal spawns", 9, "spawn_rate", 1 ],
        [ "Back", 1, "" ]
    ] );

    menu_add_page( "Rounds", "ROUNDS", [
        [ "Round timer", 4, "round_timer" ],
        [ "Round +1", 6, 1, 1 ],
        [ "Round +5", 6, 5, 1 ],
        [ "Round +10", 6, 10, 1 ],
        [ "Round +100", 6, 100, 1 ],
        [ "Round -1", 6, -1, 1 ],
        [ "Round -5", 6, -5, 1 ],
        [ "Round -10", 6, -10, 1 ],
        [ "Round -100", 6, -100, 1 ],
        [ "Round 1", 6, 1, 0 ],
        [ "Round 10", 6, 10, 0 ],
        [ "Round 25", 6, 25, 0 ],
        [ "Round 50", 6, 50, 0 ],
        [ "Round 100", 6, 100, 0 ],
        [ "Round 255", 6, 255, 0 ],
        [ "Round 500", 6, 500, 0 ],
        [ "Max round (999)", 6, 999, 0 ],
        [ "Back", 1, "" ]
    ] );

    menu_add_page( "Powerups", "BONUS", [
        [ "All power-ups", 5, "drop_all" ],
        [ "Double points", 7, "double_points" ],
        [ "Max ammo", 7, "full_ammo" ],
        [ "Max armor", 7, "full_armor" ],
        [ "Full power", 7, "full_power" ],
        [ "Free perk", 7, "free_perk" ],
        [ "Fire sale", 7, "fire_sale" ],
        [ "Permanent fire sale", 4, "fire_sale_loop" ],
        [ "Nuke", 7, "nuke" ],
        [ "Bonus points", 7, "bonus_points_team" ],
        [ "Power-up duration", 2, "PowerupTime" ],
        [ "Back", 1, "" ]
    ] );

    menu_add_page( "PowerupTime", "POWER-UP DURATION", [
        [ "Duration x2", 9, "powerup_time", 2 ],
        [ "Duration x5", 9, "powerup_time", 5 ],
        [ "Normal duration", 9, "powerup_time", 1 ],
        [ "Back", 1, "" ]
    ] );

    menu_add_page( "World", "WORLD", [
        [ "Turn on power", 5, "power" ],
        [ "Open all doors", 5, "open_doors" ],
        [ "Start Boss Fight", 5, "boss_fight" ],
        [ "Restart Map", 5, "map_restart" ],
        [ "Mystery box", 2, "Box" ],
        [ "Disable all mods", 5, "reset" ],
        [ "Back", 1, "" ]
    ] );


    menu_add_page( "Forge", "FORGE", [
        [ "Box", 9, "forge", 0 ],
        [ "Door", 9, "forge", 5 ],
        [ "Stack on last", 9, "forge", 6 ],
        [ "Stairs", 9, "forge", 7 ],
        [ "Sky platform", 9, "forge", 8 ],
        [ "Mini base", 9, "forge", 10 ],
        [ "Wall", 9, "forge", 11 ],
        [ "Tower", 9, "forge", 12 ],
        [ "Delete all", 9, "forge", 9 ],
        [ "Back", 1, "" ]
    ] );

    menu_add_page( "Settings", "SETTINGS", [
        [ "Menu color", 5, "theme" ],
        [ "Menu on the right", 4, "menu_right" ],
        [ "Text mode (no HUD)", 4, "text_mode" ],
        [ "Back", 1, "" ]
    ] );
}

// one give entry per weapon: sat_<class>_<name>_mp, label = name
function menu_weapon_page( id, title, cat, names )
{
    items = [];
    foreach ( name in names )
    {
        // full ref: zm_mod_menu_post.lua swaps it for the game's weapon name
        items[ items.size ] = [ "sat_" + cat + "_" + name, 8, "sat_" + cat + "_" + name + "_mp" ];
    }
    items[ items.size ] = [ "Back", 1, "" ];
    menu_add_page( id, title, items );
}

// enable the spawn zone the player stands in (and its linked zones), as opening its door would
function menu_force_spawn_zone()
{
    self.zmm.spawn_zone = namespace_63a203e154ffeca0::function_90e5c3e2272b0130( self.origin );
    if ( !isdefined( self.zmm.spawn_zone ) )
    {
        return 0;
    }
    namespace_63a203e154ffeca0::function_b59ce32b3b1a7b17( self.zmm.spawn_zone.var_8a1bbd1390cd5db6, 1 );
    return 1;
}

// the game's own equipment give: replaces the lethal (primary) or tactical (secondary) slot
function menu_give_equip( action, ref )
{
    self.zmm.equip_slot = "secondary";
    if ( action == "equip_l" )
    {
        self.zmm.equip_slot = "primary";
    }
    self namespace_c33cbcea986a02aa::function_f44eebdbe7ad3e81( ref, self.zmm.equip_slot );
    // a ref the map did not load is skipped by the game: report it as failed
    return isdefined( self.equipment ) && self.equipment[ self.zmm.equip_slot ] === ref;
}

// the game's own door buy, for free; quest-locked barriers stay closed (last arg 0)
function menu_open_doors()
{
    foreach ( door in function_5aa6763dda3aad84( "zombie_door", "targetname" ) )
    {
        door thread doorbuy::function_ff4e31657c10cfde( undefined, undefined, 0 );
    }
}

function menu_currency_page( id, title, kind )
{
    menu_add_page( id, title, [
        [ "Set to max", 9, kind, 999999 ],
        [ "+100 000", 9, kind, 100000 ],
        [ "+10 000", 9, kind, 10000 ],
        [ "+1 000", 9, kind, 1000 ],
        [ "-1 000", 9, kind, -1000 ],
        [ "-10 000", 9, kind, -10000 ],
        [ "-100 000", 9, kind, -100000 ],
        [ "Remove all", 9, kind, -999999 ],
        [ "Back", 1, "" ]
    ] );
}

function menu_add_page( id, title, items )
{
    page = spawnstruct();
    page.title = title;
    page.items = items;
    level.zmm_pages[ id ] = page;
    foreach ( entry in items )
    {
        if ( entry[ 1 ] == 4 || entry[ 1 ] == 5 )
        {
            level.zmm_labels[ entry[ 2 ] ] = entry[ 0 ];
        }
    }
}

function menu_scan_players()
{
    for ( i = 0; i < 480; i++ )
    {
        found = false;
        if ( isdefined( level.players ) )
        {
            foreach ( player in level.players )
            {
                if ( isdefined( player ) && isplayer( player ) && isalive( player ) && player.sessionstate == "playing" )
                {
                    found = true;
                    player thread menu_on_spawned( undefined );
                }
            }
        }
        if ( found )
        {
            return;
        }
        wait 0.25;
    }
}

function menu_on_spawned( params )
{
    if ( !isdefined( self ) || !isplayer( self ) )
    {
        return;
    }
    if ( isdefined( self.zmm ) && self.zmm.running )
    {
        menu_reapply();
        return;
    }

    state = spawnstruct();
    state.running = true;
    state.is_open = false;
    state.page = "Main";
    state.cursor = 0;
    state.top = 0;
    state.stack = [];
    state.depth = 0;
    state.toggles = [];
    state.toggles[ "menu_right" ] = 1;
    state.equip_loop = 0;
    state.upgrade_loop = 0;
    state.god_loop = 0;
    state.hornet_loop = 0;
    state.points_loop = 0;
    state.has_save = 0;
    state.theme = 0;
    state.lua = 0;
    state.status = "";
    state.spawn_origin = self.origin;
    state.spawn_angles = self getplayerangles();
    self.zmm = state;
    self thread menu_input_loop();
    self thread menu_welcome();
}

function menu_on_death( params )
{
    if ( isdefined( self ) && isdefined( self.zmm ) )
    {
        menu_close();
    }
}

function menu_on_disconnect( params )
{
    if ( isdefined( self ) && isdefined( self.zmm ) )
    {
        self.zmm.running = false;
        menu_close();
    }
}

// ---------------------------------------------------------------- input / navigation

function menu_input_loop()
{
    for ( ;; )
    {
        state = self.zmm;
        if ( !isdefined( state ) || !state.running )
        {
            return;
        }

        if ( !state.is_open )
        {
            if ( self adsbuttonpressed() && self meleebuttonpressed() )
            {
                menu_open();
                while ( self adsbuttonpressed() || self meleebuttonpressed() )
                {
                    wait 0.05;
                }
                wait 0.2;
            }
            else
            {
                wait 0.1;
            }
            continue;
        }

        if ( menu_lua_nav() )
        {
            wait 0.05;
        }
        else if ( self adsbuttonpressed() )
        {
            menu_move( -1 );
            wait 0.15;
        }
        else if ( self attackbuttonpressed() )
        {
            menu_move( 1 );
            wait 0.15;
        }
        else if ( self usebuttonpressed() )
        {
            menu_confirm();
            while ( self usebuttonpressed() )
            {
                wait 0.05;
            }
        }
        else if ( self meleebuttonpressed() )
        {
            menu_back();
            while ( self meleebuttonpressed() )
            {
                wait 0.05;
            }
        }
        else
        {
            wait 0.05;
        }
    }
}

// arrow keys / D-pad: zm_mod_menu_post.lua bumps the zmm_up / zmm_down counters on each press
// shortcut: two presses within one 0.05 s poll count once, fine for menu navigation
function menu_lua_nav()
{
    state = self.zmm;
    if ( getdvar( @"zmm_up" ) != state.nav_up )
    {
        state.nav_up = getdvar( @"zmm_up" );
        menu_move( -1 );
        return true;
    }
    if ( getdvar( @"zmm_down" ) != state.nav_down )
    {
        state.nav_down = getdvar( @"zmm_down" );
        menu_move( 1 );
        return true;
    }
    return false;
}

function menu_open()
{
    state = self.zmm;
    state.page = "Main";
    state.cursor = 0;
    state.top = 0;
    state.stack = [];
    state.depth = 0;
    state.status = "Round " + menu_current_round();
    // presses made while the menu was closed are ignored
    state.nav_up = getdvar( @"zmm_up" );
    state.nav_down = getdvar( @"zmm_down" );
    state.is_open = true;
    menu_hud_create();
    menu_render();
}

function menu_close()
{
    state = self.zmm;
    state.is_open = false;
    state.stack = [];
    state.depth = 0;
    setdvar( @"zmm_view", "" );
    menu_hud_destroy();
}

function menu_move( direction )
{
    state = self.zmm;
    count = level.zmm_pages[ state.page ].items.size;
    state.cursor += direction;
    if ( state.cursor < 0 )
    {
        state.cursor = count - 1;
    }
    else if ( state.cursor >= count )
    {
        state.cursor = 0;
    }
    menu_render();
}

function menu_enter( page_id )
{
    if ( !isdefined( level.zmm_pages[ page_id ] ) )
    {
        return;
    }
    state = self.zmm;
    frame = spawnstruct();
    frame.page = state.page;
    frame.cursor = state.cursor;
    state.stack[ state.depth ] = frame;
    state.depth++;
    state.page = page_id;
    state.cursor = 0;
    state.top = 0;
    menu_render();
}

function menu_back()
{
    state = self.zmm;
    if ( state.depth <= 0 )
    {
        menu_close();
        return;
    }
    state.depth--;
    frame = state.stack[ state.depth ];
    state.page = frame.page;
    state.cursor = frame.cursor;
    state.top = 0;
    state.stack[ state.depth ] = undefined;
    menu_render();
}

function menu_confirm()
{
    state = self.zmm;
    entry = level.zmm_pages[ state.page ].items[ state.cursor ];
    kind = entry[ 1 ];
    if ( kind == 0 )
    {
        menu_close();
    }
    else if ( kind == 1 )
    {
        menu_back();
    }
    else if ( kind == 2 )
    {
        menu_enter( entry[ 2 ] );
    }
    else if ( kind == 4 )
    {
        menu_toggle( entry[ 2 ] );
    }
    else if ( kind == 5 )
    {
        menu_action( entry[ 2 ] );
    }
    else if ( kind == 6 )
    {
        target = entry[ 2 ];
        if ( entry[ 3 ] )
        {
            target = menu_current_round() + entry[ 2 ];
        }
        if ( target < 1 )
        {
            target = 1;
        }
        else if ( target > 999 )
        {
            target = 999;
        }
        menu_notify( "Round -> " + target, menu_jump_round( target ) );
    }
    else if ( kind == 7 )
    {
        menu_notify( entry[ 0 ], menu_drop_powerup( entry[ 2 ] ) );
    }
    else if ( kind == 8 )
    {
        menu_notify( entry[ 0 ] + " ^3...", 1 );
        self thread menu_wonder_worker( entry[ 0 ], entry[ 2 ] );
    }
    else if ( kind == 9 )
    {
        self thread menu_param( entry[ 0 ], entry[ 2 ], entry[ 3 ] );
    }
}

function menu_notify( label, ok )
{
    if ( !isdefined( self ) || !isdefined( self.zmm ) )
    {
        return;
    }
    if ( ok )
    {
        text = label + " ^2OK";
    }
    else
    {
        text = label + " ^1failed";
    }
    self.zmm.status = text;
    if ( self.zmm.is_open )
    {
        menu_render();
    }
    // hud mode shows results in the kill feed: one hud string per result would fill the 256 text slots
    if ( !self.zmm.is_open || isdefined( self.zmm.hud ) )
    {
        iprintln( text );
    }
}

function menu_tip_action( action_id, ok )
{
    label = action_id;
    if ( isdefined( level.zmm_labels[ action_id ] ) )
    {
        label = level.zmm_labels[ action_id ];
    }
    menu_notify( label, ok );
}

// ---------------------------------------------------------------- HUD (drawn by zm_mod_menu_hud.gsc)

function menu_hud_create()
{
    state = self.zmm;
    menu_hud_destroy();
    state.lua = getdvar( @"zmm_lua" ) == "1";
    if ( state.lua || menu_toggle_state( "text_mode" ) )
    {
        return;
    }
    if ( isdefined( level.zmm_hud_create ) )
    {
        state.hud_right = menu_toggle_state( "menu_right" );
        self [[ level.zmm_hud_create ]]();
    }
    if ( !isdefined( state.hud ) )
    {
        // HUD script missing or newclienthudelem unavailable
        state.toggles[ "text_mode" ] = 1;
        return;
    }
}

function menu_line_text( entry, on )
{
    if ( entry[ 1 ] == 2 )
    {
        return entry[ 0 ] + "  ^3>";
    }
    if ( entry[ 1 ] == 4 )
    {
        return entry[ 0 ] + ( on ? "  ^2ON" : "  OFF" );
    }
    return entry[ 0 ];
}

function menu_page_list( page, top )
{
    list = "";
    for ( i = 0; i < level.zmm_visible && top + i < page.items.size; i++ )
    {
        entry = page.items[ top + i ];
        if ( i > 0 )
        {
            list += "
";
        }
        list += menu_line_text( entry, entry[ 1 ] == 4 && menu_toggle_state( entry[ 2 ] ) );
    }
    return list;
}

function menu_welcome()
{
    // spawn happens during the intro, and the intro teleports the player: wait for real walking
    // (small steps several ticks in a row) or a button press
    prev = self.origin;
    steps = 0;
    for ( i = 0; i < 600 && steps < 5; i++ )
    {
        wait 0.05;
        if ( !isdefined( self ) )
        {
            return;
        }
        if ( self adsbuttonpressed() || self attackbuttonpressed() || self usebuttonpressed() || self meleebuttonpressed() )
        {
            break;
        }
        // no distance builtin: an unknown builtin would stop the whole script from linking
        d = self.origin - prev;
        prev = self.origin;
        moved = d[ 0 ] * d[ 0 ] + d[ 1 ] * d[ 1 ];
        if ( moved > 2 && moved < 2500 )
        {
            steps++;
        }
        else
        {
            steps = 0;
        }
    }
    wait 0.5;
    if ( !isdefined( self ) || !isdefined( self.zmm ) )
    {
        return;
    }
    hint = level.zmm_hint;
    if ( isdefined( level.zmm_hud_splash ) )
    {
        self.zmm.hud_right = menu_toggle_state( "menu_right" );
        self [[ level.zmm_hud_splash ]]( level.zmm_name, hint );
    }
    else
    {
        iprintlnbold( "^5" + level.zmm_name );
        iprintln( hint );
    }
}

function menu_hud_destroy()
{
    state = self.zmm;
    if ( isdefined( state.hud ) && isdefined( level.zmm_hud_destroy ) )
    {
        self [[ level.zmm_hud_destroy ]]();
    }
    state.hud = undefined;
}

function menu_hud_set( key, elem, text )
{
    hud = self.zmm.hud;
    if ( isdefined( hud.cache[ key ] ) && hud.cache[ key ] == text )
    {
        return 0;
    }
    self [[ level.zmm_hud_set ]]( key, elem, text );
    return 1;
}

function menu_item_label( entry )
{
    if ( entry[ 1 ] == 2 )
    {
        return entry[ 0 ] + "  ^3>";
    }
    if ( entry[ 1 ] == 4 )
    {
        if ( menu_toggle_state( entry[ 2 ] ) )
        {
            return entry[ 0 ] + "  ^2[ON]";
        }
        return entry[ 0 ] + "  ^1[OFF]";
    }
    return entry[ 0 ];
}

function menu_render()
{
    state = self.zmm;
    if ( !state.is_open )
    {
        return;
    }
    page = level.zmm_pages[ state.page ];
    count = page.items.size;
    position = "(" + ( state.cursor + 1 ) + "/" + count + ")";

    vis = level.zmm_visible;
    if ( state.cursor < state.top )
    {
        state.top = state.cursor;
    }
    else if ( state.cursor >= state.top + vis )
    {
        state.top = state.cursor - vis + 1;
    }

    if ( state.lua )
    {
        rows = "";
        n = 0;
        for ( ; n < vis && state.top + n < count; n++ )
        {
            rows += menu_view_row( page.items[ state.top + n ] ) + "|";
        }
        right = menu_toggle_state( "menu_right" ) ? "1" : "0";
        setdvar( @"zmm_view", "ZMM|" + state.theme + "|" + right + "|" + page.title + "|" + ( state.cursor - state.top ) + "|" + n + "|" + ( state.cursor + 1 ) + "/" + count + "|" + rows + "END" );
        return;
    }

    if ( !isdefined( state.hud ) )
    {
        iprintlnbold( "^5" + page.title + " ^7" + position + " ^3" + menu_item_label( page.items[ state.cursor ] ) );
        if ( state.status != "" )
        {
            iprintln( state.status );
        }
        return;
    }

    hud = state.hud;
    menu_hud_set( "name", hud.name, level.zmm_name );
    menu_hud_set( "subtitle", hud.subtitle, page.title );
    // the whole list is one text element: 12 line elements only showed new text when it was
    // sent again ~0.3 s later, a single element (like the subtitle) shows it at once
    menu_hud_set( "list", hud.list, menu_page_list( page, state.top ) );
    bar_y = hud.line_y + ( state.cursor - state.top ) * hud.spacing;
    hud.bar.y = bar_y;
    hud.accent.y = bar_y;
    menu_hud_set( "footer", hud.footer, level.zmm_footer );
}

// one row of the zmm_view dvar: a marker for zm_mod_menu_post.lua, then the label
function menu_view_row( entry )
{
    if ( entry[ 1 ] == 2 )
    {
        return ">" + entry[ 0 ];
    }
    if ( entry[ 1 ] == 4 )
    {
        return ( menu_toggle_state( entry[ 2 ] ) ? "+" : "-" ) + entry[ 0 ];
    }
    return " " + entry[ 0 ];
}

function menu_apply_theme()
{
    state = self.zmm;
    state.theme++;
    if ( state.theme >= level.zmm_themes.size )
    {
        state.theme = 0;
    }
    if ( isdefined( state.hud ) )
    {
        color = level.zmm_themes[ state.theme ];
        foreach ( e in state.hud.themed )
        {
            e.color = color;
        }
        state.hud.subtitle.color = color;
    }
    menu_notify( "Color: " + level.zmm_theme_names[ state.theme ], 1 );
}

// ---------------------------------------------------------------- toggles

function menu_toggle( key )
{
    state = self.zmm;
    now_on = !menu_toggle_state( key );
    state.toggles[ key ] = now_on ? 1 : 0;
    if ( !menu_apply_toggle( key ) )
    {
        state.toggles[ key ] = now_on ? 0 : 1;
        menu_tip_action( key, 0 );
        return;
    }
    label = level.zmm_labels[ key ];
    if ( now_on )
    {
        state.status = label + " ^2enabled";
    }
    else
    {
        state.status = label + " ^1disabled";
    }
    if ( key == "menu_right" || key == "text_mode" )
    {
        menu_hud_create();
    }
    menu_render();
}

function menu_toggle_state( key )
{
    state = self.zmm;
    if ( !isdefined( state.toggles[ key ] ) )
    {
        return false;
    }
    return istrue( state.toggles[ key ] );
}

function menu_reapply()
{
    foreach ( key in [ "extra_ammo", "god_mode", "firepower", "ignoreme", "golden_armor", "pause_spawn", "inf_points", "speed", "equip_inf", "upgrade_inf", "rapid_fire", "fast_reload", "tacsprint", "no_armor" ] )
    {
        if ( menu_toggle_state( key ) )
        {
            menu_apply_toggle( key );
        }
    }
    if ( isdefined( self.zmm.points_mult ) && self.zmm.points_mult != 1 )
    {
        menu_override( "zmm_points", [ "zm_points_scalar" ], [ self.zmm.points_mult ], 1 );
    }
    if ( isdefined( self.zmm.jump ) && self.zmm.jump != 1 )
    {
        menu_move_option( "jump", self.zmm.jump );
    }
    if ( isdefined( self.zmm.gravity ) && self.zmm.gravity != 1 )
    {
        menu_move_option( "gravity", self.zmm.gravity );
    }
}

function menu_start_equip_loop()
{
    state = self.zmm;
    if ( !istrue( state.equip_loop ) )
    {
        state.equip_loop = 1;
        self thread menu_equip_loop();
    }
}

function menu_start_upgrade_loop()
{
    state = self.zmm;
    if ( !istrue( state.upgrade_loop ) )
    {
        state.upgrade_loop = 1;
        self thread menu_field_upgrade_loop();
    }
}

function menu_apply_toggle( key )
{
    on = menu_toggle_state( key );
    state = self.zmm;
    if ( key == "extra_ammo" )
    {
        self setinfiniteammo( on || menu_toggle_state( "firepower" ) );
        return true;
    }
    if ( key == "god_mode" )
    {
        return menu_apply_god( on );
    }
    if ( key == "firepower" )
    {
        state.toggles[ "hornet_bless" ] = on ? 1 : 0;
        menu_apply_hornet( on );
        if ( on )
        {
            self setinfiniteammo( 1 );
            menu_start_equip_loop();
            menu_start_upgrade_loop();
            menu_pap( 4 );
            menu_rarity( 5 );
        }
        else
        {
            self setinfiniteammo( menu_toggle_state( "extra_ammo" ) );
        }
        return true;
    }
    if ( key == "equip_inf" )
    {
        if ( on )
        {
            menu_start_equip_loop();
        }
        return true;
    }
    if ( key == "upgrade_inf" )
    {
        if ( on )
        {
            menu_start_upgrade_loop();
        }
        return true;
    }
    if ( key == "ignoreme" )
    {
        self.ignoreme = on ? 1 : 0;
        return true;
    }
    if ( key == "pause_spawn" )
    {
        return menu_apply_pause_spawn( on );
    }
    if ( key == "back_shield" )
    {
        // each switch-on gives a fresh shield
        state.shield_hits = 15;
        if ( on && !istrue( state.hud_loop ) )
        {
            state.hud_loop = 1;
            self thread menu_hud_loop();
        }
        return true;
    }
    if ( key == "classic" )
    {
        // "all on" switch of the Old School page
        foreach ( sub in [ "old_school", "no_armor", "back_shield", "og_specials", "cl_prices", "cl_perk_cap", "cl_fizz", "cl_qr", "cl_sprinters", "cl_health", "cl_points", "cl_salvage", "cl_ww" ] )
        {
            state.toggles[ sub ] = on ? 1 : 0;
            menu_apply_toggle( sub );
        }
        return true;
    }
    if ( key == "god_all" )
    {
        // one switch for the cheat toggles
        foreach ( sub in [ "god_mode", "extra_ammo", "inf_points", "free_buy", "no_recoil", "aimbot", "wallhack", "rapid_fire", "equip_inf", "upgrade_inf", "no_fall", "no_self_explo", "tacsprint", "firepower", "speed" ] )
        {
            state.toggles[ sub ] = on ? 1 : 0;
            menu_apply_toggle( sub );
        }
        menu_move_option( "jump", on ? 4 : 1 );
        menu_move_option( "gravity", on ? 0.5 : 1 );
        if ( on )
        {
            menu_give_perks( 1 );
        }
        return true;
    }
    if ( issubstr( key, "cl_" ) )
    {
        return menu_classic_part( key, on );
    }
    if ( key == "og_specials" )
    {
        if ( on )
        {
            // max specials alive at once, read by zm_round_spawning (-1 = game default)
            setdvar( @"hash_3c05d1d16d772c9e", 1 );
            if ( !istrue( level.zmm_elite_hooked ) )
            {
                level.zmm_elite_hooked = 1;
                level.zmm_elite_prev = level.var_609a4c84665ec35;
                level.var_609a4c84665ec35 = &menu_elite_allowed;
            }
            level.zmm_elite_round = menu_current_round();
            if ( !istrue( state.elite_loop ) )
            {
                state.elite_loop = 1;
                self thread menu_elite_loop();
            }
        }
        else
        {
            setdvar( @"hash_3c05d1d16d772c9e", -1 );
            if ( istrue( level.zmm_elite_hooked ) )
            {
                level.zmm_elite_hooked = 0;
                level.var_609a4c84665ec35 = level.zmm_elite_prev;
            }
        }
        return true;
    }
    if ( key == "no_spread" )
    {
        // the game's own switch for the per-zombie speed and path offset that breaks up trains
        if ( on )
        {
            namespace_60b3bdcc70f79fc6::function_9771699e420ec0fd( "disallow_zombie_spreader" );
            if ( !istrue( state.train_loop ) )
            {
                state.train_loop = 1;
                self thread menu_train_loop();
            }
        }
        else
        {
            namespace_60b3bdcc70f79fc6::function_72a990b4fbab3418( "disallow_zombie_spreader" );
        }
        return true;
    }
    if ( key == "golden_armor" )
    {
        return menu_apply_golden( on );
    }
    if ( key == "inf_points" )
    {
        if ( on && !istrue( state.points_loop ) )
        {
            state.points_loop = 1;
            self thread menu_points_loop();
        }
        return true;
    }
    if ( key == "free_box" || key == "fast_box" || key == "free_perks" || key == "free_ammo" )
    {
        return menu_box_override( key, on );
    }
    if ( key == "free_buy" )
    {
        if ( on && !istrue( state.free_buy_loop ) )
        {
            state.free_buy_loop = 1;
            self thread menu_free_buy_loop();
        }
        return true;
    }
    if ( key == "fire_sale_loop" )
    {
        if ( on && !istrue( state.fire_sale_loop ) )
        {
            state.fire_sale_loop = 1;
            self thread menu_fire_sale_loop();
        }
        return true;
    }
    if ( key == "cinema" )
    {
        // noclip through the Lua console hook, game HUD hidden, gun lowered
        setdvar( @"zmm_exec", "noclip " + gettime() );
        self setclientomnvar( "ui_hide_hud", on ? 1 : 0 );
        if ( on )
        {
            self disableweapons();
        }
        else
        {
            self enableweapons();
        }
        return true;
    }
    if ( key == "speed" )
    {
        if ( !isdefined( level.zmm_set_speed ) )
        {
            return false;
        }
        self [[ level.zmm_set_speed ]]( on ? 1.6 : 1 );
        return true;
    }
    if ( key == "free_craft" )
    {
        // engine dvar Nexus sets for its "Free Crafting" option
        setdvar( @"hash_8054c9327575fd95", on ? 1 : 0 );
        return true;
    }
    if ( key == "tacsprint" )
    {
        // perk used by Nexus 1.3
        if ( on )
        {
            self setperk( "specialty_infinite_tacsprint", 1 );
        }
        else
        {
            self unsetperk( "specialty_infinite_tacsprint", 1 );
        }
        return true;
    }
    if ( key == "no_armor" )
    {
        if ( !isdefined( level.zmm_allow_armor ) )
        {
            level.zmm_allow_armor = level.allowArmor;
        }
        if ( on )
        {
            // same call the game uses to strip plates (also refreshes the HUD), then block new plates
            self armor::function_6a2b9bcb602048f( 0, 1 );
            level.allowArmor = 0;
        }
        else
        {
            level.allowArmor = level.zmm_allow_armor;
        }
        return true;
    }
    if ( key == "fast_reload" )
    {
        menu_override( "zmm_fast_reload", [ "reload_speed" ], [ 0.05 ], on );
        return true;
    }
    if ( key == "free_pap" )
    {
        // pack_a_punch reads its cost from this hook (as ProjectNexus)
        if ( on && !istrue( level.zmm_pap_hooked ) )
        {
            level.zmm_pap_hooked = 1;
            level.zmm_pap_prev = level.var_b8e43eaa228221e9;
            level.var_b8e43eaa228221e9 = &menu_box_free;
        }
        else if ( !on && istrue( level.zmm_pap_hooked ) )
        {
            level.zmm_pap_hooked = 0;
            if ( level.var_b8e43eaa228221e9 == &menu_box_free )
            {
                level.var_b8e43eaa228221e9 = level.zmm_pap_prev;
            }
        }
        return true;
    }
    if ( key == "rapid_fire" )
    {
        menu_override( "zmm_rapid_fire", [ "fire_time_scale", "reload_speed" ], [ 5, 0.05 ], on );
        return true;
    }
    if ( key == "despawn" )
    {
        return menu_apply_despawn( on );
    }
    if ( key == "zombie_counter" || key == "round_timer" )
    {
        if ( on && !istrue( state.hud_loop ) )
        {
            state.hud_loop = 1;
            self thread menu_hud_loop();
        }
        return true;
    }
    if ( key == "freeze" )
    {
        if ( on && !istrue( state.freeze_loop ) )
        {
            state.freeze_loop = 1;
            self thread menu_freeze_loop();
        }
        return true;
    }
    if ( key == "aimbot" )
    {
        if ( on && !istrue( state.aim_loop ) )
        {
            state.aim_loop = 1;
            self thread menu_aimbot_loop();
        }
        return true;
    }
    if ( key == "wallhack" )
    {
        if ( on && !istrue( state.wh_loop ) )
        {
            state.wh_loop = 1;
            self thread menu_wallhack_loop();
        }
        return true;
    }
    if ( key == "no_recoil" )
    {
        // zm_mod_menu_post.lua sets bg_recoil_gunkick_scale / bg_recoil_viewkick_scale from this
        setdvar( @"zmm_recoil", on ? "1" : "0" );
        return true;
    }
    // menu_right / text_mode: handled by menu_toggle
    return true;
}

// zm_mod_menu_post.lua draws zmm_hud at the top of the screen; counters avoid int() / floor()
function menu_hud_loop()
{
    state = self.zmm;
    state.hud_round = -1;
    while ( isdefined( self ) && ( menu_loop_active( "zombie_counter" ) || menu_loop_active( "round_timer" ) || menu_loop_active( "back_shield" ) ) )
    {
        if ( state.hud_round != menu_current_round() )
        {
            state.hud_round = menu_current_round();
            state.hud_min = 0;
            state.hud_sec = 0;
        }
        state.hud_text = "";
        if ( menu_toggle_state( "zombie_counter" ) )
        {
            state.hud_list = menu_zombie_list();
            state.hud_alive = 0;
            if ( isdefined( state.hud_list ) )
            {
                foreach ( ai in state.hud_list )
                {
                    if ( menu_ai_awake( ai ) )
                    {
                        state.hud_alive++;
                    }
                }
            }
            // the raw list also holds dead, sleeping and off-map pooled zombies, so count active ones only
            state.hud_text = "Zombies: " + state.hud_alive + "      ";
        }
        if ( menu_toggle_state( "round_timer" ) )
        {
            state.hud_text = state.hud_text + "Round " + state.hud_round + "  " + state.hud_min + ":" + ( state.hud_sec < 10 ? "0" : "" ) + state.hud_sec + "      ";
        }
        if ( menu_toggle_state( "back_shield" ) )
        {
            // a broken shield stays switched on and rebuilds itself at the next round
            if ( state.shield_hits <= 0 && state.hud_round != state.shield_round )
            {
                state.shield_hits = 15;
            }
            state.hud_text = state.hud_text + ( state.shield_hits > 0 ? "Shield: " + state.shield_hits + "/15" : "Shield: broken" );
        }
        setdvar( @"zmm_hud", state.hud_text );
        wait 1;
        state.hud_sec++;
        if ( state.hud_sec >= 60 )
        {
            state.hud_sec = 0;
            state.hud_min++;
        }
    }
    state.hud_loop = 0;
    setdvar( @"zmm_hud", "" );
}

// while aiming (menu closed: aim is its "up" key), turns the view to the head of the visible zombie
// closest to the crosshair; state fields instead of new locals (BO7 locals pitfall)
function menu_aimbot_loop()
{
    state = self.zmm;
    while ( menu_loop_active( "aimbot" ) )
    {
        if ( !state.is_open && self adsbuttonpressed() )
        {
            state.aim_eye = self geteye();
            state.aim_forward = anglestoforward( self getplayerangles() );
            state.aim_best = undefined;
            // dot product limit: only zombies within about 25 degrees of the crosshair
            state.aim_score = 0.9;
            state.aim_list = menu_zombie_list();
            if ( isdefined( state.aim_list ) )
            {
                foreach ( ai in state.aim_list )
                {
                    if ( menu_ai_awake( ai ) )
                    {
                        state.aim_head = ai gettagorigin( "j_head" );
                        state.aim_dot = vectordot( state.aim_forward, vectornormalize( state.aim_head - state.aim_eye ) );
                        if ( state.aim_dot > state.aim_score && sighttracepassed( state.aim_eye, state.aim_head, 0, self ) )
                        {
                            state.aim_score = state.aim_dot;
                            state.aim_best = state.aim_head;
                        }
                    }
                }
            }
            if ( isdefined( state.aim_best ) )
            {
                self setplayerangles( vectortoangles( state.aim_best - state.aim_eye ) );
            }
        }
        wait 0.05;
    }
    state.aim_loop = 0;
}

// only the "nodepth" outline assets draw through walls; ints and outline_depth_* showed nothing (tested 01/11/2026)
function menu_wallhack_loop()
{
    state = self.zmm;
    while ( menu_loop_active( "wallhack" ) )
    {
        state.wh_list = menu_zombie_list();
        if ( isdefined( state.wh_list ) )
        {
            foreach ( ai in state.wh_list )
            {
                if ( menu_ai_awake( ai ) )
                {
                    ai.zmm_wh = 1;
                    ai hudoutlineenable( "outline_nodepth_red" );
                }
                else if ( isdefined( ai ) && istrue( ai.zmm_wh ) )
                {
                    ai.zmm_wh = 0;
                    ai hudoutlinedisable();
                }
            }
        }
        // every frame: the outline perk (orange zombies) overrides ours, so keep putting it back
        wait 0.05;
    }
    state.wh_list = menu_zombie_list();
    if ( isdefined( state.wh_list ) )
    {
        foreach ( ai in state.wh_list )
        {
            if ( isdefined( ai ) && istrue( ai.zmm_wh ) )
            {
                ai.zmm_wh = 0;
                ai hudoutlinedisable();
            }
        }
    }
    state.wh_loop = 0;
}

// zombies are linked to a fixed script_origin (move_speed_scale alone did not stop them), new spawns caught by the loop
function menu_freeze_loop()
{
    state = self.zmm;
    while ( menu_loop_active( "freeze" ) )
    {
        state.freeze_list = menu_zombie_list();
        if ( isdefined( state.freeze_list ) )
        {
            foreach ( ai in state.freeze_list )
            {
                if ( isdefined( ai ) && isalive( ai ) && !istrue( ai.zmm_frozen ) && !menu_ai_protected( ai ) )
                {
                    ai.zmm_frozen = 1;
                    ai.zmm_anchor = spawn( "script_origin", ai.origin );
                    ai linkto( ai.zmm_anchor );
                    ai thread menu_anchor_cleanup( ai.zmm_anchor );
                    ai menu_override( "zmm_freeze", [ "move_speed_scale" ], [ 0 ], 1 );
                }
            }
        }
        wait 0.25;
    }
    state.freeze_loop = 0;
    state.freeze_list = menu_zombie_list();
    if ( isdefined( state.freeze_list ) )
    {
        foreach ( ai in state.freeze_list )
        {
            if ( isdefined( ai ) && istrue( ai.zmm_frozen ) )
            {
                ai.zmm_frozen = 0;
                ai unlink();
                if ( isdefined( ai.zmm_anchor ) )
                {
                    ai.zmm_anchor delete();
                }
                ai menu_override( "zmm_freeze", [ "move_speed_scale" ], [ 0 ], 0 );
            }
        }
    }
}

// elite gate the round spawner calls before each elite; keeps the map's own gate
function menu_elite_allowed()
{
    if ( isdefined( level.zmm_elite_prev ) && !( [[ level.zmm_elite_prev ]]() ) )
    {
        return false;
    }
    return menu_current_round() >= level.zmm_elite_round;
}

// each new elite pushes the next one 4 to 5 rounds later
function menu_elite_loop()
{
    state = self.zmm;
    while ( menu_loop_active( "og_specials" ) )
    {
        state.elite_list = menu_zombie_list();
        if ( isdefined( state.elite_list ) )
        {
            foreach ( ai in state.elite_list )
            {
                if ( isdefined( ai ) && isalive( ai ) && ai.var_e4312c2c1a4a2190 === "elite" && !istrue( ai.zmm_elite_seen ) )
                {
                    ai.zmm_elite_seen = 1;
                    level.zmm_elite_round = menu_current_round() + 4 + randomint( 2 );
                }
            }
        }
        wait 0.25;
    }
    state.elite_loop = 0;
}

// mixed walk/run/sprint is what spreads BO7 zombies: one speed for all makes them follow in a line
function menu_train_loop()
{
    state = self.zmm;
    while ( menu_loop_active( "no_spread" ) )
    {
        state.train_list = menu_zombie_list();
        if ( isdefined( state.train_list ) )
        {
            foreach ( ai in state.train_list )
            {
                if ( isdefined( ai ) && isalive( ai ) && !istrue( ai.zmm_train ) && !menu_ai_protected( ai ) )
                {
                    ai.zmm_train = 1;
                    ai namespace_56fb43fc0b6ee43e::function_a8ce00e0448cb6f0( "sprint", "zmm_train", 100 );
                }
            }
        }
        wait 0.25;
    }
    state.train_loop = 0;
    state.train_list = menu_zombie_list();
    if ( isdefined( state.train_list ) )
    {
        foreach ( ai in state.train_list )
        {
            if ( isdefined( ai ) && istrue( ai.zmm_train ) )
            {
                ai.zmm_train = 0;
                // undefined speed removes our entry from the stack
                ai namespace_56fb43fc0b6ee43e::function_a8ce00e0448cb6f0( undefined, "zmm_train" );
            }
        }
    }
}

// a zombie killed while frozen must not leave its script_origin behind
function menu_anchor_cleanup( anchor )
{
    self waittill( #"death" );
    if ( isdefined( anchor ) )
    {
        anchor delete();
    }
}

function menu_on_damaged( params )
{
    if ( !isdefined( self ) || !isdefined( self.zmm ) || !isdefined( params ) || !isdefined( params.var_f5a880abf0b199dc ) )
    {
        return;
    }
    if ( params.var_f5a880abf0b199dc == "MOD_FALLING" && menu_toggle_state( "no_fall" ) )
    {
        params.var_a87b62c261a8d114 = 0;
    }
    // shortcut: any explosive damage is cancelled, not only the player's own (zombies rarely deal it)
    if ( menu_toggle_state( "no_self_explo" ) && ( params.var_f5a880abf0b199dc == "MOD_GRENADE_SPLASH" || params.var_f5a880abf0b199dc == "MOD_PROJECTILE_SPLASH" || params.var_f5a880abf0b199dc == "MOD_EXPLOSIVE" ) )
    {
        params.var_a87b62c261a8d114 = 0;
    }
    // back shield, like the old Zombies shield: blocks zombie hits from behind, breaks after 15
    if ( menu_toggle_state( "back_shield" ) && self.zmm.shield_hits > 0 && params.var_f5a880abf0b199dc == "MOD_MELEE" && isdefined( params.var_917e21c98d80255e ) && !isplayer( params.var_917e21c98d80255e ) && params.var_a87b62c261a8d114 > 0 && menu_hit_from_back( params.var_917e21c98d80255e ) )
    {
        params.var_a87b62c261a8d114 = 0;
        self.zmm.shield_hits--;
        if ( self.zmm.shield_hits <= 0 )
        {
            self.zmm.shield_round = menu_current_round();
            // the game's own armor break sound (same check and call as namespace armor)
            if ( isdefined( level.gamemodebundle.var_b8f236e7432f6fdc ) && function_43b69b5e5fb69205( level.gamemodebundle.var_b8f236e7432f6fdc ) )
            {
                self function_a4c8b0f6cf33e203( level.gamemodebundle.var_b8f236e7432f6fdc, self );
            }
        }
        return;
    }
    // old-school: every zombie hit deals 50, whatever the round
    if ( menu_toggle_state( "old_school" ) && params.var_f5a880abf0b199dc == "MOD_MELEE" && isdefined( params.var_917e21c98d80255e ) && !isplayer( params.var_917e21c98d80255e ) && params.var_a87b62c261a8d114 > 0 )
    {
        params.var_a87b62c261a8d114 = 50;
    }
}

// attacker in the half behind where the player looks (flat, ignores height)
function menu_hit_from_back( attacker )
{
    return vectordot( anglestoforward( ( 0, self getplayerangles()[ 1 ], 0 ) ), vectornormalize( ( attacker.origin[ 0 ] - self.origin[ 0 ], attacker.origin[ 1 ] - self.origin[ 1 ], 0 ) ) ) < -0.2;
}

function menu_loop_active( key )
{
    if ( !isdefined( self ) || !isplayer( self ) || !isdefined( self.zmm ) || !self.zmm.running )
    {
        return false;
    }
    return istrue( self.zmm.toggles[ key ] );
}

function menu_points_loop()
{
    while ( menu_loop_active( "inf_points" ) )
    {
        menu_fill_currency();
        wait 1;
    }
    if ( isdefined( self ) && isdefined( self.zmm ) )
    {
        self.zmm.points_loop = 0;
    }
}

// any gun from the weapon pages (melee left out), given like a menu pick
function menu_random_gun()
{
    self.zmm.rand_pool = [];
    foreach ( page_id in [ "W_ar", "W_sm", "W_lm", "W_sh", "W_dm", "W_sn", "W_pi", "W_la" ] )
    {
        foreach ( entry in level.zmm_pages[ page_id ].items )
        {
            if ( entry[ 1 ] == 8 )
            {
                self.zmm.rand_pool[ self.zmm.rand_pool.size ] = entry;
            }
        }
    }
    self.zmm.rand_pick = self.zmm.rand_pool[ randomint( self.zmm.rand_pool.size ) ];
    menu_notify( self.zmm.rand_pick[ 0 ] + " ^3...", 1 );
    self thread menu_wonder_worker( self.zmm.rand_pick[ 0 ], self.zmm.rand_pick[ 2 ] );
}

// the weapon object keeps its build (attachments, camo, variant), e.g. a mystery box roll
// builds live in kronos/fuzmenu/builds.json (ship that file for premade builds): one key per slot,
// "root,variant,camo,pap,att,attvariant,..." as the loot IDs the game's own save uses
function menu_store_build( slot )
{
    self.zmm.bk_gun = self getcurrentweapon();
    if ( !isdefined( self.zmm.bk_gun ) || isnullweapon( self.zmm.bk_gun ) )
    {
        return 0;
    }
    self.zmm.bk_root = weapon::function_f541f60718130d5d( self.zmm.bk_gun );
    self.zmm.bk_id = namespace_952965bfef60cff8::function_fae2e7aa6e279966( self.zmm.bk_root );
    if ( !isdefined( self.zmm.bk_id ) || self.zmm.bk_id == 0 )
    {
        return 0;
    }
    self.zmm.bk_str = "" + self.zmm.bk_id + "," + ( isdefined( self.zmm.bk_gun.variantid ) ? self.zmm.bk_gun.variantid : 0 );
    self.zmm.bk_id = undefined;
    if ( isdefined( self.zmm.bk_gun.camo ) )
    {
        self.zmm.bk_id = namespace_952965bfef60cff8::function_fae2e7aa6e279966( self.zmm.bk_gun.camo );
    }
    self.zmm.bk_str = self.zmm.bk_str + "," + ( isdefined( self.zmm.bk_id ) ? self.zmm.bk_id : 0 ) + "," + menu_pap_level( self.zmm.bk_gun );
    self.zmm.bk_atts = function_2938687b7cf2650c( self.zmm.bk_gun );
    self.zmm.bk_defs = weapon::function_cf0cbe4e64095367( self.zmm.bk_root );
    for ( self.zmm.bk_i = 0; self.zmm.bk_i < self.zmm.bk_atts.size; self.zmm.bk_i++ )
    {
        self.zmm.bk_att = self.zmm.bk_atts[ self.zmm.bk_i ];
        if ( isdefined( self.zmm.bk_defs ) && isdefined( self.zmm.bk_defs[ self.zmm.bk_att ] ) )
        {
            continue;
        }
        self.zmm.bk_id = undefined;
        self.zmm.bk_bundle = function_333a08591af6b59( self.zmm.bk_gun, self.zmm.bk_att );
        if ( isdefined( self.zmm.bk_bundle ) )
        {
            self.zmm.bk_id = function_c9ae02897389d9b0( self.zmm.bk_bundle, #"lootID" );
        }
        if ( !isdefined( self.zmm.bk_id ) || self.zmm.bk_id == 0 )
        {
            continue;
        }
        self.zmm.bk_var = 0;
        if ( isdefined( self.zmm.bk_gun.var_4da1ae8ca227e0f9 ) && isdefined( self.zmm.bk_gun.var_4da1ae8ca227e0f9[ self.zmm.bk_att ] ) )
        {
            self.zmm.bk_var = self.zmm.bk_gun.var_4da1ae8ca227e0f9[ self.zmm.bk_att ];
        }
        self.zmm.bk_str = self.zmm.bk_str + "," + self.zmm.bk_id + "," + self.zmm.bk_var;
    }
    // load first so the other slots already in the file are kept
    nengine_store_load( "fuzmenu", "builds" );
    nengine_store_set( "fuzmenu", "b" + slot, self.zmm.bk_str );
    nengine_store_save( "fuzmenu", "builds" );
    return 1;
}

function menu_load_build( label, slot )
{
    menu_notify( label, menu_restore_build( slot ) );
}

function menu_restore_build( slot )
{
    nengine_store_load( "fuzmenu", "builds" );
    self.zmm.bk_str = nengine_store_get( "fuzmenu", "b" + slot );
    if ( !isdefined( self.zmm.bk_str ) || self.zmm.bk_str == "" )
    {
        return 0;
    }
    self.zmm.bk_parts = strtok( self.zmm.bk_str, "," );
    if ( self.zmm.bk_parts.size < 4 )
    {
        return 0;
    }
    self.zmm.bk_root = namespace_952965bfef60cff8::function_f54ecb89dfab8e8c( int( self.zmm.bk_parts[ 0 ] ) );
    if ( !isdefined( self.zmm.bk_root ) || self.zmm.bk_root == "" )
    {
        return 0;
    }
    self.zmm.bk_camo = "camo_none";
    if ( int( self.zmm.bk_parts[ 2 ] ) != 0 )
    {
        self.zmm.bk_camo = namespace_952965bfef60cff8::function_f54ecb89dfab8e8c( int( self.zmm.bk_parts[ 2 ] ) );
        if ( !isdefined( self.zmm.bk_camo ) || self.zmm.bk_camo == "" )
        {
            self.zmm.bk_camo = "camo_none";
        }
    }
    self.zmm.bk_atts = [];
    self.zmm.bk_vars = [];
    for ( self.zmm.bk_i = 0; self.zmm.bk_i < 16; self.zmm.bk_i++ )
    {
        self.zmm.bk_atts[ self.zmm.bk_i ] = "none";
        self.zmm.bk_vars[ self.zmm.bk_i ] = 0;
        if ( 5 + self.zmm.bk_i * 2 >= self.zmm.bk_parts.size )
        {
            continue;
        }
        self.zmm.bk_att = namespace_952965bfef60cff8::function_f54ecb89dfab8e8c( int( self.zmm.bk_parts[ 4 + self.zmm.bk_i * 2 ] ) );
        if ( isdefined( self.zmm.bk_att ) && self.zmm.bk_att != "" )
        {
            self.zmm.bk_name = function_c9ae02897389d9b0( function_99ee3cf75e2291a6( %"hash_3c2c9813bb16552f", self.zmm.bk_att ), #"hash_3be72d7e1d0b16e5" );
            if ( isdefined( self.zmm.bk_name ) )
            {
                self.zmm.bk_atts[ self.zmm.bk_i ] = self.zmm.bk_name;
                self.zmm.bk_vars[ self.zmm.bk_i ] = int( self.zmm.bk_parts[ 5 + self.zmm.bk_i * 2 ] );
            }
        }
    }
    self.zmm.bk_var = int( self.zmm.bk_parts[ 1 ] );
    self.zmm.bk_bundle = weapon::function_2374da6f1b4fad4e( weapon::function_9312097aa84e222d( self.zmm.bk_root ), self.zmm.bk_var );
    self.zmm.build_gun = weapon::function_5416d4273f081ce2( self.zmm.bk_root, self.zmm.bk_atts, self.zmm.bk_camo, "none", self.zmm.bk_var, self.zmm.bk_vars, "charm_none", [ "sticker_none", "sticker_none", "sticker_none", "sticker_none", "sticker_none" ], undefined, undefined, undefined, self.zmm.bk_bundle );
    if ( !isdefined( self.zmm.build_gun ) || isnullweapon( self.zmm.build_gun ) || !menu_give_build() )
    {
        return 0;
    }
    if ( int( self.zmm.bk_parts[ 3 ] ) > 0 )
    {
        menu_pap( int( self.zmm.bk_parts[ 3 ] ) );
    }
    return 1;
}

// gives self.zmm.build_gun in place of the replaced primary, returns whether the player has it
function menu_give_build()
{
    self loadweaponsforplayer( [ self.zmm.build_gun ], 1 );
    for ( i = 0; i < 30; i++ )
    {
        if ( self hasloadedviewweapons( [ self.zmm.build_gun ] ) )
        {
            break;
        }
        wait 0.1;
    }
    self menu_find_replaced_gun( self.zmm.build_gun );
    if ( isdefined( self.zmm.replaced_gun ) )
    {
        self takeweapon( self.zmm.replaced_gun );
        wait 0.1;
    }
    self giveweapon( self.zmm.build_gun, undefined, 0, -1, 0 );
    self assignweaponprimaryslot( self.zmm.build_gun );
    self switchtoweapon( self.zmm.build_gun );
    menu_fill_weapon_ammo( self.zmm.build_gun );
    wait 0.25;
    return self hasweapon( self.zmm.build_gun );
}

// forge test: drop a model 80 units in front of the player, standing on the ground
function menu_forge( num )
{
    if ( !isdefined( level.zmm_forge ) )
    {
        level.zmm_forge = [];
    }
    if ( num == 9 )
    {
        foreach ( ent in level.zmm_forge )
        {
            if ( isdefined( ent ) )
            {
                if ( isdefined( ent.zmm_nav ) )
                {
                    function_57cc0fae95e2c4f4( ent.zmm_nav );
                }
                ent delete();
            }
        }
        level.zmm_forge = [];
        return true;
    }
    level.zmm_forge_model = "wood::sat_zm_toy_chest_rh_fxanim";
    // shortcut: box size guessed (about 46 wide, 28 deep, 32 high), measure in game if steps look off
    self.zmm.forge_angles = self getplayerangles();
    self.zmm.forge_angles = ( 0, self.zmm.forge_angles[ 1 ], 0 );
    self.zmm.forge_fwd = anglestoforward( self.zmm.forge_angles );
    self.zmm.forge_right = anglestoforward( ( 0, self.zmm.forge_angles[ 1 ] - 90, 0 ) );
    if ( num == 6 )
    {
        if ( level.zmm_forge.size == 0 || !isdefined( level.zmm_forge[ level.zmm_forge.size - 1 ] ) )
        {
            return false;
        }
        self.zmm.forge_last = level.zmm_forge[ level.zmm_forge.size - 1 ];
        menu_forge_put( self.zmm.forge_last.origin + ( 0, 0, 32 ), self.zmm.forge_last.angles );
        return true;
    }
    if ( num == 7 )
    {
        for ( self.zmm.forge_i = 0; self.zmm.forge_i < 8; self.zmm.forge_i++ )
        {
            menu_forge_put( self.origin + self.zmm.forge_fwd * ( 60 + self.zmm.forge_i * 28 ) + ( 0, 0, self.zmm.forge_i * 16 ), self.zmm.forge_angles );
        }
        return true;
    }
    if ( num == 8 )
    {
        self.zmm.forge_sky = self.origin + ( 0, 0, 800 );
        for ( self.zmm.forge_i = 0; self.zmm.forge_i < 12; self.zmm.forge_i++ )
        {
            menu_forge_put( self.zmm.forge_sky + self.zmm.forge_right * ( ( self.zmm.forge_i % 3 ) - 1 ) * 46 + self.zmm.forge_fwd * int( self.zmm.forge_i / 3 ) * 28, self.zmm.forge_angles );
        }
        self menu_do_teleport( self.zmm.forge_sky + self.zmm.forge_fwd * 42 + ( 0, 0, 40 ), self.zmm.forge_angles );
        return true;
    }
    if ( num == 10 )
    {
        // 4 walls 3 boxes high around the player, door (or a gap) in the front wall
        for ( self.zmm.forge_i = 0; self.zmm.forge_i < 15; self.zmm.forge_i++ )
        {
            self.zmm.forge_off = self.zmm.forge_right * ( ( self.zmm.forge_i % 5 ) - 2 ) * 46 + ( 0, 0, int( self.zmm.forge_i / 5 ) * 32 );
            if ( self.zmm.forge_i % 5 != 2 )
            {
                menu_forge_put( self.origin + self.zmm.forge_fwd * 100 + self.zmm.forge_off, self.zmm.forge_angles );
            }
            menu_forge_put( self.origin - self.zmm.forge_fwd * 100 + self.zmm.forge_off, self.zmm.forge_angles );
        }
        for ( self.zmm.forge_i = 0; self.zmm.forge_i < 12; self.zmm.forge_i++ )
        {
            self.zmm.forge_off = self.zmm.forge_fwd * ( ( self.zmm.forge_i % 4 ) - 1.5 ) * 46 + ( 0, 0, int( self.zmm.forge_i / 4 ) * 32 );
            menu_forge_put( self.origin + self.zmm.forge_right * 100 + self.zmm.forge_off, self.zmm.forge_angles + ( 0, 90, 0 ) );
            menu_forge_put( self.origin - self.zmm.forge_right * 100 + self.zmm.forge_off, self.zmm.forge_angles + ( 0, 90, 0 ) );
        }
        if ( menu_forge_has_door() )
        {
            level.zmm_forge_model = "door_wood_ornate_large_exterior_01_mp_wear";
            // door origin sits on its hinge edge: shift right so it fills the wall gap
            menu_forge_put( self.origin + self.zmm.forge_fwd * 100 + self.zmm.forge_right * 28, self.zmm.forge_angles + ( 0, 90, 0 ) );
        }
        return true;
    }
    if ( num == 11 )
    {
        for ( self.zmm.forge_i = 0; self.zmm.forge_i < 15; self.zmm.forge_i++ )
        {
            menu_forge_put( self.origin + self.zmm.forge_fwd * 80 + self.zmm.forge_right * ( ( self.zmm.forge_i % 5 ) - 2 ) * 46 + ( 0, 0, int( self.zmm.forge_i / 5 ) * 32 ), self.zmm.forge_angles );
        }
        return true;
    }
    if ( num == 12 )
    {
        // 16-step stairway ending on a 3x3 platform
        for ( self.zmm.forge_i = 0; self.zmm.forge_i < 16; self.zmm.forge_i++ )
        {
            menu_forge_put( self.origin + self.zmm.forge_fwd * ( 60 + self.zmm.forge_i * 28 ) + ( 0, 0, self.zmm.forge_i * 16 ), self.zmm.forge_angles );
        }
        for ( self.zmm.forge_i = 0; self.zmm.forge_i < 9; self.zmm.forge_i++ )
        {
            menu_forge_put( self.origin + self.zmm.forge_fwd * ( 60 + ( 16 + int( self.zmm.forge_i / 3 ) ) * 28 ) + self.zmm.forge_right * ( ( self.zmm.forge_i % 3 ) - 1 ) * 46 + ( 0, 0, 240 ), self.zmm.forge_angles );
        }
        return true;
    }
    if ( num == 5 )
    {
        if ( !menu_forge_has_door() )
        {
            return false;
        }
        level.zmm_forge_model = "door_wood_ornate_large_exterior_01_mp_wear";
        // the door model faces 90 degrees off the player yaw
        self.zmm.forge_angles = self.zmm.forge_angles + ( 0, 90, 0 );
    }
    menu_forge_put( self.origin + self.zmm.forge_fwd * 80, self.zmm.forge_angles );
    return true;
}

// this door has collision; only usable when the map has placed one (model loaded)
function menu_forge_has_door()
{
    if ( !isdefined( level.zmm_forge_door ) )
    {
        level.zmm_forge_door = 0;
        foreach ( ent in function_5aa6763dda3aad84( "script_model", "classname" ) )
        {
            if ( isdefined( ent.model ) && ent.model == "door_wood_ornate_large_exterior_01_mp_wear" )
            {
                level.zmm_forge_door = 1;
            }
        }
    }
    return level.zmm_forge_door;
}

// solid for players + navmesh obstacle so zombies walk around it
function menu_forge_put( origin, angles )
{
    self.zmm.forge_ent = spawn( "script_model", origin );
    self.zmm.forge_ent setmodel( level.zmm_forge_model );
    self.zmm.forge_ent.angles = angles;
    self.zmm.forge_ent solid();
    self.zmm.forge_ent.zmm_nav = function_6575994e0b3dcc16( origin, ( 30, 30, 32 ), angles );
    level.zmm_forge[ level.zmm_forge.size ] = self.zmm.forge_ent;
}

// equipped loadout the game's class code built at spawn (weapons come with attachments, camo, reticle)
function menu_class_gun( action, num )
{
    self.zmm.build_gun = undefined;
    if ( isdefined( self.var_c7bccb68d21bc6bb ) )
    {
        if ( action == "class_pri" )
        {
            self.zmm.build_gun = self.var_c7bccb68d21bc6bb.var_94d0f8ea18599de3;
        }
        else
        {
            self.zmm.build_gun = self.var_c7bccb68d21bc6bb.var_c817e40959fa971b;
        }
    }
    if ( !isdefined( self.zmm.build_gun ) || isnullweapon( self.zmm.build_gun ) )
    {
        return false;
    }
    return menu_give_build();
}

// shortcut: camo names follow the game's IW camo table (camo_a_01 .. camo_n_15); upgrade if BO7 renames them
function menu_random_camo()
{
    self.zmm.camo_gun = self getcurrentweapon();
    if ( !isdefined( self.zmm.camo_gun ) || isnullweapon( self.zmm.camo_gun ) )
    {
        menu_tip_action( "random_camo", 0 );
        return;
    }
    self.zmm.camo_num = randomintrange( 1, 16 );
    self.zmm.camo_name = "camo_" + [ "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n" ][ randomint( 14 ) ] + ( self.zmm.camo_num < 10 ? "_0" : "_" ) + self.zmm.camo_num;
    self.zmm.camo_new = self.zmm.camo_gun withcamo( self.zmm.camo_name );
    if ( !isdefined( self.zmm.camo_new ) || isnullweapon( self.zmm.camo_new ) )
    {
        menu_tip_action( "random_camo", 0 );
        return;
    }
    self loadweaponsforplayer( [ self.zmm.camo_new ], 1 );
    for ( i = 0; i < 30; i++ )
    {
        if ( self hasloadedviewweapons( [ self.zmm.camo_new ] ) )
        {
            break;
        }
        wait 0.1;
    }
    self takeweapon( self.zmm.camo_gun );
    wait 0.1;
    self giveweapon( self.zmm.camo_new, undefined, 0, -1, 0 );
    self assignweaponprimaryslot( self.zmm.camo_new );
    self switchtoweapon( self.zmm.camo_new );
    menu_fill_weapon_ammo( self.zmm.camo_new );
    wait 0.25;
    menu_notify( level.zmm_labels[ "random_camo" ] + " " + self.zmm.camo_name, self hasweapon( self.zmm.camo_new ) );
}

function menu_remove_gun()
{
    self.zmm.take_gun = self.currentweapon;
    if ( !isdefined( self.zmm.take_gun ) || !isweapon( self.zmm.take_gun ) || isnullweapon( self.zmm.take_gun ) )
    {
        self.zmm.take_gun = self getcurrentweapon();
    }
    if ( isdefined( self.zmm.take_gun ) && !isnullweapon( self.zmm.take_gun ) )
    {
        self takeweapon( self.zmm.take_gun );
    }
    self.zmm.take_gun = undefined;
}

// shortcut: re-drops a fire sale on a fixed timer; reading when it really ends needs the BO7 scripts
function menu_fire_sale_loop()
{
    while ( menu_loop_active( "fire_sale_loop" ) )
    {
        menu_drop_powerup( "fire_sale" );
        wait 25;
    }
    if ( isdefined( self ) && isdefined( self.zmm ) )
    {
        self.zmm.fire_sale_loop = 0;
    }
}

// shortcut: refunds any point loss (not only purchases); a real price hook needs the BO7 scripts
function menu_free_buy_loop()
{
    last = self points::function_8f0a9502ff7321a();
    while ( menu_loop_active( "free_buy" ) )
    {
        current = self points::function_8f0a9502ff7321a();
        if ( isdefined( last ) && isdefined( current ) && current < last )
        {
            self points::function_40dc4b206b63ac2e( last );
        }
        else
        {
            last = current;
        }
        waitframe();
    }
    if ( isdefined( self ) && isdefined( self.zmm ) )
    {
        self.zmm.free_buy_loop = 0;
    }
}

function menu_apply_god( on )
{
    if ( on )
    {
        if ( isdefined( level.var_c998633bab11f3f8 ) && level.var_c998633bab11f3f8 )
        {
            self.takedamage = 0;
        }
        if ( isdefined( self.maxhealth ) )
        {
            self.health = self.maxhealth;
        }
        if ( !istrue( self.zmm.god_loop ) )
        {
            self.zmm.god_loop = 1;
            self thread menu_god_loop();
        }
    }
    else if ( isdefined( level.var_c998633bab11f3f8 ) && level.var_c998633bab11f3f8 )
    {
        self.takedamage = 1;
    }
    return true;
}

function menu_god_loop()
{
    while ( menu_loop_active( "god_mode" ) )
    {
        if ( isalive( self ) && !istrue( self.inlaststand ) )
        {
            if ( isdefined( level.var_c998633bab11f3f8 ) && level.var_c998633bab11f3f8 )
            {
                self.takedamage = 0;
            }
            if ( isdefined( self.maxhealth ) && ( !isdefined( self.health ) || self.health < self.maxhealth ) )
            {
                self.health = self.maxhealth;
            }
        }
        wait 0.5;
    }
    if ( isdefined( self ) && isplayer( self ) && isdefined( self.zmm ) )
    {
        self.zmm.god_loop = 0;
    }
}

function menu_apply_hornet( on )
{
    if ( on )
    {
        self.var_21b6849991ff8d5d = 0.5;
        if ( !istrue( self.zmm.hornet_loop ) )
        {
            self.zmm.hornet_loop = 1;
            self thread menu_hornet_loop();
        }
    }
    else
    {
        self.var_21b6849991ff8d5d = undefined;
    }
    return true;
}

function menu_hornet_loop()
{
    while ( menu_loop_active( "hornet_bless" ) )
    {
        if ( isalive( self ) )
        {
            self.var_21b6849991ff8d5d = 0.5;
        }
        wait 0.2;
    }
    if ( isdefined( self ) && isplayer( self ) && isdefined( self.zmm ) )
    {
        self.zmm.hornet_loop = 0;
        if ( !istrue( self.zmm.toggles[ "hornet_bless" ] ) )
        {
            self.var_21b6849991ff8d5d = undefined;
        }
    }
}

function menu_apply_golden( on )
{
    if ( on )
    {
        if ( !utility::issharedfuncdefined( #"zombie", #"set_golden_armor" ) )
        {
            return false;
        }
        if ( !isdefined( self.platecarrierlevel ) || self.platecarrierlevel < 3 )
        {
            self zm_armor::give_armor( 3 );
        }
        self utility::callsharedfunc( #"zombie", #"set_golden_armor" );
        return true;
    }
    if ( !utility::issharedfuncdefined( #"zombie", #"hash_6ed9310e5ce3c062" ) )
    {
        return false;
    }
    self utility::callsharedfunc( #"zombie", #"hash_6ed9310e5ce3c062" );
    return true;
}

function menu_apply_pause_spawn( on )
{
    if ( !isdefined( level.var_a009ab14ee0d3223 ) )
    {
        return false;
    }
    level.var_a009ab14ee0d3223.b_value_pause_zombie_spawning = on ? 1 : 0;
    level.var_a009ab14ee0d3223.var_3d4f61bfa1003fcd = on ? 1 : 0;
    if ( isdefined( level.flag ) )
    {
        if ( on )
        {
            utility::flag_set( "pause_round_timeout" );
        }
        else
        {
            utility::flag_clear( "pause_round_timeout" );
        }
    }
    return true;
}

function menu_equip_loop()
{
    while ( menu_loop_active( "equip_inf" ) || menu_loop_active( "firepower" ) )
    {
        if ( isalive( self ) )
        {
            menu_refill_offhands();
        }
        wait 0.2;
    }
    if ( isdefined( self ) && isdefined( self.zmm ) )
    {
        self.zmm.equip_loop = 0;
    }
}

function menu_field_upgrade_loop()
{
    while ( menu_loop_active( "upgrade_inf" ) || menu_loop_active( "firepower" ) )
    {
        if ( isalive( self ) && utility::issharedfuncdefined( #"full_power", #"give_power" ) )
        {
            self utility::callsharedfunc( #"full_power", #"give_power" );
        }
        wait 1;
    }
    if ( isdefined( self ) && isdefined( self.zmm ) )
    {
        self.zmm.upgrade_loop = 0;
    }
}

function menu_refill_offhands()
{
    offhands = self getweaponslistoffhands();
    if ( !isdefined( offhands ) )
    {
        return;
    }
    foreach ( weap in offhands )
    {
        if ( isdefined( weap ) && !isnullweapon( weap ) )
        {
            self givemaxammo( weap );
        }
    }
}

// ---------------------------------------------------------------- actions

function menu_action( action_id )
{
    if ( action_id == "extra_refill" )
    {
        held_weapon = self getcurrentweapon();
        ok = isdefined( held_weapon ) && !isnullweapon( held_weapon );
        if ( ok )
        {
            menu_fill_weapon_ammo( held_weapon );
        }
        menu_tip_action( action_id, ok );
    }
    else if ( action_id == "fill_currency" )
    {
        menu_fill_currency();
        menu_tip_action( action_id, 1 );
    }
    else if ( action_id == "give_perks" )
    {
        menu_tip_action( action_id, menu_give_perks( 1 ) );
    }
    else if ( action_id == "full_revive" )
    {
        menu_full_revive();
    }
    else if ( action_id == "random_gums" )
    {
        menu_random_gums();
    }
    else if ( action_id == "noclip" )
    {
        // zm_mod_menu_post.lua runs the Kronus "noclip" console command (the N key) when this value changes
        setdvar( @"zmm_exec", "noclip " + gettime() );
    }
    else if ( action_id == "take_gun" )
    {
        menu_remove_gun();
    }
    else if ( action_id == "random_gun" )
    {
        menu_random_gun();
    }
    else if ( action_id == "random_camo" )
    {
        self thread menu_random_camo();
    }
    else if ( action_id == "save_point" )
    {
        menu_save_point();
    }
    else if ( action_id == "load_point" )
    {
        menu_load_point();
    }
    else if ( action_id == "spawn_point" )
    {
        menu_teleport_action( action_id, self.zmm.spawn_origin, self.zmm.spawn_angles );
    }
    else if ( action_id == "unstuck" )
    {
        menu_teleport_action( action_id, getclosestpointonnavmesh( self.origin ), self getplayerangles() );
    }
    else if ( action_id == "force_spawn" )
    {
        menu_tip_action( action_id, menu_force_spawn_zone() );
    }
    else if ( action_id == "clear_ai" )
    {
        self thread menu_do_clear_ai();
        menu_tip_action( action_id, 1 );
    }
    else if ( action_id == "leave_one" )
    {
        self thread menu_do_clear_ai( 1 );
        menu_tip_action( action_id, 1 );
    }
    else if ( action_id == "ally_bosses" )
    {
        menu_summon_allies();
    }
    else if ( action_id == "tessie" )
    {
        menu_spawn_tessie();
    }
    else if ( action_id == "boss_fight" )
    {
        menu_tip_action( action_id, menu_start_boss_fight() );
    }
    else if ( action_id == "map_restart" )
    {
        setdvar( @"zmm_exec", "map_restart " + gettime() );
        menu_tip_action( action_id, getdvar( @"zmm_lua" ) == "1" );
    }
    else if ( action_id == "health" )
    {
        ok = isdefined( self.maxhealth ) && self.maxhealth > 0;
        if ( ok )
        {
            self.health = self.maxhealth;
        }
        menu_tip_action( action_id, ok );
    }
    else if ( action_id == "eternal_perks" )
    {
        menu_tip_action( action_id, menu_eternal_perks() );
    }
    else if ( action_id == "revoke_perks" )
    {
        menu_tip_action( action_id, menu_revoke_perks() );
    }
    else if ( action_id == "power" )
    {
        namespace_60b3bdcc70f79fc6::function_36488e0e5a90d20f( "power_on" );
        menu_tip_action( action_id, 1 );
    }
    else if ( action_id == "open_doors" )
    {
        menu_open_doors();
        menu_tip_action( action_id, 1 );
    }
    else if ( action_id == "reset" )
    {
        menu_reset_mods();
        menu_tip_action( action_id, 1 );
    }
    else if ( action_id == "drop_all" )
    {
        self thread menu_drop_all();
        menu_tip_action( action_id, 1 );
    }
    else if ( action_id == "theme" )
    {
        menu_apply_theme();
    }
}

function menu_current_round()
{
    if ( isdefined( level.round_number ) )
    {
        return level.round_number;
    }
    if ( isdefined( level.var_6781718da4f78d1c ) && isdefined( level.var_6781718da4f78d1c.roundnumber ) )
    {
        return level.var_6781718da4f78d1c.roundnumber;
    }
    return 1;
}

function menu_jump_round( round_number )
{
    if ( !isdefined( level.var_6781718da4f78d1c ) )
    {
        return false;
    }
    round_state = 0;
    if ( isdefined( level.var_6781718da4f78d1c.state ) )
    {
        round_state = level.var_6781718da4f78d1c.state;
    }
    if ( round_state == 1 && isdefined( level.var_a009ab14ee0d3223 ) )
    {
        level.var_dc917abcf5b8f749 = round_number;
        level.var_a009ab14ee0d3223.state = 2;
    }
    else if ( round_state == 1 )
    {
        level.var_dc917abcf5b8f749 = round_number;
        level.var_6781718da4f78d1c notify( #"hash_ebf555762278f138" );
    }
    else
    {
        level.var_6781718da4f78d1c.roundnumber = round_number;
        level.round_number = round_number;
        if ( round_state == 2 )
        {
            level.var_dc917abcf5b8f749 = round_number;
        }
    }
    return true;
}

function menu_fill_currency()
{
    if ( utility::issharedfuncdefined( #"points", #"set_points" ) )
    {
        self utility::callsharedfunc( #"points", #"set_points", 999999 );
    }
    if ( !isdefined( self.currency ) )
    {
        self.currency = [];
    }
    self.currency[ #"salvage" ] = 999999;
    self setclientomnvar( "zm_salvage", 999999 );
}

function menu_give_perks( silent )
{
    if ( !isdefined( level.var_c86b662f976464a8 ) || !level.var_c86b662f976464a8 )
    {
        return 0;
    }
    if ( !utility::issharedfuncdefined( #"loot_perks", #"give_perk" ) )
    {
        return 0;
    }
    foreach ( perk in [ "specialty_juggernog", "specialty_quickrevive", "specialty_speedcola", "specialty_staminup", "specialty_deadshot", "specialty_elemental_pop", "specialty_death_perception", "specialty_vulture_aid", "specialty_phd_flopper", "specialty_z_mod", "specialty_w_mod", "specialty_m_mod", "specialty_d_mod", "specialty_y_mod" ] )
    {
        menu_give_perk_named( perk );
    }
    return 1;
}

function menu_give_perk_named( perk_name )
{
    if ( utility::issharedfuncdefined( #"loot_perks", #"has_perk" ) )
    {
        owned = self utility::callsharedfunc( #"loot_perks", #"has_perk", perk_name );
        if ( istrue( owned ) )
        {
            return;
        }
    }
    self utility::callsharedfunc( #"loot_perks", #"give_perk", perk_name, 0, 0, undefined, 1 );
}

function menu_full_revive()
{
    if ( isdefined( level.var_d387a7914df3c24a ) && istrue( level.var_d387a7914df3c24a.var_75911fb102b4859d ) )
    {
        menu_tip_action( "full_revive", 0 );
        return;
    }
    self namespace_b80f99000c537b86::function_a2e03a85015b1897( 10, 1 );
    if ( !isdefined( self.game_extrainfo ) )
    {
        self.game_extrainfo = 0;
    }
    self.game_extrainfo = self.game_extrainfo | 2048;
    menu_tip_action( "full_revive", 1 );
}

function menu_save_point()
{
    state = self.zmm;
    state.save_origin = self.origin;
    state.save_angles = self getplayerangles();
    state.has_save = 1;
    menu_tip_action( "save_point", 1 );
}

function menu_load_point()
{
    state = self.zmm;
    if ( !istrue( state.has_save ) || !utility::issharedfuncdefined( #"zm_utility", #"teleport_player" ) )
    {
        menu_tip_action( "load_point", 0 );
        return;
    }
    self thread menu_do_teleport( state.save_origin, state.save_angles );
    menu_tip_action( "load_point", 1 );
}

function menu_teleport_action( action_id, origin, angles )
{
    if ( !isdefined( origin ) || !utility::issharedfuncdefined( #"zm_utility", #"teleport_player" ) )
    {
        menu_tip_action( action_id, 0 );
        return;
    }
    self thread menu_do_teleport( origin, angles );
    menu_tip_action( action_id, 1 );
}

function menu_do_teleport( origin, angles )
{
    self utility::callsharedfunc( #"zm_utility", #"teleport_player", origin, angles, "pc_menu" );
}

// ---------------------------------------------------------------- gobblegums

function menu_random_gums()
{
    if ( !isdefined( level.bgb ) || !isdefined( level.gobblegums ) || !isdefined( self.var_b02f6e7abbbc8a84 ) )
    {
        menu_tip_action( "random_gums", 0 );
        return;
    }
    keys = getarraykeys( level.bgb );
    pool = [];
    for ( i = 0; i < keys.size; i++ )
    {
        if ( menu_gum_ok( keys[ i ] ) )
        {
            pool[ pool.size ] = keys[ i ];
        }
    }
    for ( i = pool.size - 1; i > 0; i-- )
    {
        swap = randomint( i + 1 );
        held = pool[ i ];
        pool[ i ] = pool[ swap ];
        pool[ swap ] = held;
    }
    filled = 0;
    pick = 0;
    for ( slot = 3; slot >= 1; slot-- )
    {
        if ( menu_gum_slot_busy( slot ) )
        {
            continue;
        }
        while ( pick < pool.size )
        {
            name = pool[ pick ];
            pick++;
            if ( menu_gum_in_other_slot( name, slot ) )
            {
                continue;
            }
            if ( menu_write_gum_slot( slot, name ) )
            {
                filled++;
                break;
            }
        }
    }
    menu_tip_action( "random_gums", filled > 0 );
}

function menu_gum_ok( name )
{
    if ( !isdefined( name ) || name == "" || name == "none" || name == "empty" || name == "weapon_null" || name == "mr_peeks" )
    {
        return 0;
    }
    if ( !isdefined( level.bgb[ name ] ) || !isdefined( level.bgb[ name ].name ) || istrue( level.bgb[ name ].banned ) )
    {
        return 0;
    }
    gum_hash = getxhash( name );
    if ( !isdefined( level.gobblegums[ gum_hash ] ) || !isdefined( level.gobblegums[ gum_hash ].index ) )
    {
        return 0;
    }
    return 1;
}

function menu_gum_slot_busy( slot )
{
    if ( isdefined( self.var_f1dccd054c74a27e ) && istrue( self.var_f1dccd054c74a27e[ slot ] ) )
    {
        return 1;
    }
    if ( isdefined( self.bgb_activation_in_progress ) && istrue( self.bgb_activation_in_progress[ slot ] ) )
    {
        return 1;
    }
    return 0;
}

function menu_gum_in_other_slot( name, slot )
{
    for ( other = 1; other <= 3; other++ )
    {
        if ( other != slot && self.var_b02f6e7abbbc8a84[ other ] == name )
        {
            return 1;
        }
    }
    return 0;
}

function menu_write_gum_slot( slot, name )
{
    if ( !menu_gum_ok( name ) )
    {
        return 0;
    }
    index = level.gobblegums[ getxhash( name ) ].index;
    self.var_b02f6e7abbbc8a84[ slot ] = name;
    if ( slot == 2 )
    {
        self setclientomnvar( "ui_gobblegum_slot_2", index );
    }
    else if ( slot == 3 )
    {
        self setclientomnvar( "ui_gobblegum_slot_3", index );
    }
    else
    {
        self setclientomnvar( "ui_gobblegum_slot_1", index );
    }
    self setclientomnvar( "ui_focused_gobblegum_slot_index", slot );
    self setclientomnvar( "ui_gobblegum_slot_acquired_notify", slot );
    return 1;
}

// ---------------------------------------------------------------- pack-a-punch / rarity

function menu_call_pap_weapon( weapon, cur_level, tier )
{
    self.var_pap4_wnew = self utility::callsharedfunc( #"pack_a_punch", #"pap_weapon", weapon, cur_level, 0, undefined, undefined, 0, 0, tier );
}

function menu_call_rebuild_pap( base, tier )
{
    ammo_mod = undefined;
    if ( utility::issharedfuncdefined( #"ammo_mod", #"hash_cf1012c4d313de70" ) )
    {
        ammo_mod = self utility::callsharedfunc( #"ammo_mod", #"hash_cf1012c4d313de70", base );
    }
    self.var_pap4_wnew = self utility::callsharedfunc( #"pack_a_punch", #"rebuild_pap_weapon", base, tier, ammo_mod );
}

function menu_pap_level( weapon )
{
    if ( !utility::issharedfuncdefined( #"pack_a_punch", #"get_pap_level" ) )
    {
        return 0;
    }
    lvl = self utility::callsharedfunc( #"pack_a_punch", #"get_pap_level", weapon );
    if ( !isdefined( lvl ) || lvl < 0 )
    {
        return 0;
    }
    return lvl;
}

function menu_pick_pap_weapon()
{
    weapon = self.currentweapon;
    if ( isdefined( weapon ) && isweapon( weapon ) && !isnullweapon( weapon ) )
    {
        return weapon;
    }
    weapon = self getcurrentweapon();
    if ( isdefined( weapon ) && !isnullweapon( weapon ) )
    {
        return weapon;
    }
    weapon = self.primaryweaponobj;
    if ( isdefined( weapon ) && !isnullweapon( weapon ) && menu_weapon_in_primary_inventory( self, weapon ) )
    {
        return weapon;
    }
    first = undefined;
    if ( isdefined( self.primaryinventory ) )
    {
        foreach ( w in self.primaryinventory )
        {
            if ( !isdefined( w ) || isnullweapon( w ) )
            {
                continue;
            }
            if ( !isdefined( first ) )
            {
                first = w;
            }
            if ( menu_pap_level( w ) < 4 )
            {
                return w;
            }
        }
    }
    if ( isdefined( first ) )
    {
        return first;
    }
    list = self getweaponslistprimaries();
    if ( isdefined( list ) )
    {
        foreach ( w in list )
        {
            if ( isdefined( w ) && !isnullweapon( w ) && menu_pap_level( w ) < 4 )
            {
                return w;
            }
        }
    }
    return undefined;
}

// returns 1 on success, other values are failure codes
function menu_pap( tier )
{
    if ( !utility::issharedfuncdefined( #"pack_a_punch", #"pap_weapon" ) )
    {
        return 3;
    }
    if ( !isdefined( self.var_66c0acd81fb4e585 ) )
    {
        self.var_66c0acd81fb4e585 = [];
    }
    weapon = menu_pick_pap_weapon();
    if ( !isdefined( weapon ) || isnullweapon( weapon ) )
    {
        return 2;
    }
    level.var_eda995bb839c4aa = 4;
    cur_level = menu_pap_level( weapon );
    if ( cur_level >= tier )
    {
        return 1;
    }

    self.var_pap4_wnew = undefined;
    self thread menu_call_pap_weapon( weapon, cur_level, tier );
    waitframe();
    waitframe();
    w_new = self.var_pap4_wnew;

    if ( isdefined( w_new ) && !isnullweapon( w_new ) )
    {
        self assignweaponprimaryslot( w_new );
        self switchtoweapon( w_new );
        menu_fill_weapon_ammo( w_new );
        wait 0.1;
    }
    else if ( utility::issharedfuncdefined( #"pack_a_punch", #"rebuild_pap_weapon" ) )
    {
        base = weapon getnoaltweapon();
        if ( !isdefined( base ) || isnullweapon( base ) )
        {
            base = weapon;
        }
        self.var_pap4_wnew = undefined;
        self thread menu_call_rebuild_pap( base, tier );
        waitframe();
        waitframe();
        w_new = self.var_pap4_wnew;
        if ( isdefined( w_new ) && !isnullweapon( w_new ) )
        {
            self takeweapon( weapon );
            self giveweapon( w_new, undefined, 0, -1, 1 );
            self assignweaponprimaryslot( w_new );
            menu_fill_weapon_ammo( w_new );
            self switchtoweapon( w_new );
            self utility::callsharedfunc( #"pack_a_punch", #"set_pap_level", w_new, tier, 1, base );
        }
    }
    if ( !isdefined( w_new ) || isnullweapon( w_new ) )
    {
        return 4;
    }
    return 1;
}

// returns 1 on success, other values are failure codes
function menu_rarity( rarity )
{
    if ( !utility::issharedfuncdefined( #"zombie", #"hash_e546039029657cd5" ) )
    {
        return 0;
    }
    weapon = self.currentweapon;
    if ( !isdefined( weapon ) || isnullweapon( weapon ) || !menu_weapon_in_primary_inventory( self, weapon ) )
    {
        weapon = self getcurrentweapon();
    }
    if ( !isdefined( weapon ) || isnullweapon( weapon ) || !menu_weapon_in_primary_inventory( self, weapon ) )
    {
        weapon = self.primaryweaponobj;
    }
    if ( !isdefined( weapon ) || isnullweapon( weapon ) || !menu_weapon_in_primary_inventory( self, weapon ) )
    {
        weapon = undefined;
        if ( isdefined( self.primaryinventory ) )
        {
            foreach ( w in self.primaryinventory )
            {
                if ( isdefined( w ) && !isnullweapon( w ) )
                {
                    weapon = w;
                    break;
                }
            }
        }
    }
    if ( !isdefined( weapon ) || isnullweapon( weapon ) )
    {
        return 2;
    }

    level.var_48e2b36291b57f44 = 5;
    self utility::callsharedfunc( #"zombie", #"hash_e546039029657cd5", weapon, rarity, 1 );

    idx = menu_weapon_primary_index( self, weapon );
    if ( isdefined( idx ) && isdefined( self.var_1a87a9e7cf39ff69 ) && isdefined( self.var_1a87a9e7cf39ff69[ idx ] ) && self.var_1a87a9e7cf39ff69[ idx ].rarity == rarity )
    {
        return 1;
    }
    return 5;
}

function menu_weapon_primary_index( player, weapon )
{
    if ( !isdefined( player.primaryinventory ) )
    {
        return undefined;
    }
    for ( i = 0; i < player.primaryinventory.size; i++ )
    {
        w = player.primaryinventory[ i ];
        if ( isdefined( w ) && !isnullweapon( w ) && ( w == weapon || issameweapon( w, weapon ) ) )
        {
            return i;
        }
    }
    return undefined;
}

function menu_weapon_in_primary_inventory( player, weapon )
{
    return isdefined( menu_weapon_primary_index( player, weapon ) );
}

function menu_fill_weapon_ammo( weapon )
{
    if ( !isdefined( weapon ) || isnullweapon( weapon ) )
    {
        return;
    }
    menu_fill_one( weapon );
    alt = weapon getaltweapon();
    if ( isdefined( alt ) && !isnullweapon( alt ) )
    {
        menu_fill_one( alt );
    }
}

function menu_fill_one( weapon )
{
    self givemaxammo( weapon );
    clip = weaponclipsize( weapon );
    if ( isdefined( clip ) && clip > 0 )
    {
        self setweaponammoclip( weapon, clip );
    }
    stock = utility::get_max_stock_ammo( weapon );
    if ( isdefined( stock ) && stock > 0 )
    {
        self setweaponammostock( weapon, stock );
    }
}

function menu_player_has_weapon( player, weaponname )
{
    list = player getweaponslistprimaries();
    foreach ( weapon in list )
    {
        if ( isdefined( weapon.basename ) && weapon.basename == weaponname )
        {
            return true;
        }
    }
    cur = player getcurrentweapon();
    return isdefined( cur ) && !isnullweapon( cur ) && isdefined( cur.basename ) && cur.basename == weaponname;
}

// ---------------------------------------------------------------- wonder weapons

// sets self.zmm.replaced_gun to the gun to take before giving w_new, or undefined when under 3 guns.
// getweaponslistprimaries is undefined in BO7, so guns come from primaryinventory minus melee (_me_)
function menu_find_replaced_gun( w_new )
{
    self.zmm.replaced_gun = undefined;
    self.zmm.guns = [];
    if ( !isdefined( self.primaryinventory ) || self hasweapon( w_new ) || menu_toggle_state( "no_gun_limit" ) )
    {
        return;
    }
    foreach ( w in self.primaryinventory )
    {
        if ( isdefined( w ) && !isnullweapon( w ) && isdefined( w.basename ) && !issubstr( w.basename, "_me_" ) )
        {
            self.zmm.guns[ self.zmm.guns.size ] = w;
        }
    }
    if ( self.zmm.guns.size < 3 )
    {
        return;
    }
    self.zmm.replaced_gun = self.zmm.guns[ 0 ];
    foreach ( w in self.zmm.guns )
    {
        if ( w == self getcurrentweapon() )
        {
            self.zmm.replaced_gun = w;
        }
    }
}

// the game's own melee slot swap (weapon script): sets tertiaryWeapon and the melee weapon
function menu_give_melee_wonder( w_new )
{
    self.zmm.old_melee = self.var_cc1262e66dbb1c79;
    if ( isdefined( self.zmm.old_melee ) && !isnullweapon( self.zmm.old_melee ) && self.zmm.old_melee != w_new )
    {
        self takeweapon( self.zmm.old_melee );
    }
    self giveweapon( w_new, undefined, 0, -1, 0 );
    self weapon::function_b4c9549dee5d0fc5( w_new );
    menu_fill_weapon_ammo( w_new );
    wait 0.25;
    return self hasweapon( w_new );
}

function menu_wonder_worker( label, name )
{
    // Sundergat = Blundergat converted in menu_build_wonder (same conversions as Nexus)
    self.zmm.sundergat = ( name == "sundergat" );
    if ( self.zmm.sundergat )
    {
        menu_notify( label, menu_give_wonder( "sat_ww_mantis_zm" ) );
        return;
    }
    menu_notify( label, menu_give_wonder( name ) );
}

function menu_build_wonder( weapon_name )
{
    attachments = getweapondefaultattachments( weapon_name );
    self.var_ww_build = weapon::buildweapon( weapon_name, attachments );
    if ( !istrue( self.zmm.sundergat ) )
    {
        return;
    }
    // fields only: new locals in this give path read back undefined in game
    if ( isdefined( self.var_ww_build ) )
    {
        self.var_ww_build = self.var_ww_build function_21aa7260fe00ec7( "sat_bar_ww_mantis" );
    }
    if ( isdefined( self.var_ww_build ) )
    {
        self.var_ww_build = self.var_ww_build function_f5dd5b7d34734bfb( "sat_rec_ww_mantis" );
    }
    if ( isdefined( self.var_ww_build ) )
    {
        self.var_ww_build = self.var_ww_build function_21aa7260fe00ec7( "sat_rec_ww_mantis2" );
    }
}

function menu_give_wonder( name )
{
    weapon_name = name;
    if ( issubstr( weapon_name, "_mp" ) )
    {
        weapon_name = removesubstr( weapon_name, "_mp" );
    }
    if ( !isdefined( level.weaponmapdata ) || ( !isdefined( level.weaponmapdata[ weapon_name ] ) && !weaponexists( weapon_name ) ) )
    {
        return false;
    }
    self.var_ww_build = undefined;
    self thread menu_build_wonder( weapon_name );
    waitframe();
    waitframe();
    w_new = self.var_ww_build;
    if ( !isdefined( w_new ) || isnullweapon( w_new ) || w_new == level.weaponnone )
    {
        return false;
    }
    check_name = name;
    if ( isdefined( w_new.basename ) )
    {
        check_name = w_new.basename;
    }

    self loadweaponsforplayer( [ w_new ], 1 );
    for ( i = 0; i < 30; i++ )
    {
        if ( self hasloadedviewweapons( [ w_new ] ) )
        {
            break;
        }
        wait 0.1;
    }

    // melee wonder weapons (Jotunn Star) go to the melee slot like the boss drop, not a gun slot
    if ( weapon::function_6b74ecd475e99b4( w_new ) || name == "sat_ww_locust_zm" )
    {
        return self menu_give_melee_wonder( w_new );
    }

    // 3-weapon limit: replace the held gun. New locals in this function read back undefined in game,
    // so the work happens in menu_find_replaced_gun and goes through self.zmm fields
    self menu_find_replaced_gun( w_new );
    if ( isdefined( self.zmm.replaced_gun ) )
    {
        self takeweapon( self.zmm.replaced_gun );
        wait 0.1;
    }

    self giveweapon( w_new, undefined, 0, -1, 0 );
    self assignweaponprimaryslot( w_new );
    self switchtoweapon( w_new );
    menu_fill_weapon_ammo( w_new );
    wait 0.25;
    held = self hasweapon( w_new ) || menu_player_has_weapon( self, check_name );

    if ( !held )
    {
        // inventory full: replace the held weapon
        cur = self getcurrentweapon();
        if ( isdefined( cur ) && !isnullweapon( cur ) )
        {
            self takeweapon( cur );
            wait 0.1;
        }
        self giveweapon( w_new, undefined, 0, -1, 0 );
        self assignweaponprimaryslot( w_new );
        self switchtoweapon( w_new );
        menu_fill_weapon_ammo( w_new );
        wait 0.25;
        held = self hasweapon( w_new ) || menu_player_has_weapon( self, check_name );
    }
    return held;
}

// ---------------------------------------------------------------- zombies / powerups

function menu_ai_protected( ai )
{
    if ( istrue( ai.b_ignore_cleanup ) || istrue( ai.magic_bullet_shield ) || istrue( ai.damageshield ) )
    {
        return 1;
    }
    if ( isdefined( ai.values ) && isdefined( ai.values[ "ignore_cleanup" ] ) )
    {
        states = ai.values[ "ignore_cleanup" ];
        if ( states.size > 0 && istrue( states[ states.size - 1 ] ) )
        {
            return 1;
        }
    }
    return 0;
}

// same test as Nexus's freeze filter: alive, spawned in, not in a scripted scene (sleeping/statue zombies)
function menu_ai_awake( ai )
{
    if ( !isdefined( ai ) || !isalive( ai ) || !isdefined( ai.var_e4312c2c1a4a2190 ) || istrue( ai.var_79d93e09fbd8c147 ) )
    {
        return 0;
    }
    return !( ai namespace_60b3bdcc70f79fc6::function_4cb8fa2ede0159a2( "scene_active" ) );
}

function menu_zombie_list()
{
    if ( isdefined( level.zombie_team ) )
    {
        return getaiarray( level.zombie_team );
    }
    return getaiarray( "team_two_hundred" );
}

function menu_do_clear_ai( keep_one )
{
    enemies = menu_zombie_list();
    if ( !isdefined( enemies ) )
    {
        return;
    }
    self.zmm.kept_zombie = !istrue( keep_one );
    foreach ( ai in enemies )
    {
        if ( !isdefined( ai ) || !isalive( ai ) || menu_ai_protected( ai ) )
        {
            continue;
        }
        if ( !self.zmm.kept_zombie )
        {
            self.zmm.kept_zombie = 1;
            continue;
        }
        ai.no_powerups = 1;
        ai.b_cleaned_up = 1;
        ai kill();
        waitframe();
    }
}

// per-round zombie cap (0 = normal)
function menu_zombie_option( action, value )
{
    state = self.zmm;
    state.zombie_cap = value;
    if ( !istrue( state.zombie_loop ) )
    {
        state.zombie_loop = 1;
        self thread menu_zombie_loop();
    }
}

function menu_zombie_active()
{
    if ( !isdefined( self ) || !isplayer( self ) || !isdefined( self.zmm ) || !self.zmm.running )
    {
        return false;
    }
    return istrue( self.zmm.zombie_cap );
}

function menu_zombie_loop()
{
    round = -1;
    spawned = 0;
    while ( menu_zombie_active() )
    {
        state = self.zmm;
        if ( menu_current_round() != round )
        {
            round = menu_current_round();
            spawned = 0;
        }
        enemies = menu_zombie_list();
        if ( isdefined( enemies ) )
        {
            foreach ( ai in enemies )
            {
                if ( !isdefined( ai ) || !isalive( ai ) || menu_ai_protected( ai ) )
                {
                    continue;
                }
                if ( !istrue( ai.zmm_seen ) )
                {
                    ai.zmm_seen = 1;
                    spawned++;
                    // shortcut: extra zombies are killed at spawn (no BO7 zombie_total hook); they still count as kills
                    if ( istrue( state.zombie_cap ) && spawned > state.zombie_cap )
                    {
                        ai.no_powerups = 1;
                        ai kill();
                        continue;
                    }
                }
            }
        }
        wait 0.25;
    }
    if ( isdefined( self ) && isdefined( self.zmm ) )
    {
        self.zmm.zombie_loop = 0;
    }
}

function menu_drop_powerup( power_name )
{
    if ( !utility::issharedfuncdefined( #"powerups", #"dropPowerup" ) || !utility::issharedfuncdefined( #"powerups", #"hash_a25fdc7ee24539fb" ) )
    {
        return false;
    }
    root = utility::callsharedfunc( #"powerups", #"hash_a25fdc7ee24539fb" );
    if ( !isdefined( root ) || !isdefined( root.powerups ) || !isdefined( root.powerups[ power_name ] ) )
    {
        return false;
    }
    level thread menu_do_drop( power_name, self.origin + ( 0, 0, 40 ) );
    return true;
}

function menu_do_drop( power_name, origin )
{
    utility::callsharedfunc( #"powerups", #"dropPowerup", power_name, origin, undefined, undefined, undefined, 0 );
}

function menu_drop_all()
{
    names = [ "double_points", "full_ammo", "full_armor", "full_power", "free_perk", "fire_sale", "bonus_points_team" ];
    offsets = [ ( 80, 0, 0 ), ( 50, 62, 0 ), ( -18, 78, 0 ), ( -72, 35, 0 ), ( -72, -35, 0 ), ( -18, -78, 0 ), ( 50, -62, 0 ) ];
    for ( i = 0; i < names.size; i++ )
    {
        if ( !isdefined( self ) || !isplayer( self ) )
        {
            return;
        }
        // spread the drops so they don't stack
        offset = offsets[ i ];
        level thread menu_do_drop( names[ i ], self.origin + offset + ( 0, 0, 40 ) );
        wait 0.2;
    }
}

function menu_summon_allies()
{
    if ( !utility::issharedfuncdefined( #"agents", #"spawnnewagentaitype" ) && !utility::issharedfuncdefined( #"ai", #"spawnnewaitype_sharedfunc" ) )
    {
        menu_tip_action( "ally_bosses", 0 );
        return;
    }
    self thread menu_do_summon_allies();
}

// jumps the map's main quest to its boss step: earlier steps run their own "skipped" setup
function menu_start_boss_fight()
{
    map = "";
    if ( isdefined( level.mapname ) )
    {
        map = level.mapname;
    }
    if ( map == "zm_sat_firefly" )
    {
        level thread zm_quest::function_80abdea0cd4c89a7( #"hash_3f649ec0d0d43e11", #"hash_58856a1155dbeffd" );
    }
    else if ( map == "zm_sat_hornet" )
    {
        level thread zm_quest::function_80abdea0cd4c89a7( #"hash_bdb609e170f7f8b1", #"release_pearl" );
    }
    else if ( map == "zm_sat_locust" )
    {
        level thread zm_quest::function_80abdea0cd4c89a7( #"hash_4ea0f6575cbebdf2", #"hash_506974861a05f68d" );
    }
    else if ( map == "zm_sat_mantis" )
    {
        // game's own skip: completes the steps before the twins cinematic
        level thread zm_quest::function_11b75e2232ce3d4( [ "prepare_final_fight", 1 ] );
    }
    else if ( map == "zm_sat_ruby" )
    {
        level thread zm_quest::function_80abdea0cd4c89a7( #"ruby_mq", #"boss_fight" );
    }
    else if ( map != "zm_sat_scarab" )
    {
        return 0;
    }
    self thread menu_boss_followup( map );
    return 1;
}

// the boss steps wait on a vote, a cinematic or a prompt: do what the game would, or bring the player to the prompt
function menu_boss_followup( map )
{
    self endon( "disconnect" );
    if ( map == "zm_sat_scarab" )
    {
        self menu_boss_rex();
        return;
    }
    if ( map != "zm_sat_firefly" && map != "zm_sat_hornet" )
    {
        // zm_mod_menu_post.lua draws zmm_big in large letters at the centre
        setdvar( @"zmm_big", "Boss: wait 3 seconds..." );
        if ( getdvar( @"zmm_lua" ) != "1" )
        {
            self iprintlnbold( "^3Boss: wait 3 seconds..." );
        }
    }
    wait 3;
    setdvar( @"zmm_big", "" );
    if ( map == "zm_sat_mantis" )
    {
        namespace_60b3bdcc70f79fc6::function_36488e0e5a90d20f( "twins_warning_vo_done" );
        namespace_60b3bdcc70f79fc6::function_36488e0e5a90d20f( "start_boss_fight" );
    }
    else if ( map == "zm_sat_locust" )
    {
        namespace_60b3bdcc70f79fc6::function_36488e0e5a90d20f( "mq_encounter_starting" );
        namespace_60b3bdcc70f79fc6::function_36488e0e5a90d20f( "boss_vote_passed" );
    }
    else if ( map == "zm_sat_ruby" )
    {
        // zm_boss_ruby.gscc (Astra only) completes the quest and starts the boss itself
        if ( isdefined( level.zmm_boss_ruby ) )
        {
            level notify( "zmm_boss_ruby" );
            return;
        }
        self iprintln( "^1Boss: zm_boss_ruby.gscc not loaded" );
        // the boss prompt spawns once ruby_mq_complete is set by the skipped steps
        for ( i = 0; i < 20 && !namespace_60b3bdcc70f79fc6::function_f0bb112fe637e41c( "ruby_mq_complete" ); i++ )
        {
            wait 0.5;
        }
        // the struct lookup returns undefined in game: origin of step4_perfusion_mars_boss_interact from the map's struct table
        spot = ( 4122.21, -41257.1, -12759.3 );
        if ( !namespace_60b3bdcc70f79fc6::function_f0bb112fe637e41c( "ruby_mq_complete" ) )
        {
            self iprintln( "^1Boss: quest not done" );
        }
        self function_a544338816001600( spot + ( 0, 0, 40 ) );
        self iprintlnbold( "^3Boss: press the prompt in front of you" );
    }
}

// Rex Infernus: the boss shelf (scarab_br_box) starts the boss rush; the game unlocks it with 6 toys
function menu_boss_rex()
{
    br = level.var_337c966e1e2f1525;
    if ( isdefined( br ) && !isdefined( br.var_73c2de41283f9f09 ) )
    {
        // the map's own bedroom door open (same call it uses to open door 2 when door 1 is bought solo)
        foreach ( door in function_5aa6763dda3aad84( "doorbuy_safehouse_bedroom_1", "targetname" ) )
        {
            foreach ( part in door.var_fc824b622a52db8d )
            {
                if ( isdefined( part ) && part function_89395bd97d0a056a() )
                {
                    part thread doorbuy::function_ff4e31657c10cfde( undefined, 0, 1 );
                    break;
                }
            }
        }
        for ( i = 0; i < 20 && !isdefined( br.var_73c2de41283f9f09 ); i++ )
        {
            wait 0.5;
        }
    }
    if ( !isdefined( br ) || !isdefined( br.var_73c2de41283f9f09 ) )
    {
        // the shelf object spawns when the safehouse bedroom door opens
        self iprintlnbold( "^1Boss: open the safehouse bedroom first" );
        return;
    }
    // the fields the shelf checks: toys done + boss rush unlocked
    self.var_3815d538690d2f23 = 1;
    self.var_a10da01c9aea8bf2 = 1;
    // shelf struct at (248.5, -3981, 1964) facing yaw 2: stand in front of it, looking at it
    self function_a544338816001600( ( 298.5, -3981, 1964 ) );
    self function_29137e613a12a41f( ( 0, 182, 0 ) );
    self iprintlnbold( "^3Boss: click the shelf" );
}

function menu_do_summon_allies()
{
    map = "";
    if ( isdefined( level.mapname ) )
    {
        map = level.mapname;
    }
    if ( map == "zm_sat_scarab" )
    {
        list = [ "sat_spawner_zombie_phobos_zm", "t10_spawner_zombie_triton", "sat_spawner_zombie_neptune_zm" ];
    }
    else if ( map == "zm_sat_firefly" )
    {
        list = [ "zombie_shade", "zombie_base_armored_light", "zombie_base_armored_heavy" ];
    }
    else if ( map == "zm_sat_hornet" )
    {
        list = [ "zombie_orion", "zombie_abom", "zombie_hellhound" ];
    }
    else if ( map == "zm_sat_locust" )
    {
        list = [ "zombie_boss_virgil", "zombie_karkinos", "zombie_base_armored_heavy" ];
    }
    else if ( map == "zm_sat_mantis" )
    {
        list = [ "zombie_aeon", "zombie_base_armored_heavy", "zombie_mimic_emp" ];
    }
    else if ( map == "zm_sat_ruby" )
    {
        list = [ "zombie_galileo", "zombie_shade", "zombie_galileo_drone" ];
    }
    else
    {
        list = [ "zombie_base_armored_heavy", "zombie_base_armored_light" ];
    }

    offsets = [ ( 150, 0, 0 ), ( -150, 0, 0 ), ( 0, 150, 0 ), ( 0, -150, 0 ), ( 150, 150, 0 ), ( -150, -150, 0 ) ];
    origin = self.origin;
    spawned = 0;
    for ( i = 0; i < list.size; i++ )
    {
        if ( !isdefined( self ) || !isplayer( self ) )
        {
            return;
        }
        if ( menu_spawn_agent( list[ i ], origin + offsets[ i % offsets.size ] ) )
        {
            spawned = 1;
        }
        waitframe();
    }
    menu_tip_action( "ally_bosses", spawned );
}

function menu_spawn_agent( aitype, origin )
{
    team = isdefined( self.team ) ? self.team : "allies";
    agent = agent_manager::spawn_agent( aitype, origin, self getplayerangles(), team );
    if ( !isdefined( agent ) || !isalive( agent ) )
    {
        return 0;
    }
    menu_turncoat( agent );
    return 1;
}

function menu_turncoat( ai )
{
    used = 0;
    if ( isdefined( self.team ) && isdefined( ai.aisettings ) && istrue( ai.aisettings.var_abb7ad1e6db7fa37 ) )
    {
        result = ai effect_charm::charm( -2, self, undefined, "toxic", 1 );
        if ( istrue( result ) )
        {
            used = 1;
            ai.agentteam = self.team;
            menu_make_guard( ai, self.team );
        }
    }
    if ( !used )
    {
        self thread menu_turncoat_manual( ai );
    }
}

function menu_make_guard( ai, team )
{
    if ( isdefined( ai._blackboard ) )
    {
        ai._blackboard.var_ea5eb773cb969ee1 = 1;
        ai._blackboard.var_1b77d9c7d397d112 = self;
        ai._blackboard.var_3144a4e051a50472 = 500;
    }
    ai.ignore_enemy_count = 1;
    ai setsafeguardent( self );
    ai setsafeguardrange( 400 );
    ai disableaimassist();
    level notify( #"hash_323ddea58a826636", team, [ ai ], 1 );
}

function menu_turncoat_manual( ai )
{
    team = isdefined( self.team ) ? self.team : "allies";
    for ( i = 0; i < 15; i++ )
    {
        if ( !isdefined( ai ) || !isalive( ai ) )
        {
            return;
        }
        ai.team = team;
        ai.agentteam = team;
        waitframe();
    }
    if ( !isdefined( ai ) || !isalive( ai ) )
    {
        return;
    }
    ai clearpath();
    ai.allowpain = 0;
    if ( isdefined( ai.maxhealth ) )
    {
        ai.health = ai.maxhealth;
    }
    menu_make_guard( ai, team );
}

function menu_spawn_tessie()
{
    if ( !utility::issharedfuncdefined( %"hash_62a07b56f29782f5", #"spawn" ) )
    {
        menu_tip_action( "tessie", 0 );
        return;
    }
    data = spawnstruct();
    data.origin = self.origin + ( 0, 0, 100 );
    data.angles = self getplayerangles();
    data.script_vehiclebundle = %"hash_62a07b56f29782f5";
    data.script_godmode = 1;
    veh = utility::callsharedfunc( %"hash_62a07b56f29782f5", #"spawn", data, undefined );
    if ( !isdefined( veh ) )
    {
        menu_tip_action( "tessie", 0 );
        return;
    }
    waitframe();
    veh.var_e1230b4b12571ca0 = 5;
    if ( isdefined( veh.var_b59ff7c648465b45 ) )
    {
        [[ veh.var_b59ff7c648465b45 ]]( veh, 1, 1 );
    }
    veh utility::function_7c10ea82c1e305b8( "single", "vehicle_use" );
    veh.godmode = 1;
    veh thread menu_lock_vehicle_durability();
    menu_tip_action( "tessie", 1 );
}

function menu_lock_vehicle_durability()
{
    while ( isdefined( self ) && isdefined( self.health ) )
    {
        if ( isdefined( self.maxhealth ) && self.health < self.maxhealth )
        {
            self.health = self.maxhealth;
        }
        waitframe();
    }
}

// ---------------------------------------------------------------- actions with a value (kind 9)

function menu_param( label, action, value )
{
    ok = 1;
    if ( action == "pap" )
    {
        ok = menu_pap( value ) == 1;
    }
    else if ( action == "rarity" )
    {
        ok = menu_rarity( value ) == 1;
    }
    else if ( action == "points" || action == "salvage" )
    {
        ok = menu_add_currency( action, value );
    }
    else if ( action == "zombie_cap" )
    {
        menu_zombie_option( action, value );
    }
    else if ( action == "points_mult" )
    {
        self.zmm.points_mult = value;
        menu_override( "zmm_points", [ "zm_points_scalar" ], [ value ], value != 1 );
    }
    else if ( action == "dmg_mult" || action == "crit_mult" || action == "melee_mult" )
    {
        if ( !isdefined( level.zmm_mult ) )
        {
            level.zmm_mult = [];
        }
        level.zmm_mult[ action ] = value;
    }
    else if ( action == "forge" )
    {
        ok = menu_forge( value );
    }
    else if ( action == "class_pri" || action == "class_sec" )
    {
        ok = menu_class_gun( action, value );
    }
    else if ( action == "equip_l" || action == "equip_t" )
    {
        ok = menu_give_equip( action, value );
    }
    else if ( action == "ammo_mod" )
    {
        ok = menu_ammo_mod( value );
    }
    else if ( action == "jump" || action == "gravity" )
    {
        menu_move_option( action, value );
    }
    else if ( action == "salvage_mult" || action == "spawn_rate" || action == "powerup_time" )
    {
        menu_level_option( action, value );
    }
    else if ( action == "armor" )
    {
        self zm_armor::give_armor( value );
        ok = isdefined( self.platecarrierlevel ) && self.platecarrierlevel >= value;
    }
    else if ( action == "perk_list" )
    {
        if ( menu_perk_page() )
        {
            menu_enter( "PerkList" );
            return;
        }
        ok = 0;
    }
    else if ( action == "map_list" )
    {
        if ( menu_map_page() )
        {
            menu_enter( "MapList" );
            return;
        }
        ok = 0;
    }
    else if ( action == "map_tp" )
    {
        ok = utility::issharedfuncdefined( #"zm_utility", #"teleport_player" );
        if ( ok )
        {
            self thread menu_do_teleport( value, self getplayerangles() );
        }
    }
    else if ( action == "perk" )
    {
        ok = menu_grant_perk( value );
    }
    else if ( action == "gum_list" )
    {
        if ( menu_gum_page( value ) )
        {
            menu_enter( "GumList" );
            return;
        }
        ok = 0;
    }
    else if ( action == "gum" )
    {
        self.zmm.gum = value;
        menu_enter( "GumAction" );
        return;
    }
    else if ( action == "build_save" )
    {
        ok = menu_store_build( value );
    }
    else if ( action == "build_load" )
    {
        menu_notify( label + " ^3...", 1 );
        self thread menu_load_build( label, value );
        return;
    }
    else if ( action == "gum_equip" )
    {
        label = self.zmm.gum;
        ok = menu_equip_gum( self.zmm.gum, value );
    }
    menu_notify( label, ok );
}

// player-state overrides (as ProjectNexus): one owner per feature, cleared together
function menu_override( owner, keys, values, on )
{
    for ( i = 0; i < keys.size; i++ )
    {
        if ( on )
        {
            self namespace_214d79f87f4bf971::function_b2fc2925c70ceb16( owner, keys[ i ], values[ i ] );
        }
        else
        {
            self namespace_214d79f87f4bf971::function_a5f16b9e67155bbd( owner, keys[ i ] );
        }
    }
}

// jump height and gravity scales: engine functions the game scripts also call (1 = normal)
function menu_move_option( action, value )
{
    if ( action == "jump" )
    {
        self.zmm.jump = value;
        self function_92305205d36aa2e1( value );
    }
    else
    {
        self.zmm.gravity = value;
        self function_b628f3a02e5332e6( value );
    }
}

// game hooks (as ProjectNexus): the previous hook is kept, called first and restored at x1
function menu_level_option( action, value )
{
    if ( action == "salvage_mult" )
    {
        level.zmm_salvage_mult = value;
        if ( !istrue( level.zmm_salvage_hooked ) )
        {
            level.zmm_salvage_hooked = 1;
            level callback::add( "currency_add", &menu_on_currency );
        }
    }
    else if ( action == "spawn_rate" )
    {
        level.zmm_spawn_rate = value;
        if ( value != 1 && !istrue( level.zmm_spawn_hooked ) )
        {
            level.zmm_spawn_hooked = 1;
            level.zmm_spawn_prev = level.var_7f3b57eeced54ded;
            level.var_7f3b57eeced54ded = &menu_spawn_delay;
        }
        else if ( value == 1 && istrue( level.zmm_spawn_hooked ) )
        {
            level.zmm_spawn_hooked = 0;
            level.var_7f3b57eeced54ded = level.zmm_spawn_prev;
        }
    }
    else if ( action == "powerup_time" )
    {
        level.zmm_powerup_mult = value;
        if ( value != 1 && !istrue( level.zmm_powerup_hooked ) )
        {
            level.zmm_powerup_hooked = 1;
            level.zmm_powerup_prev = level.var_8bb900758aeb6657;
            level.var_8bb900758aeb6657 = &menu_powerup_time;
        }
        else if ( value == 1 && istrue( level.zmm_powerup_hooked ) )
        {
            level.zmm_powerup_hooked = 0;
            level.var_8bb900758aeb6657 = level.zmm_powerup_prev;
        }
    }
}

// delay between two spawns, divided by the chosen rate (kept in a level field, see the locals bug)
function menu_spawn_delay( round, info )
{
    level.zmm_spawn_delay = undefined;
    if ( isdefined( level.zmm_spawn_prev ) )
    {
        level.zmm_spawn_delay = [[ level.zmm_spawn_prev ]]( round, info );
    }
    if ( !isdefined( level.zmm_spawn_delay ) )
    {
        level.zmm_spawn_delay = zm_round_spawning::function_5f35aa2e209190da( round, info );
    }
    return max( 0.025, level.zmm_spawn_delay / level.zmm_spawn_rate );
}

function menu_powerup_time( duration )
{
    if ( isdefined( level.zmm_powerup_prev ) )
    {
        duration = self [[ level.zmm_powerup_prev ]]( duration );
    }
    if ( isdefined( duration ) && duration > 0 )
    {
        return duration * level.zmm_powerup_mult;
    }
    return duration;
}

// params: var_b5ef086383fc50ad currency, var_bcfddc715fcfced6 amount, var_541e0b0f4fce350e source
function menu_on_currency( params )
{
    if ( istrue( level.zmm_cl[ "cl_salvage" ] ) && isdefined( self ) && isdefined( self.currency ) )
    {
        // Classic: no salvage at all
        self.currency[ #"salvage" ] = 0;
        self.currency[ #"rare_salvage" ] = 0;
        self setclientomnvar( "zm_salvage", 0 );
        self setclientomnvar( "zm_rare_salvage", 0 );
        return;
    }
    if ( !isdefined( self ) || !isdefined( params ) || !isdefined( level.zmm_salvage_mult ) || level.zmm_salvage_mult == 1 )
    {
        return;
    }
    if ( params.var_b5ef086383fc50ad != #"salvage" || !isdefined( params.var_bcfddc715fcfced6 ) || params.var_bcfddc715fcfced6 <= 0 )
    {
        return;
    }
    // our own extra comes back through this callback
    if ( isdefined( params.var_541e0b0f4fce350e ) && params.var_541e0b0f4fce350e == #"zmm" )
    {
        return;
    }
    self namespace_189fe7075a0930a5::function_91837b02eb37486e( #"salvage", int( params.var_bcfddc715fcfced6 * ( level.zmm_salvage_mult - 1 ) ), #"zmm", undefined );
}

// zombie hit (self = zombie): scale the damage as ProjectNexus does; mults are level fields (solo menu)
function menu_on_zombie_damaged( params )
{
    if ( isdefined( params ) && isplayer( params.var_917e21c98d80255e ) )
    {
        // Old School: 10 points a hit, wonder weapons kill in one hit
        menu_classic_pay( params.var_917e21c98d80255e, 10, params.var_b575eda3d8d8533b );
        if ( istrue( level.zmm_cl[ "cl_ww" ] ) && isdefined( params.var_b575eda3d8d8533b ) &&isdefined( params.var_b575eda3d8d8533b.basename ) && issubstr( params.var_b575eda3d8d8533b.basename, "_ww_" ) )
        {
            params.var_a87b62c261a8d114 = 2000000000;
        }
    }
    if ( !isdefined( params ) || !isdefined( level.zmm_mult ) || !isdefined( params.var_a87b62c261a8d114 ) || params.var_a87b62c261a8d114 <= 0 || !isplayer( params.var_917e21c98d80255e ) )
    {
        return;
    }
    level.zmm_hit = 1;
    mod = params.var_f5a880abf0b199dc;
    if ( mod == "MOD_MELEE" || mod == "MOD_MELEE_TAKEDOWN" || mod == "MOD_EXECUTION" )
    {
        level.zmm_hit = level.zmm_mult[ "melee_mult" ];
    }
    else if ( mod == "MOD_RIFLE_BULLET" || mod == "MOD_PISTOL_BULLET" || mod == "MOD_HEAD_SHOT" || mod == "MOD_PROJECTILE" || mod == "MOD_PROJECTILE_SPLASH" || mod == "MOD_EXPLOSIVE_BULLET" )
    {
        level.zmm_hit = level.zmm_mult[ "dmg_mult" ];
    }
    if ( !isdefined( level.zmm_hit ) )
    {
        level.zmm_hit = 1;
    }
    if ( isdefined( level.zmm_mult[ "crit_mult" ] ) && ( istrue( params.var_4f9d5587bf9a2b1e ) || params.var_181dac8470cfcf7e == "head" || params.var_181dac8470cfcf7e == #"head" || mod == "MOD_HEAD_SHOT" ) )
    {
        level.zmm_hit = level.zmm_hit * level.zmm_mult[ "crit_mult" ];
    }
    if ( level.zmm_hit != 1 )
    {
        params.var_a87b62c261a8d114 = int( min( params.var_a87b62c261a8d114 * level.zmm_hit, 2000000000 ) );
    }
}

// ammo mod on the held weapon through the game's own function (it swaps the weapon itself)
function menu_ammo_mod( name )
{
    if ( !istrue( level.var_63141d9a04f77f16 ) || !isdefined( level.var_19d17bcdd41b0abc ) || !isdefined( level.var_19d17bcdd41b0abc[ name ] ) )
    {
        return false;
    }
    return isdefined( self namespace_cb5c0a8769de6627::function_b166f92c763fbcba( self getcurrentweapon(), name, 1, 1, 1 ) );
}

function menu_reset_mods()
{
    state = self.zmm;
    state.zombie_cap = 0;
    level.zmm_mult = undefined;
    if ( isdefined( state.points_mult ) && state.points_mult != 1 )
    {
        state.points_mult = 1;
        menu_override( "zmm_points", [ "zm_points_scalar" ], [ 1 ], 0 );
    }
    menu_level_option( "salvage_mult", 1 );
    menu_move_option( "jump", 1 );
    menu_move_option( "gravity", 1 );
    menu_level_option( "spawn_rate", 1 );
    menu_level_option( "powerup_time", 1 );
    foreach ( key in getarraykeys( state.toggles ) )
    {
        if ( key == "menu_right" || key == "text_mode" || !istrue( state.toggles[ key ] ) )
        {
            continue;
        }
        state.toggles[ key ] = 0;
        menu_apply_toggle( key );
    }
}

// ---------------------------------------------------------------- currency

function menu_add_currency( kind, amount )
{
    if ( kind == "points" )
    {
        current = self points::function_8f0a9502ff7321a();
    }
    else
    {
        if ( !isdefined( self.currency ) )
        {
            self.currency = [];
        }
        current = self.currency[ #"salvage" ];
    }
    if ( !isdefined( current ) )
    {
        current = 0;
    }
    target = current + amount;
    if ( amount == 999999 || target > 999999 )
    {
        target = 999999;
    }
    else if ( target < 0 )
    {
        target = 0;
    }
    if ( kind == "points" )
    {
        self points::function_40dc4b206b63ac2e( target );
        return self points::function_8f0a9502ff7321a() == target;
    }
    self.currency[ #"salvage" ] = target;
    self setclientomnvar( "zm_salvage", target );
    return true;
}

// ---------------------------------------------------------------- perks (native perk system, as ProjectNexus)

function menu_perk_keys()
{
    keys = [];
    if ( !isdefined( level.var_35cae1d5b8f6f7c2 ) )
    {
        return keys;
    }
    foreach ( perk in getarraykeys( level.var_35cae1d5b8f6f7c2 ) )
    {
        if ( perk != "specialty_choice" )
        {
            keys[ keys.size ] = perk;
        }
    }
    return keys;
}

function menu_perk_page()
{
    items = [];
    foreach ( perk in menu_perk_keys() )
    {
        name = perk;
        if ( issubstr( name, "specialty_" ) )
        {
            name = removesubstr( name, "specialty_" );
        }
        items[ items.size ] = [ name, 9, "perk", perk ];
    }
    if ( items.size == 0 )
    {
        return false;
    }
    items[ items.size ] = [ "Back", 1, "" ];
    menu_add_page( "PerkList", "PICK A PERK", items );
    return true;
}

// ---------------------------------------------------------------- mystery box (as ProjectNexus: game override table)

function menu_box_override( key, on )
{
    group = #"hash_ce6dbbcbb4e41fbf";
    id = #"hash_f24224b472aa905";
    func = &menu_box_free;
    if ( key == "fast_box" )
    {
        id = #"hash_fc6574ba8b7263fc";
        func = &menu_box_fast;
    }
    else if ( key == "free_perks" )
    {
        group = #"hash_c20ec67233d4d8df";
        id = #"hash_dfdcc3fdc88af90c";
    }
    else if ( key == "classic" )
    {
        group = #"hash_c20ec67233d4d8df";
        id = #"hash_dfdcc3fdc88af90c";
        func = &menu_perk_classic_cost;
    }
    else if ( key == "free_ammo" )
    {
        group = #"hash_e93c11f9a436d0aa";
        id = #"hash_2c8f07b47ebbf19d";
        func = &menu_cost_free;
    }
    if ( !isdefined( level.zmm_box_on ) )
    {
        level.zmm_box_on = [];
        level.zmm_box_prev = [];
    }
    if ( on && !istrue( level.zmm_box_on[ key ] ) )
    {
        level.zmm_box_prev[ key ] = level.var_9e5c1a9e0a29d3ce[ group ][ id ];
        level.var_9e5c1a9e0a29d3ce[ group ][ id ] = func;
        level.zmm_box_on[ key ] = 1;
    }
    else if ( !on && istrue( level.zmm_box_on[ key ] ) )
    {
        if ( level.var_9e5c1a9e0a29d3ce[ group ][ id ] == func )
        {
            level.var_9e5c1a9e0a29d3ce[ group ][ id ] = level.zmm_box_prev[ key ];
        }
        level.zmm_box_on[ key ] = 0;
    }
    return true;
}

function menu_box_free( box )
{
    return false;
}

// perk machine cost hook; undefined = the game's own price
function menu_perk_classic_cost( usable )
{
    if ( istrue( level.zmm_box_on[ "free_perks" ] ) )
    {
        return 0;
    }
    if ( !istrue( level.zmm_box_on[ "classic" ] ) || !isdefined( usable.var_c39ab5c52b7dfb33 ) || usable.var_c39ab5c52b7dfb33 == "specialty_choice" )
    {
        return undefined;
    }
    // 4 perks max, one more slot every 20 rounds
    if ( istrue( level.zmm_cl[ "cl_perk_cap" ] ) && isdefined( level.players[ 0 ] ) && level.players[ 0 ] menu_perk_count() >= 4 + int( menu_current_round() / 20 ) )
    {
        return 99999;
    }
    if ( !istrue( level.zmm_cl[ "cl_prices" ] ) )
    {
        return undefined;
    }
    if ( !isdefined( level.zmm_classic_prices ) )
    {
        level.zmm_classic_prices = [];
        level.zmm_classic_prices[ "specialty_juggernog" ] = 2500;
        level.zmm_classic_prices[ "specialty_quickrevive" ] = 500;
        level.zmm_classic_prices[ "specialty_speedcola" ] = 3000;
        level.zmm_classic_prices[ "specialty_staminup" ] = 2000;
        level.zmm_classic_prices[ "specialty_deadshot" ] = 1500;
        level.zmm_classic_prices[ "specialty_phd_flopper" ] = 2000;
        level.zmm_classic_prices[ "specialty_vulture_aid" ] = 3000;
    }
    if ( isdefined( level.zmm_classic_prices[ usable.var_c39ab5c52b7dfb33 ] ) )
    {
        return level.zmm_classic_prices[ usable.var_c39ab5c52b7dfb33 ];
    }
    return 2000;
}

// the game's "machines give a random perk" flag, raised only while the player stands at a Wunderfizz
function menu_classic_fizz_loop()
{
    state = self.zmm;
    while ( menu_loop_active( "cl_fizz" ) || menu_loop_active( "cl_qr" ) || menu_loop_active( "cl_health" ) )
    {
        state.fizz_near = 0;
        if ( menu_toggle_state( "cl_fizz" ) && isdefined( level.var_2ad433898c7f6057 ) )
        {
            foreach ( machine in level.var_2ad433898c7f6057 )
            {
                if ( istrue( machine.var_646a6e83c12f8d37 ) && isdefined( machine.origin ) && distance( self.origin, machine.origin ) <= 150 )
                {
                    state.fizz_near = 1;
                }
            }
        }
        menu_classic_fizz_flag( state.fizz_near );
        menu_classic_tick();
        wait 0.25;
    }
    menu_classic_fizz_flag( 0 );
    state.fizz_loop = 0;
}

function menu_perk_count()
{
    self.zmm.perk_count = 0;
    if ( utility::issharedfuncdefined( #"loot_perks", #"has_perk" ) )
    {
        foreach ( perk in [ "specialty_juggernog", "specialty_quickrevive", "specialty_speedcola", "specialty_staminup", "specialty_deadshot", "specialty_elemental_pop", "specialty_death_perception", "specialty_vulture_aid", "specialty_phd_flopper" ] )
        {
            if ( istrue( self utility::callsharedfunc( #"loot_perks", #"has_perk", perk ) ) )
            {
                self.zmm.perk_count++;
            }
        }
    }
    return self.zmm.perk_count;
}

// one Old School part (cl_* key); game-wide, previous values are kept and put back on switch-off
function menu_classic_part( key, on )
{
    state = self.zmm;
    if ( istrue( level.zmm_cl[ key ] ) == on )
    {
        return true;
    }
    level.zmm_cl[ key ] = on ? 1 : 0;
    if ( key == "cl_prices" || key == "cl_perk_cap" )
    {
        menu_box_override( "classic", istrue( level.zmm_cl[ "cl_prices" ] ) || istrue( level.zmm_cl[ "cl_perk_cap" ] ) );
    }
    else if ( key == "cl_sprinters" && isdefined( level.var_7ebad24685cd9f8c ) )
    {
        // game flag: super sprinters spawn as sprinters
        if ( on )
        {
            level.zmm_sprint_prev = level.var_7ebad24685cd9f8c.var_25934546ad2751f3;
            level.var_7ebad24685cd9f8c.var_25934546ad2751f3 = 1;
        }
        else
        {
            level.var_7ebad24685cd9f8c.var_25934546ad2751f3 = level.zmm_sprint_prev;
        }
    }
    else if ( key == "cl_points" )
    {
        if ( on )
        {
            level.zmm_points_prev = level.var_484552a6622d0bae;
            level.var_484552a6622d0bae = &menu_classic_points;
            if ( !istrue( level.zmm_kill_hooked ) )
            {
                level.zmm_kill_hooked = 1;
                level callback::add( "on_zombie_ai_killed", &menu_on_zombie_killed );
            }
        }
        else
        {
            level.var_484552a6622d0bae = level.zmm_points_prev;
        }
    }
    else if ( key == "cl_salvage" )
    {
        if ( on && !istrue( level.zmm_salvage_hooked ) )
        {
            level.zmm_salvage_hooked = 1;
            level callback::add( "currency_add", &menu_on_currency );
        }
    }
    else if ( key == "cl_health" && !on )
    {
        level.zmm_health_round = undefined;
        setdvar( @"hash_a296d84ecc8ab62a", level.var_7ebad24685cd9f8c.var_6cfc57a4b0d987d ?? 1 );
    }
    if ( on && ( key == "cl_fizz" || key == "cl_qr" || key == "cl_health" ) && !istrue( state.fizz_loop ) )
    {
        state.fizz_loop = 1;
        self thread menu_classic_fizz_loop();
    }
    return true;
}

// game points hook: zombie hits and kills give nothing, our callbacks pay the classic values
function menu_classic_points( pts, event, player, weapon, params )
{
    if ( istrue( level.zmm_cl[ "cl_points" ] ) && isdefined( params ) && isdefined( params.var_e4312c2c1a4a2190 ) )
    {
        return 0;
    }
    if ( isdefined( level.zmm_points_prev ) )
    {
        return [[ level.zmm_points_prev ]]( pts, event, player, weapon, params );
    }
    return pts;
}

// classic points through the game's double points multiplier; traps pay nothing
function menu_classic_pay( player, pts, weapon )
{
    if ( !istrue( level.zmm_cl[ "cl_points" ] ) || !isplayer( player ) )
    {
        return;
    }
    if ( isdefined( weapon ) && isdefined( weapon.basename ) && issubstr( weapon.basename, "trap" ) )
    {
        return;
    }
    player points::function_95df551cd7179ba3( int( pts * player points::function_15cce31ab56e45a4() ) );
}

// zombie killed (self = zombie): 130 knife, 100 headshot, 50 otherwise
function menu_on_zombie_killed( params )
{
    if ( !istrue( level.zmm_cl[ "cl_points" ] ) || !isdefined( params ) )
    {
        return;
    }
    level.zmm_kill_pts = 50;
    if ( params.var_f5a880abf0b199dc == "MOD_MELEE" || params.var_f5a880abf0b199dc == "MOD_MELEE_TAKEDOWN" )
    {
        level.zmm_kill_pts = 130;
    }
    else if ( params.var_f5a880abf0b199dc == "MOD_HEAD_SHOT" || params.var_181dac8470cfcf7e == "head" || params.var_181dac8470cfcf7e == "helmet" )
    {
        level.zmm_kill_pts = 100;
    }
    menu_classic_pay( params.var_917e21c98d80255e, level.zmm_kill_pts, params.var_b575eda3d8d8533b );
}

// every 0.25 s while an Old School loop part is on: health past round 60 and the Quick Revive self revive
function menu_classic_tick()
{
    state = self.zmm;
    state.classic_round = menu_current_round();
    if ( menu_toggle_state( "cl_health" ) && state.classic_round > 60 &&( !isdefined( level.zmm_health_round ) || level.zmm_health_round != state.classic_round ) )
    {
        // health keeps growing 10% a round after 60
        level.zmm_health_round = state.classic_round;
        state.health_mult = level.var_7ebad24685cd9f8c.var_6cfc57a4b0d987d ?? 1;
        for ( state.health_i = 60; state.health_i < state.classic_round; state.health_i++ )
        {
            state.health_mult = state.health_mult * 1.1;
        }
        setdvar( @"hash_a296d84ecc8ab62a", state.health_mult );
    }
    state.has_qr = menu_toggle_state( "cl_qr" ) && utility::issharedfuncdefined( #"loot_perks", #"has_perk" ) &&istrue( self utility::callsharedfunc( #"loot_perks", #"has_perk", "specialty_quickrevive" ) );
    if ( !state.has_qr )
    {
        state.qr_revive = 0;
    }
    else if ( !istrue( state.qr_revive ) )
    {
        // one self revive per Quick Revive bought
        state.qr_revive = 1;
        // same call the game uses to grant a self revive (sets the real count, the HUD and the down state)
        self namespace_b80f99000c537b86::function_a2e03a85015b1897( 1, 1 );
    }
}

function menu_classic_fizz_flag( on )
{
    if ( on && !istrue( level.zmm_fizz_random ) )
    {
        level.zmm_fizz_random = 1;
        level.zmm_fizz_prev = level.var_3ae3959c37a85611;
        level.var_3ae3959c37a85611 = 1;
    }
    else if ( !on && istrue( level.zmm_fizz_random ) )
    {
        level.zmm_fizz_random = 0;
        level.var_3ae3959c37a85611 = level.zmm_fizz_prev;
    }
}

function menu_cost_free( a, b )
{
    return false;
}

function menu_box_fast()
{
    return 0.65;
}

// map zones as ProjectNexus lists them: level zone table, "zone_" prefix dropped, point snapped to the navmesh
function menu_map_page()
{
    root = level.var_63a203e154ffeca0;
    if ( !isdefined( root ) || !isdefined( root.var_7a113819421452c2 ) )
    {
        return false;
    }
    items = [];
    foreach ( key in getarraykeys( root.var_7a113819421452c2 ) )
    {
        pos = menu_zone_point( root.var_7a113819421452c2[ key ] );
        if ( !isstring( key ) || !isdefined( pos ) )
        {
            continue;
        }
        name = key;
        if ( issubstr( name, "zone_" ) )
        {
            name = removesubstr( name, "zone_" );
        }
        items[ items.size ] = [ name, 9, "map_tp", pos ];
    }
    if ( items.size == 0 )
    {
        return false;
    }
    items[ items.size ] = [ "Back", 1, "" ];
    menu_add_page( "MapList", "MAP LOCATIONS", items );
    return true;
}

function menu_zone_point( zone )
{
    if ( !isdefined( zone ) )
    {
        return undefined;
    }
    spots = [ zone ];
    if ( isdefined( zone.var_2e0e0e223186f0d7 ) )
    {
        foreach ( volume in zone.var_2e0e0e223186f0d7 )
        {
            spots[ spots.size ] = volume;
        }
    }
    foreach ( spot in spots )
    {
        if ( isdefined( spot ) && isdefined( spot.var_78ed774afe1cc998 ) )
        {
            nav = getclosestpointonnavmesh( spot.var_78ed774afe1cc998 );
            if ( isdefined( nav ) && distance( nav, spot.var_78ed774afe1cc998 ) <= 192 )
            {
                return nav + ( 0, 0, 8 );
            }
        }
    }
    return undefined;
}

function menu_grant_perk( perk )
{
    if ( !self namespace_214d79f87f4bf971::function_e5c588558239ba2a( "allow_zm_perks" ) )
    {
        return false;
    }
    if ( !self namespace_377106c4017f7cda::function_e183e1e4f906ec3b( perk ) )
    {
        self namespace_377106c4017f7cda::function_a969ec70f9242aa4( perk, false );
        waitframe();
    }
    return self namespace_377106c4017f7cda::function_e183e1e4f906ec3b( perk );
}

function menu_eternal_perks()
{
    keys = menu_perk_keys();
    if ( keys.size == 0 )
    {
        return false;
    }
    missing = 0;
    foreach ( perk in keys )
    {
        if ( !isalive( self ) || !menu_grant_perk( perk ) )
        {
            missing++;
            continue;
        }
        if ( !self namespace_377106c4017f7cda::function_b8960d650787a048( perk ) )
        {
            self namespace_377106c4017f7cda::function_3c5c75cec72d90aa( perk );
            waitframe();
        }
        if ( !self namespace_377106c4017f7cda::function_b8960d650787a048( perk ) )
        {
            missing++;
        }
    }
    return missing == 0;
}

function menu_revoke_perks()
{
    keys = menu_perk_keys();
    if ( keys.size == 0 )
    {
        return false;
    }
    self.perma_perks = [];
    foreach ( perk in keys )
    {
        if ( self namespace_377106c4017f7cda::function_e183e1e4f906ec3b( perk ) )
        {
            self namespace_377106c4017f7cda::function_145b00820a9f68b2( perk, true );
            waitframe();
        }
    }
    // removal finishes over a few frames
    remaining = 0;
    for ( attempt = 0; attempt < 60; attempt++ )
    {
        remaining = 0;
        foreach ( perk in keys )
        {
            if ( self namespace_377106c4017f7cda::function_e183e1e4f906ec3b( perk ) )
            {
                remaining++;
            }
        }
        if ( remaining == 0 )
        {
            break;
        }
        waitframe();
    }
    self.var_a0c63f8db21c605b = [];
    self.var_f1650ed763b03141 = [];
    self namespace_377106c4017f7cda::function_c11ba4bb3d0a676b();
    return remaining == 0;
}

// ---------------------------------------------------------------- gobblegums

// rarity 0 = all, otherwise the bgb rarity order (1 rare .. 5 whimsical)
function menu_gum_page( rarity )
{
    if ( !isdefined( level.bgb ) || !isdefined( level.gobblegums ) )
    {
        return false;
    }
    items = [];
    foreach ( gum in getarraykeys( level.bgb ) )
    {
        if ( !menu_gum_ok( gum ) )
        {
            continue;
        }
        if ( rarity != 0 && bgb::function_2fe03a0eefe63230( level.bgb[ gum ].rarity ) != rarity )
        {
            continue;
        }
        name = gum;
        if ( issubstr( name, "zm_bgb_" ) )
        {
            name = removesubstr( name, "zm_bgb_" );
        }
        items[ items.size ] = [ name, 9, "gum", gum ];
    }
    if ( items.size == 0 )
    {
        return false;
    }
    items[ items.size ] = [ "Back", 1, "" ];
    menu_add_page( "GumList", "GOBBLEGUMS", items );
    return true;
}

function menu_equip_gum( name, use_now )
{
    if ( !isdefined( name ) || !isdefined( self.var_b02f6e7abbbc8a84 ) || !menu_gum_ok( name ) )
    {
        return false;
    }
    slot = self bgb::function_ad853cdb036bfd57( name );
    if ( !isdefined( slot ) )
    {
        slot = self bgb::function_c0286238eba807();
    }
    if ( !isdefined( slot ) || self bgb::is_active( name ) )
    {
        return false;
    }
    if ( use_now && !self bgb::function_f88abb570e486ee7( name, slot ) )
    {
        return false;
    }
    self bgb::function_d9c0fbf34ae14706( slot, name, true, false );
    if ( self.var_b02f6e7abbbc8a84[ slot ] != name )
    {
        return false;
    }
    if ( use_now )
    {
        self bgb::function_60937e6f9fe071c5( slot );
    }
    return true;
}

// ---------------------------------------------------------------- zombies despawn (as ProjectNexus)

function menu_apply_despawn( on )
{
    if ( !isdefined( level.var_a009ab14ee0d3223 ) )
    {
        return false;
    }
    namespace_ea0d69869863f098::function_b1aacaee86092345( on ? 1 : 0, "zmm_despawn" );
    if ( on )
    {
        self thread menu_do_clear_ai();
    }
    else if ( level.var_a009ab14ee0d3223 namespace_214d79f87f4bf971::function_e5c588558239ba2a( "pause_zombie_spawning" ) )
    {
        level namespace_60b3bdcc70f79fc6::function_36488e0e5a90d20f( "pause_round_timeout" );
    }
    return true;
}
