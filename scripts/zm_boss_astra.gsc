#using scripts\common\utility;
#using script_733fd6f06f5f7c21;
#using script_7ef53ef2a48b73fc;

// Astra Malorum only: links against the map's boss scripts, so it does not load on other maps
autoexec zm_boss_astra_init()
{
    level.zmm_boss_astra = 1;
    level thread zm_boss_astra_wait();
}

// zm_mod_menu notifies this after its quest jump; same start as the map's devgui "start boss"
zm_boss_astra_wait()
{
    for ( ;; )
    {
        level waittill( "zmm_boss_astra" );
        // the quest jump does not reach the melody end: run its skip callback (flags + the 5 pillars the boss summon uses)
        level thread namespace_43a44122837a58c7::function_e71c6b59bfc4b3c6( 1 );
        for ( i = 0; i < 10 && !( isdefined( level.ruby_mq.var_e2f32ef1fd6fc6d3 ) && level.ruby_mq.var_e2f32ef1fd6fc6d3.size == 5 ); i++ )
        {
            wait 0.5;
        }
        if ( !( isdefined( level.ruby_mq.var_e2f32ef1fd6fc6d3 ) && level.ruby_mq.var_e2f32ef1fd6fc6d3.size == 5 ) )
        {
            iprintlnbold( "^1Boss: pillars missing" );
        }
        namespace_60b3bdcc70f79fc6::function_36488e0e5a90d20f( "ruby_boss_triggered" );
        // makes the boss start open all doors and teleport everyone to zone_temple (only other use: the devgui round-30 setup)
        level.var_8bd966e8e0c1bbaa = 1;
        iprintlnbold( "^3Boss: starting" );
        level thread namespace_8e068254785149ca::function_780ddb41e796b027();
    }
}
