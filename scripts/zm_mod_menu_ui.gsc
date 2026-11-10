// FuzMenu UI extras: weapon picture data, boss bar data, typed round jump, saved spots.
// Drawn by zm_mod_menu_post.lua through the dvars zmm_pic, zmm_boss, zmm_type and zmm_typed.
#using scripts\common\utility;

#namespace zm_mod_menu_ui;

autoexec ui_init()
{
    if ( !utility::iszm() )
    {
        return;
    }
    // the Lua can only write dvars that exist: zmm_typed is written by the Lua, the others are read
    setdvar( @"zmm_pic", "" );
    setdvar( @"zmm_boss", "" );
    setdvar( @"zmm_type", "0" );
    setdvar( @"zmm_typed", "" );
    level.ui_pic_last = "";
    level.ui_boss_out = "";
    level thread ui_wait_menu();
}

function ui_wait_menu()
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
    level.zmm_ext[ "ui_type" ] = &ui_type_round;
    level.zmm_ext[ "ui_spot_save" ] = &ui_spot_save;
    level.zmm_ext[ "ui_spot_go" ] = &ui_spot_go;
    level.zmm_on_render = &ui_on_render;

    [[ level.zmm_add_page ]]( "XSpots", "SAVED SPOTS", [
        [ "Save spot 1", 10, "ui_spot_save", 1 ],
        [ "Save spot 2", 10, "ui_spot_save", 2 ],
        [ "Save spot 3", 10, "ui_spot_save", 3 ],
        [ "Save spot 4", 10, "ui_spot_save", 4 ],
        [ "Save spot 5", 10, "ui_spot_save", 5 ],
        [ "Go to spot 1", 10, "ui_spot_go", 1 ],
        [ "Go to spot 2", 10, "ui_spot_go", 2 ],
        [ "Go to spot 3", 10, "ui_spot_go", 3 ],
        [ "Go to spot 4", 10, "ui_spot_go", 4 ],
        [ "Go to spot 5", 10, "ui_spot_go", 5 ],
        [ "Back", 1, "" ]
    ] );
    level thread ui_boss_loop();
}

// ---------------------------------------------------------------- weapon picture

// line|ref|label of the selected weapon row, "" on any other row; written only when it changes
function ui_on_render( entry, line )
{
    pic = "";
    if ( isdefined( entry ) && entry[ 1 ] == 8 && isstring( entry[ 2 ] ) )
    {
        pic = line + "|" + entry[ 2 ] + "|" + entry[ 0 ];
    }
    if ( pic == level.ui_pic_last )
    {
        return;
    }
    level.ui_pic_last = pic;
    setdvar( @"zmm_pic", pic );
}

// ---------------------------------------------------------------- boss bar

// "Boss|pct" for a live map boss; leaves the dvar alone while another writer owns it
function ui_boss_loop()
{
    level endon( "game_ended" );
    for ( ;; )
    {
        wait 0.25;
        level.ui_boss_now = getdvar( @"zmm_boss" );
        if ( level.ui_boss_now != "" && level.ui_boss_now != level.ui_boss_out )
        {
            level.ui_boss_out = "";
            continue;
        }
        level.ui_boss_val = ui_boss_text();
        if ( level.ui_boss_val != level.ui_boss_now )
        {
            level.ui_boss_out = level.ui_boss_val;
            setdvar( @"zmm_boss", level.ui_boss_val );
        }
    }
}

function ui_boss_text()
{
    team = isdefined( level.zombie_team ) ? level.zombie_team : "team_two_hundred";
    foreach ( ai in getaiarray( team ) )
    {
        if ( isdefined( ai ) && isalive( ai ) && ai.var_e4312c2c1a4a2190 === "boss" && isdefined( ai.maxhealth ) && ai.maxhealth > 0 && isdefined( ai.health ) )
        {
            pct = int( ai.health * 100 / ai.maxhealth );
            if ( pct < 1 )
            {
                pct = 1;
            }
            if ( pct > 100 )
            {
                pct = 100;
            }
            return "Boss|" + pct;
        }
    }
    return "";
}

// ---------------------------------------------------------------- typed round jump

// the Lua shows the typed text while zmm_type is "1" and writes zmm_typed "ok|<text>" on Enter or "x" on Esc
function ui_type_round( unused )
{
    if ( !istrue( self [[ level.zmm_is_host_fn ]]() ) )
    {
        self [[ level.zmm_notify_fn ]]( "Host only", 0 );
        return;
    }
    if ( istrue( level.ui_typing ) )
    {
        return;
    }
    level.ui_typing = 1;
    setdvar( @"zmm_typed", "" );
    setdvar( @"zmm_type", "1" );
    level.ui_ty_left = 600;
    level.ui_ty_got = "";
    while ( level.ui_ty_left > 0 && level.ui_ty_got == "" && isdefined( self ) )
    {
        wait 0.05;
        level.ui_ty_left--;
        level.ui_ty_got = getdvar( @"zmm_typed" );
    }
    setdvar( @"zmm_type", "0" );
    setdvar( @"zmm_typed", "" );
    level.ui_typing = 0;
    if ( !isdefined( self ) )
    {
        return;
    }
    level.ui_ty_target = self ui_type_target( level.ui_ty_got );
    if ( level.ui_ty_target < 1 )
    {
        if ( !( level.ui_ty_got == "x" ) )
        {
            self [[ level.zmm_notify_fn ]]( "Round jump", 0 );
        }
        return;
    }
    self [[ level.zmm_notify_fn ]]( "Round jump", self [[ level.zmm_jump_round_fn ]]( level.ui_ty_target ) );
}

// "ok|272" absolute, "ok|+5" / "ok|-5" relative to the current round; 0 when nothing valid was typed
function ui_type_target( got )
{
    // self fields, not locals: locals can read undefined after a call in BO7
    self.ui_ty_parts = strtok( got, "|" );
    if ( self.ui_ty_parts.size < 2 || !( self.ui_ty_parts[ 0 ] == "ok" ) || self.ui_ty_parts[ 1 ].size == 0 )
    {
        return 0;
    }
    self.ui_ty_text = self.ui_ty_parts[ 1 ];
    self.ui_ty_sign = getsubstr( self.ui_ty_text, 0, 1 );
    self.ui_ty_val = 0;
    if ( self.ui_ty_sign == "+" || self.ui_ty_sign == "-" )
    {
        if ( self.ui_ty_text.size < 2 )
        {
            return 0;
        }
        self.ui_ty_n = int( getsubstr( self.ui_ty_text, 1 ) );
        self.ui_ty_val = self [[ level.zmm_round_fn ]]();
        if ( self.ui_ty_sign == "+" )
        {
            self.ui_ty_val += self.ui_ty_n;
        }
        else
        {
            self.ui_ty_val -= self.ui_ty_n;
        }
    }
    else
    {
        self.ui_ty_val = int( self.ui_ty_text );
    }
    if ( self.ui_ty_val < 1 )
    {
        return 0;
    }
    if ( self.ui_ty_val > 9999 )
    {
        self.ui_ty_val = 9999;
    }
    return self.ui_ty_val;
}

// ---------------------------------------------------------------- saved spots (nengine_store kronos/fuzmenu/ui_spots.json)

function ui_spot_key( slot )
{
    map = isdefined( level.mapname ) ? level.mapname : level.script;
    return map + "_" + slot;
}

function ui_spot_save( slot )
{
    self.ui_spot_str = int( self.origin[ 0 ] ) + "," + int( self.origin[ 1 ] ) + "," + int( self.origin[ 2 ] ) + "," + int( self getplayerangles()[ 1 ] );
    nengine_store_load( "fuzmenu", "ui_spots" );
    nengine_store_set( "fuzmenu", ui_spot_key( slot ), self.ui_spot_str );
    nengine_store_save( "fuzmenu", "ui_spots" );
    self [[ level.zmm_notify_fn ]]( "Spot saved", 1 );
}

function ui_spot_go( slot )
{
    nengine_store_load( "fuzmenu", "ui_spots" );
    self.ui_spot_str = nengine_store_get( "fuzmenu", ui_spot_key( slot ) );
    if ( !isdefined( self.ui_spot_str ) || !isstring( self.ui_spot_str ) || self.ui_spot_str == "" )
    {
        self [[ level.zmm_notify_fn ]]( "Empty spot", 0 );
        return;
    }
    self.ui_spot_p = strtok( self.ui_spot_str, "," );
    if ( self.ui_spot_p.size < 4 )
    {
        self [[ level.zmm_notify_fn ]]( "Empty spot", 0 );
        return;
    }
    self [[ level.zmm_teleport_fn ]]( ( int( self.ui_spot_p[ 0 ] ), int( self.ui_spot_p[ 1 ] ), int( self.ui_spot_p[ 2 ] ) ), ( 0, int( self.ui_spot_p[ 3 ] ), 0 ) );
}
