// FuzMenu extension: XGame (match rules, game modes) and XFun (chaos, power-ups, zombie toys, vehicles, kill effects)
#using scripts\common\utility;
#using scripts\common\callbacks;
#using scripts\common\vehicle;
#using scripts\common\weapon;
#using scripts\mp\zm\systems\agent_manager;
// ai move speed stack (walk/run/sprint by priority), public game script (same as zm_mod_menu)
#using script_6c2f6a14fa53759e;
// zone manager (spawn zones), public game script (same as zm_mod_menu)
#using script_7b92812967b04687;
// lastStand: revive, public game script (same as zm_mod_menu)
#using script_8c8e132af264960;

#namespace zm_mod_menu_fun;

autoexec fun_init()
{
    if ( !utility::iszm() )
    {
        return;
    }
    level thread fun_wait_menu();
}

function fun_wait_menu()
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
    level.fun_rule = [];
    level.fun_on = [];
    level.fun_mode = "";
    level.fun_vehs = [];
    level.fun_gun_pages = [ "W_ar", "W_sm", "W_lm", "W_sh", "W_dm", "W_sn", "W_pi" ];
    // a W6_ (BO6) page joins the class of the BO7 page before it
    level.fun_ladder_pages = [ "W_pi", "W6_pi", "W_sm", "W6_sm", "W_sh", "W6_sh", "W_ar", "W6_ar", "W_lm", "W6_lm", "W_dm", "W6_dm", "W_sn", "W6_sn", "W_la", "W6_la" ];
    level.fun_pu_names = [ "double_points", "insta_kill", "full_ammo", "full_armor", "full_power", "free_perk", "fire_sale", "bonus_points_team" ];
    level.fun_rush_types = [ "zombie_abom", "zombie_amalgam", "zombie_mimic", "zombie_karkinos", "zombie_orion", "zombie_loom", "zombie_hellhound" ];
    level.fun_groups = [];
    level.fun_groups[ "hs" ] = [ "hs", "melee" ];
    level.fun_groups[ "melee" ] = level.fun_groups[ "hs" ];
    level.fun_groups[ "t2" ] = [ "t2", "t5", "t10" ];
    level.fun_groups[ "t5" ] = level.fun_groups[ "t2" ];
    level.fun_groups[ "t10" ] = level.fun_groups[ "t2" ];
    level.fun_groups[ "rest10" ] = [ "rest10", "rest30" ];
    level.fun_groups[ "rest30" ] = level.fun_groups[ "rest10" ];
    level.fun_groups[ "spr20" ] = [ "spr20", "spr40" ];
    level.fun_groups[ "spr40" ] = level.fun_groups[ "spr20" ];
    fun_tables();
    fun_vehicle_refs();

    level.zmm_ext[ "fun_rule" ] = &fun_rule;
    level.zmm_ext_on[ "fun_rule" ] = &fun_rule_on;
    level.zmm_ext[ "fun_mode" ] = &fun_mode;
    level.zmm_ext_on[ "fun_mode" ] = &fun_mode_on;
    level.zmm_ext[ "fun_chaos" ] = &fun_chaos;
    level.zmm_ext[ "fun_tog" ] = &fun_tog;
    level.zmm_ext_on[ "fun_tog" ] = &fun_tog_on;
    level.zmm_ext[ "fun_veh" ] = &fun_veh;

    fun_pages();
    level callback::add( #"hash_652eb614ba902b3d", &fun_player_hurt );
    level callback::add( "on_zombie_ai_damaged", &fun_zombie_hurt );
    level callback::add( "on_zombie_ai_killed", &fun_zombie_dead );
    level callback::add( #"player_spawned", &fun_mode_respawn );
    level thread fun_round_watch();
    level thread fun_zone_keep();
}

function fun_pages()
{
    [[ level.zmm_add_page ]]( "XGame", "GAME MODES & RULES", [
        [ "Match rules", 2, "XGameRules" ],
        [ "Game modes", 2, "XGameModes" ],
        [ "Old School Zombies", 2, "OldSchool" ],
        [ "Back", 1, "" ] ] );
    [[ level.zmm_add_page ]]( "XGameRules", "MATCH RULES", [
        [ "Headshots only", 11, "fun_rule", "hs" ],
        [ "Melee only", 11, "fun_rule", "melee" ],
        [ "Tough zombies x2", 11, "fun_rule", "t2" ],
        [ "Tough zombies x5", 11, "fun_rule", "t5" ],
        [ "Tough zombies x10", 11, "fun_rule", "t10" ],
        [ "Random weapon every round", 11, "fun_rule", "rgun" ],
        [ "Heal + revive at round end", 11, "fun_rule", "heal" ],
        [ "Rest break 10 s", 11, "fun_rule", "rest10" ],
        [ "Rest break 30 s", 11, "fun_rule", "rest30" ],
        [ "Super sprinters from round 20", 11, "fun_rule", "spr20" ],
        [ "Super sprinters from round 40", 11, "fun_rule", "spr40" ],
        [ "All rules off", 10, "fun_rule", "off" ],
        [ "Back", 1, "" ] ] );
    [[ level.zmm_add_page ]]( "XGameModes", "GAME MODES", [
        [ "Gun Game", 11, "fun_mode", "gg" ],
        [ "One in the Chamber", 11, "fun_mode", "oitc" ],
        [ "Sharpshooter (new gun every 30 s)", 11, "fun_mode", "sharp" ],
        [ "One-gun roulette", 11, "fun_mode", "roul" ],
        [ "Boss Rush", 11, "fun_mode", "rush" ],
        [ "Zone rotation (every 2 rounds)", 11, "fun_mode", "zone2" ],
        [ "Zone rotation (every 4 rounds)", 11, "fun_mode", "zone4" ],
        [ "Mode off", 10, "fun_mode", "off" ],
        [ "Back", 1, "" ] ] );
    [[ level.zmm_add_page ]]( "XFun", "FUN & CHAOS", [
        [ "Chaos effects", 2, "XFunChaos" ],
        [ "Zombie toys", 2, "XFunToys" ],
        [ "Vehicles", 2, "XFunVeh" ],
        [ "Kill effects", 2, "XFunKill" ],
        [ "Shot effects", 2, "ArsShots" ],
        [ "Back", 1, "" ] ] );
    [[ level.zmm_add_page ]]( "XFunChaos", "CHAOS EFFECTS", [
        [ "Black hole", 10, "fun_chaos", "hole" ],
        [ "Tornado", 10, "fun_chaos", "tornado" ],
        [ "Conga line", 10, "fun_chaos", "conga" ],
        [ "Frost nova", 10, "fun_chaos", "frost" ],
        [ "Meteor shower", 10, "fun_chaos", "meteor" ],
        [ "Lightning storm", 10, "fun_chaos", "storm" ],
        [ "Magnet", 10, "fun_chaos", "magnet" ],
        [ "Fireworks", 10, "fun_chaos", "fireworks" ],
        [ "Thanos snap", 10, "fun_chaos", "snap" ],
        [ "Ground pound", 10, "fun_chaos", "pound" ],
        [ "Earthquake", 10, "fun_chaos", "quake" ],
        [ "Explosive punch", 11, "fun_tog", "xpunch" ],
        [ "Bullet time", 11, "fun_tog", "btime" ],
        [ "Back", 1, "" ] ] );
    [[ level.zmm_add_page ]]( "XFunToys", "ZOMBIE TOYS", [
        [ "Grab / throw zombie", 10, "fun_chaos", "grab" ],
        [ "Zombies orbit me", 11, "fun_tog", "orbit" ],
        [ "Float zombies up", 10, "fun_chaos", "float" ],
        [ "Make looked-at an ally", 10, "ars_ally", 0 ],
        [ "Summon an ally", 10, "ars_summon", 0 ],
        [ "Size", 2, "ArsSize" ],
        [ "Ragdoll looked-at", 10, "ars_ragdoll", 0 ],
        [ "Ragdoll all", 10, "ars_ragdoll", 1 ],
        [ "Animations", 2, "ArsAnim" ],
        [ "Back", 1, "" ] ] );
    [[ level.zmm_add_page ]]( "XFunVeh", "VEHICLES", [
        [ "Blood Burner bike", 10, "fun_veh", 0 ],
        [ "Transport heli", 10, "fun_veh", 1 ],
        [ "Remove vehicles", 10, "fun_veh", 2 ],
        [ "Back", 1, "" ] ] );
    [[ level.zmm_add_page ]]( "XFunKill", "KILL EFFECTS", [
        [ "Chain-reaction kills", 11, "fun_tog", "chain" ],
        [ "Auto nuke every 15 s", 11, "fun_tog", "nuke" ],
        [ "Pinata kills", 11, "fun_tog", "pinata" ],
        [ "Back", 1, "" ] ] );
}

// function tables instead of long else-if chains
function fun_tables()
{
    level.fun_mode_fn = [];
    level.fun_mode_fn[ "gg" ] = &fun_gg_start;
    level.fun_mode_fn[ "oitc" ] = &fun_oitc_start;
    level.fun_mode_fn[ "sharp" ] = &fun_sharp_start;
    level.fun_mode_fn[ "roul" ] = &fun_roul_start;
    level.fun_mode_fn[ "rush" ] = &fun_rush_start;
    level.fun_mode_fn[ "zone2" ] = &fun_zone_start;
    level.fun_mode_fn[ "zone4" ] = &fun_zone_start;

    level.fun_chaos_fn = [];
    level.fun_chaos_fn[ "hole" ] = &fun_black_hole;
    level.fun_chaos_fn[ "tornado" ] = &fun_tornado;
    level.fun_chaos_fn[ "conga" ] = &fun_conga;
    level.fun_chaos_fn[ "frost" ] = &fun_frost;
    level.fun_chaos_fn[ "meteor" ] = &fun_meteor;
    level.fun_chaos_fn[ "storm" ] = &fun_storm;
    level.fun_chaos_fn[ "magnet" ] = &fun_magnet;
    level.fun_chaos_fn[ "fireworks" ] = &fun_fireworks;
    level.fun_chaos_fn[ "snap" ] = &fun_snap;
    level.fun_chaos_fn[ "pound" ] = &fun_pound;
    level.fun_chaos_fn[ "quake" ] = &fun_quake;
    level.fun_chaos_fn[ "rain" ] = &fun_pu_rain;
    level.fun_chaos_fn[ "circle" ] = &fun_pu_circle;
    level.fun_chaos_fn[ "grab" ] = &fun_grab;
    level.fun_chaos_fn[ "float" ] = &fun_float;

}

// ---------------------------------------------------------------- shared helpers

function fun_round()
{
    if ( isdefined( level.zmm_round_fn ) )
    {
        return [[ level.zmm_round_fn ]]();
    }
    return isdefined( level.round_number ) ? level.round_number : 1;
}

function fun_say_all( text )
{
    foreach ( p in level.players )
    {
        if ( isdefined( p ) )
        {
            p iprintlnbold( text );
        }
    }
}

function fun_zombies()
{
    return getaiarray( isdefined( level.zombie_team ) ? level.zombie_team : "team_two_hundred" );
}

// alive zombies within r of pos
function fun_near( pos, r )
{
    level.fun_near_out = [];
    foreach ( ai in fun_zombies() )
    {
        if ( isdefined( ai ) && isalive( ai ) && distance( ai.origin, pos ) <= r )
        {
            level.fun_near_out[ level.fun_near_out.size ] = ai;
        }
    }
    return level.fun_near_out;
}

function fun_ragdoll( ai )
{
    if ( !isdefined( ai ) || !isalive( ai ) )
    {
        return;
    }
    ai.no_powerups = 1;
    ai kill();
    if ( isdefined( ai ) )
    {
        ai startragdoll();
    }
}

function fun_fx( name )
{
    if ( isdefined( level.var_d1e5f36ab9f106 ) && isdefined( level.var_d1e5f36ab9f106[ name ] ) )
    {
        return level.var_d1e5f36ab9f106[ name ];
    }
    if ( isdefined( level.var_3acf9fbc9cf0f7b5 ) && isdefined( level.var_3acf9fbc9cf0f7b5[ name ] ) )
    {
        return level.var_3acf9fbc9cf0f7b5[ name ];
    }
    if ( isdefined( level.var_7e2f6e5a16d8b454 ) && isdefined( level.var_7e2f6e5a16d8b454[ name ] ) )
    {
        return level.var_7e2f6e5a16d8b454[ name ];
    }
    if ( isdefined( level.var_788f1aed54176507 ) && isdefined( level.var_788f1aed54176507[ name ] ) )
    {
        return level.var_788f1aed54176507[ name ];
    }
    if ( isdefined( level.var_86a604cd1383c9e8 ) && isdefined( level.var_86a604cd1383c9e8[ name ] ) )
    {
        return level.var_86a604cd1383c9e8[ name ];
    }
    return undefined;
}

function fun_fx_at( name, pos )
{
    level.fun_fx_h = fun_fx( name );
    if ( isdefined( level.fun_fx_h ) )
    {
        playfx( level.fun_fx_h, pos );
    }
}

// a deletable looping effect (undefined when the effect is not loaded on this map)
function fun_fx_ent( name, pos )
{
    level.fun_fx_h = fun_fx( name );
    if ( !isdefined( level.fun_fx_h ) )
    {
        return undefined;
    }
    level.fun_fx_e = spawnfx( level.fun_fx_h, pos );
    triggerfx( level.fun_fx_e );
    return level.fun_fx_e;
}

function fun_sound_at( alias, pos )
{
    level.fun_snd_e = spawn( "script_origin", pos );
    level.fun_snd_e playsound( alias );
    level.fun_snd_e thread fun_delete_after( 4 );
}

// self = any entity
function fun_delete_after( t )
{
    wait t;
    if ( isdefined( self ) )
    {
        self delete();
    }
}

// where the player looks, up to dist
function fun_aim_point( dist )
{
    self.zmm.fun_eye = self geteye();
    self.zmm.fun_fwd = anglestoforward( self getplayerangles() );
    return physicstrace( self.zmm.fun_eye, self.zmm.fun_eye + self.zmm.fun_fwd * dist );
}

// the zombie closest to the crosshair (inside a narrow cone) within dist
function fun_aim_zombie( dist )
{
    self.zmm.fun_eye = self geteye();
    self.zmm.fun_fwd = anglestoforward( self getplayerangles() );
    self.zmm.fun_pick = undefined;
    self.zmm.fun_best = 0.94;
    foreach ( ai in fun_near( self.origin, dist ) )
    {
        level.fun_dot = vectordot( self.zmm.fun_fwd, vectornormalize( ai.origin + ( 0, 0, 40 ) - self.zmm.fun_eye ) );
        if ( level.fun_dot > self.zmm.fun_best && !istrue( ai.fun_moving ) )
        {
            self.zmm.fun_best = level.fun_dot;
            self.zmm.fun_pick = ai;
        }
    }
    return self.zmm.fun_pick;
}

// zombie on a mover: moves it to dest in t seconds, then kills it (die) or lets it walk again
function fun_fling( ai, dest, t, die, spin )
{
    if ( !isdefined( ai ) || !isalive( ai ) || istrue( ai.fun_moving ) )
    {
        return;
    }
    ai.fun_moving = 1;
    level.fun_mv = spawn( "script_origin", ai.origin );
    level.fun_mv.fun_ai = ai;
    level.fun_mv.fun_t = t;
    level.fun_mv.fun_die = die;
    level.fun_mv.fun_spin = spin;
    ai linkto( level.fun_mv );
    level.fun_mv moveto( dest, t, t * 0.4, 0 );
    level.fun_mv thread fun_fling_end();
}

// self = mover (its thread survives the zombie being removed)
function fun_fling_end()
{
    if ( istrue( self.fun_spin ) )
    {
        self rotateyaw( 900, self.fun_t );
    }
    wait self.fun_t;
    fun_release( self, self.fun_die );
}

// keeps a zombie on a mover until fun_release
function fun_hold( ai )
{
    if ( !isdefined( ai ) || !isalive( ai ) || istrue( ai.fun_moving ) )
    {
        return undefined;
    }
    ai.fun_moving = 1;
    level.fun_hm = spawn( "script_origin", ai.origin );
    level.fun_hm.fun_ai = ai;
    ai linkto( level.fun_hm );
    return level.fun_hm;
}

function fun_release( mover, die )
{
    if ( !isdefined( mover ) )
    {
        return;
    }
    if ( isdefined( mover.fun_ai ) )
    {
        mover.fun_ai unlink();
        mover.fun_ai.fun_moving = 0;
        if ( istrue( die ) )
        {
            fun_ragdoll( mover.fun_ai );
        }
    }
    mover delete();
}

// self = mover
function fun_release_after( t, die )
{
    wait t;
    fun_release( self, die );
}

// kills zombies around pos, thrown outward
function fun_blast( pos, r, fx_name, lift )
{
    fun_fx_at( fx_name, pos );
    foreach ( ai in fun_near( pos, r ) )
    {
        level.fun_out = vectornormalize( ( ai.origin[ 0 ] - pos[ 0 ], ai.origin[ 1 ] - pos[ 1 ], 0 ) + ( 0.01, 0, 0 ) );
        fun_fling( ai, ai.origin + level.fun_out * 260 + ( 0, 0, lift ), 0.45, 1, 0 );
    }
}

function fun_drop( name, pos )
{
    if ( !utility::issharedfuncdefined( #"powerups", #"dropPowerup" ) || !utility::issharedfuncdefined( #"powerups", #"hash_a25fdc7ee24539fb" ) )
    {
        return 0;
    }
    level.fun_pu_root = utility::callsharedfunc( #"powerups", #"hash_a25fdc7ee24539fb" );
    if ( !isdefined( level.fun_pu_root ) || !isdefined( level.fun_pu_root.powerups ) || !isdefined( level.fun_pu_root.powerups[ name ] ) )
    {
        return 0;
    }
    level thread fun_do_drop( name, pos );
    return 1;
}

function fun_do_drop( name, pos )
{
    utility::callsharedfunc( #"powerups", #"dropPowerup", name, pos, undefined, undefined, undefined, 0 );
}

function fun_spawn_ai( type, pos )
{
    level.fun_sp_pt = getclosestpointonnavmesh( pos );
    if ( !isdefined( level.fun_sp_pt ) )
    {
        return undefined;
    }
    return agent_manager::spawn_agent( type, level.fun_sp_pt, ( 0, randomint( 360 ), 0 ), isdefined( level.zombie_team ) ? level.zombie_team : "team_two_hundred" );
}

function fun_points()
{
    if ( !utility::issharedfuncdefined( #"points", #"get_points" ) )
    {
        return undefined;
    }
    return self utility::callsharedfunc( #"points", #"get_points" );
}

function fun_set_points( n )
{
    if ( utility::issharedfuncdefined( #"points", #"set_points" ) )
    {
        self utility::callsharedfunc( #"points", #"set_points", int( max( n, 0 ) ) );
    }
}

// ---------------------------------------------------------------- guns (names from the main menu's weapon pages)

function fun_gun_from_entry( entry )
{
    level.fun_gn = entry[ 2 ];
    if ( issubstr( level.fun_gn, "_mp" ) && !issubstr( level.fun_gn, "_mpug" ) )
    {
        level.fun_gn = removesubstr( level.fun_gn, "_mp" );
    }
    return level.fun_gn;
}

function fun_random_gun_from( pages )
{
    level.fun_pool = [];
    if ( !isdefined( level.zmm_pages ) )
    {
        return undefined;
    }
    foreach ( page_id in pages )
    {
        if ( !isdefined( level.zmm_pages[ page_id ] ) )
        {
            continue;
        }
        foreach ( entry in level.zmm_pages[ page_id ].items )
        {
            if ( entry[ 1 ] == 8 )
            {
                level.fun_pool[ level.fun_pool.size ] = entry;
            }
        }
    }
    if ( level.fun_pool.size == 0 )
    {
        return undefined;
    }
    return fun_gun_from_entry( level.fun_pool[ randomint( level.fun_pool.size ) ] );
}

// gives a gun in place of the held one; state in self.zmm fields (locals in BO7 give paths read back undefined)
function fun_give_gun( name )
{
    self endon( #"disconnect" );
    if ( !isdefined( name ) || !isdefined( self.zmm ) )
    {
        return;
    }
    self.zmm.fun_gname = name;
    if ( !( isdefined( level.weaponmapdata ) && isdefined( level.weaponmapdata[ self.zmm.fun_gname ] ) ) && !weaponexists( self.zmm.fun_gname ) )
    {
        return;
    }
    self.zmm.fun_wnew = weapon::buildweapon( self.zmm.fun_gname, getweapondefaultattachments( self.zmm.fun_gname ) );
    if ( !isdefined( self.zmm.fun_wnew ) || isnullweapon( self.zmm.fun_wnew ) )
    {
        return;
    }
    self loadweaponsforplayer( [ self.zmm.fun_wnew ], 1 );
    for ( self.zmm.fun_wi = 0; self.zmm.fun_wi < 50; self.zmm.fun_wi++ )
    {
        if ( self hasloadedviewweapons( [ self.zmm.fun_wnew ] ) )
        {
            break;
        }
        wait 0.1;
    }
    // a BO6 gun whose model never loads would be given empty
    if ( issubstr( self.zmm.fun_gname, "t10_" ) && !self hasloadedviewweapons( [ self.zmm.fun_wnew ] ) )
    {
        return;
    }
    self.zmm.fun_wold = self getcurrentweapon();
    if ( isdefined( self.zmm.fun_wold ) && !isnullweapon( self.zmm.fun_wold ) && !self hasweapon( self.zmm.fun_wnew ) && isdefined( self.zmm.fun_wold.basename ) && !issubstr( self.zmm.fun_wold.basename, "_me_" ) )
    {
        self takeweapon( self.zmm.fun_wold );
        wait 0.1;
    }
    if ( !self hasweapon( self.zmm.fun_wnew ) )
    {
        self giveweapon( self.zmm.fun_wnew, undefined, 0, -1, 0 );
        self assignweaponprimaryslot( self.zmm.fun_wnew );
    }
    self givemaxammo( self.zmm.fun_wnew );
    self switchtoweapon( self.zmm.fun_wnew );
    self.zmm.fun_w = self.zmm.fun_wnew;
}

function fun_give_random()
{
    self fun_give_gun( fun_random_gun_from( level.fun_gun_pages ) );
}

// ---------------------------------------------------------------- match rules

function fun_rule( key )
{
    if ( key == "off" )
    {
        level.fun_rule = [];
        fun_sprint_clear();
        self [[ level.zmm_notify_fn ]]( "All rules off", 1 );
        return;
    }
    level.fun_rule[ key ] = !istrue( level.fun_rule[ key ] );
    if ( istrue( level.fun_rule[ key ] ) && isdefined( level.fun_groups[ key ] ) )
    {
        foreach ( other in level.fun_groups[ key ] )
        {
            if ( !( other == key ) )
            {
                level.fun_rule[ other ] = 0;
            }
        }
    }
    if ( !istrue( level.fun_rule[ "spr20" ] ) && !istrue( level.fun_rule[ "spr40" ] ) )
    {
        fun_sprint_clear();
    }
}

function fun_rule_on( key )
{
    return istrue( level.fun_rule[ key ] );
}

function fun_tough_div()
{
    if ( istrue( level.fun_rule[ "t10" ] ) )
    {
        return 10;
    }
    if ( istrue( level.fun_rule[ "t5" ] ) )
    {
        return 5;
    }
    if ( istrue( level.fun_rule[ "t2" ] ) )
    {
        return 2;
    }
    return 1;
}

function fun_sprint_from()
{
    if ( istrue( level.fun_rule[ "spr20" ] ) )
    {
        return 20;
    }
    if ( istrue( level.fun_rule[ "spr40" ] ) )
    {
        return 40;
    }
    return 0;
}

function fun_sprint_clear()
{
    foreach ( ai in fun_zombies() )
    {
        if ( isdefined( ai ) && isalive( ai ) && istrue( ai.fun_spr ) )
        {
            ai.fun_spr = 0;
            ai namespace_56fb43fc0b6ee43e::function_a8ce00e0448cb6f0( undefined, "fun_rules" );
        }
    }
}

function fun_round_watch()
{
    level.fun_round_seen = fun_round();
    for ( ;; )
    {
        wait 0.5;
        if ( !( fun_round() == level.fun_round_seen ) )
        {
            level.fun_round_seen = fun_round();
            level thread fun_new_round();
        }
        if ( fun_sprint_from() > 0 && fun_round() >= fun_sprint_from() )
        {
            foreach ( ai in fun_zombies() )
            {
                if ( isdefined( ai ) && isalive( ai ) && !istrue( ai.fun_spr ) )
                {
                    ai.fun_spr = 1;
                    ai namespace_56fb43fc0b6ee43e::function_a8ce00e0448cb6f0( "sprint", "fun_rules", 100 );
                }
            }
        }
    }
}

function fun_new_round()
{
    if ( istrue( level.fun_rule[ "heal" ] ) )
    {
        foreach ( p in level.players )
        {
            if ( !isdefined( p ) )
            {
                continue;
            }
            if ( istrue( p.inlaststand ) )
            {
                p thread namespace_b80f99000c537b86::exit( "last_stand_revived", p );
            }
            else if ( isalive( p ) && isdefined( p.maxhealth ) )
            {
                p.health = p.maxhealth;
            }
        }
    }
    if ( istrue( level.fun_rule[ "rgun" ] ) )
    {
        foreach ( p in level.players )
        {
            if ( isdefined( p ) && isalive( p ) )
            {
                p thread fun_give_random();
            }
        }
    }
    if ( istrue( level.fun_rule[ "rest10" ] ) )
    {
        level thread fun_rest_break( 10 );
    }
    else if ( istrue( level.fun_rule[ "rest30" ] ) )
    {
        level thread fun_rest_break( 30 );
    }
    if ( level.fun_mode == "rush" )
    {
        level thread fun_rush_wave();
    }
    if ( issubstr( level.fun_mode, "zone" ) && ( fun_round() - level.fun_zone_r0 ) % level.fun_zone_every == 0 )
    {
        level thread fun_zone_shift();
    }
}

// shortcut: zombies that spawn during the break are cleaned up (b_cleaned_up, the game respawns them later), the round timer is not paused
function fun_rest_break( secs )
{
    level notify( #"fun_rest" );
    level endon( #"fun_rest" );
    fun_say_all( "^3Rest break" );
    level.fun_rest_end = gettime() + secs * 1000;
    while ( gettime() < level.fun_rest_end )
    {
        foreach ( ai in fun_zombies() )
        {
            if ( isdefined( ai ) && isalive( ai ) )
            {
                ai.no_powerups = 1;
                ai.b_cleaned_up = 1;
                ai kill();
            }
        }
        wait 0.5;
    }
    fun_say_all( "^1Break over" );
}

// ---------------------------------------------------------------- damage / kill callbacks

// self = player
function fun_player_hurt( params )
{
    if ( !isdefined( self ) || !isdefined( self.zmm ) || !isdefined( params ) || !isdefined( params.var_a87b62c261a8d114 ) )
    {
        return;
    }
    if ( params.var_f5a880abf0b199dc === "MOD_FALLING" && isdefined( self.zmm.fun_pound_end ) && gettime() < self.zmm.fun_pound_end )
    {
        params.var_a87b62c261a8d114 = 0;
    }
    if ( self.zmm.fun_glass === fun_round() && params.var_a87b62c261a8d114 > 0 )
    {
        params.var_a87b62c261a8d114 = int( params.var_a87b62c261a8d114 * 2 );
    }
}

// self = zombie
function fun_zombie_hurt( params )
{
    if ( !isdefined( params ) || !isdefined( params.var_a87b62c261a8d114 ) || !isplayer( params.var_917e21c98d80255e ) )
    {
        return;
    }
    level.fun_dmg_mod = params.var_f5a880abf0b199dc;
    level.fun_dmg_melee = level.fun_dmg_mod === "MOD_MELEE" || level.fun_dmg_mod === "MOD_MELEE_TAKEDOWN" || level.fun_dmg_mod === "MOD_EXECUTION";
    level.fun_dmg_head = level.fun_dmg_mod === "MOD_HEAD_SHOT" || params.var_181dac8470cfcf7e === "head" || params.var_181dac8470cfcf7e === "helmet";
    if ( istrue( level.fun_rule[ "hs" ] ) && !level.fun_dmg_head )
    {
        params.var_a87b62c261a8d114 = 0;
        return;
    }
    if ( istrue( level.fun_rule[ "melee" ] ) && !level.fun_dmg_melee )
    {
        params.var_a87b62c261a8d114 = 0;
        return;
    }
    if ( level.fun_mode == "oitc" && ( level.fun_dmg_head || level.fun_dmg_mod === "MOD_PISTOL_BULLET" || level.fun_dmg_mod === "MOD_RIFLE_BULLET" ) )
    {
        params.var_a87b62c261a8d114 = 2000000000;
        return;
    }
    if ( fun_tough_div() > 1 && params.var_a87b62c261a8d114 > 0 )
    {
        params.var_a87b62c261a8d114 = int( max( 1, params.var_a87b62c261a8d114 / fun_tough_div() ) );
    }
    if ( istrue( level.fun_on[ "xpunch" ] ) && level.fun_dmg_melee && isdefined( self ) )
    {
        params.var_a87b62c261a8d114 = 2000000000;
        level thread fun_punch_boom( self.origin );
    }
}

function fun_punch_boom( pos )
{
    waitframe();
    fun_sound_at( "prj_ammomod_shatterblast_proc_explode", pos );
    earthquake( 0.35, 0.5, pos, 500 );
    fun_blast( pos, 230, "perk_phd_explode_lg", 160 );
}

// self = the dead zombie
function fun_zombie_dead( params )
{
    if ( !isdefined( params ) || !isdefined( self ) )
    {
        return;
    }
    level.fun_killer = params.var_917e21c98d80255e;
    if ( isplayer( level.fun_killer ) && isdefined( level.fun_killer.zmm ) )
    {
        // melee kills do not count: the ladder is guns only
        if ( level.fun_mode == "gg" )
        {
            if ( !( params.var_f5a880abf0b199dc === "MOD_MELEE" ) && !( isdefined( params.var_b575eda3d8d8533b ) && isdefined( params.var_b575eda3d8d8533b.basename ) && issubstr( params.var_b575eda3d8d8533b.basename, "_me_" ) ) )
            {
                level.fun_killer fun_gg_kill();
            }
        }
        else if ( level.fun_mode == "oitc" && isdefined( level.fun_killer.zmm.fun_w ) )
        {
            level.fun_killer setweaponammoclip( level.fun_killer.zmm.fun_w, level.fun_killer getweaponammoclip( level.fun_killer.zmm.fun_w ) + 1 );
        }
    }
    if ( istrue( level.fun_on[ "pinata" ] ) && isplayer( level.fun_killer ) && ( !isdefined( level.fun_pinata_next ) || gettime() > level.fun_pinata_next ) )
    {
        level.fun_pinata_next = gettime() + 600;
        fun_drop( level.fun_pu_names[ randomint( level.fun_pu_names.size ) ], self.origin + ( 0, 0, 40 ) );
    }
    if ( istrue( level.fun_on[ "chain" ] ) && ( isplayer( level.fun_killer ) || isdefined( self.fun_chain ) ) )
    {
        level.fun_chain_d = isdefined( self.fun_chain ) ? self.fun_chain + 1 : 1;
        if ( level.fun_chain_d <= 3 )
        {
            level thread fun_chain_blast( self.origin, level.fun_chain_d );
        }
    }
}

function fun_chain_blast( pos, depth )
{
    wait 0.25;
    fun_fx_at( "energy_mine_explosion3", pos );
    fun_sound_at( "prj_ammomod_shatterblast_proc_explode", pos );
    level.fun_chain_n = 0;
    foreach ( ai in fun_near( pos, 190 ) )
    {
        if ( level.fun_chain_n >= 4 )
        {
            break;
        }
        level.fun_chain_n++;
        ai.fun_chain = depth;
        ai.no_powerups = 1;
        ai kill();
    }
}

// ---------------------------------------------------------------- game modes

function fun_mode( key )
{
    if ( key == "off" || level.fun_mode == key )
    {
        fun_mode_stop();
        if ( key == "off" )
        {
            self [[ level.zmm_notify_fn ]]( "Mode off", 1 );
        }
        return;
    }
    fun_mode_stop();
    level.fun_mode = key;
    level thread [[ level.fun_mode_fn[ key ] ]]( key );
}

function fun_mode_on( key )
{
    return level.fun_mode == key;
}

function fun_mode_stop()
{
    level notify( #"fun_mode_end" );
    level.fun_mode = "";
    level.fun_zone_c = undefined;
    setdvar( @"zmm_gg", "" );
}

// a player who spawns in late or comes back after a bleed-out gets the mode's gun too
function fun_mode_respawn( params )
{
    if ( isdefined( self ) && isplayer( self ) )
    {
        self thread fun_mode_rearm();
    }
}

// waits for the spawn loadout first, or it would replace the mode's gun
function fun_mode_rearm()
{
    self endon( #"disconnect" );
    wait 1;
    if ( !isdefined( self.zmm ) || !isdefined( level.fun_mode ) || !isalive( self ) )
    {
        return;
    }
    if ( level.fun_mode == "gg" && isdefined( level.fun_ladder ) && level.fun_ladder.size > 0 )
    {
        if ( !isdefined( self.zmm.fun_gg_lvl ) || self.zmm.fun_gg_lvl >= level.fun_ladder.size )
        {
            self.zmm.fun_gg_lvl = 0;
            self.zmm.fun_gg_kills = 0;
        }
        self thread fun_gg_give( level.fun_ladder[ self.zmm.fun_gg_lvl ] );
        self fun_gg_hud();
    }
    else if ( level.fun_mode == "oitc" )
    {
        self thread fun_oitc_arm();
    }
    else if ( level.fun_mode == "roul" )
    {
        self thread fun_roul_loop();
    }
    else if ( level.fun_mode == "sharp" && isdefined( level.fun_sharp_gun ) )
    {
        self thread fun_give_gun( level.fun_sharp_gun );
    }
}

function fun_mode_players()
{
    level.fun_mp = [];
    foreach ( p in level.players )
    {
        if ( isdefined( p ) && isdefined( p.zmm ) && isalive( p ) )
        {
            level.fun_mp[ level.fun_mp.size ] = p;
        }
    }
    return level.fun_mp;
}

// Gun Game: every gun of the weapon pages, class by class from pistols to launchers (shuffled inside a class); 3 kills to go up
function fun_gg_start( key )
{
    level.fun_ladder = [];
    if ( isdefined( level.zmm_pages ) )
    {
        foreach ( page_id in level.fun_ladder_pages )
        {
            if ( !isdefined( level.zmm_pages[ page_id ] ) )
            {
                continue;
            }
            if ( getsubstr( page_id, 0, 3 ) != "W6_" )
            {
                level.fun_lg_start = level.fun_ladder.size;
            }
            foreach ( entry in level.zmm_pages[ page_id ].items )
            {
                if ( entry[ 1 ] == 8 )
                {
                    level.fun_ladder[ level.fun_ladder.size ] = fun_gun_from_entry( entry );
                }
            }
            for ( level.fun_lg_i = level.fun_ladder.size - 1; level.fun_lg_i > level.fun_lg_start; level.fun_lg_i-- )
            {
                level.fun_lg_j = level.fun_lg_start + randomint( level.fun_lg_i - level.fun_lg_start + 1 );
                level.fun_lg = level.fun_ladder[ level.fun_lg_i ];
                level.fun_ladder[ level.fun_lg_i ] = level.fun_ladder[ level.fun_lg_j ];
                level.fun_ladder[ level.fun_lg_j ] = level.fun_lg;
            }
        }
    }
    if ( level.fun_ladder.size == 0 )
    {
        level.fun_mode = "";
        return;
    }
    fun_say_all( "^3Gun Game: " + level.fun_ladder.size + " guns, " + fun_gg_need( 0 ) + " kills to start, +1 every 5 guns" );
    foreach ( p in level.players )
    {
        if ( isdefined( p ) && isdefined( p.zmm ) )
        {
            p.zmm.fun_gg_lvl = 0;
            p.zmm.fun_gg_kills = 0;
        }
    }
    foreach ( p in fun_mode_players() )
    {
        p thread fun_gg_give( level.fun_ladder[ 0 ] );
        p fun_gg_hud();
    }
}

// self = player; zm_mod_menu_post.lua draws the host's zmm_gg line and turns the weapon ref into the gun's name
function fun_gg_hud()
{
    if ( [[ level.zmm_is_host_fn ]]() )
    {
        setdvar( @"zmm_gg", "Gun Game   " + ( self.zmm.fun_gg_lvl + 1 ) + "/" + level.fun_ladder.size + "   " + level.fun_ladder[ self.zmm.fun_gg_lvl ] + "   Kills " + self.zmm.fun_gg_kills + "/" + fun_gg_need( self.zmm.fun_gg_lvl ) );
    }
}

// kills to move on from gun lvl: more the further up the ladder
function fun_gg_need( lvl )
{
    return 10 + int( lvl / 5 );
}

// self = player
function fun_gg_kill()
{
    if ( !isdefined( self.zmm.fun_gg_lvl ) )
    {
        self.zmm.fun_gg_lvl = 0;
        self.zmm.fun_gg_kills = 0;
    }
    self.zmm.fun_gg_kills++;
    if ( self.zmm.fun_gg_kills < fun_gg_need( self.zmm.fun_gg_lvl ) )
    {
        self fun_gg_hud();
        return;
    }
    self.zmm.fun_gg_kills = 0;
    self.zmm.fun_gg_lvl++;
    if ( self.zmm.fun_gg_lvl >= level.fun_ladder.size )
    {
        self iprintlnbold( "^2Gun Game cleared! Back to the start" );
        self.zmm.fun_gg_lvl = 0;
    }
    else if ( ![[ level.zmm_is_host_fn ]]() || getdvar( @"zmm_lua" ) != "1" )
    {
        self iprintln( "^3Gun " + ( self.zmm.fun_gg_lvl + 1 ) + "/" + level.fun_ladder.size );
    }
    self thread fun_gg_give( level.fun_ladder[ self.zmm.fun_gg_lvl ] );
    self fun_gg_hud();
}

// the player's Gunsmith zombie build of that gun when there is one (zm_mod_menu's menu_zm_build), else the stock gun
// the PaP tier and rarity of the held gun carry over, the other gun slots are emptied
function fun_gg_give( name )
{
    self notify( #"fun_gg_give" );
    self endon( #"fun_gg_give" );
    self endon( #"disconnect" );
    self [[ level.zmm_gg_read_fn ]]();
    self.zmm.fun_w = undefined;
    if ( isdefined( level.zmm_zm_build_fn ) && isdefined( name ) && istrue( self [[ level.zmm_zm_build_fn ]]( name ) ) )
    {
        self.zmm.fun_w = self.zmm.build_gun;
    }
    else
    {
        self fun_give_gun( name );
    }
    if ( !isdefined( self.zmm.fun_w ) )
    {
        // a BO6 gun this map cannot load: go on to the next one
        if ( isdefined( name ) && issubstr( name, "t10_" ) && self.zmm.fun_gg_lvl + 1 < level.fun_ladder.size )
        {
            self.zmm.fun_gg_lvl++;
            self fun_gg_hud();
            self thread fun_gg_give( level.fun_ladder[ self.zmm.fun_gg_lvl ] );
        }
        return;
    }
    self fun_roul_strip();
    wait 0.5;
    self [[ level.zmm_gg_apply_fn ]]();
}

// One in the Chamber: a pistol with one bullet, every bullet kills, every kill gives a bullet back
function fun_oitc_start( key )
{
    fun_say_all( "^3One in the Chamber" );
    foreach ( p in fun_mode_players() )
    {
        p thread fun_oitc_arm();
    }
}

function fun_oitc_arm()
{
    self notify( #"fun_rearm" );
    self endon( #"fun_rearm" );
    self endon( #"disconnect" );
    level endon( #"fun_mode_end" );
    self.zmm.fun_w = undefined;
    // a few tries: a give can fail while the gun loads
    for ( self.zmm.fun_try = 0; self.zmm.fun_try < 3 && !isdefined( self.zmm.fun_w ); self.zmm.fun_try++ )
    {
        self fun_give_gun( fun_random_gun_from( [ "W_pi" ] ) );
    }
    if ( !isdefined( self.zmm.fun_w ) )
    {
        return;
    }
    self setweaponammoclip( self.zmm.fun_w, 1 );
    while ( level.fun_mode == "oitc" )
    {
        self setweaponammostock( self.zmm.fun_w, 0 );
        wait 0.5;
    }
}

// Sharpshooter: everyone gets the same random gun every 30 s
function fun_sharp_start( key )
{
    level endon( #"fun_mode_end" );
    while ( level.fun_mode == "sharp" )
    {
        level.fun_sharp_last = level.fun_sharp_gun;
        // never the same gun twice in a row
        for ( level.fun_sharp_try = 0; level.fun_sharp_try < 10; level.fun_sharp_try++ )
        {
            level.fun_sharp_gun = fun_random_gun_from( level.fun_gun_pages );
            if ( !isdefined( level.fun_sharp_last ) || !( level.fun_sharp_gun === level.fun_sharp_last ) )
            {
                break;
            }
        }
        fun_say_all( "^3Sharpshooter: new gun" );
        foreach ( p in fun_mode_players() )
        {
            p thread fun_give_gun( level.fun_sharp_gun );
        }
        wait 30;
    }
}

// One-gun roulette: a single random gun each; empty it and the wheel spins again
function fun_roul_start( key )
{
    fun_say_all( "^3Roulette: one gun, empty it to spin" );
    foreach ( p in fun_mode_players() )
    {
        p thread fun_roul_loop();
    }
}

function fun_roul_loop()
{
    self notify( #"fun_rearm" );
    self endon( #"fun_rearm" );
    self endon( #"disconnect" );
    level endon( #"fun_mode_end" );
    while ( level.fun_mode == "roul" )
    {
        self.zmm.fun_w = undefined;
        for ( self.zmm.fun_try = 0; self.zmm.fun_try < 3 && !isdefined( self.zmm.fun_w ); self.zmm.fun_try++ )
        {
            self fun_give_random();
        }
        if ( !isdefined( self.zmm.fun_w ) )
        {
            return;
        }
        self fun_roul_strip();
        while ( level.fun_mode == "roul" && self hasweapon( self.zmm.fun_w ) && self getweaponammoclip( self.zmm.fun_w ) + self getweaponammostock( self.zmm.fun_w ) > 0 )
        {
            wait 0.5;
        }
        wait 0.5;
    }
}

// takes every other gun (melee kept)
function fun_roul_strip()
{
    if ( !isdefined( self.primaryinventory ) )
    {
        return;
    }
    self.zmm.fun_strip = [];
    foreach ( w in self.primaryinventory )
    {
        if ( isdefined( w ) && !isnullweapon( w ) && !( w == self.zmm.fun_w ) && isdefined( w.basename ) && !issubstr( w.basename, "_me_" ) )
        {
            self.zmm.fun_strip[ self.zmm.fun_strip.size ] = w;
        }
    }
    foreach ( w in self.zmm.fun_strip )
    {
        self takeweapon( w );
    }
}

// Boss Rush: heavy enemies every round (and right away)
function fun_rush_start( key )
{
    fun_say_all( "^1Boss Rush" );
    level thread fun_rush_wave();
}

function fun_rush_wave()
{
    level endon( #"fun_mode_end" );
    level.fun_rush_n = int( min( 1 + fun_round() / 8, 4 ) );
    for ( level.fun_rush_i = 0; level.fun_rush_i < level.fun_rush_n; level.fun_rush_i++ )
    {
        level.fun_rush_p = level.players[ randomint( level.players.size ) ];
        if ( !isdefined( level.fun_rush_p ) )
        {
            continue;
        }
        level.fun_rush_pos = level.fun_rush_p.origin + anglestoforward( ( 0, randomint( 360 ), 0 ) ) * 450;
        // a few tries: not every heavy exists on every map
        for ( level.fun_rush_try = 0; level.fun_rush_try < 3; level.fun_rush_try++ )
        {
            level.fun_rush_ai = fun_spawn_ai( level.fun_rush_types[ randomint( level.fun_rush_types.size ) ], level.fun_rush_pos );
            if ( isdefined( level.fun_rush_ai ) && isalive( level.fun_rush_ai ) )
            {
                break;
            }
            waitframe();
        }
        wait 1;
    }
}

// Zone rotation: every N rounds, a warning, then everyone moves to another zone and must stay in its circle
function fun_zone_start( key )
{
    level.fun_zone_every = key == "zone4" ? 4 : 2;
    level.fun_zone_r0 = fun_round();
    level.fun_zone_r = 750;
    if ( !isdefined( level.var_63a203e154ffeca0 ) || !isdefined( level.var_63a203e154ffeca0.var_4ab2642fe2ee0966 ) )
    {
        fun_say_all( "^1Zone rotation: no zones on this map" );
        level.fun_mode = "";
        return;
    }
    level thread fun_zone_shift();
}

function fun_zone_center( zone )
{
    if ( !isdefined( zone ) )
    {
        return undefined;
    }
    if ( isdefined( zone.var_793b74c500e1858c ) && isdefined( zone.var_793b74c500e1858c[ "min" ] ) && isdefined( zone.var_793b74c500e1858c[ "max" ] ) )
    {
        level.fun_zc = getclosestpointonnavmesh( ( zone.var_793b74c500e1858c[ "min" ] + zone.var_793b74c500e1858c[ "max" ] ) * 0.5 );
        if ( isdefined( level.fun_zc ) )
        {
            return level.fun_zc;
        }
    }
    if ( isdefined( zone.var_79c508f5fd160635 ) && zone.var_79c508f5fd160635.size > 0 && isdefined( zone.var_79c508f5fd160635[ 0 ] ) )
    {
        return getclosestpointonnavmesh( zone.var_79c508f5fd160635[ 0 ].origin );
    }
    return undefined;
}

// same test as the game's fog spawning (Ashes): fog zones hurt players, so the rotation skips them
function fun_zone_fog( zone )
{
    return istrue( zone.var_4dc255bc20838308 ) && isdefined( level.var_25223259f9cd6017 ) && isdefined( zone.var_92781bc7d418ab8a ) && istrue( level.var_25223259f9cd6017[ zone.var_92781bc7d418ab8a ] );
}

function fun_zone_shift()
{
    level endon( #"fun_mode_end" );
    fun_say_all( "^3Zone shift in 10 seconds" );
    wait 10;
    level.fun_zone_keys = getarraykeys( level.var_63a203e154ffeca0.var_4ab2642fe2ee0966 );
    level.fun_zone_new = undefined;
    for ( level.fun_zone_try = 0; level.fun_zone_try < 40 && level.fun_zone_keys.size > 0; level.fun_zone_try++ )
    {
        level.fun_zone_k = level.fun_zone_keys[ randomint( level.fun_zone_keys.size ) ];
        level.fun_zone_pt = fun_zone_center( level.var_63a203e154ffeca0.var_4ab2642fe2ee0966[ level.fun_zone_k ] );
        if ( isdefined( level.fun_zone_pt ) && !fun_zone_fog( level.var_63a203e154ffeca0.var_4ab2642fe2ee0966[ level.fun_zone_k ] ) && ( !isdefined( level.fun_zone_c ) || distance( level.fun_zone_pt, level.fun_zone_c ) > 800 ) )
        {
            level.fun_zone_new = level.fun_zone_pt;
            break;
        }
    }
    if ( !isdefined( level.fun_zone_new ) )
    {
        fun_say_all( "^1Zone shift failed" );
        return;
    }
    // let zombies spawn there, as opening its door would
    if ( isdefined( level.var_63a203e154ffeca0.var_4ab2642fe2ee0966[ level.fun_zone_k ].var_8a1bbd1390cd5db6 ) )
    {
        namespace_63a203e154ffeca0::function_b59ce32b3b1a7b17( level.var_63a203e154ffeca0.var_4ab2642fe2ee0966[ level.fun_zone_k ].var_8a1bbd1390cd5db6, 1 );
    }
    level.fun_zone_c = level.fun_zone_new;
    fun_fx_at( "teleport_splash", level.fun_zone_c );
    foreach ( p in level.players )
    {
        if ( isdefined( p ) && isalive( p ) )
        {
            p [[ level.zmm_teleport_fn ]]( getclosestpointonnavmesh( level.fun_zone_c + anglestoforward( ( 0, randomint( 360 ), 0 ) ) * 60 ), p getplayerangles() );
        }
    }
    fun_say_all( "^3Stay inside the zone" );
}

// the circle: players outside are pushed back, far outside are put back in the middle
function fun_zone_keep()
{
    for ( ;; )
    {
        wait 0.5;
        if ( !issubstr( level.fun_mode, "zone" ) || !isdefined( level.fun_zone_c ) )
        {
            continue;
        }
        foreach ( p in level.players )
        {
            if ( !isdefined( p ) || !isalive( p ) || istrue( p.inlaststand ) )
            {
                continue;
            }
            level.fun_zd = distance2d( p.origin, level.fun_zone_c );
            if ( level.fun_zd > level.fun_zone_r + 500 )
            {
                p [[ level.zmm_teleport_fn ]]( level.fun_zone_c, p getplayerangles() );
            }
            else if ( level.fun_zd > level.fun_zone_r )
            {
                p setvelocity( vectornormalize( ( level.fun_zone_c[ 0 ] - p.origin[ 0 ], level.fun_zone_c[ 1 ] - p.origin[ 1 ], 0 ) ) * 450 + ( 0, 0, 120 ) );
                p iprintln( "^1Back in the zone!" );
            }
        }
    }
}

// ---------------------------------------------------------------- toggles: explosive punch, bullet time, orbit, kill effects

function fun_tog( key )
{
    level.fun_on[ key ] = !istrue( level.fun_on[ key ] );
    if ( key == "btime" )
    {
        if ( level.fun_on[ key ] )
        {
            setslowmotion( 1, 0.4, 0.5 );
        }
        else
        {
            setslowmotion( 0.4, 1, 0.5 );
        }
    }
    else if ( key == "nuke" && level.fun_on[ key ] )
    {
        level thread fun_auto_nuke();
    }
    else if ( key == "orbit" )
    {
        if ( level.fun_on[ key ] )
        {
            level.fun_orbit_owner = self;
            self thread fun_orbit();
        }
    }
}

function fun_tog_on( key )
{
    return istrue( level.fun_on[ key ] );
}

function fun_auto_nuke()
{
    level notify( #"fun_auto_nuke" );
    level endon( #"fun_auto_nuke" );
    while ( istrue( level.fun_on[ "nuke" ] ) )
    {
        wait 15;
        if ( !istrue( level.fun_on[ "nuke" ] ) )
        {
            return;
        }
        foreach ( p in level.players )
        {
            if ( isdefined( p ) )
            {
                p playsound( "evt_zm_core_powerup_nuke_explode" );
            }
        }
        foreach ( ai in fun_near( ( 0, 0, 0 ), 1000000 ) )
        {
            fun_ragdoll( ai );
            waitframe();
        }
    }
}

// up to 8 zombies circle the player on movers; turning it off lets them go
function fun_orbit()
{
    self endon( #"disconnect" );
    self.zmm.fun_orb = [];
    self.zmm.fun_orb_a = 0;
    self.zmm.fun_orb_fill = 0;
    while ( istrue( level.fun_on[ "orbit" ] ) && level.fun_orbit_owner == self )
    {
        if ( gettime() > self.zmm.fun_orb_fill )
        {
            self.zmm.fun_orb_fill = gettime() + 2000;
            self fun_orbit_fill();
        }
        self.zmm.fun_orb_a = ( self.zmm.fun_orb_a + 14 ) % 360;
        for ( self.zmm.fun_oi = 0; self.zmm.fun_oi < self.zmm.fun_orb.size; self.zmm.fun_oi++ )
        {
            level.fun_om = self.zmm.fun_orb[ self.zmm.fun_oi ];
            if ( !isdefined( level.fun_om ) )
            {
                continue;
            }
            level.fun_oang = self.zmm.fun_orb_a + self.zmm.fun_oi * 45;
            level.fun_om moveto( self.origin + ( cos( level.fun_oang ) * 170, sin( level.fun_oang ) * 170, 45 ), 0.1 );
        }
        wait 0.1;
    }
    foreach ( m in self.zmm.fun_orb )
    {
        fun_release( m, 0 );
    }
    self.zmm.fun_orb = [];
}

function fun_orbit_fill()
{
    // drop movers whose zombie died
    self.zmm.fun_orb_keep = [];
    foreach ( m in self.zmm.fun_orb )
    {
        if ( isdefined( m ) && isdefined( m.fun_ai ) && isalive( m.fun_ai ) )
        {
            self.zmm.fun_orb_keep[ self.zmm.fun_orb_keep.size ] = m;
        }
        else
        {
            fun_release( m, 0 );
        }
    }
    self.zmm.fun_orb = self.zmm.fun_orb_keep;
    foreach ( ai in fun_near( self.origin, 900 ) )
    {
        if ( self.zmm.fun_orb.size >= 8 )
        {
            break;
        }
        level.fun_om = fun_hold( ai );
        if ( isdefined( level.fun_om ) )
        {
            self.zmm.fun_orb[ self.zmm.fun_orb.size ] = level.fun_om;
        }
    }
}

// ---------------------------------------------------------------- chaos effects

function fun_chaos( key )
{
    if ( isdefined( level.fun_chaos_fn[ key ] ) )
    {
        self thread [[ level.fun_chaos_fn[ key ] ]]();
    }
}

// a dark core 700 units ahead pulls everything within 1100 for 10 s, then collapses
function fun_black_hole()
{
    if ( istrue( level.fun_bh_on ) )
    {
        return;
    }
    level.fun_bh_on = 1;
    level.fun_bh_c = self fun_aim_point( 700 ) + ( 0, 0, 70 );
    level.fun_bh_fx = fun_fx_ent( "shadow_vortex_warp_air_fx", level.fun_bh_c );
    level.fun_bh_snd = spawn( "script_origin", level.fun_bh_c );
    level.fun_bh_snd playloopsound( "wpn_dark_flare_spin_plr_loop" );
    for ( level.fun_bh_t = 0; level.fun_bh_t < 20; level.fun_bh_t++ )
    {
        if ( level.fun_bh_t % 3 == 0 )
        {
            if ( isdefined( level.fun_bh_fx ) )
            {
                triggerfx( level.fun_bh_fx );
            }
            fun_fx_at( "dark_flare_ball_effect", level.fun_bh_c );
        }
        foreach ( ai in fun_near( level.fun_bh_c, 1100 ) )
        {
            fun_fling( ai, level.fun_bh_c + ( randomfloatrange( -30, 30 ), randomfloatrange( -30, 30 ), 0 ), 0.25 + distance( ai.origin, level.fun_bh_c ) / 550, 1, 1 );
        }
        wait 0.5;
    }
    level.fun_bh_snd stoploopsound();
    level.fun_bh_snd playsound( "prj_ammomod_shadowvortex_disappear" );
    level.fun_bh_snd thread fun_delete_after( 3 );
    if ( isdefined( level.fun_bh_fx ) )
    {
        level.fun_bh_fx delete();
    }
    fun_fx_at( "shadow_vortex_explosive", level.fun_bh_c );
    earthquake( 0.5, 1.2, level.fun_bh_c, 1500 );
    level.fun_bh_on = 0;
}

// a funnel that drifts toward the nearest zombies for 12 s, spinning up and throwing what it touches
function fun_tornado()
{
    if ( istrue( level.fun_tor_on ) )
    {
        return;
    }
    level.fun_tor_on = 1;
    level.fun_tor = spawn( "script_origin", getclosestpointonnavmesh( self fun_aim_point( 450 ) ) );
    for ( level.fun_tor_t = 0; level.fun_tor_t < 40; level.fun_tor_t++ )
    {
        level.fun_tor_goal = undefined;
        foreach ( ai in fun_near( level.fun_tor.origin, 1500 ) )
        {
            if ( !isdefined( level.fun_tor_goal ) || distance( ai.origin, level.fun_tor.origin ) < distance( level.fun_tor_goal, level.fun_tor.origin ) )
            {
                level.fun_tor_goal = ai.origin;
            }
        }
        level.fun_tor_dir = anglestoforward( ( 0, randomint( 360 ), 0 ) );
        if ( isdefined( level.fun_tor_goal ) )
        {
            level.fun_tor_dir = vectornormalize( ( level.fun_tor_goal[ 0 ] - level.fun_tor.origin[ 0 ], level.fun_tor_goal[ 1 ] - level.fun_tor.origin[ 1 ], 0 ) + ( 0.01, 0, 0 ) );
        }
        level.fun_tor_next = getclosestpointonnavmesh( level.fun_tor.origin + level.fun_tor_dir * 80 );
        if ( isdefined( level.fun_tor_next ) )
        {
            level.fun_tor moveto( level.fun_tor_next, 0.3 );
        }
        for ( level.fun_tor_h = 0; level.fun_tor_h < 4; level.fun_tor_h++ )
        {
            level.fun_tor_ang = level.fun_tor_t * 50 + level.fun_tor_h * 90;
            fun_fx_at( "aether_energy_trail", level.fun_tor.origin + ( cos( level.fun_tor_ang ) * 25 * level.fun_tor_h, sin( level.fun_tor_ang ) * 25 * level.fun_tor_h, level.fun_tor_h * 80 ) );
        }
        foreach ( ai in fun_near( level.fun_tor.origin, 240 ) )
        {
            fun_fling( ai, ai.origin + anglestoforward( ( 0, randomint( 360 ), 0 ) ) * 350 + ( 0, 0, 420 ), 0.9, 1, 1 );
        }
        wait 0.3;
    }
    level.fun_tor delete();
    level.fun_tor_on = 0;
}

// up to 10 zombies dance along behind you for 15 s on the path you walked
function fun_conga()
{
    self endon( #"disconnect" );
    if ( istrue( self.zmm.fun_conga_on ) )
    {
        return;
    }
    self.zmm.fun_conga_on = 1;
    self.zmm.fun_trail = [];
    self.zmm.fun_conga = [];
    foreach ( ai in fun_near( self.origin, 1500 ) )
    {
        if ( self.zmm.fun_conga.size >= 10 )
        {
            break;
        }
        level.fun_cm = fun_hold( ai );
        if ( isdefined( level.fun_cm ) )
        {
            self.zmm.fun_conga[ self.zmm.fun_conga.size ] = level.fun_cm;
        }
    }
    if ( self.zmm.fun_conga.size == 0 )
    {
        self.zmm.fun_conga_on = 0;
        self [[ level.zmm_notify_fn ]]( "Conga line", 0 );
        return;
    }
    for ( self.zmm.fun_ct = 0; self.zmm.fun_ct < 75; self.zmm.fun_ct++ )
    {
        // newest point first, 40 kept
        self.zmm.fun_trail2 = [ self.origin ];
        for ( self.zmm.fun_ci = 0; self.zmm.fun_ci < self.zmm.fun_trail.size && self.zmm.fun_ci < 39; self.zmm.fun_ci++ )
        {
            self.zmm.fun_trail2[ self.zmm.fun_trail2.size ] = self.zmm.fun_trail[ self.zmm.fun_ci ];
        }
        self.zmm.fun_trail = self.zmm.fun_trail2;
        for ( self.zmm.fun_ci = 0; self.zmm.fun_ci < self.zmm.fun_conga.size; self.zmm.fun_ci++ )
        {
            level.fun_cm = self.zmm.fun_conga[ self.zmm.fun_ci ];
            level.fun_cidx = int( min( ( self.zmm.fun_ci + 1 ) * 3, self.zmm.fun_trail.size - 1 ) );
            if ( isdefined( level.fun_cm ) && isdefined( level.fun_cm.fun_ai ) && isalive( level.fun_cm.fun_ai ) )
            {
                // a little side to side shuffle
                level.fun_cm moveto( self.zmm.fun_trail[ level.fun_cidx ] + ( 0, 0, ( self.zmm.fun_ct % 2 ) * 8 ), 0.2 );
            }
        }
        wait 0.2;
    }
    foreach ( m in self.zmm.fun_conga )
    {
        fun_release( m, 0 );
    }
    self.zmm.fun_conga = [];
    self.zmm.fun_conga_on = 0;
}

// freezes everything within 550 for 2.5 s, then they shatter
function fun_frost()
{
    self endon( #"disconnect" );
    fun_fx_at( "flash_freeze_shatter_fx", self.origin );
    self playsound( "prj_ammomod_cryofreeze_proc" );
    self.zmm.fun_ice = [];
    foreach ( ai in fun_near( self.origin, 550 ) )
    {
        level.fun_im = fun_hold( ai );
        if ( isdefined( level.fun_im ) )
        {
            self.zmm.fun_ice[ self.zmm.fun_ice.size ] = level.fun_im;
        }
    }
    wait 2.5;
    foreach ( m in self.zmm.fun_ice )
    {
        if ( isdefined( m ) )
        {
            fun_fx_at( "flash_freeze_shatter_fx", m.origin + ( 0, 0, 40 ) );
            fun_sound_at( "evt_ammomod_cryofreeze_ai_shatter", m.origin );
            if ( isdefined( m.fun_ai ) )
            {
                m.fun_ai.no_powerups = 1;
                m.fun_ai unlink();
                m.fun_ai kill();
            }
            m delete();
        }
        waitframe();
    }
    self.zmm.fun_ice = [];
}

// 22 fire rocks over 8 s on random spots around you
function fun_meteor()
{
    self endon( #"disconnect" );
    for ( self.zmm.fun_mi = 0; self.zmm.fun_mi < 22; self.zmm.fun_mi++ )
    {
        self.zmm.fun_mpos = self.origin + ( randomfloatrange( -900, 900 ), randomfloatrange( -900, 900 ), 0 );
        level.fun_rock = spawn( "script_model", physicstrace( self.zmm.fun_mpos + ( 0, 0, 500 ), self.zmm.fun_mpos - ( 0, 0, 800 ) ) + ( randomfloatrange( -350, 350 ), randomfloatrange( -350, 350 ), 1500 ) );
        level.fun_rock.fun_ground = physicstrace( self.zmm.fun_mpos + ( 0, 0, 500 ), self.zmm.fun_mpos - ( 0, 0, 800 ) );
        level.fun_rock thread fun_meteor_fall();
        wait 0.35;
    }
}

// self = rock
function fun_meteor_fall()
{
    self setmodel( "tag_origin" );
    level.fun_fx_h = fun_fx( "vfx_sat_gameplay_zm_weapons_fld_wf_wild_fire_ball_trail" );
    if ( isdefined( level.fun_fx_h ) )
    {
        playfxontag( level.fun_fx_h, self, "tag_origin" );
    }
    self moveto( self.fun_ground, 0.9, 0.6, 0 );
    wait 0.9;
    fun_fx_at( "vfx_sat_gameplay_zm_weapons_fld_wf_wild_fire_ball_explo", self.fun_ground );
    self playsound( "prj_ammomod_shatterblast_proc_explode" );
    earthquake( 0.3, 0.5, self.fun_ground, 700 );
    fun_blast( self.fun_ground, 170, "shatterblast_explosion_effect", 220 );
    wait 2;
    self delete();
}

// 10 s of bolts on random zombies near you, each one jumping to a neighbour
function fun_storm()
{
    self endon( #"disconnect" );
    for ( self.zmm.fun_si = 0; self.zmm.fun_si < 20; self.zmm.fun_si++ )
    {
        self.zmm.fun_sl = fun_near( self.origin, 1400 );
        if ( self.zmm.fun_sl.size > 0 )
        {
            self.zmm.fun_st = self.zmm.fun_sl[ randomint( self.zmm.fun_sl.size ) ];
            fun_fx_at( "lightning_strike", self.zmm.fun_st.origin );
            fun_sound_at( "evt_lightning_strike", self.zmm.fun_st.origin );
            if ( randomint( 3 ) == 0 )
            {
                earthquake( 0.2, 0.4, self.zmm.fun_st.origin, 600 );
            }
            foreach ( ai in fun_near( self.zmm.fun_st.origin, 280 ) )
            {
                if ( !( ai == self.zmm.fun_st ) )
                {
                    fun_fx_at( "chain_lightning_bolt", ai.origin + ( 0, 0, 40 ) );
                    fun_ragdoll( ai );
                    break;
                }
            }
            fun_fx_at( "vfx_lightning_zaps_impact", self.zmm.fun_st.origin );
            fun_ragdoll( self.zmm.fun_st );
        }
        wait 0.5;
    }
}

// 8 s: zombies within 1300 are yanked into a pile 220 in front of you (alive)
function fun_magnet()
{
    self endon( #"disconnect" );
    for ( self.zmm.fun_gi = 0; self.zmm.fun_gi < 20; self.zmm.fun_gi++ )
    {
        self.zmm.fun_gp = self.origin + anglestoforward( ( 0, self getplayerangles()[ 1 ], 0 ) ) * 220;
        foreach ( ai in fun_near( self.origin, 1300 ) )
        {
            if ( distance( ai.origin, self.zmm.fun_gp ) > 90 )
            {
                fun_fling( ai, self.zmm.fun_gp + ( randomfloatrange( -50, 50 ), randomfloatrange( -50, 50 ), 0 ), 0.35, 0, 0 );
            }
        }
        wait 0.4;
    }
}

// 7 rockets around you; each burst kills the zombies under it
function fun_fireworks()
{
    self endon( #"disconnect" );
    for ( self.zmm.fun_fi = 0; self.zmm.fun_fi < 7; self.zmm.fun_fi++ )
    {
        level.fun_rkt = spawn( "script_model", self.origin + ( randomfloatrange( -300, 300 ), randomfloatrange( -300, 300 ), 10 ) );
        level.fun_rkt thread fun_rocket();
        wait 0.3;
    }
}

// self = rocket
function fun_rocket()
{
    self setmodel( "tag_origin" );
    level.fun_fx_h = fun_fx( "fx_trail" );
    if ( isdefined( level.fun_fx_h ) )
    {
        playfxontag( level.fun_fx_h, self, "tag_origin" );
    }
    self playsound( "prj_ammomod_fireworks_fire_large" );
    self.fun_top = self.origin + ( randomfloatrange( -120, 120 ), randomfloatrange( -120, 120 ), randomfloatrange( 450, 750 ) );
    self moveto( self.fun_top, 1.1, 0.3, 0 );
    wait 1.1;
    fun_fx_at( "firework_vfx", self.fun_top );
    self playsound( "prj_ammomod_fireworks_explo" );
    foreach ( ai in fun_near( self.fun_top, 1000 ) )
    {
        if ( distance2d( ai.origin, self.fun_top ) < 260 )
        {
            fun_fling( ai, ai.origin + ( 0, 0, 300 ), 0.6, 1, 1 );
        }
    }
    wait 2;
    self delete();
}

// half of all zombies turn to dust, picked at random
function fun_snap()
{
    self playsound( "prj_ammomod_shadowvortex_disappear" );
    self iprintlnbold( "^5Perfectly balanced" );
    self.zmm.fun_snap = fun_near( self.origin, 1000000 );
    foreach ( ai in self.zmm.fun_snap )
    {
        if ( randomint( 2 ) == 0 && isdefined( ai ) && isalive( ai ) )
        {
            fun_fx_at( "teleport_splash", ai.origin + ( 0, 0, 30 ) );
            ai.no_powerups = 1;
            ai kill();
            wait 0.05;
        }
    }
}

// jump, slam down, everything within 420 is thrown; no fall damage
function fun_pound()
{
    self endon( #"disconnect" );
    self.zmm.fun_pound_end = gettime() + 3000;
    self setvelocity( ( 0, 0, 650 ) );
    wait 0.45;
    self setvelocity( ( 0, 0, -1600 ) );
    for ( self.zmm.fun_pw = 0; self.zmm.fun_pw < 30 && !self isonground(); self.zmm.fun_pw++ )
    {
        wait 0.05;
    }
    self playsound( "prj_ammomod_shatterblast_proc_explode" );
    earthquake( 0.7, 1, self.origin, 900 );
    fun_blast( self.origin, 420, "shatterblast_explosion_effect_100", 220 );
}

// 6 s quake: zombies within 1500 stagger around, a few fall in
function fun_quake()
{
    self endon( #"disconnect" );
    earthquake( 0.55, 6, self.origin, 2500 );
    for ( self.zmm.fun_qi = 0; self.zmm.fun_qi < 4; self.zmm.fun_qi++ )
    {
        foreach ( ai in fun_near( self.origin, 1500 ) )
        {
            if ( randomint( 6 ) == 0 )
            {
                fun_fx_at( "dark_flare_impact_effect", ai.origin );
                fun_ragdoll( ai );
            }
            else
            {
                fun_fling( ai, ai.origin + ( randomfloatrange( -70, 70 ), randomfloatrange( -70, 70 ), 0 ), 0.3, 0, 0 );
            }
        }
        wait 1.5;
    }
}

// 10 s of random power-ups falling around you
function fun_pu_rain()
{
    self endon( #"disconnect" );
    for ( self.zmm.fun_ri = 0; self.zmm.fun_ri < 20; self.zmm.fun_ri++ )
    {
        self.zmm.fun_rp = getclosestpointonnavmesh( self.origin + ( randomfloatrange( -450, 450 ), randomfloatrange( -450, 450 ), 0 ) );
        if ( isdefined( self.zmm.fun_rp ) && !fun_drop( level.fun_pu_names[ randomint( level.fun_pu_names.size ) ], self.zmm.fun_rp + ( 0, 0, 40 ) ) )
        {
            self [[ level.zmm_notify_fn ]]( "Power-up rain", 0 );
            return;
        }
        wait 0.5;
    }
}

// 12 random power-ups in a wide ring
function fun_pu_circle()
{
    self endon( #"disconnect" );
    for ( self.zmm.fun_ri = 0; self.zmm.fun_ri < 12; self.zmm.fun_ri++ )
    {
        self.zmm.fun_rp = self.origin + ( cos( self.zmm.fun_ri * 30 ) * 240, sin( self.zmm.fun_ri * 30 ) * 240, 40 );
        if ( !fun_drop( level.fun_pu_names[ randomint( level.fun_pu_names.size ) ], self.zmm.fun_rp ) )
        {
            self [[ level.zmm_notify_fn ]]( "Power-up circle", 0 );
            return;
        }
        wait 0.15;
    }
}

// first press: the zombie under the crosshair floats in front of you; second press: thrown where you look
function fun_grab()
{
    if ( isdefined( self.zmm.fun_held ) )
    {
        level.fun_th = self.zmm.fun_held;
        self.zmm.fun_held = undefined;
        level.fun_th.fun_end = self fun_aim_point( 1400 );
        level.fun_th moveto( level.fun_th.fun_end, 0.45, 0, 0 );
        level.fun_th thread fun_throw_land();
        return;
    }
    self.zmm.fun_gai = self fun_aim_zombie( 1500 );
    self.zmm.fun_held = fun_hold( self.zmm.fun_gai );
    if ( !isdefined( self.zmm.fun_held ) )
    {
        self [[ level.zmm_notify_fn ]]( "Grab zombie", 0 );
        return;
    }
    self thread fun_grab_follow();
}

function fun_grab_follow()
{
    self endon( #"disconnect" );
    while ( isdefined( self.zmm.fun_held ) )
    {
        if ( !isdefined( self.zmm.fun_held.fun_ai ) || !isalive( self.zmm.fun_held.fun_ai ) || !isalive( self ) )
        {
            fun_release( self.zmm.fun_held, 0 );
            self.zmm.fun_held = undefined;
            return;
        }
        self.zmm.fun_held moveto( self geteye() + anglestoforward( self getplayerangles() ) * 120 - ( 0, 0, 50 ), 0.05 );
        wait 0.05;
    }
}

// self = thrown mover
function fun_throw_land()
{
    wait 0.45;
    fun_fx_at( "shatterblast_explosion_effect", self.origin );
    self playsound( "prj_ammomod_shatterblast_proc_explode" );
    fun_release( self, 1 );
}

// zombies within 1200 rise for 2 s, hang, spin, then drop dead
function fun_float()
{
    foreach ( ai in fun_near( self.origin, 1200 ) )
    {
        level.fun_fm = fun_hold( ai );
        if ( isdefined( level.fun_fm ) )
        {
            level.fun_fm thread fun_float_go();
        }
    }
}

// self = mover
function fun_float_go()
{
    self moveto( self.origin + ( 0, 0, randomfloatrange( 200, 320 ) ), 2, 0.5, 0.5 );
    wait 2;
    self rotateyaw( 720, 2.5 );
    wait 2.5;
    fun_release( self, 1 );
}

// ---------------------------------------------------------------- vehicles

function fun_vehicle_refs()
{
    level.fun_vref = [];
    level.fun_vdef = [];
    level.fun_vref[ 0 ] = %"vehiclebundle:veh_sat_blood_burner_ob";
    level.fun_vdef[ 0 ] = %"veh_sat_blood_burner";
    level.fun_vref[ 1 ] = %"vehiclebundle:veh_t10_mil_us_heli_medium_trans_mp";
    level.fun_vdef[ 1 ] = %"veh_t10_mil_us_heli_medium_trans";
}

function fun_veh_ready( i )
{
    level.fun_vr = level.fun_vref[ i ];
    if ( !vehicle::has_data( level.fun_vr ) )
    {
        vehicle::generic_init( level.fun_vr );
    }
    if ( vehicle::has_data( level.fun_vr ) )
    {
        return 1;
    }
    // fall back on the vehicle def when the bundle has no data on this map
    level.fun_vr = level.fun_vdef[ i ];
    if ( !vehicle::has_data( level.fun_vr ) )
    {
        vehicle::generic_init( level.fun_vr );
    }
    if ( vehicle::has_data( level.fun_vr ) )
    {
        level.fun_vref[ i ] = level.fun_vr;
        return 1;
    }
    return 0;
}

function fun_veh( i )
{
    if ( i == 2 )
    {
        foreach ( v in level.fun_vehs )
        {
            if ( isdefined( v ) )
            {
                v delete();
            }
        }
        level.fun_vehs = [];
        self [[ level.zmm_notify_fn ]]( "Remove vehicles", 1 );
        return;
    }
    if ( !fun_veh_ready( i ) )
    {
        self [[ level.zmm_notify_fn ]]( "Vehicle", 0 );
        return;
    }
    self.zmm.fun_vspot = { #origin:self.origin + anglestoforward( ( 0, self getplayerangles()[ 1 ], 0 ) ) * 260 + ( 0, 0, 20 ), #angles:( 0, self getplayerangles()[ 1 ], 0 ) };
    self.zmm.fun_v = vehicle::spawn( level.fun_vref[ i ], self.zmm.fun_vspot );
    if ( !isdefined( self.zmm.fun_v ) )
    {
        self [[ level.zmm_notify_fn ]]( "Vehicle", 0 );
        return;
    }
    level.fun_vehs[ level.fun_vehs.size ] = self.zmm.fun_v;
    self [[ level.zmm_notify_fn ]]( "Vehicle", 1 );
}
