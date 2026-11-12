#using script_c1369b1abe9a0d1;
#using script_5aa50822d5a27fae;
#using script_40912451a2502514;

// Totenreich only: links against the map's Viking helmet script, so it does not load on other maps
autoexec zm_helmets_locust_init()
{
    // the map's side quests (helmets, gnome form...) only set up when this dvar is on (playlist side content);
    // it is read by their system init, which runs after the autoexecs
    setdvar( @"hash_427ebffc772911dd", 1 );
    level.zmm_helmet_fn = &zm_helmet_give;
}

// marks a quest step done like the map's own save restore: the quest then runs its setup in "skipped" mode
zm_helmet_step_done( quest, step )
{
    if ( !zm_quest::function_81d3aa805b848ed8( quest, step ) )
        zm_quest::function_e65609834444650c( zm_quest::function_878e500f7d327f32( quest, step ), 1 );
}

// self = player; id "01" to "04": the map's own pickup (a helmet already worn drops to the ground, like a swap)
zm_helmet_give( id )
{
    self namespace_af40524476e775e4::function_be049f87a535cb47( id );
    // the helmet powers also need the side quest steps (sub-steps of parallel steps, so no quest jump);
    // own thread: if the quest code errors, the helmet stays given
    if ( !isdefined( level.zmm_helmet_quest ) )
    {
        level.zmm_helmet_quest = 1;
        self thread zm_helmet_quests();
    }
    // gnome form straight away too, in case the quest link is not there yet
    if ( id == "02" )
    {
        s = spawnstruct();
        s.var_5b53f19c893758d7 = self;
        namespace_a472b557a1093c2e::function_98851f234097ec14( s );
    }
}

zm_helmet_quests()
{
    helmets = #"hash_e004eacc72faecc8";
    // every step, in registration order (sub-steps included: a done parent skips them already)
    steps = [ #"hash_9a04796b4badfc6c", #"hash_eabbf2a5d557394b", #"hash_8bc86c90ba8b24e6", #"hash_fc7784e7cbab98f0", #"hash_c077c657dc228dbc", #"hash_eabbf3a5d5573afe", #"hash_6c7535e070b12000", #"hash_cae50793bacd1cf2", #"hash_eabbf4a5d5573cb1", #"hash_97614a87dd1e534f", #"hash_135604eccd97f7c4", #"hash_a3fc4d1e6706df9e", #"hash_eabbf5a5d5573e64", #"hash_cc1e3c63eeebb950", #"hash_2735a18ead53ba04" ];
    foreach ( step in steps )
        zm_helmet_step_done( helmets, step );
    // gnome quest step 1 done: step 2 starts and links helmet 02 to the gnome form
    zm_helmet_step_done( #"hash_1cf7ef91edc75b52", #"hash_4be629d8287cef13" );
}
