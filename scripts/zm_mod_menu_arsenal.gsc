#using scripts\common\utility;
#using scripts\common\weapon;
#using scripts\common\status_effects\effect_charm;
#using scripts\mp\zm\systems\agent_manager;
// loot (namespace_952965bfef60cff8): loot ID <-> ref
#using script_1ade2fa7cae9593d;
// operator (operator skins)
#using script_2dc447b1dd033a26;

#namespace zm_mod_menu_arsenal;

// FuzMenu extension: extra weapon lists, shot effects and zombie pages (waves, size, animations)

autoexec ars_init()
{
    if ( !utility::iszm() )
    {
        return;
    }
    level thread ars_wait_menu();
}

function ars_wait_menu()
{
    while ( !isdefined( level.zmm_add_page ) )
    {
        wait 0.05;
    }
    if ( !isdefined( level.zmm_ext ) )
    {
        level.zmm_ext = [];
    }
    if ( !isdefined( level.zmm_ext_on ) )
    {
        level.zmm_ext_on = [];
    }
    level.zmm_ext[ "ars_give" ] = &ars_give;
    level.zmm_ext[ "ars_shot" ] = &ars_shot;
    level.zmm_ext_on[ "ars_shot" ] = &ars_shot_on;
    level.zmm_ext[ "ars_wave" ] = &ars_wave;
    level.zmm_ext[ "ars_wave_size" ] = &ars_wave_size;
    level.zmm_ext_on[ "ars_wave_size" ] = &ars_wave_size_on;
    level.zmm_ext[ "ars_detect_scan" ] = &ars_detect_scan;
    level.zmm_ext[ "ars_detect_spawn" ] = &ars_detect_spawn;
    level.zmm_ext[ "ars_ally" ] = &ars_ally;
    level.zmm_ext[ "ars_summon" ] = &ars_summon;
    level.zmm_ext[ "ars_size_look" ] = &ars_size_look;
    level.zmm_ext[ "ars_size_all" ] = &ars_size_all;
    level.zmm_ext[ "ars_ragdoll" ] = &ars_ragdoll;
    level.zmm_ext[ "ars_anim" ] = &ars_anim;
    level.zmm_ext[ "ars_anim_stop" ] = &ars_anim_stop;
    level.zmm_ext[ "ars_rescan" ] = &ars_rescan;

    level.ars_bad = [];
    level.ars_good = [];
    ars_add_weapon_pages();
    ars_add_zombie_pages();
    ars_add_anim_pages();
    level thread ars_scan_later();
}

// ---------------------------------------------------------------- pages

function ars_add_weapon_pages()
{
    ars_list_page( "ArsNew", "NEW WEAPONS", [] );
    ars_list_page( "ArsStreak", "SCORESTREAK WEAPONS", [] );
    ars_list_page( "ArsDoa", "DEAD OPS ARCADE GUNS", [] );
    [[ level.zmm_add_page ]]( "ArsShots", "SHOT EFFECTS", [
        [ "Explosive bullets", 11, "ars_shot", "boom" ],
        [ "Lightning bullets", 11, "ars_shot", "zap" ],
        [ "Freeze bullets", 11, "ars_shot", "ice" ],
        [ "Teleport gun", 11, "ars_shot", "tp" ],
        [ "Effect gun", 11, "ars_shot", "fx" ],
        [ "Back", 1, "" ] ] );
}

function ars_add_zombie_pages()
{
    [[ level.zmm_add_page ]]( "ArsWave", "CUSTOM WAVES", [
        [ "Wave size 3", 11, "ars_wave_size", 3 ],
        [ "Wave size 6", 11, "ars_wave_size", 6 ],
        [ "Wave size 12", 11, "ars_wave_size", 12 ],
        [ "Boss wave", 10, "ars_wave", "boss" ],
        [ "Elite wave", 10, "ars_wave", "elite" ],
        [ "Armored wave", 10, "ars_wave", "armor" ],
        [ "Dog wave", 10, "ars_wave", "dog" ],
        [ "Mixed wave", 10, "ars_wave", "mixed" ],
        [ "Back", 1, "" ] ] );
    [[ level.zmm_add_page ]]( "ArsSize", "SIZE", [
        [ "Looked-at bigger", 10, "ars_size_look", 1.6 ],
        [ "Looked-at smaller", 10, "ars_size_look", 0.5 ],
        [ "Looked-at normal", 10, "ars_size_look", 1.0 ],
        [ "All bigger", 10, "ars_size_all", 1.6 ],
        [ "All smaller", 10, "ars_size_all", 0.5 ],
        [ "All normal", 10, "ars_size_all", 1.0 ],
        [ "Back", 1, "" ] ] );
    ars_detect_page();
}

// pages whose rows come from a scan: the give rows, then Rescan and Back
function ars_list_page( id, title, rows )
{
    items = [];
    foreach ( row in rows )
    {
        items[ items.size ] = row;
    }
    if ( items.size == 0 )
    {
        items[ items.size ] = [ "Nothing found yet", 10, "ars_none", 0 ];
    }
    if ( id != "ArsNew" )
    {
        items[ items.size ] = [ "Rescan", 10, "ars_rescan", 0 ];
    }
    items[ items.size ] = [ "Back", 1, "" ];
    [[ level.zmm_add_page ]]( id, title, items );
}

// ---------------------------------------------------------------- weapon scan

function ars_scan_later()
{
    level endon( #"game_ended" );
    wait 5;
    ars_scan_weapons();
}

function ars_rescan( unused )
{
    ars_scan_weapons();
    self [[ level.zmm_notify_fn ]]( "Weapon scan", 1 );
}

// the name the game knows for n (plain, _zm or _mp), or undefined
function ars_real_name( n )
{
    if ( weaponexists( n ) )
    {
        return n;
    }
    if ( weaponexists( n + "_zm" ) )
    {
        return n + "_zm";
    }
    if ( weaponexists( n + "_mp" ) )
    {
        return n + "_mp";
    }
    return undefined;
}

function ars_base_name( n )
{
    if ( n.size > 3 )
    {
        tail = getsubstr( n, n.size - 3 );
        if ( tail == "_mp" || tail == "_zm" )
        {
            return getsubstr( n, 0, n.size - 3 );
        }
    }
    return n;
}

// a gun worth listing: sat_<class>_... or t10_<class>_..., no dummies, menus, fists or DOA guns
function ars_is_gun( n )
{
    parts = strtok( n, "_" );
    if ( parts.size < 3 || !( parts[ 0 ] == "sat" || parts[ 0 ] == "t10" ) )
    {
        return 0;
    }
    if ( !issubstr( " ar sm lm sh dm sn pi la me ww sl ", " " + parts[ 1 ] + " " ) )
    {
        return 0;
    }
    foreach ( bad in [ "_ui_", "dummy", "none", "fists", "zombie_melee", "diveknife", "zombie_mimic", "ztron" ] )
    {
        if ( issubstr( n, bad ) )
        {
            return 0;
        }
    }
    return 1;
}

// row label: the game's own name when it is plain text; sat_<cls>_<word> is turned into the
// localized name by the Lua renderer; anything else gets a readable cleanup
function ars_label( name )
{
    w = weapon::buildweapon( name, getweapondefaultattachments( name ) );
    if ( isdefined( w ) && isdefined( w.displayname ) && isstring( w.displayname ) && w.displayname != "" )
    {
        return w.displayname;
    }
    base = ars_base_name( name );
    parts = strtok( base, "_" );
    if ( parts.size == 3 && parts[ 0 ] == "sat" )
    {
        return base;
    }
    if ( parts.size == 4 && parts[ 0 ] == "t10" && getsubstr( parts[ 2 ], 0, 1 ) == "p" )
    {
        return base;
    }
    text = "";
    for ( i = 2; i < parts.size; i++ )
    {
        text = text + ( i > 2 ? " " : "" ) + parts[ i ];
    }
    return text == "" ? base : text;
}

function ars_scan_weapons()
{
    // names already on the main Give pages (kind 8 rows)
    level.ars_listed = [];
    if ( isdefined( level.zmm_pages ) )
    {
        foreach ( page in level.zmm_pages )
        {
            foreach ( entry in page.items )
            {
                if ( entry[ 1 ] == 8 && isstring( entry[ 2 ] ) )
                {
                    level.ars_listed[ ars_base_name( entry[ 2 ] ) ] = 1;
                }
            }
        }
    }
    level.ars_rows = [];
    if ( isdefined( level.weaponmapdata ) )
    {
        level.ars_keys = getarraykeys( level.weaponmapdata );
        for ( level.ars_k = 0; level.ars_k < level.ars_keys.size && level.ars_rows.size < 80; level.ars_k++ )
        {
            ars_scan_one( level.ars_keys[ level.ars_k ] );
            // each new row builds the gun for its name: spread the work over frames
            if ( level.ars_k % 20 == 19 )
            {
                waitframe();
            }
        }
    }
    level.ars_rows = ars_pick_rows( level.ars_rows );
    ars_list_page( "ArsNew", "NEW WEAPONS", level.ars_rows );
    ars_list_page( "ArsStreak", "SCORESTREAK WEAPONS", ars_rows_for( [ "sat_pi_handcannon", "sat_lm_deathmachine" ] ) );
    ars_list_page( "ArsDoa", "DEAD OPS ARCADE GUNS", ars_rows_for( [ "sat_pi_ztronraygun", "sat_ar_ztrondg2", "sat_lm_ztronjetgun", "sat_lm_ztrondeathmachine", "sat_la_ztronwarmachine", "sat_la_ztroncrossbow", "sat_la_ztronpable3", "sat_lm_ztronlmg", "sat_sh_ztronshotgun", "sat_dm_ztronp38" ] ) );
}

// keeps the guns worth giving and names the ones the game calls "Undefined"
// shortcut: picks by scan position (12 rows seen in game); any other count is left as is, switch to weapon refs if a map lists them differently
function ars_pick_rows( rows )
{
    if ( rows.size != 12 )
    {
        return rows;
    }
    return [ rows[ 0 ], [ "NX Ravager", 10, "ars_give", rows[ 2 ][ 3 ] ], [ "Gol Havoc", 10, "ars_give", rows[ 3 ][ 3 ] ], rows[ 4 ], [ "Siren", 10, "ars_give", rows[ 5 ][ 3 ] ], rows[ 6 ] ];
}

function ars_scan_one( key )
{
    if ( !isstring( key ) || !ars_is_gun( key ) )
    {
        return;
    }
    base = ars_base_name( key );
    if ( isdefined( level.ars_listed[ base ] ) )
    {
        return;
    }
    real = ars_real_name( base );
    if ( !isdefined( real ) )
    {
        real = ars_real_name( key );
    }
    if ( !isdefined( real ) )
    {
        return;
    }
    level.ars_listed[ base ] = 1;
    level.ars_rows[ level.ars_rows.size ] = [ ars_label( real ), 10, "ars_give", real ];
}

function ars_rows_for( names )
{
    rows = [];
    foreach ( n in names )
    {
        real = ars_real_name( n );
        if ( isdefined( real ) )
        {
            rows[ rows.size ] = [ ars_label( real ), 10, "ars_give", real ];
        }
    }
    return rows;
}

// ---------------------------------------------------------------- give

// same steps as the main Give pages, but keeps the exact name (some guns only exist as _mp)
function ars_give( name )
{
    self endon( #"disconnect" );
    self.zmm.ars_gname = name;
    self.zmm.ars_gun = undefined;
    self thread ars_build_gun();
    waitframe();
    waitframe();
    if ( !isdefined( self.zmm.ars_gun ) || isnullweapon( self.zmm.ars_gun ) )
    {
        self [[ level.zmm_notify_fn ]]( "Weapon given", 0 );
        return;
    }
    self loadweaponsforplayer( [ self.zmm.ars_gun ], 1 );
    for ( self.zmm.ars_t = 0; self.zmm.ars_t < 100; self.zmm.ars_t++ )
    {
        if ( self hasloadedviewweapons( [ self.zmm.ars_gun ] ) )
        {
            break;
        }
        wait 0.1;
    }
    ars_make_room();
    self giveweapon( self.zmm.ars_gun, undefined, 0, -1, 0 );
    self assignweaponprimaryslot( self.zmm.ars_gun );
    self switchtoweapon( self.zmm.ars_gun );
    self givemaxammo( self.zmm.ars_gun );
    wait 0.25;
    self [[ level.zmm_notify_fn ]]( "Weapon given", self hasweapon( self.zmm.ars_gun ) );
}

function ars_build_gun()
{
    self.zmm.ars_gun = weapon::buildweapon( self.zmm.ars_gname, getweapondefaultattachments( self.zmm.ars_gname ) );
}

// 3 guns carried: drop the held one first
function ars_make_room()
{
    if ( !isdefined( self.primaryinventory ) || self hasweapon( self.zmm.ars_gun ) )
    {
        return;
    }
    guns = 0;
    foreach ( w in self.primaryinventory )
    {
        if ( isdefined( w ) && !isnullweapon( w ) && isdefined( w.basename ) && !issubstr( w.basename, "_me_" ) )
        {
            guns++;
        }
    }
    cur = self getcurrentweapon();
    if ( guns >= 3 && isdefined( cur ) && !isnullweapon( cur ) )
    {
        self takeweapon( cur );
    }
}

// ---------------------------------------------------------------- shot effects

function ars_shot_on( mode )
{
    return isdefined( self.zmm.ars_shots ) && istrue( self.zmm.ars_shots[ mode ] );
}

function ars_shot( mode )
{
    if ( !isdefined( self.zmm.ars_shots ) )
    {
        self.zmm.ars_shots = [];
    }
    self.zmm.ars_shots[ mode ] = !ars_shot_on( mode );
    if ( !istrue( self.zmm.ars_shot_run ) )
    {
        self thread ars_shot_loop();
    }
}

function ars_any_shot()
{
    foreach ( v in self.zmm.ars_shots )
    {
        if ( istrue( v ) )
        {
            return 1;
        }
    }
    return 0;
}

// fires while the trigger is held and the menu is closed (the trigger also scrolls the menu)
function ars_shot_loop()
{
    self endon( #"disconnect" );
    self.zmm.ars_shot_run = 1;
    self.zmm.ars_shot_t = 0;
    while ( ars_any_shot() )
    {
        if ( !self.zmm.is_open && self attackbuttonpressed() && gettime() - self.zmm.ars_shot_t > 200 )
        {
            self.zmm.ars_shot_t = gettime();
            ars_fire();
        }
        wait 0.05;
    }
    self.zmm.ars_shot_run = 0;
}

function ars_fire()
{
    eye = self geteye();
    self.zmm.ars_fwd = anglestoforward( self getplayerangles() );
    self.zmm.ars_hit = physicstrace( eye, eye + self.zmm.ars_fwd * 6000 );
    if ( ars_shot_on( "boom" ) )
    {
        ars_fire_boom();
    }
    if ( ars_shot_on( "zap" ) )
    {
        ars_fire_zap();
    }
    if ( ars_shot_on( "ice" ) )
    {
        ars_fire_ice();
    }
    if ( ars_shot_on( "fx" ) )
    {
        ars_fire_fx();
    }
    if ( ars_shot_on( "tp" ) )
    {
        ars_fire_tp();
    }
}

function ars_fx( name )
{
    if ( isdefined( level.var_d1e5f36ab9f106 ) && isdefined( level.var_d1e5f36ab9f106[ name ] ) )
    {
        return level.var_d1e5f36ab9f106[ name ];
    }
    return undefined;
}

function ars_play( name, pos )
{
    fx = ars_fx( name );
    if ( isdefined( fx ) )
    {
        playfx( fx, pos );
    }
}

function ars_zombies()
{
    return getaiarray( isdefined( level.zombie_team ) ? level.zombie_team : "team_two_hundred" );
}

// same idea as the main menu: never touch scripted / cleanup-proof AI (bosses in scenes, quest AI)
function ars_protected( ai )
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

function ars_fire_boom()
{
    ars_play( "shatterblast_explosion_effect", self.zmm.ars_hit );
    earthquake( 0.25, 0.4, self.zmm.ars_hit, 450 );
    self playsound( "prj_ammomod_shatterblast_proc_explode" );
    foreach ( ai in ars_zombies() )
    {
        if ( isalive( ai ) && !ars_protected( ai ) && distancesquared( ai.origin, self.zmm.ars_hit ) < 180 * 180 )
        {
            ai dodamage( 1500, self.zmm.ars_hit, self );
        }
    }
}

// shortcut: hits the first 4 zombies found in range, not the 4 nearest
function ars_fire_zap()
{
    ars_play( "lightning_strike", self.zmm.ars_hit );
    hits = 0;
    foreach ( ai in ars_zombies() )
    {
        if ( hits < 4 && isalive( ai ) && !ars_protected( ai ) && distancesquared( ai.origin, self.zmm.ars_hit ) < 380 * 380 )
        {
            ars_play( "vfx_lightning_zaps_impact", ai.origin + ( 0, 0, 40 ) );
            ai dodamage( 900, ai.origin, self );
            hits++;
        }
    }
    if ( hits > 0 )
    {
        self playsound( "evt_lightning_strike" );
    }
}

function ars_fire_ice()
{
    foreach ( ai in ars_zombies() )
    {
        if ( isalive( ai ) && !ars_protected( ai ) && !istrue( ai.ars_iced ) && distancesquared( ai.origin, self.zmm.ars_hit ) < 240 * 240 )
        {
            ai thread ars_ice();
        }
    }
}

// self = AI: pinned to a still anchor for a few seconds; the anchor removes itself even if the AI is gone
function ars_ice()
{
    self.ars_iced = 1;
    self.ars_anchor = spawn( "script_origin", self.origin );
    self.ars_anchor thread ars_anchor_life();
    self linkto( self.ars_anchor );
    ars_play( "flash_freeze_shatter_fx", self.origin + ( 0, 0, 40 ) );
    self playsound( "evt_ammomod_cryofreeze_ai_shatter" );
    wait 2.5;
    if ( isdefined( self ) )
    {
        self unlink();
        self.ars_iced = 0;
    }
}

function ars_anchor_life()
{
    wait 3;
    self delete();
}

function ars_fire_tp()
{
    if ( gettime() - ( isdefined( self.zmm.ars_tp_t ) ? self.zmm.ars_tp_t : 0 ) < 600 )
    {
        return;
    }
    self.zmm.ars_tp_t = gettime();
    spot = self [[ level.zmm_nav_point_fn ]]( self.zmm.ars_hit - self.zmm.ars_fwd * 40 );
    ars_play( "teleport_splash", self.origin );
    self [[ level.zmm_teleport_fn ]]( spot, self getplayerangles() );
    ars_play( "aether_shroud_teleport", spot );
}

// a random loaded effect from the game's own table
function ars_fire_fx()
{
    if ( !isdefined( level.ars_fxkeys ) )
    {
        level.ars_fxkeys = [];
        if ( isdefined( level.var_d1e5f36ab9f106 ) )
        {
            foreach ( k in getarraykeys( level.var_d1e5f36ab9f106 ) )
            {
                if ( isstring( k ) )
                {
                    level.ars_fxkeys[ level.ars_fxkeys.size ] = k;
                }
            }
        }
    }
    if ( level.ars_fxkeys.size > 0 )
    {
        ars_play( level.ars_fxkeys[ randomint( level.ars_fxkeys.size ) ], self.zmm.ars_hit );
    }
}

// ---------------------------------------------------------------- spawning

// one AI of type on team, in a ring around the player, snapped to the navmesh; remembers types the map refuses
function ars_spawn_one( type, team, near, far )
{
    if ( isdefined( level.ars_bad[ type ] ) )
    {
        return undefined;
    }
    yaw = randomfloat( 360 );
    spot = self [[ level.zmm_nav_point_fn ]]( self.origin + anglestoforward( ( 0, yaw, 0 ) ) * randomfloatrange( near, far ) );
    ai = agent_manager::spawn_agent( type, spot, ( 0, yaw + 180, 0 ), team );
    if ( !isdefined( ai ) || !isalive( ai ) )
    {
        if ( !isdefined( level.ars_good[ type ] ) )
        {
            level.ars_bad[ type ] = 1;
        }
        return undefined;
    }
    level.ars_good[ type ] = 1;
    return ai;
}

function ars_zombie_team()
{
    return isdefined( level.zombie_team ) ? level.zombie_team : "team_two_hundred";
}

function ars_map()
{
    return isdefined( level.mapname ) ? level.mapname : "";
}

function ars_boss_pool()
{
    map = ars_map();
    if ( map == "zm_sat_scarab" )
    {
        return [ "sat_spawner_zombie_phobos_zm", "t10_spawner_zombie_triton" ];
    }
    if ( map == "zm_sat_ruby" )
    {
        return [ "sat_spawner_zombie_uranus_zm", "zombie_galileo" ];
    }
    if ( map == "zm_sat_mantis" )
    {
        return [ "zombie_aeon" ];
    }
    if ( map == "zm_sat_locust" )
    {
        return [ "zombie_boss_virgil" ];
    }
    return [ "zombie_abom_hvt", "zombie_callisto_hvt" ];
}

function ars_pool( kind )
{
    if ( kind == "boss" )
    {
        return ars_boss_pool();
    }
    if ( kind == "elite" )
    {
        return [ "zombie_abom", "zombie_callisto" ];
    }
    if ( kind == "armor" )
    {
        return [ "zombie_base_armored_light", "zombie_base_armored_heavy" ];
    }
    if ( kind == "dog" )
    {
        return [ "zombie_hellhound" ];
    }
    return [ "zombie_base", "zombie_base_armored_light", "zombie_hellhound", "zombie_mimic", "zombie_abom", "zombie_shade", "zombie_viper" ];
}

function ars_wave_size( n )
{
    self.zmm.ars_wave_n = n;
}

function ars_wave_size_on( n )
{
    return ( isdefined( self.zmm.ars_wave_n ) ? self.zmm.ars_wave_n : 6 ) == n;
}

function ars_wave( kind )
{
    self endon( #"disconnect" );
    self.zmm.ars_pool = ars_pool( kind );
    self.zmm.ars_n = isdefined( self.zmm.ars_wave_n ) ? self.zmm.ars_wave_n : 6;
    self.zmm.ars_made = 0;
    for ( self.zmm.ars_w = 0; self.zmm.ars_w < self.zmm.ars_n; self.zmm.ars_w++ )
    {
        if ( isdefined( ars_spawn_one( self.zmm.ars_pool[ randomint( self.zmm.ars_pool.size ) ], ars_zombie_team(), 350, 700 ) ) )
        {
            self.zmm.ars_made++;
        }
        wait 0.2;
    }
    self [[ level.zmm_notify_fn ]]( "Wave spawned", self.zmm.ars_made > 0 );
}

// ---------------------------------------------------------------- detected types

function ars_detect_page()
{
    if ( !isdefined( level.ars_types ) )
    {
        level.ars_types = [];
    }
    items = [];
    foreach ( t in level.ars_types )
    {
        items[ items.size ] = [ t, 10, "ars_detect_spawn", t ];
    }
    items[ items.size ] = [ "Scan for types", 10, "ars_detect_scan", 0 ];
    items[ items.size ] = [ "Back", 1, "" ];
    [[ level.zmm_add_page ]]( "ArsDetect", "DETECTED TYPES", items );
}

function ars_detect_add( t )
{
    if ( !isdefined( t ) || !isstring( t ) || t == "" )
    {
        return;
    }
    foreach ( have in level.ars_types )
    {
        if ( have == t )
        {
            return;
        }
    }
    if ( level.ars_types.size < 40 )
    {
        level.ars_types[ level.ars_types.size ] = t;
    }
}

// types the game has spawned this match (its per-type table) plus every living AI's type
function ars_detect_scan( unused )
{
    if ( isdefined( level.var_83048cc59a40c0af ) )
    {
        foreach ( k in getarraykeys( level.var_83048cc59a40c0af ) )
        {
            ars_detect_add( k );
        }
    }
    foreach ( ai in getaiarray() )
    {
        if ( isdefined( ai ) && isdefined( ai.var_ef88add57e25f858 ) )
        {
            ars_detect_add( ai.var_ef88add57e25f858 );
        }
    }
    ars_detect_page();
    self [[ level.zmm_notify_fn ]]( "Type scan", level.ars_types.size > 0 );
}

function ars_detect_spawn( type )
{
    level.ars_bad[ type ] = undefined;
    self [[ level.zmm_notify_fn ]]( "Spawn", isdefined( ars_spawn_one( type, ars_zombie_team(), 250, 450 ) ) );
}

// ---------------------------------------------------------------- allies

// the AI closest to the crosshair within range
function ars_look_ai()
{
    eye = self geteye();
    fwd = anglestoforward( self getplayerangles() );
    best = undefined;
    best_dot = 0.97;
    foreach ( ai in getaiarray() )
    {
        if ( !isalive( ai ) || ars_protected( ai ) || distancesquared( eye, ai.origin ) > 2500 * 2500 )
        {
            continue;
        }
        dot = vectordot( fwd, vectornormalize( ai.origin + ( 0, 0, 40 ) - eye ) );
        if ( dot > best_dot )
        {
            best_dot = dot;
            best = ai;
        }
    }
    return best;
}

function ars_ally( unused )
{
    ai = ars_look_ai();
    if ( !isdefined( ai ) || ( isdefined( self.team ) && ai.team === self.team ) )
    {
        self [[ level.zmm_notify_fn ]]( "Ally", 0 );
        return;
    }
    ai.ars_owner = self;
    ai thread ars_join();
    self [[ level.zmm_notify_fn ]]( "Ally", 1 );
}

// summons the map's special (else a common one) on the player's team, then makes it a guard
function ars_summon( unused )
{
    map = ars_map();
    pool = [];
    if ( map == "zm_sat_scarab" )
    {
        pool[ pool.size ] = "t10_spawner_zombie_triton";
    }
    else if ( map == "zm_sat_ruby" )
    {
        pool[ pool.size ] = "sat_spawner_zombie_uranus_zm";
    }
    pool[ pool.size ] = "zombie_abom";
    pool[ pool.size ] = "zombie_mimic";
    pool[ pool.size ] = "zombie_hellhound";
    team = isdefined( self.team ) ? self.team : "allies";
    foreach ( type in pool )
    {
        ai = ars_spawn_one( type, team, 120, 220 );
        if ( isdefined( ai ) )
        {
            ai.ars_owner = self;
            ai thread ars_join();
            self [[ level.zmm_notify_fn ]]( "Ally", 1 );
            return;
        }
    }
    self [[ level.zmm_notify_fn ]]( "Ally", 0 );
}

// self = AI, self.ars_owner = player: charm when the AI supports it, else force the team for a few frames
function ars_join()
{
    self endon( #"death" );
    if ( !isdefined( self.ars_owner ) || !isdefined( self.ars_owner.team ) )
    {
        return;
    }
    if ( isdefined( self.aisettings ) && istrue( self.aisettings.var_abb7ad1e6db7fa37 ) && istrue( self effect_charm::charm( -2, self.ars_owner, undefined, "toxic", 1 ) ) )
    {
        self.agentteam = self.ars_owner.team;
        ars_guard();
        return;
    }
    for ( self.ars_f = 0; self.ars_f < 15; self.ars_f++ )
    {
        self.team = self.ars_owner.team;
        self.agentteam = self.ars_owner.team;
        waitframe();
    }
    self clearpath();
    self.allowpain = 0;
    if ( isdefined( self.maxhealth ) )
    {
        self.health = self.maxhealth;
    }
    ars_guard();
}

// self = AI: follow and protect the owner
function ars_guard()
{
    if ( !isdefined( self.ars_owner ) )
    {
        return;
    }
    if ( isdefined( self._blackboard ) )
    {
        self._blackboard.var_ea5eb773cb969ee1 = 1;
        self._blackboard.var_1b77d9c7d397d112 = self.ars_owner;
        self._blackboard.var_3144a4e051a50472 = 500;
    }
    self.ignore_enemy_count = 1;
    self setsafeguardent( self.ars_owner );
    self setsafeguardrange( 400 );
    self disableaimassist();
    level notify( #"hash_323ddea58a826636", self.ars_owner.team, [ self ], 1 );
}

// ---------------------------------------------------------------- size and ragdoll

function ars_size_look( scale )
{
    ai = ars_look_ai();
    if ( isdefined( ai ) )
    {
        ai setscale( scale );
    }
    self [[ level.zmm_notify_fn ]]( "Size", isdefined( ai ) );
}

function ars_size_all( scale )
{
    foreach ( ai in ars_zombies() )
    {
        if ( isalive( ai ) && !ars_protected( ai ) )
        {
            ai setscale( scale );
        }
    }
    self [[ level.zmm_notify_fn ]]( "Size", 1 );
}

// 0 looked-at, 1 every zombie
function ars_ragdoll( all )
{
    if ( !all )
    {
        ai = ars_look_ai();
        if ( isdefined( ai ) )
        {
            ars_ragdoll_one( ai );
        }
        self [[ level.zmm_notify_fn ]]( "Ragdoll", isdefined( ai ) );
        return;
    }
    foreach ( ai in ars_zombies() )
    {
        if ( isalive( ai ) && !ars_protected( ai ) )
        {
            ars_ragdoll_one( ai );
        }
    }
    self [[ level.zmm_notify_fn ]]( "Ragdoll", 1 );
}

function ars_ragdoll_one( ai )
{
    ai kill();
    if ( isdefined( ai ) )
    {
        ai startragdoll();
    }
}

// ---------------------------------------------------------------- animations

// %"..." refs must sit in a variable before a call, so they live in level.ars_anims
function ars_add_anim_pages()
{
    level.ars_anims = [];
    level.ars_anims[ 0 ] = %"ai_t10_zm_zombie_emerge_02";
    level.ars_anims[ 1 ] = %"ai_t10_zm_zombie_base_cannonball_v1";
    level.ars_anims[ 2 ] = %"ai_t10_zm_zombie_base_dth_dissolve";
    level.ars_anims[ 3 ] = %"ai_t10_zm_zombie_base_jetgun_walk_v1";
    level.ars_anims[ 4 ] = %"ai_t9_zm_zombie_base_boardtear_aligned_m_1_pull";
    level.ars_anims[ 5 ] = %"ai_t9_zombie_dog_idle_howl";
    level.ars_anims[ 6 ] = %"ai_t9_zombie_dog_dig";
    level.ars_anims[ 7 ] = %"ai_t9_zombie_dog_com_pet_loop";
    level.ars_anims[ 8 ] = %"ai_t9_zombie_dog_stun_loop";
    level.ars_anims[ 9 ] = %"ai_t9_zm_abom_charge_intro";
    level.ars_anims[ 10 ] = %"ai_t9_zm_abom_stun_in";
    level.ars_anims[ 11 ] = %"ai_t10_zm_amalgam_roar_01";
    level.ars_anims[ 12 ] = %"ai_t10_zm_amalgam_throw_01";
    level.ars_anims[ 13 ] = %"ai_sat_zm_orion_charge_lightning_attack";
    level.ars_anims[ 14 ] = %"ai_sat_zm_orion_charge_slam_attack";
    level.ars_anims[ 15 ] = %"ai_sat_zm_karkinos_claw_hammer_charge_intro";
    level.ars_anims[ 16 ] = %"ai_sat_zm_karkinos_knockdown_front";
    level.ars_anims[ 17 ] = %"ai_t10_zm_viper_energy_blast_01";
    level.ars_anims[ 18 ] = %"ai_t10_zm_viper_knockdown_f";
    level.ars_anims[ 19 ] = %"ai_sat_zm_shade_cannonball";
    level.ars_anims[ 20 ] = %"ai_sat_zm_shade_stun_01_loop";
    level.ars_anims[ 21 ] = %"ai_t10_zm_ghoul_spit_center_01";

    [[ level.zmm_add_page ]]( "ArsAnim", "ANIMATIONS (LOOKED-AT)", [
        [ "Zombie", 2, "ArsAnimZ" ],
        [ "Hellhound", 2, "ArsAnimD" ],
        [ "Abomination / Amalgam", 2, "ArsAnimA" ],
        [ "Orion / Karkinos", 2, "ArsAnimO" ],
        [ "Viper / Shade / Ghoul", 2, "ArsAnimV" ],
        [ "Stop animations", 10, "ars_anim_stop", 0 ],
        [ "Back", 1, "" ] ] );
    [[ level.zmm_add_page ]]( "ArsAnimZ", "ZOMBIE", [
        [ "Climb out of the ground", 10, "ars_anim", 0 ],
        [ "Cannonball", 10, "ars_anim", 1 ],
        [ "Dissolve", 10, "ars_anim", 2 ],
        [ "Fight the wind", 10, "ars_anim", 3 ],
        [ "Tear a board", 10, "ars_anim", 4 ],
        [ "Back", 1, "" ] ] );
    [[ level.zmm_add_page ]]( "ArsAnimD", "HELLHOUND", [
        [ "Howl", 10, "ars_anim", 5 ],
        [ "Dig", 10, "ars_anim", 6 ],
        [ "Wants pets", 10, "ars_anim", 7 ],
        [ "Dazed", 10, "ars_anim", 8 ],
        [ "Back", 1, "" ] ] );
    [[ level.zmm_add_page ]]( "ArsAnimA", "ABOMINATION / AMALGAM", [
        [ "Abomination charge", 10, "ars_anim", 9 ],
        [ "Abomination stunned", 10, "ars_anim", 10 ],
        [ "Amalgam roar", 10, "ars_anim", 11 ],
        [ "Amalgam throw", 10, "ars_anim", 12 ],
        [ "Back", 1, "" ] ] );
    [[ level.zmm_add_page ]]( "ArsAnimO", "ORION / KARKINOS", [
        [ "Orion lightning", 10, "ars_anim", 13 ],
        [ "Orion slam", 10, "ars_anim", 14 ],
        [ "Karkinos claw charge", 10, "ars_anim", 15 ],
        [ "Karkinos knocked down", 10, "ars_anim", 16 ],
        [ "Back", 1, "" ] ] );
    [[ level.zmm_add_page ]]( "ArsAnimV", "VIPER / SHADE / GHOUL", [
        [ "Viper blast", 10, "ars_anim", 17 ],
        [ "Viper knocked down", 10, "ars_anim", 18 ],
        [ "Shade cannonball", 10, "ars_anim", 19 ],
        [ "Shade dazed", 10, "ars_anim", 20 ],
        [ "Ghoul spit", 10, "ars_anim", 21 ],
        [ "Back", 1, "" ] ] );
}

function ars_anim( i )
{
    ai = ars_look_ai();
    if ( !isdefined( ai ) )
    {
        self [[ level.zmm_notify_fn ]]( "Animation", 0 );
        return;
    }
    ai.ars_aref = level.ars_anims[ i ];
    ai thread ars_anim_run();
    self [[ level.zmm_notify_fn ]]( "Animation", 1 );
}

// self = AI: play once, hand control back after a few seconds (a wrong creature's anim just does nothing)
function ars_anim_run()
{
    self endon( #"death" );
    self notify( #"ars_anim" );
    self endon( #"ars_anim" );
    self.ars_anim_on = 1;
    self function_f6b4d1849d98c555( "ars_anim", self.origin, self.angles, self.ars_aref );
    wait 6;
    self function_1492235b4eb6e229();
    self.ars_anim_on = 0;
}

function ars_anim_stop( unused )
{
    foreach ( ai in getaiarray() )
    {
        if ( isalive( ai ) && istrue( ai.ars_anim_on ) )
        {
            ai notify( #"ars_anim" );
            ai function_1492235b4eb6e229();
            ai.ars_anim_on = 0;
        }
    }
    self [[ level.zmm_notify_fn ]]( "Animation", 1 );
}
