#using scripts\common\utility;
#using scripts\common\weapon;
#using scripts\common\callbacks;
#using scripts\common\status_effects\effect_charm;
#using scripts\mp\zm\systems\zm_armor;
#using scripts\mp\zm\systems\agent_manager;
// hashed game scripts, same list as ProjectNexus: perks, points, overrides, bgb, round flags
#using script_3b64eb40368c1450;
#using script_6995a3eb7d571a9f;
#using script_4e3b2b1d9542e66b;
#using script_4fca32f463c5e4fa;
#using script_25a8fa2ac8997425;
#using script_3a9d7a7cfee99885;
#using script_2301d27669c5a079;
#using script_aa3bac81ad4fc8e;
#using script_427ce33ec0c820cf;
#using script_4f24ca7a470a5fa8;
#using script_4ccf8f7e270f2426;
#using script_4b576523c81e6ee3;
#using script_27623f7ac600060c;
#using script_54198e0a02e4a0cd;
#using script_7bef99a2b184bfd5;
#using script_46fecad419c065b2;
// crafting_table, gobblegum machine (both loaded by the zm core script, like magicbox)
#using script_23131bd305bbd11b;
#using script_4478f81b31480314;
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
// 10 extension action [ label, 10, module, value ]: self thread [[ level.zmm_ext[ module ] ]]( value )
// 11 extension toggle, same call; the +/- mark comes from [[ level.zmm_ext_on[ module ] ]]( value )
// Extension files (zm_mod_menu_*.gsc) wait for level.zmm_add_page, then add their pages with it.

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
    // zm_splitter_post.lua hides the split panel while this is "0"
    setdvar( @"zmm_ptimer", "0" );
    setdvar( @"zmm_recoil", "" );
    setdvar( @"zmm_hud", "" );
    setdvar( @"zmm_gg", "" );
    setdvar( @"zmm_big", "" );
    setdvar( @"zmm_logo", "" );
    setdvar( @"hash_3c05d1d16d772c9e", -1 );
    setdvar( @"hash_8054c9327575fd95", 0 );
    // the Lua can only write dvars that already exist
    setdvar( @"zmm_up", "0" );
    setdvar( @"zmm_down", "0" );
    setdvar( @"zmm_enter", "0" );
    setdvar( @"zmm_back", "0" );
    setdvar( @"zmm_open", "0" );
    setdvar( @"zmm_pad", "0" );
    setdvar( @"zmm_hk", "0" );
    // Old School parts that are on, read by the game-wide hooks
    level.zmm_cl = [];
    menu_build_pages();
    level.zmm_add_page = &menu_add_page;
    // shared helpers for the extension files (they cannot #using this script)
    level.zmm_notify_fn = &menu_notify;
    level.zmm_jump_round_fn = &menu_jump_round;
    level.zmm_round_fn = &menu_current_round;
    level.zmm_is_host_fn = &menu_is_host;
    level.zmm_ee_steps_fn = &menu_ee_steps;
    level.zmm_ee_jump_fn = &menu_ee_jump;
    level.zmm_teleport_fn = &menu_do_teleport;
    level.zmm_nav_point_fn = &menu_nav_point;
    level.zmm_zm_build_fn = &menu_zm_build;
    level callback::add( #"player_spawned", &menu_on_spawned );
    level callback::add( #"player_death", &menu_on_death );
    level callback::add( #"player_disconnect", &menu_on_disconnect );
    // player damage event used by Nexus 1.3: params.var_a87b62c261a8d114 is the damage, var_f5a880abf0b199dc the means of death
    level callback::add( #"hash_652eb614ba902b3d", &menu_on_damaged );
    level callback::add( "on_zombie_ai_damaged", &menu_on_zombie_damaged );
    level thread menu_scan_players();
    level thread menu_sr_loop();
    level thread zmsplit_bridge();
}

function menu_build_pages()
{
    level.zmm_pages = [];
    level.zmm_labels = [];
    level.zmm_toggle_keys = [];

    menu_add_page( "Main", "MAIN MENU", [
        [ "Favorites", 2, "Favorites" ],
        [ "Player", 2, "Player" ],
        [ "OP Mode", 4, "god_all" ],
        [ "Teleports", 2, "Teleports" ],
        [ "Weapons", 2, "Weapons" ],
        [ "Perks", 2, "Perks" ],
        [ "Gobblegums", 2, "Gums" ],
        [ "Points & scrap", 2, "Money" ],
        [ "Zombies", 2, "Zombies" ],
        [ "Rounds", 2, "Rounds" ],
        [ "Bonus", 2, "Powerups" ],
        [ "World", 2, "World" ],
        [ "Game modes & rules", 2, "XGame" ],
        [ "Fun & chaos", 2, "XFun" ],
        [ "Forge", 2, "Forge" ],
        [ "Speedrun", 2, "Practice" ],
        [ "Co-op", 9, "coop_list", 0 ],
        [ "Disable all mods", 5, "reset" ],
        [ "Settings", 2, "Settings" ],
        [ "Close", 0, "" ]
    ] );

    menu_add_page( "Weapons", "WEAPONS", [
        [ "Give a weapon", 2, "WeapGive" ],
        [ "Wonder weapons", 2, "Wonder" ],
        [ "Shooting options", 2, "WeapFire" ],
        [ "Damage", 2, "WeapDmg" ],
        [ "Upgrade", 2, "WeapUp" ],
        [ "Back", 1, "" ]
    ] );

    menu_add_page( "CoopAction", "PLAYER", [
        [ "Revive", 9, "coop_do", "revive" ],
        [ "Go to player", 9, "coop_do", "goto" ],
        [ "Bring to me", 9, "coop_do", "bring" ],
        [ "Back", 1, "" ]
    ] );

    menu_add_page( "Player", "PLAYER", [
        [ "God mode", 4, "god_mode" ],
        [ "Noclip (same as N key)", 5, "noclip" ],
        [ "Cinematic mode", 4, "cinema" ],
        [ "Zombies ignore me", 4, "ignoreme" ],
        [ "Speed x1.6", 4, "speed" ],
        [ "No fall damage", 4, "no_fall" ],
        [ "No explosive self-damage", 4, "no_self_explo" ],
        [ "Restore health", 5, "health" ],
        [ "Self revives x10", 5, "full_revive" ],
        [ "Infinite tactical sprint", 4, "tacsprint" ],
        [ "Jump height", 2, "Jump" ],
        [ "Gravity", 2, "Gravity" ],
        [ "Field of view", 2, "Fov" ],
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

    // console cg_fov 110 + cg_fovscale 1.3 (the game settings stop at 120)
    menu_add_page( "Fov", "FIELD OF VIEW", [
        [ "FOV +", 9, "fov", 1 ],
        [ "Default FOV", 9, "fov", 0 ],
        [ "Back", 1, "" ]
    ] );

    menu_add_page( "Teleports", "TELEPORTS", [
        [ "Map locations", 9, "map_list", 0 ],
        [ "Return to spawn", 5, "spawn_point" ],
        [ "Unstuck", 5, "unstuck" ],
        [ "Saved spots", 2, "XSpots" ],
        [ "Back", 1, "" ]
    ] );

    menu_add_page( "Perks", "PERKS", [
        [ "All perks", 5, "give_perks" ],
        [ "Remove all perks", 5, "revoke_perks" ],
        [ "Pick a perk", 9, "perk_list", "perk" ],
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
        [ "Camos", 2, "WeapCamo" ],
        [ "Builds", 2, "WeapBuild" ],
        [ "Back", 1, "" ]
    ] );

    menu_add_page( "WeapCamo", "CAMOS", [
        [ "Random camo", 5, "random_camo" ],
        [ "Next camo", 5, "camo_next" ],
        [ "Previous camo", 5, "camo_prev" ],
        [ "Back", 1, "" ]
    ] );

    menu_add_page( "WeapBuild", "BUILDS", [
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
        [ "Use my zombie build", 4, "zm_build" ],
        [ "Assault rifles", 2, "W_ar" ],
        [ "SMGs", 2, "W_sm" ],
        [ "LMGs", 2, "W_lm" ],
        [ "Shotguns", 2, "W_sh" ],
        [ "Marksman rifles", 2, "W_dm" ],
        [ "Sniper rifles", 2, "W_sn" ],
        [ "Pistols", 2, "W_pi" ],
        [ "Launchers", 2, "W_la" ],
        [ "Melee", 2, "W_me" ],
        [ "BO6 weapons", 2, "W_bo6" ],
        [ "New weapons", 2, "ArsNew" ],
        [ "Scorestreak weapons", 2, "ArsStreak" ],
        [ "Dead Ops Arcade guns", 2, "ArsDoa" ],
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
        [ "Wonder weapon", 9, "rarity", 6 ],
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
    menu_add_page( "W_bo6", "BO6 WEAPONS", [
        [ "Assault rifles", 2, "W6_ar" ],
        [ "SMGs", 2, "W6_sm" ],
        [ "LMGs", 2, "W6_lm" ],
        [ "Shotguns", 2, "W6_sh" ],
        [ "Marksman rifles", 2, "W6_dm" ],
        [ "Sniper rifles", 2, "W6_sn" ],
        [ "Pistols", 2, "W6_pi" ],
        [ "Launchers", 2, "W6_la" ],
        [ "Melee", 2, "W6_me" ],
        [ "Specials", 2, "W6_sl" ],
        [ "Back", 1, "" ]
    ] );
    menu_bo6_page( "W6_ar", "ASSAULT RIFLES", [ "t10_ar_p01_coslo723", "t10_ar_p02_aking74", "t10_ar_p04_clove", "t10_ar_p05_fable", "t10_ar_p05_rmary2", "t10_ar_p06_asvalor", "t10_ar_p22_able18", "t10_ar_p23_love85", "t10_ar_p34_tbaker", "t10_ar_p45_kent", "t10_ar_p47_gilroy", "t10_ar_p49_fresno", "t10_ar_p54_aspen", "t10_ar_p56_milan" ] );
    menu_bo6_page( "W6_sm", "SMGS", [ "t10_sm_p02_geasy9", "t10_sm_p03_safox", "t10_sm_p04_chuck9", "t10_sm_p06_sroger3", "t10_sm_p12_roger31", "t10_sm_p21_pparis90", "t10_sm_p28_saug", "t10_sm_p41_perth", "t10_sm_p43_schuck", "t10_sm_p52_lisbon", "t10_sm_p57_mpug40" ] );
    menu_bo6_page( "W6_lm", "LMGS", [ "t10_lm_p01_aroger10", "t10_lm_p02_puncle21", "t10_lm_p07_ksugar58", "t10_lm_p33_uxray", "t10_lm_p53_mesa" ] );
    menu_bo6_page( "W6_sh", "SHOTGUNS", [ "t10_sh_p10_moslo500", "t10_sh_p11_olove", "t10_sh_p25_uncle12", "t10_sh_p27_jhavana" ] );
    menu_bo6_page( "W6_dm", "MARKSMAN RIFLES", [ "t10_dm_p01_sroger25", "t10_dm_p02_aeasy", "t10_dm_p03_sgeorge550", "t10_dm_p05_falove", "t10_dm_p09_svalor", "t10_dm_p50_erie" ] );
    menu_bo6_page( "W6_sn", "SNIPER RIFLES", [ "t10_sn_p08_ultiger", "t10_sn_p09_droger", "t10_sn_p24_love96", "t10_sn_p26_mary82", "t10_sn_p46_hugo" ] );
    menu_bo6_page( "W6_pi", "PISTOLS", [ "t10_pi_p12_paris30", "t10_pi_p13_usugar9", "t10_pi_p14_mable", "t10_pi_p14_stiger", "t10_pi_p42_pyork" ] );
    menu_bo6_page( "W6_la", "LAUNCHERS", [ "t10_la_p17_pable3", "t10_la_p18_stisaac" ] );
    menu_bo6_page( "W6_me", "MELEE", [ "t10_me_p16_bat", "t10_me_p30_cleaver", "t10_me_p31_drill", "t10_me_p36_skateboard", "t10_me_p37_katanas", "t10_me_p38_sais", "t10_me_p39_nunchaku", "t10_me_p40_bostaff", "t10_me_p48_keene", "t10_me_p51_pickaxe", "t10_me_p55_bgloves", "t10_me_p59_csaw" ] );
    menu_bo6_page( "W6_sl", "SPECIALS", [ "t10_sl_p29_goslo", "t10_sl_p35_blauncher", "t10_sl_p44_napa", "t10_sl_p58_wand" ] );

    menu_add_page( "Equip", "GIVE EQUIPMENT", [
        [ "Kazimir (black hole)", 9, "equip_t", "equip_blackhole_bomb" ],
        [ "Decoy", 9, "equip_t", "equip_decoy" ],
        [ "Monkey bomb", 9, "equip_t", "equip_monkey_bomb" ],
        [ "Stim", 9, "equip_t", "equip_adrenaline" ],
        [ "Stun grenade", 9, "equip_t", "equip_concussion" ],
        [ "Flash", 9, "equip_t", "equip_flash" ],
        [ "Smoke", 9, "equip_t", "equip_smoke" ],
        [ "Void Claw (Rex)", 9, "equip_t", "equip_grappling_hook" ],
        [ "Void Talon (upgraded, Rex)", 9, "equip_t", "equip_grappling_hook_upgraded" ],
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
        [ "Necrofluid (Ashes, Rex)", 8, "sat_ww_firefly_zm" ],
        [ "Nekomancer (Kowakujo)", 8, "sat_ww_hornet_zm" ],
        [ "Jotunn Star (Totenreich)", 8, "sat_ww_locust_zm" ],
        [ "Blundergat (Paradox)", 8, "sat_ww_mantis_zm" ],
        [ "Sundergat (Paradox)", 8, "sundergat" ],
        [ "LGM-1 (Astra)", 8, "sat_ww_ruby_zm" ],
        [ "Warden's Blight (Rex)", 8, "sat_ww_scarab_zm" ],
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
        [ "Lock the box in place", 4, "lock_box" ],
        [ "Back", 1, "" ]
    ] );

    menu_add_page( "Money", "POINTS & SCRAP", [
        [ "Max points & scrap", 5, "fill_currency" ],
        [ "Infinite points", 4, "inf_points" ],
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
        [ "Double Tap 2.0 (2 bullets)", 4, "cl_dtap" ],
        [ "Zombies in a line (training)", 4, "no_spread" ],
        [ "Running zombies", 4, "cl_run" ],
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
        [ "Spawn a zombie", 2, "ZSpawn" ],
        [ "Zombie speed", 2, "ZombieSpeed" ],
        [ "Behavior", 2, "ZombieBehav" ],
        [ "Spawning", 2, "ZombieSpawns" ],
        [ "Zombie counter", 4, "zombie_counter" ],
        [ "Tessie", 5, "tessie" ],
        [ "Back", 1, "" ]
    ] );

    menu_add_page( "ZombieSpeed", "ZOMBIE SPEED", [
        [ "Walk", 9, "zombie_speed", "walk" ],
        [ "Run", 9, "zombie_speed", "run" ],
        [ "Sprint", 9, "zombie_speed", "sprint" ],
        [ "Normal (game)", 9, "zombie_speed", "" ],
        [ "Back", 1, "" ]
    ] );

    menu_add_page( "ZombieBehav", "BEHAVIOR", [
        [ "Freeze zombies", 4, "freeze" ],
        [ "Zombies in a line (training)", 4, "no_spread" ],
        [ "Despawn zombies", 4, "despawn" ],
        [ "Back", 1, "" ]
    ] );

    menu_add_page( "ZombieSpawns", "SPAWNING", [
        [ "Stop spawns", 4, "pause_spawn" ],
        [ "Zombies per round", 2, "ZombieCount" ],
        [ "Spawn rate", 2, "SpawnRate" ],
        [ "Force spawn here", 5, "force_spawn" ],
        [ "Add a spawn point", 5, "spawn_pt_set" ],
        [ "Spawn at placed point", 4, "spawn_pt" ],
        [ "Clear spawn points", 5, "spawn_pt_clear" ],
        [ "Can zombies reach here?", 5, "nav_test" ],
        [ "Custom waves", 2, "ArsWave" ],
        [ "Detected types", 2, "ArsDetect" ],
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

    menu_add_page( "ZSpawn", "SPAWN A ZOMBIE", [
        [ "Hostile mode", 4, "spawn_hostile" ],
        [ "Regular zombies", 2, "ZSpawnBase" ],
        [ "Specials", 2, "ZSpawnSpecial" ],
        [ "Elites", 2, "ZSpawnElite" ],
        [ "Boss", 2, "ZSpawnBoss" ],
        [ "Back", 1, "" ]
    ] );

    menu_add_page( "ZSpawnBase", "REGULAR ZOMBIES", [
        [ "Zombie", 9, "spawn_ai", "zombie_base" ],
        [ "Toxic zombie", 9, "spawn_ai", "zombie_base_toxic" ],
        [ "Light armored zombie", 9, "spawn_ai", "zombie_base_armored_light" ],
        [ "Heavy armored zombie", 9, "spawn_ai", "zombie_base_armored_heavy" ],
        [ "Back", 1, "" ]
    ] );

    menu_add_page( "ZSpawnSpecial", "SPECIALS", [
        [ "Hellhound", 9, "spawn_ai", "zombie_hellhound" ],
        [ "Shade", 9, "spawn_ai", "zombie_shade" ],
        [ "Ghoul", 9, "spawn_ai", "zombie_ghoul" ],
        [ "Viper", 9, "spawn_ai", "zombie_viper" ],
        [ "Mini Viper", 9, "spawn_ai", "zombie_viper_mini" ],
        [ "Mimic", 9, "spawn_ai", "zombie_mimic" ],
        [ "Mimic EMP", 9, "spawn_ai", "zombie_mimic_emp" ],
        [ "Loom", 9, "spawn_ai", "zombie_loom" ],
        [ "Loom Minion", 9, "spawn_ai", "zombie_loom_minion" ],
        [ "Karkinos", 9, "spawn_ai", "zombie_karkinos" ],
        [ "Amalgam", 9, "spawn_ai", "zombie_amalgam" ],
        [ "Orion", 9, "spawn_ai", "zombie_orion" ],
        [ "Back", 1, "" ]
    ] );

    menu_add_page( "ZSpawnElite", "ELITES", [
        [ "Abomination", 9, "spawn_ai", "zombie_abom" ],
        [ "Abomination HVT", 9, "spawn_ai", "zombie_abom_hvt" ],
        [ "Zursa", 9, "spawn_ai", "zombie_callisto" ],
        [ "Zursa HVT", 9, "spawn_ai", "zombie_callisto_hvt" ],
        [ "Ghoul HVT", 9, "spawn_ai", "zombie_ghoul_hvt" ],
        [ "Karkinos HVT", 9, "spawn_ai", "zombie_karkinos_hvt" ],
        [ "Mimic HVT", 9, "spawn_ai", "zombie_mimic_hvt" ],
        [ "Mimic EMP HVT", 9, "spawn_ai", "zombie_mimic_hvt_emp" ],
        [ "Orion HVT", 9, "spawn_ai", "zombie_orion_hvt" ],
        [ "Viper HVT", 9, "spawn_ai", "zombie_viper_hvt" ],
        [ "Back", 1, "" ]
    ] );

    menu_add_page( "ZSpawnBoss", "BOSS", [
        [ "Z-Rex (Rex)", 9, "spawn_ai", "sat_spawner_zombie_phobos_zm" ],
        [ "Golem (Rex)", 9, "spawn_ai", "t10_spawner_zombie_triton" ],
        [ "Neptune (Rex, Astra)", 9, "spawn_ai", "sat_spawner_zombie_neptune_zm" ],
        [ "Uranus (Astra)", 9, "spawn_ai", "sat_spawner_zombie_uranus_zm" ],
        [ "Galileo (Astra)", 9, "spawn_ai", "zombie_galileo" ],
        [ "Galileo Drone (Astra)", 9, "spawn_ai", "zombie_galileo_drone" ],
        [ "Aeon (Paradox)", 9, "spawn_ai", "zombie_aeon" ],
        [ "Virgil (Totenreich)", 9, "spawn_ai", "zombie_boss_virgil" ],
        [ "Back", 1, "" ]
    ] );

    menu_add_page( "SpawnRate", "SPAWN RATE", [
        [ "Spawns x0.5", 9, "spawn_rate", 0.5 ],
        [ "Spawns x2", 9, "spawn_rate", 2 ],
        [ "Spawns x4", 9, "spawn_rate", 4 ],
        [ "Normal spawns", 9, "spawn_rate", 1 ],
        [ "Back", 1, "" ]
    ] );

    menu_add_page( "Practice", "SPEEDRUN", [
        [ "Start speedrun", 9, "practice", -1 ],
        [ "Replay the split", 9, "practice", 0 ],
        [ "Save my position as start", 9, "practice_pos", 0 ],
        [ "Back", 1, "" ]
    ] );

    menu_add_page( "Rounds", "ROUNDS", [
        [ "Type a round number", 10, "ui_type", 0 ],
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
        [ "Insta kill", 7, "insta_kill" ],
        [ "Max ammo", 7, "full_ammo" ],
        [ "Max armor", 7, "full_armor" ],
        [ "Full power", 7, "full_power" ],
        [ "Free perk", 7, "free_perk" ],
        [ "Fire sale", 7, "fire_sale" ],
        [ "Permanent fire sale", 4, "fire_sale_loop" ],
        [ "Nuke", 7, "nuke" ],
        [ "Bonus points", 7, "bonus_points_team" ],
        [ "Power-up rain", 10, "fun_chaos", "rain" ],
        [ "Power-up circle", 10, "fun_chaos", "circle" ],
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
        [ "Finish Boss Fight", 5, "boss_finish" ],
        [ "Skip to EE step", 10, "ui_ee_step", 0 ],
        [ "Restart Map", 5, "map_restart" ],
        [ "Mystery box", 2, "Box" ],
        [ "Back", 1, "" ]
    ] );


    menu_add_page( "Forge", "FORGE", [
        [ "Props", 2, "ForgeDeco" ],
        [ "Machines", 2, "ForgeMach" ],
        [ "Teleporter (place 2)", 9, "forge", 114 ],
        [ "Adjust last", 2, "ForgeEdit" ],
        [ "Save", 2, "ForgeSave" ],
        [ "Delete last", 9, "forge", 13 ],
        [ "Delete all", 9, "forge", 9 ],
        [ "Back", 1, "" ]
    ] );

    menu_add_page( "ForgeDeco", "PROPS", [
        [ "Box", 9, "forge", 0 ],
        [ "Doors", 2, "ForgePortes" ],
        [ "Walls", 2, "ForgeMurs" ],
        [ "Objects", 2, "ForgeObjets" ],
        [ "Zombie window", 9, "forge", 113 ],
        [ "Tower", 9, "forge", 12 ],
        [ "Stairs", 9, "forge", 7 ],
        [ "Mini base", 9, "forge", 10 ],
        [ "Sky platform", 9, "forge", 8 ],
        [ "Stack on last", 9, "forge", 6 ],
        [ "Back", 1, "" ]
    ] );

    menu_add_page( "ForgePortes", "DOORS", [
        [ "Webbed gate", 9, "forge", 121 ],
        [ "Ornate door (some maps)", 9, "forge", 5 ],
        [ "Back", 1, "" ]
    ] );

    menu_add_page( "ForgeMurs", "WALLS", [
        [ "Box wall", 9, "forge", 11 ],
        [ "Low wall", 9, "forge", 103 ],
        [ "Wide wall", 9, "forge", 104 ],
        [ "Wall with opening", 9, "forge", 106 ],
        [ "Pillar", 9, "forge", 105 ],
        [ "Back", 1, "" ]
    ] );

    menu_add_page( "ForgeObjets", "OBJECTS", [
        [ "Essence container", 9, "forge", 120 ],
        [ "Pack-a-Punch (deco)", 9, "forge", 124 ],
        [ "Weapon machine", 9, "forge", 125 ],
        [ "Back", 1, "" ]
    ] );

    menu_add_page( "ForgeMach", "MACHINES", [
        [ "Working mystery box", 9, "forge_mach", "box" ],
        [ "Pack-a-Punch", 9, "forge_mach", "pap" ],
        [ "Perk machine", 9, "perk_list", "forge_mach" ],
        [ "Der Wunderfizz", 9, "forge_mach", "fizz" ],
        [ "Gobblegum machine", 9, "forge_mach", "bgb" ],
        [ "Arsenal", 9, "forge_mach", "arsenal" ],
        [ "Crafting table", 9, "forge_mach", "craft" ],
        [ "Ammo crate", 9, "forge_mach", "ammo" ],
        [ "Back", 1, "" ]
    ] );

    menu_add_page( "ForgeEdit", "ADJUST LAST", [
        [ "Rotate last", 9, "forge", 16 ],
        [ "Rotate last (-45)", 9, "forge", 22 ],
        [ "Push last away", 9, "forge", 17 ],
        [ "Move last back", 9, "forge", 23 ],
        [ "Move last left", 9, "forge", 24 ],
        [ "Move last right", 9, "forge", 25 ],
        [ "Raise last", 9, "forge", 18 ],
        [ "Lower last", 9, "forge", 19 ],
        [ "Delete nearest", 9, "forge", 26 ],
        [ "Back", 1, "" ]
    ] );

    menu_add_page( "ForgeSave", "SAVE", [
        [ "Save Forge (map)", 9, "forge", 20 ],
        [ "Load Forge (map)", 9, "forge", 21 ],
        [ "Back", 1, "" ]
    ] );

    menu_add_page( "Settings", "SETTINGS", [
        [ "Menu color", 5, "theme" ],
        [ "Menu on the right", 4, "menu_right" ],
        [ "Text mode (no HUD)", 4, "text_mode" ],
        [ "Start logo", 4, "start_logo" ],
        [ "Mouse navigation", 4, "mouse_nav" ],
        [ "Aim + Melee opens the menu", 4, "aim_melee" ],
        [ "Shortcuts (F1-F12)", 9, "hk_list", 0 ],
        [ "Profiles", 2, "Profiles" ],
        [ "Back", 1, "" ]
    ] );

    menu_add_page( "Profiles", "PROFILES", [
        [ "Save profile 1", 9, "prof_save", 1 ],
        [ "Load profile 1", 9, "prof_load", 1 ],
        [ "Save profile 2", 9, "prof_save", 2 ],
        [ "Load profile 2", 9, "prof_load", 2 ],
        [ "Save profile 3", 9, "prof_save", 3 ],
        [ "Load profile 3", 9, "prof_load", 3 ],
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

// can zombies live here: navmesh under the player, then one enemy zombie 200 units ahead that should walk to him
function menu_nav_test()
{
    self.zmm.nav = getclosestpointonnavmesh( self.origin );
    if ( !isdefined( self.zmm.nav ) )
    {
        self iprintlnbold( "^1No navmesh here" );
    }
    else
    {
        self iprintlnbold( "^2Navmesh at " + int( distance( self.zmm.nav, self.origin ) ) + " units" );
    }
    self.zmm.nav_team = "team_two_hundred";
    if ( isdefined( level.zombie_team ) )
    {
        self.zmm.nav_team = level.zombie_team;
    }
    self.zmm.spawn_pos = self.origin + anglestoforward( ( 0, self getplayerangles()[ 1 ], 0 ) ) * 200;
    self.zmm.nav_ai = agent_manager::spawn_agent( "zombie_base_armored_light", menu_nav_point( self.zmm.spawn_pos ), self getplayerangles(), self.zmm.nav_team );
    return isdefined( self.zmm.nav_ai ) && isalive( self.zmm.nav_ai );
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

// BO6 refs are given without _mp, like the BO7 ones once menu_give_wonder strips it
function menu_bo6_page( id, title, refs )
{
    items = [];
    foreach ( ref in refs )
    {
        items[ items.size ] = [ ref, 8, ref ];
    }
    items[ items.size ] = [ "Back", 1, "" ];
    menu_add_page( id, title, items );
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
            // literal strings: the profiles cannot rely on getarraykeys, which hashes some keys
            if ( entry[ 1 ] == 4 && !isdefined( level.zmm_labels[ entry[ 2 ] ] ) )
            {
                level.zmm_toggle_keys[ level.zmm_toggle_keys.size ] = entry[ 2 ];
            }
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
    // Settings > Start logo, remembered across matches in kronos/fuzmenu/settings.json
    nengine_store_load( "fuzmenu", "settings" );
    state.toggles[ "start_logo" ] = nengine_store_get( "fuzmenu", "logo" ) === "0" ? 0 : 1;
    // on unless turned off: aim/fire move the cursor, aim + melee opens the menu (always on without the Lua, which has no other keys)
    state.toggles[ "mouse_nav" ] = nengine_store_get( "fuzmenu", "mouse" ) === "0" ? 0 : 1;
    state.toggles[ "aim_melee" ] = nengine_store_get( "fuzmenu", "aimmelee" ) === "0" ? 0 : 1;
    // Give a weapon uses the player's Gunsmith zombie build when there is one
    state.toggles[ "zm_build" ] = nengine_store_get( "fuzmenu", "zmbuild" ) === "1" ? 1 : 0;
    state.equip_loop = 0;
    state.upgrade_loop = 0;
    state.god_loop = 0;
    state.hornet_loop = 0;
    state.points_loop = 0;
    state.theme = 0;
    state.lua = 0;
    state.nav_open = getdvar( @"zmm_open" );
    state.spawn_origin = self.origin;
    state.spawn_angles = self getplayerangles();
    self.zmm = state;
    self thread menu_input_loop();
    self thread menu_hk_loop();
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
            // the setting is for keyboard and mouse: a controller or a guest (no Insert) always opens with aim + melee
            if ( self adsbuttonpressed() && self meleebuttonpressed() && ( !state.lua || istrue( state.toggles[ "aim_melee" ] ) || istrue( self function_7cab310f9d8209c9() ) || !menu_is_host() ) )
            {
                menu_open();
                while ( self adsbuttonpressed() || self meleebuttonpressed() )
                {
                    wait 0.05;
                }
                wait 0.2;
            }
            else if ( menu_lua_open() )
            {
                menu_open();
            }
            else
            {
                wait 0.1;
            }
            continue;
        }

        menu_sync_pad();
        if ( menu_lua_nav() )
        {
            wait 0.05;
        }
        else if ( ( !state.lua || istrue( state.toggles[ "mouse_nav" ] ) || !menu_is_host() ) && self adsbuttonpressed() )
        {
            menu_move( -1 );
            wait 0.15;
        }
        else if ( ( !state.lua || istrue( state.toggles[ "mouse_nav" ] ) || !menu_is_host() ) && self attackbuttonpressed() )
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
    // the arrow counters come from the host's keyboard only
    if ( !istrue( state.lua ) )
    {
        return false;
    }
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
    if ( getdvar( @"zmm_enter" ) != state.nav_enter )
    {
        state.nav_enter = getdvar( @"zmm_enter" );
        menu_confirm();
        return true;
    }
    if ( getdvar( @"zmm_back" ) != state.nav_back )
    {
        state.nav_back = getdvar( @"zmm_back" );
        menu_back();
        return true;
    }
    return false;
}

// tells the Lua footer which device the host is on (same builtin as the game's gamepad_only / kbm_only prompts)
function menu_sync_pad()
{
    state = self.zmm;
    if ( !state.lua )
    {
        return;
    }
    state.pad = istrue( self function_7cab310f9d8209c9() ) ? "1" : "0";
    if ( getdvar( @"zmm_pad" ) != state.pad )
    {
        setdvar( @"zmm_pad", state.pad );
    }
}

// Insert: the zmm_open counter comes from the host's keyboard only
function menu_lua_open()
{
    state = self.zmm;
    if ( getdvar( @"zmm_open" ) == state.nav_open )
    {
        return false;
    }
    state.nav_open = getdvar( @"zmm_open" );
    return menu_is_host();
}

function menu_open()
{
    state = self.zmm;
    state.page = "Main";
    state.cursor = 0;
    state.top = 0;
    state.stack = [];
    state.depth = 0;
    // presses made while the menu was closed are ignored
    state.nav_up = getdvar( @"zmm_up" );
    state.nav_down = getdvar( @"zmm_down" );
    state.nav_enter = getdvar( @"zmm_enter" );
    state.nav_back = getdvar( @"zmm_back" );
    state.is_open = true;
    menu_hud_create();
    menu_render();
}

function menu_close()
{
    state = self.zmm;
    state.is_open = false;
    state.nav_open = getdvar( @"zmm_open" );
    state.stack = [];
    state.depth = 0;
    if ( istrue( state.lua ) )
    {
        setdvar( @"zmm_view", "" );
    }
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
    menu_run_entry( level.zmm_pages[ state.page ].items[ state.cursor ] );
}

// what a menu row does: the selected row, or a shortcut key's saved row
function menu_run_entry( entry )
{
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
    else if ( kind == 10 || kind == 11 )
    {
        if ( isdefined( level.zmm_ext ) && isdefined( level.zmm_ext[ entry[ 2 ] ] ) )
        {
            self thread [[ level.zmm_ext[ entry[ 2 ] ] ]]( entry[ 3 ] );
        }
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
    if ( self.zmm.is_open )
    {
        menu_render();
    }
    // hud mode shows results in the kill feed: one hud string per result would fill the 256 text slots
    if ( !self.zmm.is_open || isdefined( self.zmm.hud ) )
    {
        self iprintln( text );
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

function menu_is_host()
{
    // a guest can sit at level.players[ 0 ], so index 0 only counts when no player reports being host
    foreach ( player in level.players )
    {
        if ( istrue( player function_b36623eefe0028c8() ) )
        {
            return self == player;
        }
    }
    return isdefined( level.players[ 0 ] ) && self == level.players[ 0 ];
}

function menu_hud_create()
{
    state = self.zmm;
    menu_hud_destroy();
    // the Lua display runs on the host's machine only: guests fall back to text mode
    state.lua = menu_is_host() && getdvar( @"zmm_lua" ) == "1";
    // guests: HUD text uses host-only nengine_text slots, so they get the text menu
    if ( state.lua || !menu_is_host() || menu_toggle_state( "text_mode" ) )
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

// text menu: previous and next item around the highlighted one
function menu_text_rows( page, cursor )
{
    count = page.items.size;
    line = "^3> " + menu_item_label( page.items[ cursor ] ) + " ^3<";
    if ( cursor > 0 )
    {
        line = "^7" + menu_item_label( page.items[ cursor - 1 ] ) + "   " + line;
    }
    if ( cursor + 1 < count )
    {
        line = line + "   ^7" + menu_item_label( page.items[ cursor + 1 ] );
    }
    return line;
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
    if ( menu_is_host() && menu_toggle_state( "start_logo" ) )
    {
        // zm_mod_menu_post.lua shows images/fuzmenu_logo.png once when this turns "1"
        setdvar( @"zmm_logo", "1" );
    }
    hint = menu_toggle_state( "aim_melee" ) || istrue( self function_7cab310f9d8209c9() ) || !menu_is_host() ? level.zmm_hint : "Insert to open";
    if ( isdefined( level.zmm_hud_splash ) )
    {
        self.zmm.hud_right = menu_toggle_state( "menu_right" );
        self [[ level.zmm_hud_splash ]]( level.zmm_name, hint );
    }
    else
    {
        // the start logo already shows the name
        if ( !( menu_is_host() && menu_toggle_state( "start_logo" ) ) )
        {
            self iprintlnbold( "^5" + level.zmm_name );
        }
        self iprintln( hint );
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
        // extension hook (weapon picture next to the menu): selected row and its line on screen
        if ( isdefined( level.zmm_on_render ) )
        {
            self [[ level.zmm_on_render ]]( page.items[ state.cursor ], state.cursor - state.top );
        }
        setdvar( @"zmm_view", "ZMM|" + state.theme + "|" + right + "|" + page.title + "|" + ( state.cursor - state.top ) + "|" + n + "|" + ( state.cursor + 1 ) + "/" + count + "|" + rows + "END" );
        return;
    }

    if ( !isdefined( state.hud ) )
    {
        // BO7 shows one centre line at a time and drops line breaks: previous / current / next on one line
        self iprintlnbold( "^5" + page.title + " ^7" + position + "   " + menu_text_rows( page, state.cursor ) );
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
    if ( entry[ 1 ] == 11 && isdefined( level.zmm_ext_on ) && isdefined( level.zmm_ext_on[ entry[ 2 ] ] ) )
    {
        return ( self [[ level.zmm_ext_on[ entry[ 2 ] ] ]]( entry[ 3 ] ) ? "+" : "-" ) + entry[ 0 ];
    }
    // perk page: Have it / Eternal show their state
    if ( entry[ 1 ] == 9 && entry[ 2 ] == "perk_have" )
    {
        return ( self namespace_377106c4017f7cda::function_e183e1e4f906ec3b( entry[ 3 ] ) ? "+" : "-" ) + entry[ 0 ];
    }
    if ( entry[ 1 ] == 9 && entry[ 2 ] == "perk_eternal" )
    {
        return ( isdefined( self.zmm.eternal ) && istrue( self.zmm.eternal[ entry[ 3 ] ] ) ? "+" : "-" ) + entry[ 0 ];
    }
    // Pick a perk: opens the perk page, eternal ones say so
    if ( entry[ 1 ] == 9 && entry[ 2 ] == "perk" )
    {
        if ( isdefined( self.zmm.eternal ) && istrue( self.zmm.eternal[ entry[ 3 ] ] ) )
        {
            return ">" + entry[ 0 ] + " (eternal)";
        }
        return ">" + entry[ 0 ];
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
    if ( key == "start_logo" || key == "mouse_nav" || key == "aim_melee" || key == "zm_build" )
    {
        nengine_store_load( "fuzmenu", "settings" );
        nengine_store_set( "fuzmenu", key == "start_logo" ? "logo" : ( key == "mouse_nav" ? "mouse" : ( key == "aim_melee" ? "aimmelee" : "zmbuild" ) ), on ? "1" : "0" );
        nengine_store_save( "fuzmenu", "settings" );
        return true;
    }
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
        foreach ( sub in [ "old_school", "no_armor", "back_shield", "og_specials", "cl_prices", "cl_perk_cap", "cl_fizz", "cl_qr", "cl_sprinters", "cl_health", "cl_points", "cl_salvage", "cl_ww", "cl_dtap", "no_spread", "cl_run" ] )
        {
            state.toggles[ sub ] = on ? 1 : 0;
            menu_apply_toggle( sub );
        }
        return true;
    }
    if ( key == "god_all" )
    {
        // one switch for the cheat toggles
        foreach ( sub in [ "god_mode", "extra_ammo", "inf_points", "no_recoil", "aimbot", "wallhack", "rapid_fire", "equip_inf", "upgrade_inf", "no_fall", "no_self_explo", "tacsprint", "firepower", "speed" ] )
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
            // max specials alive at once, read by zm_round_spawning (-1 = game default, 0 = none); menu_elite_loop switches it
            setdvar( @"hash_3c05d1d16d772c9e", 1 );
            level.zmm_special_round = menu_current_round();
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
    if ( key == "spawn_pt" )
    {
        if ( on && !istrue( state.spawn_pt_loop ) )
        {
            state.spawn_pt_loop = 1;
            self thread menu_spawn_pt_loop();
        }
        return !on || isdefined( level.zmm_spawn_pts ) || isdefined( level.zmm_windows );
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
    if ( key == "lock_box" )
    {
        // the game's own no-teddy switch: every box (map or spawned) keeps its spot
        if ( on && !istrue( level.zmm_box_locked ) )
        {
            level.zmm_box_lock_prev = level.var_5542fc8f8eafa0c0;
            level.var_5542fc8f8eafa0c0 = 1;
            level.zmm_box_locked = 1;
        }
        else if ( !on && istrue( level.zmm_box_locked ) )
        {
            level.var_5542fc8f8eafa0c0 = level.zmm_box_lock_prev;
            level.zmm_box_locked = 0;
        }
        return true;
    }
    if ( key == "free_box" || key == "fast_box" || key == "free_perks" || key == "free_ammo" )
    {
        return menu_box_override( key, on );
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
        // zmm_exec runs on the host's console: a guest would toggle the host's noclip
        if ( menu_is_host() )
        {
            setdvar( @"zmm_exec", "noclip " + gettime() );
        }
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
        self setmovespeedscale( on ? 1.6 : 1 );
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
    if ( key == "speedrun" )
    {
        if ( menu_is_host() )
        {
            setdvar( @"zmm_ptimer", on ? "1" : "0" );
        }
        return true;
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
        if ( menu_is_host() )
        {
            setdvar( @"zmm_recoil", on ? "1" : "0" );
        }
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
            // once a round, so walls of newly opened areas get hooked too
            if ( !( level.zmm_armor_hook_round === state.hud_round ) )
            {
                level.zmm_armor_hook_round = state.hud_round;
                menu_armor_wall_hook();
            }
            state.hud_text = state.hud_text + ( state.shield_hits > 0 ? "Shield: " + state.shield_hits + "/15" : "Shield: broken (armor wall)" );
        }
        if ( menu_is_host() )
        {
            setdvar( @"zmm_hud", state.hud_text );
        }
        wait 1;
        state.hud_sec++;
        if ( state.hud_sec >= 60 )
        {
            state.hud_sec = 0;
            state.hud_min++;
        }
    }
    state.hud_loop = 0;
    if ( menu_is_host() )
    {
        setdvar( @"zmm_hud", "" );
    }
}

// ---------------------------------------------------------------- speedrun splits

// one level flag per split, in run order; returns false on maps without a split list
function menu_sr_setup()
{
    map = "";
    if ( isdefined( level.mapname ) )
    {
        map = level.mapname;
    }
    sr = spawnstruct();
    if ( map == "zm_sat_ruby" )
    {
        sr.names = [ "LGM-1", "Brain", "Mars", "Ritual", "Caltheris" ];
        sr.flags = [ "ruby_wwq_complete", "ruby_mq_s2_defend_success", "ruby_mq_s3_orrery_defend_success", "ruby_mq_all_5_melody_pillars_on", "ruby_boss_fight_complete" ];
        // practice loadout per split: round, PaP tier of the held gun, armor, points, perks (first N of menu_sr_loadout's list)
        sr.lo = [ [ 7, 1, 1, 5000, 2 ], [ 12, 2, 2, 10000, 3 ], [ 15, 2, 2, 10000, 3 ], [ 18, 2, 3, 15000, 3 ], [ 20, 3, 3, 20000, 4 ] ];
    }
    else if ( map == "zm_sat_firefly" )
    {
        // fixed splits: Gauntlet, lab lockdown (serum trial) end, keys cinematic start, challenges, boss arena
        sr.mq = #"hash_3f649ec0d0d43e11";
        sr.ww = "sat_ww_firefly_zm";
        sr.quest = zm_quest::function_bf48db63228e7ef( #"firefly_ww_quest" );
        if ( !isdefined( sr.quest ) )
        {
            return false;
        }
        sr.names = [ "Gauntlet", "Lockdown end", "Keys", "Challenges", "Veytarion" ];
        sr.flags = [ sr.quest, "serum_t_finished", "mid_igc_started", "MQ_STEP_18_COMPLETE", "firefly_boss_fight_complete" ];
        // main quest step practice splits 2 to 4 start on
        sr.jumps = [ #"serum_trial", #"hash_ff159ae12616b58", #"hash_30d17f8fd9002869" ];
        sr.lo = [ [ 8, 0, 1, 5000, 2 ], [ 0, 0, 0, 0, 0 ], [ 12, 0, 1, 10000, 2 ], [ 15, 2, 1, 10000, 2 ], [ 0, 3, 1, 0, 2 ] ];
        sr.pkey = "firefly2_pos";
    }
    else if ( map == "zm_sat_hornet" )
    {
        // fixed splits, in quest order; step 29 is the banners placed on the right spots
        sr.mq = #"hash_bdb609e170f7f8b1";
        sr.ww = "sat_ww_hornet_zm";
        sr.names = [ "Cat", "Mask", "Noble", "Poisons", "Locations", "Boss", "End" ];
        sr.flags = [ "nekomata_acquired", "mq_step_5_complete", "mq_acc_n_killed", "mq_step_21_complete", "mq_step_29_complete", "hornet_boss_fight_start", "hornet_boss_fight_complete" ];
        // main quest step practice splits 2 to 6 start on
        sr.jumps = [ #"hash_e4040d7209af1d17", #"hash_7f12f627b62cc20e", #"hash_65606753e026db1b", #"hash_a79bdc3b4712faa3", #"hash_e42bbd92f05f883c" ];
        // shortcut: loadouts estimated like the other maps, tune a row if a split starts too weak or too strong
        sr.lo = [ [ 0, 0, 0, 0, 0 ], [ 8, 1, 1, 5000, 2 ], [ 12, 2, 2, 10000, 3 ], [ 15, 2, 2, 10000, 3 ], [ 18, 2, 3, 15000, 3 ], [ 20, 3, 3, 20000, 4 ], [ 20, 3, 3, 20000, 4 ] ];
        // new key: spots saved for the old generic splits do not match these
        sr.pkey = "hornet7_pos";
    }
    else if ( map == "zm_sat_locust" )
    {
        // fixed splits, in quest order
        sr.ww = "sat_ww_locust_zm";
        sr.names = [ "JOTUNN Star", "Atomkraft core", "Boss enter", "End" ];
        sr.flags = [ "ww_step_08", "mq_rp_step_03", "boss_fight_start", "boss_fight_end" ];
        // Atomkraft quest steps practice splits 2 and 3 start on: its first step, the one after the claw machine
        sr.jumps = [ #"hash_6f181b4d8608302", #"hash_e928524cf387f1a1" ];
        // shortcut: loadouts estimated like the other maps, tune a row if a split starts too weak or too strong
        sr.lo = [ [ 0, 0, 0, 0, 0 ], [ 10, 1, 2, 5000, 3 ], [ 15, 2, 3, 10000, 4 ], [ 20, 3, 3, 20000, 4 ] ];
        // new key: spots saved for the old generic splits do not match these
        sr.pkey = "locust4_pos";
    }
    else if ( map == "zm_sat_mantis" )
    {
        // fixed splits, in quest order
        sr.mq = #"hash_c863b996e7e1593c";
        sr.ww = "sat_ww_mantis_zm";
        sr.names = [ "Chalk", "Sundergat", "Symbols", "Soulbox", "Boss enter", "End" ];
        sr.flags = [ "chalk_picked_up", "wwu_weapon_retrieved", "music_notes_puzzle_completed", "sheet_music_delivered", "start_boss_fight", "boss_fight_done" ];
        sr.jumps = [ #"hash_e648d162912a28d7", #"hash_7958efe97a9d29af", #"hash_e6cfb931cb2b8e3e", #"prepare_final_fight" ];
        sr.lo = [ [ 0, 0, 0, 0, 0 ], [ 9, 1, 2, 0, 7 ], [ 13, 2, 2, 5000, 7 ], [ 15, 2, 2, 10000, 7 ], [ 17, 3, 2, 15000, 7 ], [ 17, 3, 2, 15000, 7 ] ];
        // new key: spots saved for the old generic splits do not match these
        sr.pkey = "mantis6_pos";
    }
    else if ( map == "zm_sat_scarab" )
    {
        // fixed splits, in quest order; the PaP quest has no end flag, so split 1 reads the quest itself
        sr.mq = #"hash_3757a1a15a487f02";
        sr.ww = "sat_ww_scarab_zm";
        sr.quest = zm_quest::function_bf48db63228e7ef( #"hash_fbb52a4fe83b2f5c" );
        if ( !isdefined( sr.quest ) )
        {
            return false;
        }
        sr.names = [ "Pap", "House", "Vey Finish", "Boss Enter", "End" ];
        sr.flags = [ sr.quest, "wanna_wingo_eh", "vey_temples", "enter_boss_fight_done", "scarab_boss_fight_complete" ];
        // main quest steps practice splits 2 to 4 start on: symbols, after the Eye, boss elevator
        sr.jumps = [ #"hash_b6fc86ad6da775a5", #"hash_78987cae5ae8057e", #"enter_boss_fight" ];
        // shortcut: loadouts estimated like the other maps, tune a row if a split starts too weak or too strong
        sr.lo = [ [ 0, 0, 0, 0, 0 ], [ 11, 1, 2, 5000, 3 ], [ 15, 2, 2, 10000, 4 ], [ 20, 3, 3, 15000, 4 ], [ 20, 3, 3, 20000, 4 ] ];
        // new key: spots saved for the old generic splits do not match these
        sr.pkey = "scarab5_pos";
    }
    else
    {
        return false;
    }
    // Astra kept its old save keys; other maps get their own so spots do not mix
    if ( !isdefined( sr.pkey ) )
    {
        sr.pkey = "pos";
    }
    if ( isdefined( sr.lo ) )
    {
        menu_sr_items( sr );
    }
    sr.map = map;
    sr.host = level.players[ 0 ];
    foreach ( player in level.players )
    {
        if ( player menu_is_host() )
        {
            sr.host = player;
        }
    }
    sr.index = 0;
    sr.times = [];
    sr.pb = [];
    // PB = split times of the fastest finished run, "ms,ms,..." in kronos/fuzmenu/speedrun.json
    nengine_store_load( "fuzmenu", "speedrun" );
    sr.pb_str = nengine_store_get( "fuzmenu", map );
    if ( isdefined( sr.pb_str ) && sr.pb_str != "" )
    {
        foreach ( part in strtok( sr.pb_str, "," ) )
        {
            sr.pb[ sr.pb.size ] = int( part );
        }
    }
    if ( sr.flags.size == 0 )
    {
        return false;
    }
    if ( sr.pb.size != sr.flags.size )
    {
        sr.pb = [];
    }
    // practice split asked before the restart, cleared so the next restart is a normal run
    sr.practice = 0;
    sr.p_str = nengine_store_get( "fuzmenu", "practice" );
    if ( isdefined( sr.p_str ) && sr.p_str != "" && sr.p_str != "0" )
    {
        sr.practice = int( sr.p_str );
        if ( sr.practice > sr.flags.size )
        {
            sr.practice = 0;
        }
        nengine_store_set( "fuzmenu", "practice", "0" );
        nengine_store_save( "fuzmenu", "speedrun" );
    }
    if ( map == "zm_sat_ruby" )
    {
        // ruby_mq step practice splits 3 and 4 start on (after the brain defense, on Mars)
        sr.jumps = [ #"hash_35b90be15aed204e", #"hash_41487e30c43486f1" ];
    }
    level.zmm_sr = sr;
    return true;
}

// splits from the map's quest structs: PaP, WW, each top step of the main quest, then the boss
function menu_sr_items( sr )
{
    // the Practice page lists this map's splits
    sr.items = [ [ "Start speedrun", 9, "practice", -1 ], [ "Replay the split", 9, "practice", 0 ], [ "Save my position as start", 9, "practice_pos", 0 ] ];
    for ( i = 0; i < sr.names.size; i++ )
    {
        sr.items[ sr.items.size ] = [ "Split " + ( i + 1 ) + ": " + sr.names[ i ], 9, "practice", i + 1 ];
    }
    sr.items[ sr.items.size ] = [ "Back", 1, "" ];
    menu_add_page( "Practice", "SPEEDRUN", sr.items );
}

// Paradox: the game parks its energy ball entity at the past's cloud point when the orb appears, then moves it away
// a split ends on a level flag (Astra, bosses) or on a quest / step struct marked done
function menu_sr_done( index )
{
    sr = level.zmm_sr;
    if ( sr.flags[ index ] === "vey_temples" )
    {
        return namespace_60b3bdcc70f79fc6::function_f0bb112fe637e41c( "sst_made_nice1" ) && namespace_60b3bdcc70f79fc6::function_f0bb112fe637e41c( "sst_made_nice2" ) && namespace_60b3bdcc70f79fc6::function_f0bb112fe637e41c( "sst_made_nice3" ) && namespace_60b3bdcc70f79fc6::function_f0bb112fe637e41c( "sst_made_nice4" );
    }
    if ( isstring( sr.flags[ index ] ) )
    {
        return namespace_60b3bdcc70f79fc6::function_f0bb112fe637e41c( sr.flags[ index ] );
    }
    return sr.flags[ index ].var_cb2962eb3d2eb963 == 1;
}

// other maps: finish the side quests before the split, give the WW, jump the main quest to the split's step
// splits always run from the first spawn, the speedrun toggle only shows them
function menu_sr_loop()
{
    level endon( #"game_ended" );
    while ( !menu_sr_someone_playing() )
    {
        wait 0.05;
    }
    // level.mapname is read once the map is up
    if ( !menu_sr_setup() )
    {
        return;
    }
    sr = level.zmm_sr;
    if ( sr.practice > 0 )
    {
        menu_sr_practice();
        return;
    }
    // "Start speedrun" restarted the map: show the splits
    if ( sr.practice < 0 )
    {
        sr.practice = 0;
        menu_sr_show();
    }
    menu_sr_wait_move();
    sr.start = gettime();
    while ( sr.index < sr.flags.size )
    {
        if ( menu_sr_done( sr.index ) )
        {
            sr.times[ sr.index ] = gettime() - sr.start;
            if ( sr.map != "zm_sat_mantis" && sr.map != "zm_sat_firefly" )
            {
                sr.host menu_sr_store_pos( sr.index + 2 );
            }
            iprintlnbold( "^2Split " + ( sr.index + 1 ) + "/" + sr.flags.size + " ^7" + sr.names[ sr.index ] + "  ^3" + menu_sr_time( sr.times[ sr.index ] ) + menu_sr_delta( sr.index ) );
            sr.index++;
        }
        else
        {
            waitframe();
        }
    }
    if ( sr.pb.size == 0 || sr.times[ sr.times.size - 1 ] < sr.pb[ sr.pb.size - 1 ] )
    {
        sr.pb = sr.times;
        sr.pb_str = "" + sr.times[ 0 ];
        for ( i = 1; i < sr.times.size; i++ )
        {
            sr.pb_str = sr.pb_str + "," + sr.times[ i ];
        }
        nengine_store_load( "fuzmenu", "speedrun" );
        nengine_store_set( "fuzmenu", sr.map, sr.pb_str );
        nengine_store_save( "fuzmenu", "speedrun" );
        iprintlnbold( "^2New PB: " + menu_sr_time( sr.times[ sr.times.size - 1 ] ) );
    }
}

function menu_sr_someone_playing()
{
    if ( !isdefined( level.players ) )
    {
        return false;
    }
    foreach ( player in level.players )
    {
        if ( isdefined( player ) && isalive( player ) && player.sessionstate == "playing" )
        {
            return true;
        }
    }
    return false;
}

// m:ss.t with subtraction loops (no int() / floor() on time values)
function menu_sr_time( ms )
{
    sr = level.zmm_sr;
    sr.f_ms = ms;
    sr.f_min = 0;
    sr.f_sec = 0;
    sr.f_tenth = 0;
    while ( sr.f_ms >= 60000 )
    {
        sr.f_min++;
        sr.f_ms -= 60000;
    }
    while ( sr.f_ms >= 1000 )
    {
        sr.f_sec++;
        sr.f_ms -= 1000;
    }
    while ( sr.f_ms >= 100 )
    {
        sr.f_tenth++;
        sr.f_ms -= 100;
    }
    return sr.f_min + ":" + ( sr.f_sec < 10 ? "0" : "" ) + sr.f_sec + "." + sr.f_tenth;
}

// gap to the PB at the same split: green ahead, red behind
function menu_sr_delta( index )
{
    sr = level.zmm_sr;
    if ( sr.pb.size == 0 )
    {
        return "";
    }
    if ( sr.times[ index ] <= sr.pb[ index ] )
    {
        return "  ^2-" + menu_sr_time( sr.pb[ index ] - sr.times[ index ] );
    }
    return "  ^1+" + menu_sr_time( sr.times[ index ] - sr.pb[ index ] );
}

// ---------------------------------------------------------------- splitter layout bridge
// Hands the speedrun data to zm_splitter_post.lua through dvars:
//   zm_sr 1 = splits from this mod, 2 = still waiting, 0 = no splits for this map (own clock, F6 splits)
//   zm_srmap map name, zm_srnames split names (|), zm_srpb PB times in ms (,), zm_srt finished split times in ms (,)
//   zm_tms time in ms (0 until you move, stays at the last split when done), zm_srp 1 = practice
function zmsplit_join( arr, sep )
{
    out = "";
    if ( !isdefined( arr ) )
    {
        return out;
    }
    for ( i = 0; i < arr.size; i++ )
    {
        if ( i > 0 )
        {
            out = out + sep;
        }
        out = out + arr[ i ];
    }
    return out;
}

// practice: zeros for the splits before the practised one, then its time once it is done
function zmsplit_practice_times( sr )
{
    out = "";
    for ( i = 0; i < sr.practice - 1; i++ )
    {
        if ( i > 0 )
        {
            out = out + ",";
        }
        out = out + "0";
    }
    if ( isdefined( sr.seg ) )
    {
        if ( sr.practice > 1 )
        {
            out = out + ",";
        }
        out = out + sr.seg;
    }
    return out;
}

// best segments: kept per key in the store ("<map>_best", or "<map>_pap_best" in PaP mode) as "ms,ms,..."
// and updated each time a split ends faster than ever before
function zmsplit_best_key( sr )
{
    return sr.map + "_best";
}

function zmsplit_best_load( sr, st )
{
    st.bkey = zmsplit_best_key( sr );
    st.best = [];
    nengine_store_load( "fuzmenu", "speedrun" );
    st.bstr = nengine_store_get( "fuzmenu", st.bkey );
    if ( isdefined( st.bstr ) && st.bstr != "" )
    {
        foreach ( part in strtok( st.bstr, "," ) )
        {
            st.best[ st.best.size ] = int( part );
        }
    }
    if ( st.best.size != sr.flags.size )
    {
        st.best = [];
    }
    st.nd = sr.times.size;
}

function zmsplit_best_text( sr, st )
{
    out = "";
    for ( i = 0; i < sr.flags.size; i++ )
    {
        if ( i > 0 )
        {
            out = out + ",";
        }
        if ( isdefined( st.best[ i ] ) )
        {
            out = out + st.best[ i ];
        }
        else
        {
            out = out + "0";
        }
    }
    return out;
}

function zmsplit_best_update( sr, st )
{
    st.dirty = 0;
    while ( st.nd < sr.times.size )
    {
        st.seg = sr.times[ st.nd ];
        if ( st.nd > 0 )
        {
            st.seg = st.seg - sr.times[ st.nd - 1 ];
        }
        if ( !isdefined( st.best[ st.nd ] ) || st.best[ st.nd ] <= 0 || st.seg < st.best[ st.nd ] )
        {
            st.best[ st.nd ] = st.seg;
            st.dirty = 1;
        }
        st.nd++;
    }
    if ( st.dirty )
    {
        nengine_store_load( "fuzmenu", "speedrun" );
        nengine_store_set( "fuzmenu", st.bkey, zmsplit_best_text( sr, st ) );
        nengine_store_save( "fuzmenu", "speedrun" );
    }
}

function zmsplit_bridge()
{
    level endon( #"game_ended" );
    st = spawnstruct();
    st.active = 0;
    st.manual = 0;
    st.sent = "";
    st.nm_sent = "";
    st.pb_sent = "";
    st.bt_sent = "";
    st.frame = 0;
    st.chg_sent = "";

    setdvar( "zm_tms", 0 );
    setdvar( "zm_sr", 2 );
    setdvar( "zm_srp", 0 );
    setdvar( "zm_srmap", "" );
    setdvar( "zm_srnames", "" );
    setdvar( "zm_srpb", "" );
    setdvar( "zm_srbest", "" );
    setdvar( "zm_srt", "" );
    setdvar( "zm_split", 0 );

    while ( !isdefined( level.players ) || level.players.size == 0 )
    {
        waitframe();
    }
    st.t0 = gettime();

    while ( true )
    {
        sr = level.zmm_sr;
        if ( isdefined( sr ) && isdefined( sr.names ) && isdefined( sr.flags ) )
        {
            if ( !st.active )
            {
                st.active = 1;
                setdvar( "zm_srmap", sr.map );
                setdvar( "zm_sr", 1 );
            }
            // the strings are rebuilt on a split or practice change, and twice a second for name or PB swaps
            st.frame++;
            st.chg = "" + sr.index + "_" + sr.practice;
            if ( isdefined( sr.seg ) )
            {
                st.chg = st.chg + "s";
            }
            if ( st.chg != st.chg_sent || st.frame % 10 == 0 )
            {
                st.chg_sent = st.chg;
                // names and PB are re-sent when they change (a new PB replaces the old)
                st.nm = zmsplit_join( sr.names, "|" );
                if ( st.nm != st.nm_sent )
                {
                    st.nm_sent = st.nm;
                    setdvar( "zm_srnames", st.nm );
                }
                st.pbs = zmsplit_join( sr.pb, "," );
                if ( st.pbs != st.pb_sent )
                {
                    st.pb_sent = st.pbs;
                    setdvar( "zm_srpb", st.pbs );
                }
                st.key = "" + sr.index;
                st.times = zmsplit_join( sr.times, "," );
                setdvar( "zm_srp", 0 );
                if ( sr.practice > 0 )
                {
                    setdvar( "zm_srp", 1 );
                    st.times = zmsplit_practice_times( sr );
                    st.has = 0;
                    if ( isdefined( sr.seg ) )
                    {
                        st.has = 1;
                    }
                    st.key = "p" + sr.practice + "_" + st.has;
                }
                else
                {
                    // best segments (not while practising: those times are single segments of a partial run)
                    if ( !isdefined( st.bkey ) || st.bkey != zmsplit_best_key( sr ) )
                    {
                        zmsplit_best_load( sr, st );
                    }
                    zmsplit_best_update( sr, st );
                    st.bt = zmsplit_best_text( sr, st );
                    if ( st.bt != st.bt_sent )
                    {
                        st.bt_sent = st.bt;
                        setdvar( "zm_srbest", st.bt );
                    }
                }
                if ( st.key != st.sent )
                {
                    st.sent = st.key;
                    setdvar( "zm_srt", st.times );
                }
            }
            if ( !isdefined( sr.start ) )
            {
                setdvar( "zm_tms", 0 );
            }
            else if ( sr.practice > 0 )
            {
                if ( isdefined( sr.seg ) )
                {
                    setdvar( "zm_tms", sr.seg );
                }
                else
                {
                    setdvar( "zm_tms", gettime() - sr.start );
                }
            }
            else if ( sr.index >= sr.flags.size )
            {
                setdvar( "zm_tms", sr.times[ sr.times.size - 1 ] );
            }
            else
            {
                setdvar( "zm_tms", gettime() - sr.start );
            }
        }
        else if ( gettime() - st.t0 > 15000 )
        {
            // no splits for this map: own clock from the spawn, split by hand with F6
            if ( !st.manual )
            {
                st.manual = 1;
                setdvar( "zm_sr", 0 );
            }
            setdvar( "zm_tms", gettime() - st.t0 );
        }
        waitframe();
    }
}

// practice: remembers the split, restarts the map; menu_sr_loop applies it on the next spawn
function menu_sr_practice_start( split )
{
    sr = level.zmm_sr;
    if ( !isdefined( sr ) || !menu_is_host() )
    {
        return 0;
    }
    self.zmm.sr_split = split;
    if ( self.zmm.sr_split == 0 )
    {
        self.zmm.sr_split = sr.practice;
    }
    if ( self.zmm.sr_split == 0 )
    {
        return 0;
    }
    if ( getdvar( @"zmm_lua" ) != "1" )
    {
        return 0;
    }
    nengine_store_load( "fuzmenu", "speedrun" );
    nengine_store_set( "fuzmenu", "practice", "" + self.zmm.sr_split );
    nengine_store_save( "fuzmenu", "speedrun" );
    setdvar( @"zmm_exec", "map_restart " + gettime() );
    return getdvar( @"zmm_lua" ) == "1";
}

// start point of the split being practiced, "x,y,z,yaw" (int() reads the decimals as whole units)
function menu_sr_save_pos()
{
    sr = level.zmm_sr;
    if ( !isdefined( sr ) || sr.practice == 0 )
    {
        return 0;
    }
    self menu_sr_store_pos( sr.practice );
    return 1;
}

function menu_sr_store_pos( split )
{
    sr = level.zmm_sr;
    if ( !isdefined( self ) || split > sr.flags.size )
    {
        return;
    }
    sr.pos_str = self.origin[ 0 ] + "," + self.origin[ 1 ] + "," + self.origin[ 2 ] + "," + self getplayerangles()[ 1 ];
    nengine_store_load( "fuzmenu", "speedrun" );
    nengine_store_set( "fuzmenu", sr.pkey + split, sr.pos_str );
    nengine_store_save( "fuzmenu", "speedrun" );
}

// skipping every top step runs their end code with skipped = 1; the flag is set again in case it does not
function menu_sr_finish_quest( name, flag )
{
    sr = level.zmm_sr;
    sr.quest = zm_quest::function_bf48db63228e7ef( name );
    if ( isdefined( sr.quest ) )
    {
        foreach ( step in sr.quest.var_541f59354e1e2ddd )
        {
            zm_quest::function_e65609834444650c( step, 1 );
        }
    }
    namespace_60b3bdcc70f79fc6::function_36488e0e5a90d20f( flag );
}

// Astra only: prerequisites, jump to the split's step, teleport, then time this one split (no PB save)
function menu_sr_practice()
{
    level endon( #"game_ended" );
    sr = level.zmm_sr;
    menu_sr_show();
    wait 1;
    menu_sr_split_setup();
    wait 2;
    nengine_store_load( "fuzmenu", "speedrun" );
    sr.pos_str = nengine_store_get( "fuzmenu", sr.pkey + sr.practice );
    if ( isdefined( sr.pos_str ) && sr.pos_str != "" && strtok( sr.pos_str, "," ).size >= 4 && !( sr.map == "zm_sat_mantis" && sr.practice == 6 ) && ( sr.practice != 5 || sr.map == "zm_sat_mantis" ) )
    {
        sr.parts = strtok( sr.pos_str, "," );
        sr.host menu_do_teleport( ( int( sr.parts[ 0 ] ), int( sr.parts[ 1 ] ), int( sr.parts[ 2 ] ) ), ( 0, int( sr.parts[ 3 ] ), 0 ) );
    }
    else
    {
        menu_sr_default_tp();
    }
    sr.index = sr.practice - 1;
    wait 0.5;
    menu_sr_wait_move();
    sr.start = gettime();
    iprintlnbold( "^3Practice split " + sr.practice + ": ^7" + sr.names[ sr.index ] );
    while ( !menu_sr_done( sr.index ) )
    {
        waitframe();
    }
    sr.seg = gettime() - sr.start;
    if ( sr.map != "zm_sat_mantis" && sr.map != "zm_sat_firefly" )
    {
        sr.host menu_sr_store_pos( sr.practice + 1 );
    }
    iprintlnbold( "^2Split " + sr.practice + " ^7" + sr.names[ sr.index ] + "  ^3" + menu_sr_time( sr.seg ) + menu_sr_seg_delta() );
}

// split sr.practice: quest part, then doors, loadout and wonder weapon (boss splits start the boss)
function menu_sr_split_setup()
{
    menu_sr_split_quests();
    sr = level.zmm_sr;
    if ( isdefined( sr.lo ) && !( ( sr.map == "zm_sat_mantis" || sr.map == "zm_sat_hornet" || sr.map == "zm_sat_scarab" || sr.map == "zm_sat_locust" ) && sr.practice == 1 ) )
    {
        if ( sr.practice == 5 && sr.map != "zm_sat_ruby" && sr.map != "zm_sat_mantis" && sr.map != "zm_sat_hornet" )
        {
            sr.host menu_start_boss_fight();
        }
        menu_open_doors();
        wait 1;
        menu_sr_loadout( sr.lo[ sr.practice - 1 ] );
        if ( sr.map == "zm_sat_mantis" )
        {
            menu_sr_mantis_start();
        }
        else
        {
            menu_sr_ww_start();
        }
    }
}

// side quests the split needs done, main quest jumped to split sr.practice
function menu_sr_split_quests()
{
    sr = level.zmm_sr;
    if ( sr.map == "zm_sat_ruby" )
    {
        menu_sr_finish_quest( #"ruby_pap", "ruby_papq_complete" );
        if ( sr.practice >= 2 )
        {
            menu_sr_finish_quest( #"hash_d454d716ab61eea7", "ruby_wwq_complete" );
        }
        if ( sr.practice == 3 || sr.practice == 4 )
        {
            level thread zm_quest::function_80abdea0cd4c89a7( #"ruby_mq", sr.jumps[ sr.practice - 3 ] );
        }
    }
    else if ( sr.map == "zm_sat_hornet" )
    {
        if ( sr.practice >= 2 )
        {
            menu_sr_finish_quest( #"hash_83cebfb153a856aa", "completed_pap_step_8" );
            menu_sr_finish_quest( #"hash_bb48b0394380d8c5", "nekomata_acquired" );
        }
        if ( sr.practice >= 2 && sr.practice <= 6 )
        {
            level thread zm_quest::function_80abdea0cd4c89a7( sr.mq, sr.jumps[ sr.practice - 2 ] );
        }
        else if ( sr.practice == 7 )
        {
            sr.host menu_start_boss_fight();
        }
    }
    else if ( sr.map == "zm_sat_scarab" )
    {
        if ( sr.practice >= 2 )
        {
            // this PaP quest has no end flag of its own: the name only marks it for this mod
            menu_sr_finish_quest( #"hash_fbb52a4fe83b2f5c", "sr_pap_done" );
            menu_sr_finish_quest( #"hash_76889bf443d125bb", "w_s_12_c_rivet" );
        }
        if ( sr.practice >= 2 && sr.practice <= 4 )
        {
            level thread zm_quest::function_80abdea0cd4c89a7( sr.mq, sr.jumps[ sr.practice - 2 ] );
        }
    }
    else if ( sr.map == "zm_sat_locust" )
    {
        if ( sr.practice >= 2 )
        {
            menu_sr_finish_quest( #"hash_b92f39da6a91c324", "sr_pap_done" );
            menu_sr_finish_quest( #"hash_709d77ab2b2005c5", "ww_step_08" );
        }
        if ( sr.practice == 2 || sr.practice == 3 )
        {
            level thread zm_quest::function_80abdea0cd4c89a7( #"hash_7b26a8bb39d7312", sr.jumps[ sr.practice - 2 ] );
        }
        else if ( sr.practice == 4 )
        {
            sr.host menu_start_boss_fight();
        }
    }
    else if ( sr.map == "zm_sat_mantis" )
    {
        if ( sr.practice >= 2 )
        {
            menu_sr_finish_quest( #"hash_69a26aa656916aca", "mantis_pap_quest" );
            menu_sr_finish_quest( #"hash_14b84c237e411165", "ww_picked_up" );
        }
        if ( sr.practice >= 3 )
        {
            // the upgrade quest, done during split 2
            menu_sr_finish_quest( #"hash_fceafdb93947e902", "wwu_weapon_retrieved" );
        }
        if ( sr.practice >= 2 && sr.practice <= 5 )
        {
            // jumps: after the twins' swing scene, piano notes, lost souls, pre-boss scenes
            level thread zm_quest::function_80abdea0cd4c89a7( sr.mq, sr.jumps[ sr.practice - 2 ] );
        }
    }
    else
    {
        namespace_60b3bdcc70f79fc6::function_36488e0e5a90d20f( "power_on" );
        menu_sr_finish_quest( #"firefly_pap_quest", "firefly_pap_quest" );
        if ( sr.practice <= 4 )
        {
            menu_sr_tessie();
        }
        if ( sr.practice >= 2 )
        {
            menu_sr_finish_quest( #"firefly_ww_quest", "firefly_ww_quest" );
        }
        if ( sr.practice >= 2 && sr.practice <= 4 )
        {
            // a jump's skipped step 2 never sets it, and its end callback blocks every later step on it
            namespace_60b3bdcc70f79fc6::function_36488e0e5a90d20f( "m_complete" );
            level thread zm_quest::function_80abdea0cd4c89a7( sr.mq, sr.jumps[ sr.practice - 2 ] );
        }
    }
}

// Ashes: Tessie stage 3 (lasers), or stage 4 (turret) for the challenges
function menu_sr_tessie()
{
    sr = level.zmm_sr;
    if ( sr.practice < 4 )
    {
        level thread zm_quest::function_80abdea0cd4c89a7( #"hash_be480f8c1344afa8", #"hash_6dcaf3e883539a32" );
        return;
    }
    level thread zm_quest::function_80abdea0cd4c89a7( #"hash_be480f8c1344afa8", #"hash_173b93792d622394" );
    wait 1;
    menu_sr_finish_quest( #"hash_be480f8c1344afa8", "upgraded_pluto_to_stage_4" );
}

function menu_sr_has_ww( player )
{
    if ( !isdefined( player.primaryinventory ) )
    {
        return true;
    }
    foreach ( weapon in player.primaryinventory )
    {
        if ( isdefined( weapon ) && isdefined( weapon.basename ) && weapon.basename == level.zmm_sr.ww_name )
        {
            return true;
        }
    }
    return false;
}

// Ashes challenges: Tessie already has her turret, so the skipped keys step's turret part must not stay floating
function menu_sr_free_mg_part()
{
    level endon( #"game_ended" );
    level namespace_60b3bdcc70f79fc6::function_fb7b1af19016b7f4( "MQ_STEP_10_COMPLETE" );
    if ( isdefined( level.var_2b5fa68e6a533218.var_d5a2309951a61519 ) )
    {
        level.var_2b5fa68e6a533218.var_d5a2309951a61519 function_7f6c18bb105e8057();
    }
}

// Astra and Ashes: wonder weapon after the loadout; Astra's last split then finishes the kit and starts the boss
function menu_sr_ww_start()
{
    sr = level.zmm_sr;
    if ( sr.practice < 2 )
    {
        return;
    }
    sr.ww_label = "Gauntlet";
    sr.ww_name = sr.ww;
    if ( sr.map == "zm_sat_hornet" )
    {
        sr.ww_label = "Nekomata";
    }
    if ( sr.map == "zm_sat_scarab" )
    {
        sr.ww_label = "Void Claw";
    }
    if ( sr.map == "zm_sat_locust" )
    {
        sr.ww_label = "Jotunn Star";
    }
    if ( sr.map == "zm_sat_ruby" )
    {
        sr.ww_label = "LGM-1";
        sr.ww_name = "sat_ww_ruby_zm";
    }
    foreach ( player in level.players )
    {
        player thread menu_wonder_worker( sr.ww_label, sr.ww_name );
    }
    // the give loads the weapon for up to 3 seconds, then the player switches to it
    wait 5;
    // shortcut: one retry for a lost give; loop until held if it still goes missing in game
    foreach ( player in level.players )
    {
        if ( !menu_sr_has_ww( player ) )
        {
            player thread menu_wonder_worker( sr.ww_label, sr.ww_name );
        }
    }
    if ( sr.map == "zm_sat_firefly" && sr.practice == 4 )
    {
        level thread menu_sr_free_mg_part();
    }
    if ( sr.map != "zm_sat_ruby" || sr.practice != 5 )
    {
        return;
    }
    foreach ( player in level.players )
    {
        // shortcut: PaP lands on the held gun, a no-op if the LGM is not held; pass the weapon if it stays unupgraded
        player menu_pap( 3 );
        if ( isdefined( player.primaryinventory ) )
        {
            foreach ( weapon in player.primaryinventory )
            {
                player givemaxammo( weapon );
            }
        }
    }
    sr.host menu_start_boss_fight();
}

// Paradox: wonder weapon of the split, then split 3 tops up the ammo and starts the boss
function menu_sr_mantis_start()
{
    sr = level.zmm_sr;
    foreach ( player in level.players )
    {
        if ( sr.practice >= 3 )
        {
            player thread menu_wonder_worker( "Sundergat", "sundergat" );
        }
        else
        {
            player thread menu_wonder_worker( "Blundergat", sr.ww );
        }
    }
    if ( sr.practice != 6 )
    {
        return;
    }
    wait 1;
    foreach ( player in level.players )
    {
        if ( isdefined( player.primaryinventory ) )
        {
            foreach ( weapon in player.primaryinventory )
            {
                player givemaxammo( weapon );
            }
        }
    }
    sr.host menu_start_boss_fight();
}

// spec loadout of the practice split: [ round, PaP tier, armor, points, perks ]; 0 skips that part
function menu_sr_loadout( lo )
{
    sr = level.zmm_sr;
    sr.perk_order = [ "specialty_juggernog", "specialty_staminup", "specialty_speedcola", "specialty_quickrevive" ];
    if ( sr.map == "zm_sat_mantis" )
    {
        // d_mod = Double Tap, w_mod = Wisp Tea
        sr.perk_order = [ "specialty_juggernog", "specialty_deadshot", "specialty_staminup", "specialty_vulture_aid", "specialty_d_mod", "specialty_speedcola", "specialty_w_mod" ];
    }
    if ( lo[ 0 ] > 0 )
    {
        menu_jump_round( lo[ 0 ] );
    }
    foreach ( player in level.players )
    {
        if ( lo[ 1 ] > 0 )
        {
            player menu_pap( lo[ 1 ] );
        }
        // shortcut: the spec gives no rarity, tier + 1 is assumed (PaP III = legendary); use a loadout column if a split differs
        wait 0.5;
        player menu_rarity( lo[ 1 ] + 1 );
        if ( lo[ 2 ] > 0 )
        {
            player zm_armor::give_armor( lo[ 2 ] );
        }
        if ( lo[ 3 ] > 0 )
        {
            // shortcut: adds to the starting points instead of setting them
            player menu_add_currency( "points", lo[ 3 ] );
        }
        for ( i = 0; i < lo[ 4 ]; i++ )
        {
            player menu_give_perk_named( sr.perk_order[ i ] );
        }
    }
    if ( sr.practice == 5 && sr.map == "zm_sat_ruby" )
    {
        sr.host menu_drop_powerup( "full_ammo" );
        sr.host menu_drop_powerup( "full_armor" );
    }
    else if ( sr.practice == 5 && sr.map != "zm_sat_mantis" && sr.map != "zm_sat_hornet" )
    {
        foreach ( player in level.players )
        {
            player Killstreaks::function_545ea1188d337b59( "death_machine_gun", "other", undefined, undefined, undefined, 1 );
        }
    }
}

// no saved spot: the map object where the previous split ends (Astra quest structs, always spawned)
function menu_sr_default_tp()
{
    sr = level.zmm_sr;
    if ( sr.map == "zm_sat_mantis" && sr.practice == 2 )
    {
        sr.host menu_do_teleport( ( 57344, -31526, -120 ), ( 0, 193, 0 ) );
        return;
    }
    if ( sr.map == "zm_sat_firefly" && sr.practice != 2 && sr.practice != 5 )
    {
        // shortcut: spots read from the game's scripts and not seen in game; a spot saved by hand overrides them
        if ( sr.practice == 1 && isdefined( level.europa_unlock_ee ) && isdefined( level.europa_unlock_ee.europa ) )
        {
            sr.host menu_do_teleport( level.europa_unlock_ee.europa.origin + ( 0, 60, 8 ), ( 0, 270, 0 ) );
        }
        else if ( sr.practice == 3 && isdefined( level.var_209ed49971299121 ) )
        {
            sr.host menu_do_teleport( level.var_209ed49971299121.origin + ( -100, -1300, 8 ), ( 0, 90, 0 ) );
        }
        else if ( sr.practice == 4 && isdefined( level.var_209ed49971299121 ) )
        {
            sr.host menu_do_teleport( level.var_209ed49971299121.origin + ( 0, -60, 8 ), ( 0, 90, 0 ) );
        }
        return;
    }
    if ( sr.map != "zm_sat_ruby" || sr.practice > 4 )
    {
        return;
    }
    if ( sr.practice <= 2 )
    {
        sr.spot = function_5297e95caf8175e7( "pack_a_punch_machine", "script_noteworthy" );
    }
    else
    {
        sr.ends = [ "step2_brain_machine", "step4_perfusion_mars_interact" ];
        sr.spot = namespace_60b3bdcc70f79fc6::function_6141deaf935abd8f( sr.ends[ sr.practice - 3 ], "targetname" );
    }
    if ( !isdefined( sr.spot ) || !isdefined( sr.spot.origin ) )
    {
        return;
    }
    // shortcut: 40 units in front of the object, may land in a wall if the object faces one
    sr.spot_pos = sr.spot.origin + ( 0, 0, 8 );
    sr.spot_ang = sr.host.angles;
    if ( isdefined( sr.spot.angles ) )
    {
        sr.spot_pos = sr.spot_pos + anglestoforward( sr.spot.angles ) * 40;
        sr.spot_ang = ( 0, sr.spot.angles[ 1 ] + 180, 0 );
    }
    sr.host menu_do_teleport( sr.spot_pos, sr.spot_ang );
}

// the splits HUD is the host's "speedrun" toggle, turned on without the menu
function menu_sr_show()
{
    sr = level.zmm_sr;
    while ( isdefined( sr.host ) && !isdefined( sr.host.zmm ) )
    {
        waitframe();
    }
    if ( isdefined( sr.host ) && !sr.host menu_toggle_state( "speedrun" ) )
    {
        sr.host.zmm.toggles[ "speedrun" ] = 1;
        sr.host menu_apply_toggle( "speedrun" );
    }
}

// timer starts on the host's first step (x/y only: looking around or settling on the ground does not count)
function menu_sr_wait_move()
{
    sr = level.zmm_sr;
    sr.from = sr.host.origin;
    sr.steps = 0;
    // shortcut: the 5 steps make every timer start 0.25 s late, same for all runs; subtract it if runs must match real time
    while ( isdefined( sr.host ) && sr.steps < 5 )
    {
        wait 0.05;
        sr.delta = sr.host.origin - sr.from;
        sr.from = sr.host.origin;
        sr.moved = sr.delta[ 0 ] * sr.delta[ 0 ] + sr.delta[ 1 ] * sr.delta[ 1 ];
        if ( sr.moved > 2 && sr.moved < 2500 )
        {
            sr.steps++;
        }
        else
        {
            sr.steps = 0;
        }
    }
}

// gap to the same split's segment in the PB
function menu_sr_seg_delta()
{
    sr = level.zmm_sr;
    if ( sr.pb.size == 0 )
    {
        return "";
    }
    sr.pb_seg = sr.pb[ sr.index ];
    if ( sr.index > 0 )
    {
        sr.pb_seg = sr.pb_seg - sr.pb[ sr.index - 1 ];
    }
    if ( sr.seg <= sr.pb_seg )
    {
        return "  ^2-" + menu_sr_time( sr.pb_seg - sr.seg );
    }
    return "  ^1+" + menu_sr_time( sr.seg - sr.pb_seg );
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
        setdvar( @"hash_3c05d1d16d772c9e", menu_current_round() >= level.zmm_special_round ? 1 : 0 );
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
                if ( isdefined( ai ) && isalive( ai ) && ai.var_e4312c2c1a4a2190 === "special" && !istrue( ai.zmm_elite_seen ) )
                {
                    ai.zmm_elite_seen = 1;
                    level.zmm_special_round = menu_current_round() + 4 + randomint( 2 );
                }
            }
        }
        wait 0.25;
    }
    state.elite_loop = 0;
}

// the armor wall also sells the back shield; with the shield off or full it stays the game's own wall
function menu_armor_wall_hook()
{
    if ( !isdefined( level.var_6e01645e9a8a6a06 ) || !isdefined( level.var_6e01645e9a8a6a06.var_e5c33e2780f5d934[ "wallbuy" ] ) )
    {
        return;
    }
    foreach ( inst in level.var_6e01645e9a8a6a06.var_e5c33e2780f5d934[ "wallbuy" ] )
    {
        if ( isdefined( inst.var_1d6cddfc47031bff[ "wallbuy_spawn" ] ) )
        {
            foreach ( wall_spawn in inst.var_1d6cddfc47031bff[ "wallbuy_spawn" ] )
            {
                wall = wall_spawn.var_f9b6c5834058f21c;
                if ( isdefined( wall ) && wall.var_4b7489e415c1d8bc === "armor" && !isdefined( wall.zmm_orig_use ) && isdefined( wall.var_d8e3b07237845727 ) && isdefined( wall.var_b67012ddb354bc5a ) )
                {
                    wall.zmm_orig_use = wall.var_d8e3b07237845727;
                    wall.zmm_orig_hint = wall.var_b67012ddb354bc5a;
                    wall.var_d8e3b07237845727 = [ &menu_armor_wall_use ];
                    wall.var_b67012ddb354bc5a = &menu_armor_wall_hint;
                }
            }
        }
    }
}

function menu_shield_buyable( player )
{
    return isplayer( player ) && isdefined( player.zmm ) && player menu_toggle_state( "back_shield" ) && player.zmm.shield_hits < 15 && player points::function_8f0a9502ff7321a() >= 1500;
}

// self = the wall's scriptable
function menu_armor_wall_use( player )
{
    if ( menu_shield_buyable( player ) && player namespace_189fe7075a0930a5::function_d0b76708a627ce03( level.var_62f99ee1b2f61a35, 1500, 1, undefined, #"wallbuy" ) )
    {
        player.zmm.shield_hits = 15;
        player function_a4c8b0f6cf33e203( #"hash_6cd86061dc419bd0", player );
        return;
    }
    foreach ( callback in self.zmm_orig_use )
    {
        self thread [[ callback ]]( player );
    }
}

// keeps the button live at full armor while a shield can be bought; the wall's localized title can't be changed
function menu_armor_wall_hint( usable, player )
{
    hint = self [[ usable.zmm_orig_hint ]]( usable, player );
    if ( menu_shield_buyable( player ) )
    {
        hint.var_d3e5c3e8160e26e1 = 1500;
        hint.var_d4470f062ecd2964 = 1;
        hint.var_b1ce92894353396a = undefined;
    }
    return hint;
}

function menu_spawn_pt_count()
{
    return ( isdefined( level.zmm_spawn_pts ) ? level.zmm_spawn_pts.size : 0 ) + ( isdefined( level.zmm_windows ) ? level.zmm_windows.size : 0 );
}

// each new zombie goes to a random placed point or Forge window
function menu_spawn_pt_send( ai )
{
    level.zmm_spawn_i = randomint( menu_spawn_pt_count() );
    if ( isdefined( level.zmm_spawn_pts ) )
    {
        if ( level.zmm_spawn_i < level.zmm_spawn_pts.size )
        {
            ai forceteleport( level.zmm_spawn_pts[ level.zmm_spawn_i ], level.zmm_spawn_angs[ level.zmm_spawn_i ] );
            return;
        }
        level.zmm_spawn_i = level.zmm_spawn_i - level.zmm_spawn_pts.size;
    }
    // starts on the far side from the nearest player and crosses through the hole toward them
    window = level.zmm_windows[ level.zmm_spawn_i ];
    nearest = self;
    foreach ( player in level.players )
    {
        if ( distance( player.origin, window.origin ) < distance( nearest.origin, window.origin ) )
        {
            nearest = player;
        }
    }
    dir = anglestoforward( window.angles );
    if ( vectordot( nearest.origin - window.origin, dir ) < 0 )
    {
        dir = dir * -1;
    }
    ai thread menu_window_hop( window.origin - dir * 70, window.origin + dir * 70, vectortoangles( dir ) );
}

// shortcut: teleports along an arc with no climb animation, use a real traversal if one is found
function menu_window_hop( start, end, angles )
{
    self endon( #"death" );
    self forceteleport( start, angles );
    self menu_override( "zmm_window", [ "move_speed_scale" ], [ 0 ], 1 );
    wait 1;
    for ( self.zmm_hop = 0.1; self.zmm_hop < 1; self.zmm_hop = self.zmm_hop + 0.1 )
    {
        // peaks 50 above the floor, over the 32 high sill
        self forceteleport( start + ( end - start ) * self.zmm_hop + ( 0, 0, 200 * self.zmm_hop * ( 1 - self.zmm_hop ) ), angles );
        wait 0.05;
    }
    self forceteleport( end, angles );
    self menu_override( "zmm_window", [ "move_speed_scale" ], [ 0 ], 0 );
}

// every zombie that appears is moved once to the placed point; marked so the ones already there keep walking
function menu_spawn_pt_loop()
{
    state = self.zmm;
    while ( menu_loop_active( "spawn_pt" ) )
    {
        state.spawn_pt_list = menu_zombie_list();
        if ( menu_spawn_pt_count() > 0 && isdefined( state.spawn_pt_list ) )
        {
            foreach ( ai in state.spawn_pt_list )
            {
                if ( !istrue( ai.zmm_spawn_pt ) && menu_ai_awake( ai ) && !menu_ai_protected( ai ) )
                {
                    ai.zmm_spawn_pt = 1;
                    menu_spawn_pt_send( ai );
                }
            }
        }
        wait 0.1;
    }
    state.spawn_pt_loop = 0;
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

// one speed for every zombie, on the same stack as the training toggle and above it; "" gives the game back
function menu_zombie_speed( value )
{
    level.zmm_zspeed = undefined;
    if ( value != "" )
    {
        level.zmm_zspeed = value;
        if ( !istrue( level.zmm_zspeed_loop ) )
        {
            level.zmm_zspeed_loop = 1;
            level thread menu_zombie_speed_loop();
        }
    }
}

function menu_zombie_speed_loop()
{
    while ( isdefined( level.zmm_zspeed ) )
    {
        foreach ( ai in menu_zombie_list() )
        {
            if ( isdefined( ai ) && isalive( ai ) && !( ai.zmm_speed === level.zmm_zspeed ) && !menu_ai_protected( ai ) )
            {
                ai.zmm_speed = level.zmm_zspeed;
                ai namespace_56fb43fc0b6ee43e::function_a8ce00e0448cb6f0( level.zmm_zspeed, "zmm_speed", 101 );
            }
        }
        wait 0.25;
    }
    level.zmm_zspeed_loop = 0;
    foreach ( ai in menu_zombie_list() )
    {
        if ( isdefined( ai ) && isdefined( ai.zmm_speed ) )
        {
            ai.zmm_speed = undefined;
            ai namespace_56fb43fc0b6ee43e::function_a8ce00e0448cb6f0( undefined, "zmm_speed" );
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
    return menu_build_from_str();
}

// Gunsmith zombie build of a weapon (sat_zm_weapon_setups.ddl: one setup per zm weapon), in the saved-build format "root,variant,camo,pap,att,var,..."
function menu_zm_build( base )
{
    self.zmm.bk_id = self function_4f5087ef1a3099ab( "weaponsetups", #"hash_55e618a5bf885779", base, "weaponLootID" );
    if ( !isdefined( self.zmm.bk_id ) || self.zmm.bk_id == 0 )
    {
        return 0;
    }
    // root loot id from the base name: the saved loot id can be a blueprint's
    self.zmm.bk_str = "" + namespace_952965bfef60cff8::function_fae2e7aa6e279966( base ) + "," + ( self function_4f5087ef1a3099ab( "weaponsetups", #"hash_55e618a5bf885779", base, "weaponVariantID" ) ?? 0 ) + "," + ( self function_4f5087ef1a3099ab( "weaponsetups", #"hash_55e618a5bf885779", base, "camoLootID" ) ?? 0 ) + ",0";
    for ( self.zmm.bk_i = 0; self.zmm.bk_i < 16; self.zmm.bk_i++ )
    {
        self.zmm.bk_str = self.zmm.bk_str + "," + ( self function_4f5087ef1a3099ab( "weaponsetups", #"hash_55e618a5bf885779", base, "attachmentSetup", self.zmm.bk_i, "attachmentLootID" ) ?? 0 ) + "," + ( self function_4f5087ef1a3099ab( "weaponsetups", #"hash_55e618a5bf885779", base, "attachmentSetup", self.zmm.bk_i, "attachmentVariantID" ) ?? 0 );
    }
    return menu_build_from_str();
}

// builds and gives the gun of self.zmm.bk_str
function menu_build_from_str()
{
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
        menu_pap( int( self.zmm.bk_parts[ 3 ] ), 1 );
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
            menu_forge_remove( ent );
        }
        level.zmm_forge = [];
        return true;
    }
    if ( num == 13 )
    {
        if ( level.zmm_forge.size == 0 )
        {
            return false;
        }
        self.zmm.forge_last = level.zmm_forge[ level.zmm_forge.size - 1 ];
        level.zmm_forge = function_95e538e1f602b947( level.zmm_forge, self.zmm.forge_last );
        menu_forge_remove( self.zmm.forge_last );
        return true;
    }
    if ( num >= 14 && num < 100 )
    {
        return menu_forge_tool( num );
    }
    level.zmm_forge_model = "wood::sat_zm_toy_chest_rh_fxanim";
    // shortcut: box size guessed (about 46 wide, 28 deep, 32 high), measure in game if steps look off
    self.zmm.forge_angles = self getplayerangles();
    self.zmm.forge_angles = ( 0, self.zmm.forge_angles[ 1 ], 0 );
    self.zmm.forge_fwd = anglestoforward( self.zmm.forge_angles );
    self.zmm.forge_right = anglestoforward( ( 0, self.zmm.forge_angles[ 1 ] - 90, 0 ) );
    if ( num >= 100 )
    {
        return menu_forge_piece( num );
    }
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

// a working box / PaP / perk machine 80 units in front, built by the game's own spawn code on a fake struct
function menu_forge_machine( kind )
{
    self.zmm.mach = spawnstruct();
    // menu_forge_place can give a position / yaw / wall buy weapon (paste, nudge, load); else 80 units in front
    if ( !isdefined( self.zmm.mach_pos ) )
    {
        self.zmm.mach_pos = self.origin + anglestoforward( ( 0, self getplayerangles()[ 1 ], 0 ) ) * 80;
        self.zmm.mach_yaw = self getplayerangles()[ 1 ] + 180;
        if ( kind == "box" )
        {
            self.zmm.mach_yaw = self getplayerangles()[ 1 ] + 90;
        }
    }
    self.zmm.mach.origin = self.zmm.mach_pos;
    self.zmm.mach.angles = ( 0, self.zmm.mach_yaw, 0 );
    self.zmm.mach.script_noteworthy = self.zmm.mach_key;
    self.zmm.mach_pos = undefined;
    self.zmm.mach_key = undefined;
    if ( kind == "box" )
    {
        self.zmm.mach magicbox::function_ab59e6993557d5b6();
        self.zmm.mach thread magicbox::function_d032ba44d110e870( 1 );
        // the box only sells when flagged as the active box (else fire sale only)
        self.zmm.mach.var_f14b2b4820b635e7 = 1;
        return isdefined( self.zmm.mach.var_97c6497c84d770a );
    }
    if ( kind == "ammo" )
    {
        // the game's own crate spawn from a struct; its settings exist only on maps that load ammo caches
        if ( !isdefined( level.var_6c83d1b7ba6fafa5 ) )
        {
            return false;
        }
        ammo_cache::function_48881059553792e5( self.zmm.mach );
        return isdefined( self.zmm.mach.var_38ab0335efaa5fa5 );
    }
    if ( kind == "arsenal" )
    {
        // spawned powered on, like the PaP
        self.zmm.mach.var_e502d431f3ba8706 = 1;
        self.zmm.mach arsenal::function_619c087f75c8b87b( spawnstruct() );
        return isdefined( self.zmm.mach.var_ed56d91af64d44bc );
    }
    if ( kind == "fizz" )
    {
        if ( !isdefined( level.var_e00171381ac7e63b ) || !isdefined( level.var_e00171381ac7e63b[ "specialty_wunderfizz" ] ) )
        {
            return false;
        }
        // the game's own Wunderfizz spawn from a struct; it adds itself to the perk machine list.
        // maps with the moving Wunderfizz (Ashes) wait for a set round first: spawn it as a fixed one
        self.zmm.fizz_move = level.var_7ebad24685cd9f8c.var_c0e626638c3cdd4c;
        level.var_7ebad24685cd9f8c.var_c0e626638c3cdd4c = undefined;
        self.zmm.mach namespace_34fc1661493f2405::function_e3d3bfcc06c89350( spawnstruct() );
        level.var_7ebad24685cd9f8c.var_c0e626638c3cdd4c = self.zmm.fizz_move;
        return isdefined( self.zmm.mach.var_b69810c6c14b1634 );
    }
    if ( kind == "craft" )
    {
        if ( !isdefined( level.var_fa3dd255ec3da526 ) )
        {
            return false;
        }
        self.zmm.mach crafting_table::function_c9a2832b7bc2ef97();
        return isdefined( self.zmm.mach.var_7fac639c5e7fd54 );
    }
    if ( kind == "bgb" )
    {
        if ( !isdefined( level.var_e0910c7bd4aab6fc ) )
        {
            return false;
        }
        self.zmm.mach namespace_adb04aeb7ba103ef::function_9a3e81eb8357ad32( self.zmm.mach );
        return isdefined( self.zmm.mach.var_31b963920e4331f3 );
    }
    if ( kind == "pap" )
    {
        self.zmm.mach.var_e502d431f3ba8706 = 1;
        // Ashes drops the packed gun 140 units behind the machine (built for the truck): in a wall it is lost, so upgrade in hand
        // shortcut: level-wide, the truck's PaP goes instant too once one is forged; per-machine needs a purchase callback
        if ( isdefined( level.var_7ebad24685cd9f8c ) && level.mapname === "zm_sat_firefly" )
        {
            level.var_7ebad24685cd9f8c.var_2a42ba6a1a4e260d = 0;
        }
        self.zmm.mach pack_a_punch::function_168917014e423ee8();
        return isdefined( self.zmm.mach.var_370acb837a3a86c3 );
    }
    // the game's spawn (namespace_34fc1661493f2405::function_9a3e81eb8357ad32) bails on a flag check for
    // runtime structs, so its spawn half is replayed here; shortcut: skips the map's model-swap bundle
    self.zmm.mach.script_noteworthy = kind;
    self.zmm.mach.def = level.var_35cae1d5b8f6f7c2[ kind ];
    if ( !isdefined( self.zmm.mach.def ) )
    {
        return false;
    }
    self.zmm.mach.var_5a88606a27cbabb1 = self.zmm.mach.def.var_5a88606a27cbabb1 ?? "t10_zm_machine_juggernog";
    // as the game: the map's model-swap bundle, and perks with their own model (Double Tap, Scavenger) spawn as a script_model
    self.zmm.mach.swap = self.zmm.mach.def.var_f0be533e42313bb4 ?? self.zmm.mach.var_5a88606a27cbabb1;
    self.zmm.mach.bundle = function_3161539e0a96d772().var_4a98227bf6f428ba;
    if ( function_58736ce92359fa07( self.zmm.mach.bundle ) )
    {
        foreach ( entry in self.zmm.mach.bundle )
        {
            if ( entry.var_5d4a55e1eb574935 == self.zmm.mach.swap )
            {
                self.zmm.mach.var_5a88606a27cbabb1 = entry.var_5fb82424b4f67aee;
                self.zmm.mach.swap = entry.var_5fb82424b4f67aee;
            }
        }
    }
    if ( self.zmm.mach.swap != self.zmm.mach.var_5a88606a27cbabb1 )
    {
        self.zmm.mach.var_b69810c6c14b1634 = namespace_2bf8af33322ac10f::function_66b9b0c7a4a77d6b( self.zmm.mach, self.zmm.mach.swap, 1, 1 );
    }
    else
    {
        self.zmm.mach.var_b69810c6c14b1634 = function_d5fc43f4fe047ed6( self.zmm.mach.swap, self.zmm.mach.origin, self.zmm.mach.angles );
    }
    if ( !isdefined( self.zmm.mach.var_b69810c6c14b1634 ) )
    {
        return false;
    }
    level.var_2ad433898c7f6057[ level.var_2ad433898c7f6057.size ] = self.zmm.mach;
    namespace_60b3bdcc70f79fc6::function_81557bcd4ddf6a05( #"Scriptable", #"hash_10d5e3bb8a551724", self.zmm.mach.var_b69810c6c14b1634, "icon" );
    self.zmm.mach.var_fe6d648dc993577d = namespace_189fe7075a0930a5::function_445f3db498a93435( kind );
    self.zmm.mach.RADIUS = self.zmm.mach.def.var_86c9ab7f8a945b12 ?? 64;
    self.zmm.mach.var_e2ea5c9302351a97 = self.zmm.mach.def.cost;
    if ( function_9922b1d39dd0034b( self.zmm.mach.var_b69810c6c14b1634 ) )
    {
        self.zmm.mach.var_b69810c6c14b1634.var_4cf63ec91b753a3c = namespace_7fc982453bce8e6a::register_interact( self.zmm.mach.var_b69810c6c14b1634, self.zmm.mach.RADIUS, level.var_8d83c65a20889deb[ "on_use" ], undefined, undefined, undefined, undefined, "HINT_BUTTON" );
        self.zmm.mach.var_b69810c6c14b1634.var_4cf63ec91b753a3c function_29e5a164a795cbd8( 130 );
        self.zmm.mach.var_b69810c6c14b1634.var_4cf63ec91b753a3c namespace_7fc982453bce8e6a::function_316e9b54139e4683( level.var_8d83c65a20889deb[ "per_player_hint" ] );
        if ( self.zmm.mach.var_b69810c6c14b1634 function_9f30212275828d56( "tag_hint" ) )
        {
            self.zmm.mach.var_b69810c6c14b1634 function_c5cb9ee04701c381( "tag_hint" );
        }
    }
    else
    {
        self.zmm.mach.var_b69810c6c14b1634.var_4cf63ec91b753a3c = namespace_7fc982453bce8e6a::function_2558ae94964fd952( self.zmm.mach.var_b69810c6c14b1634, level.var_8d83c65a20889deb[ "on_use" ] );
        self.zmm.mach.var_b69810c6c14b1634.var_4cf63ec91b753a3c namespace_7fc982453bce8e6a::function_316e9b54139e4683( level.var_8d83c65a20889deb[ "per_player_hint" ] );
    }
    self.zmm.mach.var_b69810c6c14b1634 namespace_34fc1661493f2405::function_9fbcc91de1978444( self.zmm.mach.var_b69810c6c14b1634.var_4cf63ec91b753a3c );
    if ( self.zmm.mach.var_b69810c6c14b1634 function_79ba985c3a2c6d8a() && self.zmm.mach.var_b69810c6c14b1634 function_94cedaac4572406a( "use" ) )
    {
        self.zmm.mach.var_b69810c6c14b1634 function_7555d0f6ef1562a9( "use", "default" );
    }
    self.zmm.mach.var_b69810c6c14b1634.var_4cf63ec91b753a3c.var_c519b7af216dc312 = self.zmm.mach;
    self.zmm.mach.var_b69810c6c14b1634 thread [[ level.var_8d83c65a20889deb[ "think" ] ]]( kind, self.zmm.mach.var_b69810c6c14b1634.var_4cf63ec91b753a3c );
    self.zmm.mach.var_b69810c6c14b1634 thread namespace_34fc1661493f2405::function_91eb8bd11a034ed2( kind );
    // machines spawn powered off: switch this one on
    self.zmm.mach.var_b69810c6c14b1634 namespace_34fc1661493f2405::function_d01edb67b9ebbd32( kind, self.zmm.mach.var_b69810c6c14b1634.var_4cf63ec91b753a3c, 1 );
    return true;
}

// builds a machine (at self.zmm.mach_pos / mach_yaw / mach_key when set) and tracks it with the props,
// so delete all / delete last / nudge / save reach it
function menu_forge_place( kind )
{
    if ( !menu_forge_machine( kind ) )
    {
        return false;
    }
    self.zmm.mach.zmm_kind = kind;
    if ( !isdefined( level.zmm_forge ) )
    {
        level.zmm_forge = [];
    }
    level.zmm_forge[ level.zmm_forge.size ] = self.zmm.mach;
    return true;
}

// 16-19 rotate / push / raise / lower the last object, 20 save / 21 load per map
function menu_forge_tool( num )
{
    if ( num == 20 )
    {
        return menu_forge_save();
    }
    if ( num == 21 )
    {
        return menu_forge_load();
    }
    if ( !isdefined( level.zmm_forge ) || level.zmm_forge.size == 0 )
    {
        return false;
    }
    if ( num == 26 )
    {
        return menu_forge_remove_nearest();
    }
    self.zmm.forge_last = level.zmm_forge[ level.zmm_forge.size - 1 ];
    self.zmm.nudge_pos = self.zmm.forge_last.origin;
    self.zmm.nudge_yaw = self.zmm.forge_last.angles[ 1 ];
    if ( num == 16 )
    {
        self.zmm.nudge_yaw = self.zmm.nudge_yaw + 45;
    }
    if ( num == 17 )
    {
        self.zmm.nudge_pos = self.zmm.nudge_pos + anglestoforward( ( 0, self getplayerangles()[ 1 ], 0 ) ) * 16;
    }
    if ( num == 22 )
    {
        self.zmm.nudge_yaw = self.zmm.nudge_yaw - 45;
    }
    if ( num == 23 )
    {
        self.zmm.nudge_pos = self.zmm.nudge_pos - anglestoforward( ( 0, self getplayerangles()[ 1 ], 0 ) ) * 16;
    }
    if ( num == 24 )
    {
        self.zmm.nudge_pos = self.zmm.nudge_pos + anglestoforward( ( 0, self getplayerangles()[ 1 ] + 90, 0 ) ) * 16;
    }
    if ( num == 25 )
    {
        self.zmm.nudge_pos = self.zmm.nudge_pos + anglestoforward( ( 0, self getplayerangles()[ 1 ] - 90, 0 ) ) * 16;
    }
    if ( num == 18 )
    {
        self.zmm.nudge_pos = self.zmm.nudge_pos + ( 0, 0, 16 );
    }
    if ( num == 19 )
    {
        self.zmm.nudge_pos = self.zmm.nudge_pos - ( 0, 0, 16 );
    }
    if ( !isdefined( self.zmm.forge_last.zmm_kind ) )
    {
        // a prop: moved with its navmesh obstacle
        self.zmm.forge_last.origin = self.zmm.nudge_pos;
        self.zmm.forge_last.angles = ( 0, self.zmm.nudge_yaw, 0 );
        // a teleporter has no obstacle, and its portal is rebuilt at the new spot
        if ( self.zmm.forge_last.zmm_model === "zmm_tele" )
        {
            menu_tele_portal( self.zmm.forge_last );
        }
        if ( isdefined( self.zmm.forge_last.zmm_nav ) )
        {
            function_57cc0fae95e2c4f4( self.zmm.forge_last.zmm_nav );
            self.zmm.forge_last.zmm_nav = function_6575994e0b3dcc16( self.zmm.nudge_pos, menu_forge_nav_half( self.zmm.forge_last.zmm_model ), self.zmm.forge_last.angles );
        }
        return true;
    }
    // a machine: rebuilt at the new spot, its spawn code places every part
    menu_forge_remove( self.zmm.forge_last );
    level.zmm_forge = function_95e538e1f602b947( level.zmm_forge, self.zmm.forge_last );
    self.zmm.mach_pos = self.zmm.nudge_pos;
    self.zmm.mach_yaw = self.zmm.nudge_yaw;
    self.zmm.mach_key = self.zmm.forge_last.script_noteworthy;
    return menu_forge_place( self.zmm.forge_last.zmm_kind );
}

// "kind,x,y,z,yaw,key;" per forge object (prop key = model), in kronos/fuzmenu/forge.json under the map name
function menu_forge_save()
{
    if ( !isdefined( level.mapname ) )
    {
        return false;
    }
    self.zmm.fs_str = "";
    if ( isdefined( level.zmm_forge ) )
    {
        foreach ( ent in level.zmm_forge )
        {
            self.zmm.fs_kind = ent.zmm_kind ?? "prop";
            self.zmm.fs_key = ent.zmm_model ?? ent.script_noteworthy ?? "-";
            self.zmm.fs_str = self.zmm.fs_str + self.zmm.fs_kind + "," + int( ent.origin[ 0 ] ) + "," + int( ent.origin[ 1 ] ) + "," + int( ent.origin[ 2 ] ) + "," + int( ent.angles[ 1 ] ) + "," + self.zmm.fs_key + ";";
        }
    }
    nengine_store_load( "fuzmenu", "forge" );
    nengine_store_set( "fuzmenu", level.mapname, self.zmm.fs_str );
    nengine_store_save( "fuzmenu", "forge" );
    return true;
}

// replaces the current forge with the saved one: cuts first, then props and machines
function menu_forge_load()
{
    if ( !isdefined( level.mapname ) )
    {
        return false;
    }
    nengine_store_load( "fuzmenu", "forge" );
    self.zmm.fs_str = nengine_store_get( "fuzmenu", level.mapname );
    if ( !isdefined( self.zmm.fs_str ) || self.zmm.fs_str == "" )
    {
        return false;
    }
    menu_forge( 9 );
    self.zmm.fs_lines = strtok( self.zmm.fs_str, ";" );
    for ( self.zmm.fs_i = 0; self.zmm.fs_i < self.zmm.fs_lines.size; self.zmm.fs_i++ )
    {
        self.zmm.fs_p = strtok( self.zmm.fs_lines[ self.zmm.fs_i ], "," );
        if ( self.zmm.fs_p.size == 6 )
        {
            self.zmm.fs_pos = ( int( self.zmm.fs_p[ 1 ] ), int( self.zmm.fs_p[ 2 ] ), int( self.zmm.fs_p[ 3 ] ) );
            if ( self.zmm.fs_p[ 0 ] == "cut" || self.zmm.fs_p[ 0 ] == "wallbuy" )
            {
                // old saves had map machine cuts and wall buys, no longer supported
            }
            else if ( self.zmm.fs_p[ 0 ] == "prop" )
            {
                level.zmm_forge_model = self.zmm.fs_p[ 5 ];
                menu_forge_put( self.zmm.fs_pos, ( 0, int( self.zmm.fs_p[ 4 ] ), 0 ) );
            }
            else
            {
                self.zmm.mach_pos = self.zmm.fs_pos;
                self.zmm.mach_yaw = int( self.zmm.fs_p[ 4 ] );
                self.zmm.mach_key = undefined;
                if ( self.zmm.fs_p[ 5 ] != "-" )
                {
                    self.zmm.mach_key = self.zmm.fs_p[ 5 ];
                }
                menu_forge_place( self.zmm.fs_p[ 0 ] );
                wait 0.1;
            }
        }
    }
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

function menu_forge_remove_nearest()
{
    self.zmm.forge_last = undefined;
    foreach ( ent in level.zmm_forge )
    {
        if ( isdefined( ent ) && ( !isdefined( self.zmm.forge_last ) || distance( self.origin, ent.origin ) < distance( self.origin, self.zmm.forge_last.origin ) ) )
        {
            self.zmm.forge_last = ent;
        }
    }
    if ( !isdefined( self.zmm.forge_last ) )
    {
        return false;
    }
    // the plain-prop path deletes the entity: take it off the list first
    level.zmm_forge = function_95e538e1f602b947( level.zmm_forge, self.zmm.forge_last );
    menu_forge_remove( self.zmm.forge_last );
    return true;
}

// a forge prop (script_model + nav obstacle) or a forge machine struct and every entity its spawn made
function menu_forge_remove( ent )
{
    if ( !isdefined( ent ) )
    {
        return;
    }
    if ( !isdefined( ent.zmm_kind ) )
    {
        if ( ent.zmm_model === "zmm_window" )
        {
            level.zmm_windows = function_95e538e1f602b947( level.zmm_windows, ent );
        }
        if ( ent.zmm_model === "zmm_tele" )
        {
            level.zmm_teles = function_95e538e1f602b947( level.zmm_teles, ent );
            if ( isdefined( ent.zmm_portal ) )
            {
                ent.zmm_portal function_7f6c18bb105e8057();
            }
        }
        if ( isdefined( ent.zmm_nav ) )
        {
            function_57cc0fae95e2c4f4( ent.zmm_nav );
        }
        ent delete();
        return;
    }
    menu_forge_unlist( ent );
    // perk / fizz, box, PaP, arsenal, ammo crate, wall buy, crafting table, gobblegum
    menu_forge_free( ent.var_b69810c6c14b1634 );
    if ( isdefined( ent.var_97c6497c84d770a ) )
    {
        ent.var_97c6497c84d770a notify( #"delete_magicbox_pings" );
    }
    menu_forge_free( ent.var_97c6497c84d770a );
    menu_forge_free( ent.var_370acb837a3a86c3 );
    menu_forge_free( ent.var_ed56d91af64d44bc );
    menu_forge_free( ent.var_38ab0335efaa5fa5 );
    menu_forge_free( ent.var_7fac639c5e7fd54 );
    menu_forge_free( ent.var_31b963920e4331f3 );
}

// out of the game's machine lists, so box moves / fire sales / power-on never reach a freed machine
function menu_forge_unlist( s )
{
    level.var_2ad433898c7f6057 = function_95e538e1f602b947( level.var_2ad433898c7f6057, s );
    if ( isdefined( level.var_1bbb5557537e2c0c ) )
    {
        level.var_1bbb5557537e2c0c = function_95e538e1f602b947( level.var_1bbb5557537e2c0c, s );
    }
    if ( isdefined( level.var_db52bcfd04d45a7a ) )
    {
        level.var_db52bcfd04d45a7a = function_95e538e1f602b947( level.var_db52bcfd04d45a7a, s );
    }
    if ( isdefined( level.var_52e94a468e66d601 ) )
    {
        level.var_52e94a468e66d601 = function_95e538e1f602b947( level.var_52e94a468e66d601, s );
    }
    if ( isdefined( level.var_fa3dd255ec3da526 ) )
    {
        level.var_fa3dd255ec3da526 = function_95e538e1f602b947( level.var_fa3dd255ec3da526, s );
    }
    if ( isdefined( level.var_e0910c7bd4aab6fc ) )
    {
        level.var_e0910c7bd4aab6fc = function_95e538e1f602b947( level.var_e0910c7bd4aab6fc, s );
    }
    if ( isdefined( level.var_6c83d1b7ba6fafa5 ) && isdefined( level.var_6c83d1b7ba6fafa5.var_ea07e36d8fd28578 ) )
    {
        level.var_6c83d1b7ba6fafa5.var_ea07e36d8fd28578 = function_95e538e1f602b947( level.var_6c83d1b7ba6fafa5.var_ea07e36d8fd28578, s );
    }
}

// a machine part, its interact, arsenal hint origin and ammo crate model
function menu_forge_free( e )
{
    if ( !isdefined( e ) )
    {
        return;
    }
    menu_forge_kill( e.var_d3e9ac2f3fe07320 );
    menu_forge_kill( e.var_a3338cc37b82b7b3 );
    // a perk entity is its own interact
    if ( isdefined( e.var_4cf63ec91b753a3c ) && e.var_4cf63ec91b753a3c != e )
    {
        menu_forge_kill( e.var_4cf63ec91b753a3c );
    }
    menu_forge_kill( e );
}

// entities are deleted, scriptables freed (as the game does)
function menu_forge_kill( e )
{
    if ( !isdefined( e ) )
    {
        return;
    }
    if ( function_9922b1d39dd0034b( e ) )
    {
        e delete();
        return;
    }
    e function_7f6c18bb105e8057();
}

// solid for players + navmesh obstacle so zombies walk around it
// every model here is in ingame_zm.ff, so it loads on all ZM maps; spacing comes from the bounds stored in that fastfile
// shortcut: only the box and ornate door are known solid, swap out any model that fails the in-game collision test
function menu_forge_piece( num )
{
    if ( num == 103 ) { menu_forge_wall( level.zmm_forge_model, 46, 32, 5, 1 ); }
    if ( num == 104 ) { menu_forge_wall( level.zmm_forge_model, 46, 32, 9, 3 ); }
    if ( num == 105 ) { menu_forge_wall( level.zmm_forge_model, 46, 32, 1, 6 ); }
    if ( num == 106 )
    {
        // walk-through opening: skip the bottom two rows of the middle column
        for ( self.zmm.forge_i = 0; self.zmm.forge_i < 15; self.zmm.forge_i++ )
        {
            if ( self.zmm.forge_i % 5 != 2 || self.zmm.forge_i >= 10 )
            {
                menu_forge_put( self.origin + self.zmm.forge_fwd * 80 + self.zmm.forge_right * ( ( self.zmm.forge_i % 5 ) - 2 ) * 46 + ( 0, 0, int( self.zmm.forge_i / 5 ) * 32 ), self.zmm.forge_angles );
            }
        }
    }
    if ( num == 113 ) { menu_forge_window(); }
    if ( num == 114 )
    {
        // shortcut: sunk mystery box as the pad (46 x 28), upgrade if a real platform model that loads on every map turns up
        level.zmm_forge_model = "zmm_tele";
        menu_forge_put( self.origin + self.zmm.forge_fwd * 80 - ( 0, 0, 26 ), self.zmm.forge_angles );
    }
    if ( num == 120 ) { menu_forge_wall( "t10_zm_essence_container_large_orange", 0, 0, 1, 1 ); }
    if ( num == 121 ) { menu_forge_wall( "sat_zm_webbed_gate_medium", 0, 0, 1, 1 ); }
    if ( num == 124 ) { menu_forge_wall( "t10_zm_pap_fxanim", 0, 0, 1, 1 ); }
    if ( num == 125 ) { menu_forge_wall( "t10_zm_weapon_machine_fxanim", 0, 0, 1, 1 ); }
    return true;
}

// 5 x 5 boxes in front of the player, the middle 3 x 3 left open; 138 wide, 96 high, 32 off the floor
function menu_forge_window()
{
    for ( self.zmm.forge_i = 0; self.zmm.forge_i < 25; self.zmm.forge_i++ )
    {
        if ( self.zmm.forge_i % 5 == 0 || self.zmm.forge_i % 5 == 4 || self.zmm.forge_i < 5 || self.zmm.forge_i >= 20 )
        {
            // the sill's middle box carries the window key, so a loaded window gets its spawn back
            level.zmm_forge_model = self.zmm.forge_i == 2 ? "zmm_window" : "wood::sat_zm_toy_chest_rh_fxanim";
            menu_forge_put( self.origin + self.zmm.forge_fwd * 80 + self.zmm.forge_right * ( ( self.zmm.forge_i % 5 ) - 2 ) * 46 + ( 0, 0, int( self.zmm.forge_i / 5 ) * 32 ), self.zmm.forge_angles );
        }
    }
}

// pairs by list order: 0-1, 2-3...; an odd last one waits for its partner
function menu_tele_loop()
{
    while ( isdefined( level.zmm_teles ) && level.zmm_teles.size > 0 )
    {
        foreach ( player in level.players )
        {
            if ( isdefined( player ) && isalive( player ) )
            {
                player menu_tele_check();
            }
        }
        wait 0.1;
    }
    level.zmm_tele_loop = 0;
}

// arriving locks the player until they step off the pad, or they would bounce back forever
function menu_tele_check()
{
    if ( isdefined( self.zmm_tele_lock ) )
    {
        if ( distance( self.origin, self.zmm_tele_lock.origin + ( 0, 0, 26 ) ) < 64 )
        {
            return;
        }
        self.zmm_tele_lock = undefined;
    }
    for ( i = 0; i < level.zmm_teles.size; i++ )
    {
        other = i % 2 == 0 ? i + 1 : i - 1;
        if ( other < level.zmm_teles.size && distance( self.origin, level.zmm_teles[ i ].origin + ( 0, 0, 26 ) ) < 40 )
        {
            self.zmm_tele_lock = level.zmm_teles[ other ];
            // setorigin, not the game's teleport_player: that one plays the black screen
            self setorigin( self.zmm_tele_lock.origin + ( 0, 0, 30 ) );
            return;
        }
    }
}

// the game's own fast travel portal, at floor height over the pad
function menu_tele_portal( ent )
{
    if ( isdefined( ent.zmm_portal ) )
    {
        ent.zmm_portal function_7f6c18bb105e8057();
    }
    ent.zmm_portal = function_d5fc43f4fe047ed6( "teleport_portal_zm_t10", ent.origin + ( 0, 0, 26 ), ent.angles );
    if ( isdefined( ent.zmm_portal ) )
    {
        ent.zmm_portal function_7555d0f6ef1562a9( "base", "idle" );
        return;
    }
    // no portal on this map: the sunk box still marks the pad
    ent setmodel( "wood::sat_zm_toy_chest_rh_fxanim" );
}

// a door is a wall of one piece
function menu_forge_wall( model, width, height, cols, rows )
{
    level.zmm_forge_model = model;
    for ( self.zmm.forge_i = 0; self.zmm.forge_i < cols * rows; self.zmm.forge_i++ )
    {
        menu_forge_put( self.origin + self.zmm.forge_fwd * 80 + self.zmm.forge_right * ( ( self.zmm.forge_i % cols ) - ( cols - 1 ) * 0.5 ) * width + ( 0, 0, int( self.zmm.forge_i / cols ) * height ), self.zmm.forge_angles );
    }
}

// zombies path around this box: wide pieces need more than the default
function menu_forge_nav_half( model )
{
    return ( 30, 30, 32 );
}

function menu_forge_put( origin, angles )
{
    self.zmm.forge_ent = spawn( "script_model", origin );
    // a window's sill is a box saved under its own key; a teleporter shows a portal instead of a model
    if ( !( level.zmm_forge_model === "zmm_tele" ) )
    {
        self.zmm.forge_ent setmodel( level.zmm_forge_model === "zmm_window" ? "wood::sat_zm_toy_chest_rh_fxanim" : level.zmm_forge_model );
    }
    // kept as a string for the per-map save
    self.zmm.forge_ent.zmm_model = level.zmm_forge_model;
    self.zmm.forge_ent.angles = angles;
    if ( level.zmm_forge_model === "zmm_tele" )
    {
        // walked into, so neither solid nor a nav obstacle
        menu_tele_portal( self.zmm.forge_ent );
        level.zmm_forge[ level.zmm_forge.size ] = self.zmm.forge_ent;
        if ( !isdefined( level.zmm_teles ) )
        {
            level.zmm_teles = [];
        }
        level.zmm_teles[ level.zmm_teles.size ] = self.zmm.forge_ent;
        if ( !istrue( level.zmm_tele_loop ) )
        {
            level.zmm_tele_loop = 1;
            level thread menu_tele_loop();
        }
        return;
    }
    self.zmm.forge_ent solid();
    self.zmm.forge_ent.zmm_nav = function_6575994e0b3dcc16( origin, menu_forge_nav_half( level.zmm_forge_model ), angles );
    level.zmm_forge[ level.zmm_forge.size ] = self.zmm.forge_ent;
    if ( level.zmm_forge_model === "zmm_window" )
    {
        if ( !isdefined( level.zmm_windows ) )
        {
            level.zmm_windows = [];
        }
        level.zmm_windows[ level.zmm_windows.size ] = self.zmm.forge_ent;
        self.zmm.toggles[ "spawn_pt" ] = 1;
        if ( !istrue( self.zmm.spawn_pt_loop ) )
        {
            self.zmm.spawn_pt_loop = 1;
            self thread menu_spawn_pt_loop();
        }
    }
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
// step 0 = random, +1 / -1 = next / previous of the 210 camo_<a..n>_<01..15>; busy: a second press would take the gun mid-swap
function menu_camo( action, step )
{
    if ( istrue( self.zmm.camo_busy ) )
    {
        return;
    }
    self.zmm.camo_busy = 1;
    if ( step == 0 )
    {
        self.zmm.camo_idx = randomint( 210 );
    }
    else if ( !isdefined( self.zmm.camo_idx ) )
    {
        self.zmm.camo_idx = step > 0 ? 0 : 209;
    }
    else
    {
        self.zmm.camo_idx = ( self.zmm.camo_idx + step + 210 ) % 210;
    }
    menu_camo_apply( action );
    self.zmm.camo_busy = 0;
}

function menu_camo_apply( action )
{
    self.zmm.camo_gun = self getcurrentweapon();
    if ( !isdefined( self.zmm.camo_gun ) || isnullweapon( self.zmm.camo_gun ) )
    {
        menu_tip_action( action, 0 );
        return;
    }
    self.zmm.camo_num = ( self.zmm.camo_idx % 15 ) + 1;
    self.zmm.camo_name = "camo_" + [ "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n" ][ int( self.zmm.camo_idx / 15 ) ] + ( self.zmm.camo_num < 10 ? "_0" : "_" ) + self.zmm.camo_num;
    self.zmm.camo_new = self.zmm.camo_gun withcamo( self.zmm.camo_name );
    if ( !isdefined( self.zmm.camo_new ) || isnullweapon( self.zmm.camo_new ) )
    {
        menu_tip_action( action, 0 );
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
    self menu_assign_slot( self.zmm.camo_new );
    self switchtoweapon( self.zmm.camo_new );
    menu_fill_weapon_ammo( self.zmm.camo_new );
    wait 0.25;
    menu_notify( level.zmm_labels[ action ] + " " + self.zmm.camo_name, self hasweapon( self.zmm.camo_new ) );
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
        if ( menu_is_host() )
        {
            setdvar( @"zmm_exec", "noclip " + gettime() );
        }
        else
        {
            menu_tip_action( action_id, false );
        }
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
        self thread menu_camo( action_id, 0 );
    }
    else if ( action_id == "camo_next" )
    {
        self thread menu_camo( action_id, 1 );
    }
    else if ( action_id == "camo_prev" )
    {
        self thread menu_camo( action_id, -1 );
    }
    else if ( action_id == "spawn_point" )
    {
        menu_teleport_action( action_id, self.zmm.spawn_origin, self.zmm.spawn_angles );
    }
    else if ( action_id == "unstuck" )
    {
        menu_teleport_action( action_id, getclosestpointonnavmesh( self.origin ), self getplayerangles() );
    }
    else if ( action_id == "nav_test" )
    {
        menu_tip_action( action_id, menu_nav_test() );
    }
    else if ( action_id == "spawn_pt_set" )
    {
        if ( !isdefined( level.zmm_spawn_pts ) )
        {
            level.zmm_spawn_pts = [];
            level.zmm_spawn_angs = [];
        }
        level.zmm_spawn_angs[ level.zmm_spawn_pts.size ] = ( 0, self getplayerangles()[ 1 ], 0 );
        level.zmm_spawn_pts[ level.zmm_spawn_pts.size ] = self.origin;
        menu_tip_action( action_id, 1 );
    }
    else if ( action_id == "spawn_pt_clear" )
    {
        level.zmm_spawn_pts = undefined;
        level.zmm_spawn_angs = undefined;
        menu_tip_action( action_id, 1 );
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
    else if ( action_id == "tessie" )
    {
        menu_spawn_tessie();
    }
    else if ( action_id == "boss_fight" )
    {
        menu_tip_action( action_id, menu_start_boss_fight() );
    }
    else if ( action_id == "boss_finish" )
    {
        menu_tip_action( action_id, menu_finish_boss_fight() );
    }
    else if ( action_id == "map_restart" )
    {
        if ( menu_is_host() )
        {
            setdvar( @"zmm_exec", "map_restart " + gettime() );
        }
        menu_tip_action( action_id, menu_is_host() && getdvar( @"zmm_lua" ) == "1" );
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
        if ( other != slot && self.var_b02f6e7abbbc8a84[ other ] === name )
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

// a rebuilt melee weapon must go back to the melee slot, as the game's own PaP does
function menu_assign_slot( w_new )
{
    if ( weapon::function_6b74ecd475e99b4( w_new ) )
    {
        self weapon::function_b4c9549dee5d0fc5( w_new );
        return;
    }
    self assignweaponprimaryslot( w_new );
}

// returns 1 on success, other values are failure codes
function menu_pap( tier, allow_lower = 0 )
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
    if ( cur_level == tier || ( cur_level > tier && !allow_lower ) )
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
        self menu_assign_slot( w_new );
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
            self menu_assign_slot( w_new );
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
    if ( isdefined( weapon ) && !isnullweapon( weapon ) && weapon::function_6b74ecd475e99b4( weapon ) )
    {
        level.var_48e2b36291b57f44 = 5;
        self utility::callsharedfunc( #"zombie", #"hash_e546039029657cd5", weapon, rarity, 1 );
        return 1;
    }
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
    if ( isdefined( list ) )
    {
        foreach ( weapon in list )
        {
            if ( isdefined( weapon.basename ) && weapon.basename == weaponname )
            {
                return true;
            }
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
    self.zmm.gun_loaded = 1;
    if ( menu_toggle_state( "zm_build" ) && issubstr( name, "sat_" ) && issubstr( name, "_mp" ) && !issubstr( name, "_mpug" ) && menu_zm_build( removesubstr( name, "_mp" ) ) )
    {
        menu_notify( label + " (my build)", 1 );
        return;
    }
    if ( menu_give_wonder( name ) )
    {
        menu_notify( label, 1 );
        return;
    }
    if ( !self.zmm.gun_loaded )
    {
        self iprintln( label + " ^1not loaded on this map (put it in a loadout)" );
        return;
    }
    menu_notify( label, 0 );
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
    if ( issubstr( weapon_name, "_mp" ) && !issubstr( weapon_name, "_mpug" ) )
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
    self.zmm.gun_loaded = 0;
    for ( i = 0; i < 100; i++ )
    {
        if ( self hasloadedviewweapons( [ w_new ] ) )
        {
            self.zmm.gun_loaded = 1;
            break;
        }
        wait 0.1;
    }
    // BO6 guns whose models never load would be given empty (no model, cannot be pulled out)
    if ( !self.zmm.gun_loaded && issubstr( weapon_name, "t10_" ) )
    {
        return false;
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
    names = [ "double_points", "insta_kill", "full_ammo", "full_armor", "full_power", "free_perk", "fire_sale", "bonus_points_team" ];
    offsets = [ ( 80, 0, 0 ), ( 57, 57, 0 ), ( 0, 80, 0 ), ( -57, 57, 0 ), ( -80, 0, 0 ), ( -57, -57, 0 ), ( 0, -80, 0 ), ( 57, -57, 0 ) ];
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

// EE steps = the speedrun splits after the first (Practice page): fills self.zmm.ee_names ("a|b|c"), returns their count, 0 on maps without splits
function menu_ee_steps()
{
    self.zmm.ee_names = "";
    if ( !isdefined( level.zmm_sr ) || !isdefined( level.zmm_sr.names ) )
    {
        return 0;
    }
    for ( i = 1; i < level.zmm_sr.names.size; i++ )
    {
        if ( i > 1 )
        {
            self.zmm.ee_names += "|";
        }
        self.zmm.ee_names += level.zmm_sr.names[ i ];
    }
    return level.zmm_sr.names.size - 1;
}

// step n (1-based) jumps the main quest to speedrun split n + 1 in place: quests only, no restart, loadout, weapon, timer or teleport (the boss start brings its own)
function menu_ee_jump( n )
{
    sr = level.zmm_sr;
    if ( !menu_is_host() || n < 1 || n > self menu_ee_steps() || istrue( sr.ee_busy ) )
    {
        return 0;
    }
    sr.ee_busy = 1;
    level thread menu_ee_run( n + 1 );
    return 1;
}

// shortcut: borrows sr.practice while the quests are set (the split writer shows practice for that moment), add a split argument if that shows
function menu_ee_run( split )
{
    sr = level.zmm_sr;
    sr.ee_prev = sr.practice;
    sr.practice = split;
    menu_sr_split_quests();
    // the last split is the boss: hornet and locust start it in the quest part
    if ( split == sr.names.size && sr.map != "zm_sat_hornet" && sr.map != "zm_sat_locust" )
    {
        sr.host menu_start_boss_fight();
    }
    sr.practice = sr.ee_prev;
    sr.ee_busy = 0;
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

// ends the running boss fight the way the game does, so its phases, death scene and quest end still play:
// Mantis phases end on the pylons' charge / release flags, the other bosses copy each map's own skip / dev kill command
function menu_finish_boss_fight()
{
    if ( isdefined( level.mapname ) && level.mapname == "zm_sat_mantis" )
    {
        if ( namespace_60b3bdcc70f79fc6::function_f0bb112fe637e41c( "boss_fight_done" ) || !isdefined( level.var_d61ad599a05754c7 ) || !isalive( level.var_d61ad599a05754c7.var_469a4c6b75d9c6cd ) )
        {
            return 0;
        }
        // the map's dev "kill boss": its death callback plays the end of the fight and sets boss_fight_done
        level.var_d61ad599a05754c7.var_469a4c6b75d9c6cd function_b2ab534731b73e2();
        return 1;
    }
    if ( isdefined( level.mapname ) && level.mapname == "zm_sat_ruby" )
    {
        if ( !namespace_60b3bdcc70f79fc6::function_f0bb112fe637e41c( "ruby_boss_fight_start" ) || namespace_60b3bdcc70f79fc6::function_f0bb112fe637e41c( "ruby_boss_fight_complete" ) )
        {
            return 0;
        }
        self thread menu_finish_astra();
        return 1;
    }
    if ( isdefined( level.mapname ) && level.mapname == "zm_sat_firefly" )
    {
        if ( !namespace_60b3bdcc70f79fc6::function_f0bb112fe637e41c( "firefly_boss_fight_start" ) || namespace_60b3bdcc70f79fc6::function_f0bb112fe637e41c( "firefly_boss_fight_complete" ) || !isdefined( level.var_302bd0b94da202e7 ) || !isalive( level.var_302bd0b94da202e7.entity ) )
        {
            return 0;
        }
        self thread menu_finish_hermes( level.var_302bd0b94da202e7.entity );
        return 1;
    }
    if ( isdefined( level.mapname ) && level.mapname == "zm_sat_hornet" )
    {
        if ( !namespace_60b3bdcc70f79fc6::function_f0bb112fe637e41c( "hornet_boss_fight_start" ) || namespace_60b3bdcc70f79fc6::function_f0bb112fe637e41c( "hornet_boss_fight_complete" ) || !isdefined( level.var_703ffbe28e244b74 ) || !isalive( level.var_703ffbe28e244b74.entity ) )
        {
            return 0;
        }
        self thread menu_finish_diana( level.var_703ffbe28e244b74.entity );
        return 1;
    }
    if ( isdefined( level.mapname ) && level.mapname == "zm_sat_locust" )
    {
        if ( !namespace_60b3bdcc70f79fc6::function_f0bb112fe637e41c( "boss_fight_start" ) || namespace_60b3bdcc70f79fc6::function_f0bb112fe637e41c( "boss_fight_end" ) || !isalive( level.var_99042256ee32a16d ) )
        {
            return 0;
        }
        level thread menu_finish_virgil();
        return 1;
    }
    if ( isdefined( level.mapname ) && level.mapname == "zm_sat_scarab" )
    {
        // the boss rush can hold Caltheris without the EE field being set: take the boss AI then
        boss = isdefined( level.var_4630353ece991c26 ) ? level.var_4630353ece991c26.entity : undefined;
        if ( !isdefined( boss ) || !isalive( boss ) )
        {
            boss = menu_boss_list()[ 0 ];
        }
        if ( !isdefined( boss ) || !isalive( boss ) )
        {
            return 0;
        }
        self thread menu_finish_caltheris( boss );
        return 1;
    }
    if ( menu_boss_list().size < 1 )
    {
        return 0;
    }
    self thread menu_finish_boss_loop();
    return 1;
}

// Scarab: same steps as the map's own dev "kill boss" command (both immune phases, then the death)
function menu_finish_caltheris( boss )
{
    self endon( "disconnect" );
    boss endon( "death" );
    boss.var_96eb4eec60875abc = 3;
    boss.var_f9e26f943ef4abc = 1;
    boss.var_1a3160838c7301bf = 1;
    boss namespace_214d79f87f4bf971::function_a5f16b9e67155bbd( "fake_death", "death" );
    boss notify( #"hash_5a0f08f4e3d91d6b" );
    wait 1;
    boss notify( #"hash_aa8f675504afb872" );
    wait 1;
    // the dev command hits once; the hit is lost while the shadow soul shield is up, so clear it and hit until the death scene runs
    for ( self.zmm.boss_t = 0; self.zmm.boss_t < 60; self.zmm.boss_t++ )
    {
        boss function_786bb6aa1b76c7ee( "shadow_soul_immune", 0 );
        boss.var_d2c854047ddd1dbc = 1;
        boss dodamage( 10000, boss.var_78ed774afe1cc998, self );
        wait 0.5;
    }
}

// Ashes: the map's dev kill (health 2, hit for 1); repeated because the hit is lost while Hermes is immune
function menu_finish_hermes( boss )
{
    self endon( "disconnect" );
    boss endon( "death" );
    for ( self.zmm.boss_t = 0; self.zmm.boss_t < 120; self.zmm.boss_t++ )
    {
        if ( boss.var_d2c854047ddd1dbc > 2 )
        {
            boss.var_d2c854047ddd1dbc = 2;
        }
        boss dodamage( 1, boss.origin, self );
        wait 0.5;
    }
}

// Hornet: the map's own boss skip (clear the shield, health 1, one hit), Diana then plays her death scene
function menu_finish_diana( boss )
{
    self endon( "disconnect" );
    boss endon( "death" );
    // same as the map's skip: end the intro first, else the hit is ignored
    if ( !namespace_60b3bdcc70f79fc6::function_f0bb112fe637e41c( "hornet_boss_fight_intro_complete" ) )
    {
        level namespace_60b3bdcc70f79fc6::function_36488e0e5a90d20f( "hornet_boss_fight_intro_complete" );
        wait 2;
    }
    boss.var_382b3e1f72536e3c = undefined;
    boss.var_d2c854047ddd1dbc = 1;
    wait 1;
    boss dodamage( 999, boss.var_78ed774afe1cc998, self );
}

// Locust: Virgil cannot die, the fight ends once his health drops under the map's threshold
function menu_finish_virgil()
{
    level endon( "game_ended" );
    for ( level.zmm_virgil_t = 0; level.zmm_virgil_t < 240 && isalive( level.var_99042256ee32a16d ) && !namespace_60b3bdcc70f79fc6::function_f0bb112fe637e41c( "boss_fight_end" ); level.zmm_virgil_t++ )
    {
        level.var_99042256ee32a16d.var_d2c854047ddd1dbc = 1;
        wait 0.5;
    }
}

// boss AI, plus the boss entities the maps keep in their own fields (Hermes, Diana, Virgil)
function menu_boss_list()
{
    bosses = [];
    enemies = menu_zombie_list();
    if ( isdefined( enemies ) )
    {
        foreach ( ai in enemies )
        {
            if ( isdefined( ai ) && isalive( ai ) && ai.var_e4312c2c1a4a2190 === "boss" )
            {
                bosses[ bosses.size ] = ai;
            }
        }
    }
    if ( isdefined( level.var_302bd0b94da202e7 ) && isalive( level.var_302bd0b94da202e7.entity ) )
    {
        bosses[ bosses.size ] = level.var_302bd0b94da202e7.entity;
    }
    if ( isdefined( level.var_703ffbe28e244b74 ) && isalive( level.var_703ffbe28e244b74.entity ) )
    {
        bosses[ bosses.size ] = level.var_703ffbe28e244b74.entity;
    }
    if ( isdefined( level.var_99042256ee32a16d ) && isalive( level.var_99042256ee32a16d ) )
    {
        bosses[ bosses.size ] = level.var_99042256ee32a16d;
    }
    return bosses;
}

// Astra: Uranus first (killed outright like the game's own skip, its death spawns Neptune), then Neptune through its own kill notify
function menu_finish_astra()
{
    self endon( "disconnect" );
    if ( !isalive( level.zombie_neptune ) )
    {
        foreach ( boss in menu_boss_list() )
        {
            boss function_b2ab534731b73e2();
        }
        for ( t = 0; t < 120 && !isalive( level.zombie_neptune ); t++ )
        {
            wait 0.5;
        }
        if ( !isalive( level.zombie_neptune ) )
        {
            return;
        }
        wait 1;
    }
    neptune = level.zombie_neptune;
    neptune.health = 1;
    neptune.var_c1a14ef3b76e22c5 = 3;
    neptune notify( #"hash_7b331537b02c28cd" );
}

// invulnerable phases ignore the damage, the loop just waits them out; stops when no boss is left or after 5 minutes
function menu_finish_boss_loop()
{
    self notify( "zmm_finish_boss" );
    self endon( "zmm_finish_boss" );
    self endon( "disconnect" );
    level endon( "game_ended" );
    for ( self.zmm.boss_t = 0; self.zmm.boss_t < 600; self.zmm.boss_t++ )
    {
        self.zmm.boss_ents = menu_boss_list();
        if ( self.zmm.boss_ents.size < 1 )
        {
            return;
        }
        foreach ( boss in self.zmm.boss_ents )
        {
            if ( isdefined( boss ) && isalive( boss ) )
            {
                boss dodamage( 1000000, boss.origin, self );
            }
        }
        wait 0.5;
    }
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
        if ( menu_is_host() )
        {
            setdvar( @"zmm_big", "Boss: wait 3 seconds..." );
        }
        if ( !menu_is_host() || getdvar( @"zmm_lua" ) != "1" )
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
        // zm_boss_astra.gsc (Astra only) completes the quest and starts the boss itself
        if ( isdefined( level.zmm_boss_astra ) )
        {
            if ( istrue( level.zmm_boss_started ) )
            {
                return;
            }
            level.zmm_boss_started = 1;
            level notify( "zmm_boss_astra" );
            return;
        }
        self iprintlnbold( "^1Boss: zm_boss_astra.gsc missing, update FuzMenu" );
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

// map-only types stay refused elsewhere: spawning one its map doesn't load is untested
function menu_ai_on_map( aitype )
{
    map = isdefined( level.mapname ) ? level.mapname : "";
    if ( aitype == "sat_spawner_zombie_phobos_zm" || aitype == "t10_spawner_zombie_triton" )
    {
        return map == "zm_sat_scarab";
    }
    if ( aitype == "sat_spawner_zombie_neptune_zm" )
    {
        return map == "zm_sat_scarab" || map == "zm_sat_ruby";
    }
    if ( aitype == "sat_spawner_zombie_uranus_zm" || aitype == "zombie_galileo" || aitype == "zombie_galileo_drone" )
    {
        return map == "zm_sat_ruby";
    }
    if ( aitype == "zombie_aeon" )
    {
        return map == "zm_sat_mantis";
    }
    if ( aitype == "zombie_boss_virgil" )
    {
        return map == "zm_sat_locust";
    }
    return true;
}

// one zombie 200 units in front of the player, friendly unless Hostile mode is on
function menu_spawn_type( aitype )
{
    if ( !menu_ai_on_map( aitype ) )
    {
        return 0;
    }
    self.zmm.spawn_pos = self.origin + anglestoforward( ( 0, self getplayerangles()[ 1 ], 0 ) ) * 200;
    origin = menu_nav_point( self.zmm.spawn_pos );
    if ( !menu_toggle_state( "spawn_hostile" ) )
    {
        return menu_spawn_agent( aitype, origin );
    }
    agent = agent_manager::spawn_agent( aitype, origin, self getplayerangles(), isdefined( level.zombie_team ) ? level.zombie_team : "team_two_hundred" );
    return isdefined( agent ) && isalive( agent );
}

// the game refuses spawns off the navmesh; falls back on the player's own spot when the target has none
function menu_nav_point( origin )
{
    point = getclosestpointonnavmesh( origin );
    if ( !isdefined( point ) )
    {
        point = getclosestpointonnavmesh( self.origin );
    }
    return isdefined( point ) ? point : origin;
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
    // last value per action, for the profiles
    if ( !isdefined( self.zmm.prof_vals ) )
    {
        self.zmm.prof_vals = [];
    }
    self.zmm.prof_vals[ action ] = value;
    if ( action == "pap" )
    {
        ok = menu_pap( value, 1 ) == 1;
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
    else if ( action == "spawn_ai" )
    {
        ok = menu_spawn_type( value );
    }
    else if ( action == "forge_mach" )
    {
        ok = menu_forge_place( value );
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
    else if ( action == "fov" )
    {
        // runs on the host's console like noclip (a cg_fovscale set from Lua did not take)
        ok = menu_is_host();
        if ( ok )
        {
            // the default values the game had before (cg_fov 65, cg_fovscale 1)
            self.zmm.fov_a = "65";
            self.zmm.fov_b = "1";
            self.zmm.fov_txt = "default";
            if ( value )
            {
                self.zmm.fov_a = "110";
                self.zmm.fov_b = "1.3";
                self.zmm.fov_txt = "+";
            }
            // set from GSC, and also through the console (zmm_exec runs one command per value)
            setdvar( @"cg_fov", self.zmm.fov_a );
            setdvar( @"cg_fovscale", self.zmm.fov_b );
            setdvar( @"zmm_exec", "cg_fov " + self.zmm.fov_a + " " + gettime() );
            wait 0.25;
            setdvar( @"zmm_exec", "cg_fovscale " + self.zmm.fov_b + " " + gettime() );
            wait 0.25;
            // readback: shows whether the game kept the values
            self iprintln( "FOV ^3" + self.zmm.fov_txt + " ^7cg_fov " + getdvar( @"cg_fov" ) + " cg_fovscale " + getdvar( @"cg_fovscale" ) );
            return;
        }
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
        if ( menu_perk_page( value ) )
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
    else if ( action == "hk_list" )
    {
        menu_hk_page();
        menu_enter( "Shortcuts" );
        return;
    }
    else if ( action == "hk_clear" )
    {
        ok = menu_hk_clear( value );
    }
    else if ( action == "perk" )
    {
        menu_add_page( "PerkOne", label, [ [ "Have it", 9, "perk_have", value ], [ "Eternal (survives downs)", 9, "perk_eternal", value ], [ "Back", 1, "" ] ] );
        menu_enter( "PerkOne" );
        return;
    }
    else if ( action == "perk_have" || action == "perk_eternal" )
    {
        ok = menu_perk_set( action, value );
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
    else if ( action == "practice" )
    {
        ok = menu_sr_practice_start( value );
    }
    else if ( action == "practice_pos" )
    {
        ok = menu_sr_save_pos();
    }
    else if ( action == "zombie_speed" )
    {
        menu_zombie_speed( value );
    }
    else if ( action == "coop_list" )
    {
        if ( menu_coop_page() )
        {
            menu_enter( self.zmm.coop_page );
            return;
        }
        ok = 0;
    }
    else if ( action == "coop_pick" )
    {
        self.zmm.coop_target = value;
        menu_enter( "CoopAction" );
        return;
    }
    else if ( action == "coop_do" )
    {
        ok = menu_coop_do( value );
    }
    else if ( action == "prof_save" )
    {
        menu_prof_save( value );
    }
    else if ( action == "prof_load" )
    {
        ok = menu_prof_load( value );
    }
    menu_notify( label, ok );
}

// one page per viewer: the list leaves out whoever opens it
function menu_coop_page()
{
    self.zmm.coop_page = "Coop" + self getentitynumber();
    items = [];
    foreach ( player in level.players )
    {
        if ( player != self )
        {
            items[ items.size ] = [ isdefined( player.name ) ? player.name : "Player", 9, "coop_pick", player ];
        }
    }
    if ( items.size == 0 )
    {
        return false;
    }
    items[ items.size ] = [ "Back", 1, "" ];
    menu_add_page( self.zmm.coop_page, "CO-OP", items );
    return true;
}

// shortcut: revives a downed player only, a dead spectator is not brought back; upgrade once the zombies respawn call is known
function menu_coop_do( action )
{
    target = self.zmm.coop_target;
    if ( !isdefined( target ) || !isalive( target ) )
    {
        return 0;
    }
    if ( action == "revive" )
    {
        if ( !istrue( target.inlaststand ) && !istrue( target.var_d0697a2251283e17 ) )
        {
            return 0;
        }
        target thread namespace_b80f99000c537b86::exit( "last_stand_revived", self );
        return 1;
    }
    if ( !utility::issharedfuncdefined( #"zm_utility", #"teleport_player" ) )
    {
        return 0;
    }
    if ( action == "goto" )
    {
        self thread menu_do_teleport( target.origin, self getplayerangles() );
    }
    else
    {
        target thread menu_do_teleport( self.origin, target getplayerangles() );
    }
    return 1;
}

// "x,toggle,toggle|x,action=value*100,...|speed" in kronos/fuzmenu/profiles.json; the x keep each part non-empty for strtok
function menu_prof_save( slot )
{
    str = "x";
    foreach ( key in level.zmm_toggle_keys )
    {
        if ( key != "menu_right" && key != "text_mode" && key != "start_logo" && key != "mouse_nav" && key != "aim_melee" && key != "zm_build" && menu_toggle_state( key ) )
        {
            str = str + "," + key;
        }
    }
    str = str + "|x";
    foreach ( action in [ "dmg_mult", "crit_mult", "melee_mult", "points_mult", "jump", "gravity", "salvage_mult", "spawn_rate", "powerup_time", "zombie_cap" ] )
    {
        if ( isdefined( self.zmm.prof_vals ) && isdefined( self.zmm.prof_vals[ action ] ) )
        {
            str = str + "," + action + "=" + int( self.zmm.prof_vals[ action ] * 100 + 0.5 );
        }
    }
    str = str + "|" + ( isdefined( level.zmm_zspeed ) ? level.zmm_zspeed : "x" );
    nengine_store_load( "fuzmenu", "profiles" );
    nengine_store_set( "fuzmenu", "p" + slot, str );
    nengine_store_save( "fuzmenu", "profiles" );
}

function menu_prof_load( slot )
{
    nengine_store_load( "fuzmenu", "profiles" );
    str = nengine_store_get( "fuzmenu", "p" + slot );
    if ( !isdefined( str ) || str == "" )
    {
        return 0;
    }
    parts = strtok( str, "|" );
    if ( parts.size != 3 )
    {
        return 0;
    }
    menu_reset_mods();
    foreach ( key in strtok( parts[ 0 ], "," ) )
    {
        // an OP Mode parent may already have switched its children on
        if ( isdefined( level.zmm_labels[ key ] ) && !menu_toggle_state( key ) )
        {
            self.zmm.toggles[ key ] = 1;
            if ( !menu_apply_toggle( key ) )
            {
                self.zmm.toggles[ key ] = 0;
            }
        }
    }
    self.zmm.prof_vals = [];
    foreach ( pair in strtok( parts[ 1 ], "," ) )
    {
        kv = strtok( pair, "=" );
        if ( kv.size == 2 )
        {
            menu_prof_set( kv[ 0 ], int( kv[ 1 ] ) / 100.0 );
        }
    }
    menu_zombie_speed( parts[ 2 ] == "x" ? "" : parts[ 2 ] );
    return 1;
}

// the silent side of the menu_param branches
function menu_prof_set( action, value )
{
    self.zmm.prof_vals[ action ] = value;
    if ( action == "jump" || action == "gravity" )
    {
        menu_move_option( action, value );
    }
    else if ( action == "salvage_mult" || action == "spawn_rate" || action == "powerup_time" )
    {
        menu_level_option( action, value );
    }
    else if ( action == "points_mult" )
    {
        self.zmm.points_mult = value;
        menu_override( "zmm_points", [ "zm_points_scalar" ], [ value ], value != 1 );
    }
    else if ( action == "zombie_cap" )
    {
        menu_zombie_option( action, int( value ) );
    }
    else
    {
        if ( !isdefined( level.zmm_mult ) )
        {
            level.zmm_mult = [];
        }
        level.zmm_mult[ action ] = value;
    }
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

function menu_is_bullet( mod )
{
    return mod == "MOD_RIFLE_BULLET" || mod == "MOD_PISTOL_BULLET" || mod == "MOD_HEAD_SHOT" || mod == "MOD_EXPLOSIVE_BULLET";
}

// zombie hit (self = zombie): scale the damage as ProjectNexus does; mults are level fields (solo menu)
function menu_on_zombie_damaged( params )
{
    if ( isdefined( params ) && isplayer( params.var_917e21c98d80255e ) )
    {
        // Old School: 10 points a hit, wonder weapons kill in one hit
        menu_classic_pay( params.var_917e21c98d80255e, 10, params.var_b575eda3d8d8533b );
        // shortcut: the second bullet is simulated (damage and points x2, no second tracer or penetration), upgrade if a GSC magic bullet builtin is identified
        if ( istrue( level.zmm_cl[ "cl_dtap" ] ) && isdefined( params.var_a87b62c261a8d114 ) && menu_is_bullet( params.var_f5a880abf0b199dc ) && utility::issharedfuncdefined( #"loot_perks", #"has_perk" ) && istrue( params.var_917e21c98d80255e utility::callsharedfunc( #"loot_perks", #"has_perk", "specialty_d_mod" ) ) )
        {
            params.var_a87b62c261a8d114 = int( min( params.var_a87b62c261a8d114 * 2, 2000000000 ) );
            menu_classic_pay( params.var_917e21c98d80255e, 10, params.var_b575eda3d8d8533b );
        }
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
    state.prof_vals = undefined;
    menu_zombie_speed( "" );
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
        if ( key == "menu_right" || key == "text_mode" || key == "start_logo" || key == "mouse_nav" || key == "aim_melee" || key == "zm_build" || !istrue( state.toggles[ key ] ) )
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

// shortcut: names keyed on the perk ids seen in the scripts; an unknown id shows as its id without "specialty_"
function menu_perk_name( perk )
{
    if ( !isdefined( level.zmm_perk_names ) )
    {
        level.zmm_perk_names = [];
        level.zmm_perk_names[ "specialty_juggernog" ] = "Juggernog";
        level.zmm_perk_names[ "specialty_quickrevive" ] = "Quick Revive";
        level.zmm_perk_names[ "specialty_speedcola" ] = "Speed Cola";
        level.zmm_perk_names[ "specialty_staminup" ] = "Stamin-Up";
        level.zmm_perk_names[ "specialty_deadshot" ] = "Deadshot Daiquiri";
        level.zmm_perk_names[ "specialty_phd_flopper" ] = "PhD Flopper";
        level.zmm_perk_names[ "specialty_elemental_pop" ] = "Elemental Pop";
        level.zmm_perk_names[ "specialty_death_perception" ] = "Death Perception";
        level.zmm_perk_names[ "specialty_vulture_aid" ] = "Vulture Aid";
        level.zmm_perk_names[ "specialty_scavenger" ] = "Scavenger";
        level.zmm_perk_names[ "specialty_doubletap" ] = "Double Tap";
        level.zmm_perk_names[ "specialty_double_tap" ] = "Double Tap";
        level.zmm_perk_names[ "specialty_mule_kick" ] = "Mule Kick";
        level.zmm_perk_names[ "specialty_mulekick" ] = "Mule Kick";
        level.zmm_perk_names[ "specialty_melee_macchiato" ] = "Melee Macchiato";
        level.zmm_perk_names[ "specialty_tombstone" ] = "Tombstone";
        level.zmm_perk_names[ "specialty_m_mod" ] = "Melee Macchiato";
        level.zmm_perk_names[ "specialty_d_mod" ] = "Double Tap";
        level.zmm_perk_names[ "specialty_z_mod" ] = "Mule Kick";
        // shortcut: these two names are inferred, not read from a game table; correct them if the in-game can says otherwise
        level.zmm_perk_names[ "specialty_w_mod" ] = "Wisp Tea";
        level.zmm_perk_names[ "specialty_y_mod" ] = "Widow's Wine";
    }
    if ( isdefined( level.zmm_perk_names[ perk ] ) )
    {
        return level.zmm_perk_names[ perk ];
    }
    if ( issubstr( perk, "specialty_" ) )
    {
        return removesubstr( perk, "specialty_" );
    }
    return perk;
}

function menu_perk_page( act )
{
    items = [];
    foreach ( perk in menu_perk_keys() )
    {
        items[ items.size ] = [ menu_perk_name( perk ), 9, act, perk ];
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
    if ( key == "free_perks" || key == "classic" )
    {
        level.zmm_box_on[ key ] = on ? 1 : 0;
        on = istrue( level.zmm_box_on[ "free_perks" ] ) || istrue( level.zmm_box_on[ "classic" ] );
        key = "perk_cost";
        func = &menu_perk_classic_cost;
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
    while ( menu_loop_active( "cl_fizz" ) || menu_loop_active( "cl_qr" ) || menu_loop_active( "cl_health" ) || menu_loop_active( "cl_perk_cap" ) )
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
    // one last pass lifts the perk limit and gives the self revives back
    menu_classic_tick();
    state.fizz_loop = 0;
}

function menu_perk_count()
{
    self.zmm_perk_count = 0;
    if ( utility::issharedfuncdefined( #"loot_perks", #"has_perk" ) )
    {
        foreach ( perk in menu_perk_keys() )
        {
            if ( istrue( self utility::callsharedfunc( #"loot_perks", #"has_perk", perk ) ) )
            {
                self.zmm_perk_count++;
            }
        }
    }
    return self.zmm_perk_count;
}

// 4 perks max, one more slot every 20 rounds; the game's own perk switch stops machines and the Wunderfizz alike
function menu_perk_cap_tick()
{
    self.zmm_perk_blocked = istrue( level.zmm_cl[ "cl_perk_cap" ] ) && menu_perk_count() >= 4 + int( menu_current_round() / 20 );
    if ( self.zmm_perk_blocked != istrue( self.zmm_perk_capped ) )
    {
        self.zmm_perk_capped = self.zmm_perk_blocked;
        self menu_override( "zmm_perk_cap", [ "allow_zm_perks" ], [ 0 ], self.zmm_perk_blocked );
    }
}

// no self revive without Quick Revive, one with it: the max fields stop the game's own refill
function menu_qr_tick()
{
    if ( !istrue( level.zmm_cl[ "cl_qr" ] ) )
    {
        if ( istrue( self.zmm_qr_on ) )
        {
            self.zmm_qr_on = 0;
            self.var_4877be4da79014b0 = level.var_7ebad24685cd9f8c.var_4292e4b6ecbd86b5;
            self.var_63cd4b355dddbeba = level.var_7ebad24685cd9f8c.var_c5ebe645f8758bc3;
        }
        return;
    }
    if ( !istrue( self.zmm_qr_on ) )
    {
        self.zmm_qr_on = 1;
        self.zmm_qr_had = 0;
        self namespace_b80f99000c537b86::function_39844c1e879cc048( 0 );
    }
    if ( !( utility::issharedfuncdefined( #"loot_perks", #"has_perk" ) && istrue( self utility::callsharedfunc( #"loot_perks", #"has_perk", "specialty_quickrevive" ) ) ) )
    {
        self.zmm_qr_had = 0;
        self.var_4877be4da79014b0 = 0;
        self.var_63cd4b355dddbeba = 0;
    }
    else if ( !istrue( self.zmm_qr_had ) )
    {
        self.zmm_qr_had = 1;
        self.var_4877be4da79014b0 = ( self.var_aecc486f34e4dd66 ?? 0 ) + 1;
        self.var_63cd4b355dddbeba = self.var_4877be4da79014b0;
        if ( self namespace_b80f99000c537b86::function_7072b516e6cffb7c() < 1 )
        {
            self namespace_b80f99000c537b86::function_39844c1e879cc048( 1 );
        }
    }
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
    else if ( key == "cl_run" )
    {
        menu_zombie_speed( on ? "run" : "" );
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
    if ( on && ( key == "cl_fizz" || key == "cl_qr" || key == "cl_health" || key == "cl_perk_cap" ) && !istrue( state.fizz_loop ) )
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
    foreach ( player in level.players )
    {
        player menu_perk_cap_tick();
        player menu_qr_tick();
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
    // Rex: the "herhouse" living-world scene (script_62a67b1064fe6074), not a zone
    if ( isdefined( level.mapname ) && level.mapname == "zm_sat_scarab" )
    {
        items[ items.size ] = [ "Her House", 9, "map_tp", ( 275, -3682, 1745 ) ];
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

// perk page toggles: Have it gives/removes the perk (removing also ends eternal), Eternal marks it to come back after a down (and gives it)
function menu_perk_set( action, perk )
{
    state = self.zmm;
    if ( !isdefined( state.eternal ) )
    {
        state.eternal = [];
    }
    if ( action == "perk_eternal" )
    {
        if ( istrue( state.eternal[ perk ] ) )
        {
            state.eternal[ perk ] = undefined;
            return true;
        }
        state.eternal[ perk ] = 1;
        self thread menu_eternal_loop();
        return self namespace_377106c4017f7cda::function_e183e1e4f906ec3b( perk ) || menu_grant_perk( perk );
    }
    if ( !self namespace_377106c4017f7cda::function_e183e1e4f906ec3b( perk ) )
    {
        return menu_grant_perk( perk );
    }
    state.eternal[ perk ] = undefined;
    self namespace_377106c4017f7cda::function_145b00820a9f68b2( perk, true );
    // removal finishes over a few frames
    for ( state.perk_try = 0; state.perk_try < 60 && self namespace_377106c4017f7cda::function_e183e1e4f906ec3b( perk ); state.perk_try++ )
    {
        waitframe();
    }
    return !self namespace_377106c4017f7cda::function_e183e1e4f906ec3b( perk );
}

// gives the eternal perks back after a down; ends once none is left
function menu_eternal_loop()
{
    self endon( "disconnect" );
    state = self.zmm;
    if ( istrue( state.eternal_loop ) )
    {
        return;
    }
    state.eternal_loop = 1;
    for ( ;; )
    {
        wait 0.5;
        state.eternal_any = 0;
        foreach ( perk in menu_perk_keys() )
        {
            if ( istrue( state.eternal[ perk ] ) )
            {
                state.eternal_any = 1;
                if ( isalive( self ) && !istrue( self.inlaststand ) && !self namespace_377106c4017f7cda::function_e183e1e4f906ec3b( perk ) )
                {
                    menu_grant_perk( perk );
                }
            }
        }
        if ( !state.eternal_any )
        {
            state.eternal_loop = 0;
            return;
        }
    }
}

function menu_revoke_perks()
{
    keys = menu_perk_keys();
    if ( keys.size == 0 )
    {
        return false;
    }
    self.perma_perks = [];
    self.zmm.eternal = [];
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
    if ( !( self.var_b02f6e7abbbc8a84[ slot ] === name ) )
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

// ---------------------------------------------------------------- shortcuts (Settings > Shortcuts)
// zm_mod_menu_post.lua writes "<key>:<count>" to zmm_hk on F1-F12 (host keyboard).
// Menu open: binds the highlighted row to that key (same key again unbinds it). Menu closed: runs the bound row.
// Saved as "kind~label~arg~value" in kronos/fuzmenu/shortcuts.json

function menu_hk_loop()
{
    self endon( "disconnect" );
    state = self.zmm;
    menu_fav_page();
    while ( isdefined( self.zmm ) && state.running )
    {
        wait 0.05;
        if ( getdvar( @"zmm_hk" ) == "0" || !menu_is_host() )
        {
            continue;
        }
        state.hk_key = strtok( getdvar( @"zmm_hk" ), ":" )[ 0 ];
        setdvar( @"zmm_hk", "0" );
        if ( state.hk_key == "fav" )
        {
            if ( state.is_open )
            {
                menu_fav_toggle();
            }
        }
        else if ( state.is_open )
        {
            menu_hk_bind( state.hk_key );
        }
        else
        {
            menu_hk_run( state.hk_key );
        }
    }
}

// strings as "s...", whole numbers as "i...", decimals as "n" + value * 1000 (no float() to read them back), nothing as "u"
function menu_hk_enc( v )
{
    if ( !isdefined( v ) )
    {
        return "u";
    }
    if ( isstring( v ) )
    {
        return "s" + v;
    }
    if ( int( v * 1000 ) % 1000 == 0 )
    {
        return "i" + int( v );
    }
    return "n" + int( v * 1000 );
}

function menu_hk_dec( v )
{
    if ( v == "u" )
    {
        return undefined;
    }
    if ( getsubstr( v, 0, 1 ) == "s" )
    {
        return getsubstr( v, 1 );
    }
    if ( getsubstr( v, 0, 1 ) == "i" )
    {
        return int( getsubstr( v, 1 ) );
    }
    return int( getsubstr( v, 1 ) ) / 1000;
}

function menu_hk_bind( key )
{
    state = self.zmm;
    state.hk_entry = level.zmm_pages[ state.page ].items[ state.cursor ];
    // rows that need a picked player or a position cannot be saved as text
    if ( state.page == "Shortcuts" || state.hk_entry[ 1 ] < 2 || ( state.hk_entry[ 1 ] == 9 && ( state.hk_entry[ 2 ] == "map_tp" || state.hk_entry[ 2 ] == "coop_pick" || state.hk_entry[ 2 ] == "coop_do" ) ) )
    {
        menu_notify( "F" + key + ": this row cannot be a shortcut", 0 );
        return;
    }
    state.hk_val = state.hk_entry[ 1 ] + "~" + state.hk_entry[ 0 ] + "~" + menu_hk_enc( state.hk_entry[ 2 ] ) + "~" + menu_hk_enc( state.hk_entry[ 3 ] );
    nengine_store_load( "fuzmenu", "shortcuts" );
    if ( nengine_store_get( "fuzmenu", "f" + key ) === state.hk_val )
    {
        nengine_store_set( "fuzmenu", "f" + key, "" );
        state.hk_label = "F" + key + " unbound";
    }
    else
    {
        nengine_store_set( "fuzmenu", "f" + key, state.hk_val );
        state.hk_label = "F" + key + " = " + state.hk_entry[ 0 ];
    }
    nengine_store_save( "fuzmenu", "shortcuts" );
    menu_notify( state.hk_label, 1 );
}

function menu_hk_run( key )
{
    state = self.zmm;
    nengine_store_load( "fuzmenu", "shortcuts" );
    state.hk_val = nengine_store_get( "fuzmenu", "f" + key );
    if ( !isstring( state.hk_val ) || state.hk_val == "" )
    {
        return;
    }
    state.hk_parts = strtok( state.hk_val, "~" );
    if ( state.hk_parts.size < 4 )
    {
        return;
    }
    state.hk_entry = [ state.hk_parts[ 1 ], int( state.hk_parts[ 0 ] ), menu_hk_dec( state.hk_parts[ 2 ] ), menu_hk_dec( state.hk_parts[ 3 ] ) ];
    state.page = "Main";
    state.stack = [];
    state.depth = 0;
    menu_run_entry( state.hk_entry );
    // a page row (or a list opener) opens the menu on that page
    if ( state.depth > 0 && !state.is_open && isdefined( level.zmm_pages[ state.page ] ) )
    {
        state.hk_page = state.page;
        menu_open();
        menu_enter( state.hk_page );
    }
}

function menu_hk_page()
{
    state = self.zmm;
    state.hk_items = [];
    nengine_store_load( "fuzmenu", "shortcuts" );
    for ( state.hk_i = 1; state.hk_i <= 12; state.hk_i++ )
    {
        state.hk_val = nengine_store_get( "fuzmenu", "f" + state.hk_i );
        state.hk_label = "-";
        if ( isstring( state.hk_val ) && state.hk_val != "" && strtok( state.hk_val, "~" ).size >= 2 )
        {
            state.hk_label = strtok( state.hk_val, "~" )[ 1 ];
        }
        state.hk_items[ state.hk_items.size ] = [ "F" + state.hk_i + ": " + state.hk_label, 9, "hk_clear", state.hk_i ];
    }
    state.hk_items[ state.hk_items.size ] = [ "Back", 1, "" ];
    menu_add_page( "Shortcuts", "SHORTCUTS: HIGHLIGHT ANY OPTION, PRESS F1-F12", state.hk_items );
}

// ---------------------------------------------------------------- favorites (Favorites page, first row of Main)
// zm_mod_menu_post.lua writes "fav:<count>" to zmm_hk on right arrow / D-pad right while the menu is open: adds the highlighted row, or removes it.
// Saved as fav1..fav8 in kronos/fuzmenu/favorites.json, same text as a shortcut.
// shortcut: pages are shared, so co-op guests see the host's favorites too; give each player a page if guests mind

function menu_fav_toggle()
{
    state = self.zmm;
    state.fav_entry = level.zmm_pages[ state.page ].items[ state.cursor ];
    if ( state.page == "Shortcuts" || state.fav_entry[ 1 ] < 2 || ( state.fav_entry[ 1 ] == 2 && state.fav_entry[ 2 ] == "Favorites" ) || ( state.fav_entry[ 1 ] == 9 && ( state.fav_entry[ 2 ] == "map_tp" || state.fav_entry[ 2 ] == "coop_pick" || state.fav_entry[ 2 ] == "coop_do" ) ) )
    {
        menu_notify( "This row cannot be a favorite", 0 );
        return;
    }
    if ( state.page == "Favorites" && state.cursor < level.zmm_fav_vals.size )
    {
        state.fav_val = level.zmm_fav_vals[ state.cursor ];
    }
    else
    {
        state.fav_val = state.fav_entry[ 1 ] + "~" + state.fav_entry[ 0 ] + "~" + menu_hk_enc( state.fav_entry[ 2 ] ) + "~" + menu_hk_enc( state.fav_entry[ 3 ] );
    }
    nengine_store_load( "fuzmenu", "favorites" );
    state.fav_free = 0;
    for ( state.fav_i = 1; state.fav_i <= 8; state.fav_i++ )
    {
        state.fav_old = nengine_store_get( "fuzmenu", "fav" + state.fav_i );
        if ( state.fav_old === state.fav_val )
        {
            nengine_store_set( "fuzmenu", "fav" + state.fav_i, "" );
            nengine_store_save( "fuzmenu", "favorites" );
            menu_fav_page();
            menu_notify( "Removed from favorites", 1 );
            return;
        }
        if ( state.fav_free == 0 && ( !isstring( state.fav_old ) || state.fav_old == "" ) )
        {
            state.fav_free = state.fav_i;
        }
    }
    if ( state.fav_free == 0 )
    {
        menu_notify( "Favorites full (8): right arrow on one removes it", 0 );
        return;
    }
    nengine_store_set( "fuzmenu", "fav" + state.fav_free, state.fav_val );
    nengine_store_save( "fuzmenu", "favorites" );
    menu_fav_page();
    menu_notify( "Added to favorites", 1 );
}

// rebuilds the Favorites page from the saved favorites
function menu_fav_page()
{
    level.zmm_fav_vals = [];
    level.zmm_fav_items = [];
    nengine_store_load( "fuzmenu", "favorites" );
    for ( level.zmm_fav_i = 1; level.zmm_fav_i <= 8; level.zmm_fav_i++ )
    {
        level.zmm_fav_v = nengine_store_get( "fuzmenu", "fav" + level.zmm_fav_i );
        if ( !isstring( level.zmm_fav_v ) || level.zmm_fav_v == "" || strtok( level.zmm_fav_v, "~" ).size < 4 )
        {
            continue;
        }
        level.zmm_fav_p = strtok( level.zmm_fav_v, "~" );
        level.zmm_fav_vals[ level.zmm_fav_vals.size ] = level.zmm_fav_v;
        level.zmm_fav_items[ level.zmm_fav_items.size ] = [ level.zmm_fav_p[ 1 ], int( level.zmm_fav_p[ 0 ] ), menu_hk_dec( level.zmm_fav_p[ 2 ] ), menu_hk_dec( level.zmm_fav_p[ 3 ] ) ];
    }
    level.zmm_fav_items[ level.zmm_fav_items.size ] = [ "Back", 1, "" ];
    menu_add_page( "Favorites", "FAVORITES: RIGHT ARROW ADDS OR REMOVES", level.zmm_fav_items );
    if ( isdefined( self.zmm ) && self.zmm.page == "Favorites" && self.zmm.cursor >= level.zmm_fav_items.size )
    {
        self.zmm.cursor = level.zmm_fav_items.size - 1;
    }
    if ( isdefined( self.zmm ) && istrue( self.zmm.is_open ) )
    {
        menu_render();
    }
}

// a row of the Shortcuts page: unbinds that key
function menu_hk_clear( key )
{
    nengine_store_load( "fuzmenu", "shortcuts" );
    if ( !isstring( nengine_store_get( "fuzmenu", "f" + key ) ) || nengine_store_get( "fuzmenu", "f" + key ) == "" )
    {
        menu_notify( "Highlight any option and press F1-F12 to bind it", 1 );
        return 1;
    }
    nengine_store_set( "fuzmenu", "f" + key, "" );
    nengine_store_save( "fuzmenu", "shortcuts" );
    menu_hk_page();
    return 1;
}
