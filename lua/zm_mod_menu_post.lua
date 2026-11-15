-- Draws zm_mod_menu (GSC) with native LUI text. The GSC writes the open page into the zmm_view
-- dvar and this script redraws it: GSC HUD text (settext) showed new lines late.
-- View: ZMM|theme|right|title|cursor|rows|position|row1|...|END, each row = marker + label
-- (">" submenu, "+" toggle on, "-" toggle off, anything else plain).
local C=rawget(_G,"CLUA")
local H=rawget(_G,"xhash") or rawget(_G,"PushXHash") or (type(C)=="table" and C.PushXHash)
local HD=rawget(_G,"xhashdvar") or rawget(_G,"PushXHashDvar") or (type(C)=="table" and C.PushXHashDvar)
if type(H)~="function" or type(HD)~="function" then return end
local function cachedHash(native)
    local cache={}
    return function(name)
        local value=cache[name]
        if value==nil then value=native(name);cache[name]=value end
        return value
    end
end
H,HD=cachedHash(H),cachedHash(HD)
local old=rawget(_G,"ZmmMenuView")
if old then old.enabled=false;if old.clear then pcall(old.clear) end end
local S={enabled=true,ticks=0,q={},cgen=0}
rawset(_G,"ZmmMenuView",S)

-- sizes match the PNGs in images/ (cap 440x16, pill 428x34)
local W,ROW,VIS,CAP,PAD=440,34,12,16,6
local ROWS_TOP=78
local THEMES={0x0099ff,0xff3333,0x33ff59,0xb34dff,0xff9900,0xffd933}
-- Aether look: second colour per theme (cursor edge, corners, selected icon, sparks)
local THEMES2={0x5ef0ff,0xff9a3d,0x3dffd0,0x3de8ff,0xffe14d,0xffffff}
local PANEL,TEXT,DIM=0x111214,0xa8acb3,0x6b6f76
local GLASS,ROWTXT,TRACK_OFF,MAGENTA=0x080d18,0xc9d1de,0x2a3346,0xff3df0
-- main page labels (FR and EN) -> Assets/Images/fuzmenu_i_<icon>.png
local ICONS={["Joueur"]="player",["Player"]="player",["OP Mode"]="op",["Teleports"]="teleport",["Teleportations"]="teleport",
    ["Armes"]="gun",["Weapons"]="gun",["Co-op"]="player",["Desactiver tous les mods"]="close",["Disable all mods"]="close",["Donner une arme"]="gun",["Give a weapon"]="gun",["Armes miracles"]="wonder",["Wonder weapons"]="wonder",
    ["Options de tir"]="fire",["Shooting options"]="fire",["Degats"]="damage",["Damage"]="damage",
    ["Ameliorer"]="upgrade",["Upgrade"]="upgrade",["Atouts"]="perks",["Perks"]="perks",["Gobblegums"]="gums",
    ["Points & scrap"]="money",["Zombies"]="zombies",["Manches"]="rounds",["Rounds"]="rounds",["Bonus"]="powerups",
    ["Speedrun"]="rounds",["Monde"]="world",["World"]="world",["Forge"]="forge",["Old School Zombies"]="oldschool",
    ["Parametres"]="settings",["Settings"]="settings",["Fermer"]="close",["Close"]="close",
    ["Game modes & rules"]="rounds",["Fun & chaos"]="powerups"}

local function plainIndex(object,key) return object[key] end
local function hashedIndex(object,key) return object[H(key)] end
local function get(object,key)
    if object==nil then return nil end
    local plain,value=pcall(plainIndex,object,key)
    if plain and value~=nil then return value end
    local ok,hashed=pcall(hashedIndex,object,key)
    if ok then return hashed end
    return nil
end
local function invoke(object,key,...)
    local f=get(object,key)
    if type(f)=="function" then return f(...) end
end
local function call(object,key,...)
    local f=get(object,key)
    if type(f)=="function" then return f(object,...) end
end
local function read(name)
    local value=invoke(rawget(_G,"Dvar"),"GetDvarString",HD(name))
    if value~=nil then return tostring(value) end
end
local function inMatch()
    return invoke(rawget(_G,"Engine"),"InFrontend")==false
end

local function newElement(kind)
    local f=get(get(rawget(_G,"LUI"),kind),"new")
    if type(f)~="function" then error("Native "..kind.." constructor unavailable",0) end
    return f()
end
local function passive(element)
    call(element,"SetHandleMouse",false);call(element,"setFocusable",false)
end
local function ease(name)
    local E=get(rawget(_G,"LUI"),"EASING")
    return get(E,name) or get(E,"outQuadratic") or get(E,"linear")
end
-- BO7 has no SetTop/SetLeft: SetAnchorsAndPosition takes the duration and easing itself (as the Kronos HUDs do)
local function place(node,x,y,w,h,duration,easing)
    if duration and duration>0 then
        call(node,"SetAnchorsAndPosition",0,1,0,1,x,x+w,y,y+h,duration,ease(easing or "outCubic"))
    else
        call(node,"SetAnchorsAndPosition",0,1,0,1,x,x+w,y,y+h)
    end
end
local function fade(node,from,to,duration)
    if from then call(node,"SetAlpha",from) end
    call(node,"SetAlpha",to,duration)
end
-- timed steps (LUI has no setTimeout): fn runs after t ticks of ~16 ms; cascade steps die when a newer cascade starts
local function later(t,fn,cascade)
    S.q[#S.q+1]={S.ticks+t,cascade and S.cgen,fn}
end
local seed=12345
local function rnd(a,b) seed=seed*16807%2147483647;return a+seed%(b-a+1) end
local function rectangle(parent,x,y,w,h,rgb,alpha)
    local element=newElement("UIImage")
    place(element,x,y,w,h)
    call(element,"SetRGB",rgb);call(element,"SetAlpha",alpha)
    passive(element);call(parent,"addElement",element)
    return element
end
local function label(parent,x,y,w,h,size,rgb,bold)
    local element=newElement("UIStyledText")
    place(element,x,y,w,h)
    local fonts=rawget(_G,"FONT_HANDLE")
    local font=(bold and get(fonts,"PrimaryBold")) or get(fonts,"TertiaryMedium") or get(fonts,"SecondaryRegular") or get(fonts,"PrimaryBold") or get(fonts,"PrimaryRegular")
    if font then call(element,"SetFont",font) end
    call(element,"SetFontSize",size*(tonumber(rawget(_G,"_PT")) or 1))
    call(element,"SetRGB",rgb);call(element,"SetAlignment",0)
    passive(element);call(parent,"addElement",element)
    return element
end

-- PNG from kronos/Assets/Images, loaded like Project Nexus loads its art
local function material(name)
    S.materials=S.materials or {}
    if S.materials[name]==nil then
        local register=rawget(_G,"RegisterMaterial")
        local asset=rawget(_G,"xhashasset") or get(C,"PushXHashAsset")
        local ok,value=false,nil
        if type(register)=="function" then
            ok,value=pcall(function()return register(type(asset)=="function" and asset(name) or name)end)
        end
        S.materials[name]=ok and value or false
    end
    return S.materials[name] or nil
end
-- white PNG tinted rgb; a plain rectangle when the picture is missing
local function picture(parent,name,x,y,w,h,rgb,alpha)
    local element=rectangle(parent,x,y,w,h,rgb,alpha)
    local mat=material(name)
    if mat then call(element,"setImage",mat) end
    return element
end

local function clear()
    if S.frame then pcall(call,S.frame,"closeTree") end
    S.frame=nil;S.parent=nil;S.last=nil;S.visible=false;S.q={};S.prev=nil
end
local function hide()
    if S.frame and S.visible then call(S.frame,"SetAlpha",0,160);S.q={} end
    S.visible=false;S.last=nil
end
local function parentFor(root)
    if type(get(root,"addElement"))~="function" then return nil end
    for _=1,16 do
        local parent=call(root,"getParent")
        if not parent or parent==root then break end
        root=parent
    end
    return root
end
local function displayParent()
    return parentFor(invoke(get(rawget(_G,"LUI"),"UIRoot"),"GetRootForControllerIndex",0))
end

-- weapon picture box beside the panel (zm_mod_menu_ui.gsc writes zmm_pic = "line|ref|label")
-- weapon pictures: images/fuzmenu_w_<class>_<name>.png
local BW,BH=240,52
local PIC_H=150
local GUN_PICS={}
for n in ("ar_albatross ar_condor ar_eagle ar_egret ar_emu ar_falcon ar_hawk ar_heron ar_kite ar_kiwi ar_macaw ar_vulture ar_wren dm_kara dm_oman dm_samar dm_scotia dm_solomon la_fang la_polis lm_hades lm_hildr lm_typhon lm_zeus me_ballisticknife me_castor me_knife me_maru me_nashira me_saiph me_shockbaton me_wasat pi_alcor pi_atlas pi_orion pi_timir sh_akita sh_corso sh_husky sh_shepherd sm_bear sm_bengal sm_civet sm_cobra sm_gecko sm_hyena sm_komodo sm_marmot sm_orca sm_otter sm_puma sm_serval sm_zebra sn_aden sn_baltic sn_caspian sn_coral sn_drake ww_firefly ww_hornet ww_locust ww_mantis ww_raygun ww_raygunmark2 ww_ruby ww_scarab ar_finch sm_mammoth sm_stoat sh_terrier dm_tasman ww_sundergat ar_coslo723 ar_aking74 ar_clove ar_fable ar_rmary2 ar_asvalor ar_able18 ar_love85 ar_tbaker ar_kent ar_gilroy ar_fresno ar_aspen ar_milan sm_geasy9 sm_safox sm_chuck9 sm_sroger3 sm_roger31 sm_pparis90 sm_saug sm_perth sm_schuck sm_lisbon sm_mpug40 lm_aroger10 lm_puncle21 lm_ksugar58 lm_uxray lm_mesa sh_moslo500 sh_olove sh_uncle12 sh_jhavana dm_sroger25 dm_aeasy dm_sgeorge550 dm_falove dm_svalor dm_erie sn_ultiger sn_droger sn_love96 sn_mary82 sn_hugo pi_paris30 pi_usugar9 pi_mable pi_stiger pi_pyork la_pable3 la_stisaac me_bat me_cleaver me_drill me_skateboard me_katanas me_sais me_nunchaku me_bostaff me_keene me_pickaxe me_bgloves me_csaw sl_blauncher sl_napa sl_wand"):gmatch("%S+") do GUN_PICS[n]=true end
local function buildPic(frame)
    local box=newElement("UIElement")
    call(box,"SetAlpha",0);passive(box);call(frame,"addElement",box)
    S.pic=box;S.picKey=nil;S.picOn=false
    S.picBack=rectangle(box,0,0,BW,BH,GLASS,.92)
    S.picEdge=rectangle(box,0,0,4,BH,THEMES[1],1)
    S.picLine=rectangle(box,4,BH-2,BW-4,2,THEMES[1],.5)
    S.picImage=rectangle(box,16,8,BW-28,(BW-28)/2,0xffffff,0)
    S.picName=label(box,16,16,BW-28,20,16,0xffffff,true)
end

local function build(parent)
    clear()
    local frame=newElement("UIElement")
    call(frame,"SetAlpha",0);call(frame,"setPriority",1000);passive(frame);call(parent,"addElement",frame)
    S.frame=frame;S.parent=parent
    -- groups fade or move as one (header, cursor, each row, footer)
    local function group(owner)
        local g=newElement("UIElement")
        place(g,0,0,W,10);passive(g);call(owner,"addElement",g)
        return g
    end
    -- glass panel: halo behind, rounded caps + stretched body, scanlines, a sweep band, 1 px glowing edge, corner brackets
    S.halo=picture(frame,"fuzmenu_a_halo",-40,-40,W+80,100,THEMES[1],.5)
    S.capTop=picture(frame,"fuzmenu_cap_t",0,0,W,CAP,GLASS,.9)
    S.body=rectangle(frame,0,CAP,W,10,GLASS,.9)
    S.capBottom=picture(frame,"fuzmenu_cap_b",0,0,W,CAP,GLASS,.9)
    S.scan=picture(frame,"fuzmenu_a_scan",0,CAP,W,10,0xffffff,.035)
    S.sweep=picture(frame,"fuzmenu_a_sweep",0,CAP,W,48,THEMES2[1],0)
    S.edge=group(frame)
    S.edgeT=picture(S.edge,"fuzmenu_a_edge_t",0,0,W,CAP,THEMES[1],1)
    S.edgeB=picture(S.edge,"fuzmenu_a_edge_b",0,0,W,CAP,THEMES[1],1)
    S.sideL=rectangle(S.edge,0,CAP,1,10,THEMES[1],1)
    S.sideR=rectangle(S.edge,W-1,CAP,1,10,THEMES[1],1)
    S.corners={}
    for k,c in ipairs({"tl","tr","bl","br"}) do S.corners[k]=picture(S.edge,"fuzmenu_a_corner_"..c,0,0,16,16,THEMES2[1],1) end
    S.head=group(frame)
    S.brand=label(S.head,20,14,200,16,13,THEMES[1])
    call(S.brand,"setText","FuzMenu")
    S.count=label(S.head,W-80,14,64,16,13,DIM)
    -- RGB-split copies of the title, shown on a page change
    S.titleC=label(S.head,20,32,W-40,30,26,THEMES2[1],true)
    S.titleM=label(S.head,20,32,W-40,30,26,MAGENTA,true)
    S.title=label(S.head,20,32,W-40,30,26,0xffffff,true)
    S.div=picture(S.head,"fuzmenu_a_line",20,66,W-40,4,THEMES[1],.7)
    -- cursor: slow ghost bar, then the bar with its bright left edge and a glint
    S.ghost=picture(frame,"fuzmenu_a_bar",PAD,ROWS_TOP,W-2*PAD,ROW,THEMES[1],.3)
    S.cur=group(frame)
    S.bar=picture(S.cur,"fuzmenu_a_bar",0,0,W-2*PAD,ROW,THEMES[1],1)
    S.barEdge=picture(S.cur,"fuzmenu_a_baredge",0,0,8,ROW,THEMES2[1],1)
    S.glint=picture(S.cur,"fuzmenu_a_glint",0,0,80,ROW,0xffffff,0)
    S.flash=picture(frame,"fuzmenu_pill",PAD,ROWS_TOP,W-2*PAD,ROW,0xffffff,0)
    S.line={}
    for i=1,VIS do
        local r={}
        r.box=group(frame)
        place(r.box,0,ROWS_TOP+(i-1)*ROW,W,ROW)
        r.icon=rectangle(r.box,20,8,18,18,TEXT,0)
        r.label=label(r.box,48,6,W-130,ROW-10,18,ROWTXT)
        r.chev=picture(r.box,"fuzmenu_i_chevron",W-34,10,14,14,DIM,0)
        r.track=picture(r.box,"fuzmenu_switch",W-52,9,30,16,TRACK_OFF,0)
        r.glow=picture(r.box,"fuzmenu_a_dot",W-56,5,24,24,THEMES2[1],0)
        r.knob=picture(r.box,"fuzmenu_knob",W-50,11,12,12,0xffffff,0)
        S.line[i]=r
    end
    S.ring=picture(frame,"fuzmenu_a_ring",0,0,12,12,THEMES2[1],0)
    S.slices={}
    for k=1,3 do S.slices[k]=rectangle(frame,0,0,W,3,k==2 and MAGENTA or THEMES2[1],0) end
    -- scroll position bar and key help
    S.foot=group(frame)
    S.track=rectangle(S.foot,20,0,W-40,3,0x1a2233,1)
    S.fill=rectangle(S.foot,20,0,3,3,THEMES[1],1)
    S.footer=label(S.foot,20,12,W-40,18,13,DIM)
    S.footer2=label(S.foot,20,30,W-40,18,13,DIM)
    S.boot=picture(frame,"fuzmenu_a_line",0,0,W,4,THEMES[1],0)
    S.dots={}
    for k=1,6 do S.dots[k]=picture(frame,"fuzmenu_a_dot",0,0,6,6,THEMES2[1],0) end
    S.pad=nil
    pcall(buildPic,frame)
end

-- weapon refs (sat_lm_typhon) become the game's localized name, as ProjectNexus does
local names={}
local function weaponName(ref)
    local name=ref:match("^sat_[a-z]+_([a-z0-9]+)$") or ref:match("^t10_[a-z]+_p%d+_([a-z0-9]+)$")
    if not name then return ref end
    if names[ref] then return names[ref] end
    local ok,raw=pcall(invoke,rawget(_G,"WEAPON"),"GetName",ref)
    if ok and raw~=nil then
        local okL,value=pcall(invoke,rawget(_G,"Engine"),"Localize",raw)
        if okL and type(value)=="string" and value~="" and value~=ref and not value:match("^#x") and not value:lower():match("^undefined") then name=value
        elseif type(raw)=="string" and raw~="" and raw~=ref and not raw:match("^#x") and not raw:lower():match("^undefined") then name=raw end
    end
    names[ref]=name;return name
end

local function showPic(value)
    if not S.pic or value==S.picKey then return end
    S.picKey=value
    local line,ref,name=value:match("^(%d+)|([^|]*)|(.*)$")
    if not line then
        if S.picOn then call(S.pic,"SetAlpha",0,80) end
        S.picOn=false;return
    end
    local accent=S.theme or THEMES[1]
    local key=ref:match("^sat_([a-z]+_[a-z0-9]+)_[mz][pm]$") or ref:match("^sat_([a-z]+_[a-z0-9]+)$") or (ref=="sundergat" and "ww_sundergat")
    if not key then local c,n=ref:match("^t10_([a-z]+)_p%d+_([a-z0-9]+)");key=c and c.."_"..n end
    local mat=key and GUN_PICS[key] and material("fuzmenu_w_"..key)
    local h=mat and PIC_H or BH
    local x=S.right and -BW-12 or W+12
    local y=math.max(0,ROWS_TOP+tonumber(line)*ROW+ROW/2-h/2)
    if S.picOn and S.picSide==S.right and S.picH==h then place(S.pic,x,y,BW,h,90) else place(S.pic,x,y,BW,h) end
    S.picSide,S.picH=S.right,h
    place(S.picBack,0,0,BW,h);place(S.picEdge,0,0,4,h);place(S.picLine,4,h-2,BW-4,2)
    call(S.picEdge,"SetRGB",accent);call(S.picLine,"SetRGB",accent)
    call(S.picName,"setText",(weaponName((name:gsub("%^%d","")))))
    place(S.picName,16,h-36,BW-28,20)
    if mat then call(S.picImage,"setImage",mat) end
    call(S.picImage,"SetAlpha",mat and 1 or 0)
    if not S.picOn then call(S.pic,"SetAlpha",1,120) end
    S.picOn=true
end

-- boss health bar from zmm_boss = "Name|pct" (map boss scan)
local BOSS_W=460
local function bossBar(value,paused)
    local name,pct=value:match("^(.-)|(%d+)$")
    if paused or not name then
        if S.boss then pcall(call,S.boss,"closeTree") end
        S.boss=nil;S.bossText=nil;return
    end
    local parent=displayParent()
    if not parent then return end
    if not S.boss or S.bossParent~=parent then
        if S.boss then pcall(call,S.boss,"closeTree") end
        local bar=newElement("UIElement")
        call(bar,"setPriority",1000);passive(bar);call(parent,"addElement",bar)
        call(bar,"SetAnchorsAndPosition",.5,.5,0,1,-BOSS_W/2,BOSS_W/2,62,110)
        rectangle(bar,0,0,BOSS_W,48,PANEL,.88)
        rectangle(bar,0,0,BOSS_W,2,0xe0402a,1)
        S.bossName=label(bar,14,7,BOSS_W-100,18,16,0xffffff,true)
        S.bossPct=label(bar,BOSS_W-70,7,56,18,16,0xe0402a,true)
        rectangle(bar,14,31,BOSS_W-28,8,0x2a2c30,1)
        S.bossFill=rectangle(bar,14,31,BOSS_W-28,8,0xe0402a,1)
        -- quarter notches over the fill
        for i=1,3 do rectangle(bar,14+math.floor((BOSS_W-28)*i/4),31,2,8,PANEL,1) end
        call(bar,"SetAlpha",1)
        S.boss=bar;S.bossParent=parent;S.bossText=nil
    end
    if value==S.bossText then return end
    S.bossText=value
    local p=math.max(0,math.min(100,tonumber(pct) or 0))
    call(S.bossName,"setText",name~="" and name or "Boss")
    call(S.bossPct,"setText",p.."%")
    place(S.bossFill,14,31,math.max(1,math.floor((BOSS_W-28)*p/100)),8)
end

-- typed EE step's name, from the "|" list GSC sends after "s<count>:" (the speedrun splits)
local function eeName(buf)
    local i=tonumber(buf or "")
    if not i or not S.typeMap then return "" end
    local k=0
    for n in S.typeMap:gmatch("[^|]+") do k=k+1;if k==i then return n end end
    return ""
end

-- round / EE step number prompt while zmm_type is not "0"; keys are read in the QueueInput wrapper below
local function typePrompt(on,paused)
    if not on or paused then
        if S.typeBox then pcall(call,S.typeBox,"closeTree") end
        S.typeBox=nil;S.typeName=nil;return
    end
    local parent=displayParent()
    if not parent or (S.typeBox and S.typeParent==parent) then return end
    if S.typeBox then pcall(call,S.typeBox,"closeTree") end
    local box=newElement("UIElement")
    call(box,"setPriority",1001);passive(box);call(parent,"addElement",box)
    -- zmm_type "s<count>:<name|name..>" is the EE step prompt (one more line: the typed step's name), "1" the round prompt
    local steps,map=S.typeMode:match("^s(%d+):?(.*)$")
    S.typeMap=map
    local h=steps and 102 or 84
    call(box,"SetAnchorsAndPosition",.5,.5,.5,.5,-190,190,40,40+h)
    rectangle(box,0,0,380,h,PANEL,.95)
    rectangle(box,0,h-2,380,2,S.theme or THEMES[1],1)
    call(label(box,16,10,348,16,13,DIM),"setText",steps and "JUMP TO EASTER EGG STEP" or "JUMP TO ROUND")
    S.typeText=label(box,16,28,348,30,26,0xffffff,true)
    S.typeName=steps and label(box,16,60,348,16,14,S.theme or THEMES[1],true) or nil
    call(label(box,16,h-22,348,16,12,DIM),"setText",steps and ("Step 1 to "..steps.."  (last = boss)    Enter / Esc") or "272 = that round    +5 / -5 = from now    Enter / Esc")
    call(box,"SetAlpha",1)
    S.typeBox=box;S.typeParent=parent
    call(S.typeText,"setText",(S.typeBuf or "").."_")
    if S.typeName then call(S.typeName,"setText",eeName(S.typeBuf)) end
end
local function typeInput(t)
    local buf=S.typeBuf or ""
    if t=="ok" or t=="x" then
        S.typeSent=true
        pcall(invoke,rawget(_G,"Dvar"),"SetDvarString",HD("zmm_typed"),t=="ok" and "ok|"..buf or "x")
        return
    elseif t=="bs" then buf=buf:sub(1,-2)
    elseif t=="+" or t=="-" then if buf=="" then buf=t end
    elseif #buf<5 then buf=buf..t end
    S.typeBuf=buf
    if S.typeText then call(S.typeText,"setText",buf.."_") end
    if S.typeName then call(S.typeName,"setText",eeName(buf)) end
end

-- shortcut: controller labels assume the default layout (Xbox names), upgrade if the game exposes the player's binds to Lua
local FOOTERS={
    ["0"]={"Arrows / RMB-LMB: Move    Enter / F: OK","Backspace / V: Back    Insert: Open"},
    ["1"]={"D-pad / LT-RT: Move    X (PS: Square): OK","R3: Back    LT + R3: Open"},
}

local function parse(text)
    if type(text)~="string" or #text>4096 then return nil end
    local f={};for field in (text.."|"):gmatch("(.-)|") do f[#f+1]=field end
    local n=tonumber(f[6])
    if f[1]~="ZMM" or not n or n<1 or n>VIS or #f~=n+8 or f[#f]~="END" then return nil end
    return f,n
end

-- panel parts between y=t and y=b (open unfolds it from the middle; page changes resize it)
local function panel(t,b,d)
    local mid=b-t-2*CAP
    place(S.halo,-40,t-40,W+80,b-t+80,d)
    place(S.capTop,0,t,W,CAP,d);place(S.edgeT,0,t,W,CAP,d)
    place(S.body,0,t+CAP,W,mid,d);place(S.scan,0,t+CAP,W,mid,d)
    place(S.sideL,0,t+CAP,1,mid,d);place(S.sideR,W-1,t+CAP,1,mid,d)
    place(S.capBottom,0,b-CAP,W,CAP,d);place(S.edgeB,0,b-CAP,W,CAP,d)
    place(S.corners[1],-4,t-4,16,16,d);place(S.corners[2],W-12,t-4,16,16,d)
    place(S.corners[3],-4,b-12,16,16,d);place(S.corners[4],W-12,b-12,16,16,d)
end
local function resetFx()
    for _,e in ipairs({S.sweep,S.glint,S.ring,S.flash,S.titleC,S.titleM,S.slices[1],S.slices[2],S.slices[3]}) do call(e,"SetAlpha",0) end
    for _,d in ipairs(S.dots) do call(d,"SetAlpha",0) end
end
-- title copies close in from -4/+4 px; divider stretches from the centre
local function titleFx()
    place(S.titleC,16,32,W-40,30);place(S.titleM,24,32,W-40,30)
    fade(S.titleC,.8,0,200);fade(S.titleM,.8,0,200)
    place(S.titleC,20,32,W-40,30,200);place(S.titleM,20,32,W-40,30,200)
    place(S.div,W/2,66,0,4);place(S.div,20,66,W-40,4,300)
end
-- three thin cyan/magenta slices jump twice, then fade
local function glitch()
    for _,s in ipairs(S.slices) do
        local function jump() place(s,rnd(-6,6),rnd(CAP,S.h-CAP-6),W,rnd(2,5)) end
        jump();call(s,"SetAlpha",.8)
        later(2,jump);later(4,jump);later(6,function() call(s,"SetAlpha",0,80) end)
    end
end
local function toggleFx(i,kx)
    local cx,cy=kx+6,ROWS_TOP+(i-1)*ROW+17
    place(S.ring,cx-6,cy-6,12,12);fade(S.ring,.9,0,320);place(S.ring,cx-22,cy-22,44,44,320)
    place(S.flash,PAD,ROWS_TOP+(i-1)*ROW,W-2*PAD,ROW);fade(S.flash,.35,0,220)
end

local function render(f,n)
    local ti=(tonumber(f[2]) or 0)+1
    local theme,second=THEMES[ti] or THEMES[1],THEMES2[ti] or THEMES2[1]
    local cursor=math.max(0,math.min(n-1,tonumber(f[5]) or 0))
    S.theme,S.right=theme,f[3]=="1"
    local fy=ROWS_TOP+n*ROW+10
    local h=fy+62
    -- GSC titles are upper case ("MENU PRINCIPAL"): shown as "Menu principal"
    local title=((f[4] or ""):lower():gsub("^%l",string.upper))
    local p=S.prev or {}
    local opening=not S.visible
    local paging=not opening and title~=p.title
    local resize=(not opening and p.h~=h) and 220 or nil
    S.h=h
    -- top edge stays put when the page length changes
    if f[3]=="1" then call(S.frame,"SetAnchorsAndPosition",1,0,.5,.5,-W-60,-60,-330,-330+h)
    else call(S.frame,"SetAnchorsAndPosition",0,1,.5,.5,60,60+W,-330,-330+h) end
    for _,e in ipairs({S.halo,S.edgeT,S.edgeB,S.sideL,S.sideR,S.brand,S.fill,S.div,S.bar,S.ghost,S.boot}) do call(e,"SetRGB",theme) end
    for _,e in ipairs({S.barEdge,S.sweep,S.ring,S.titleC,S.slices[1],S.slices[3],S.corners[1],S.corners[2],S.corners[3],S.corners[4]}) do call(e,"SetRGB",second) end
    for _,d in ipairs(S.dots) do call(d,"SetRGB",second) end
    if not opening then panel(0,h,resize) end
    place(S.foot,0,fy,W,60,resize)
    for _,e in ipairs({S.title,S.titleC,S.titleM}) do call(e,"setText",title) end
    local at,total=(f[7] or ""):match("(%d+)/(%d+)")
    call(S.count,"setText",at and string.format("%02d / %02d",tonumber(at),tonumber(total)) or "")
    local markers={}
    for i=1,VIS do
        local r=S.line[i]
        local shown,icon,marker=i<=n,nil,nil
        if shown then
            local row=f[i+7]
            marker=row:sub(1,1)
            local raw=(row:sub(2):gsub("%^%d",""))
            icon=ICONS[raw] and material("fuzmenu_i_"..ICONS[raw])
            local selected=i==cursor+1
            call(r.label,"setText",(weaponName(raw):gsub("^%l",string.upper)))
            call(r.label,"SetRGB",selected and 0xffffff or ROWTXT)
            -- selected text steps 6 px right
            local x=(icon and 48 or 20)+(selected and 6 or 0)
            if not opening and not paging and selected~=(i==(p.cursor or -1)+1) then place(r.label,x,6,W-130,ROW-10,140)
            else place(r.label,x,6,W-130,ROW-10) end
            if icon then call(r.icon,"setImage",icon);call(r.icon,"SetRGB",selected and second or TEXT) end
            call(r.chev,"SetRGB",selected and second or DIM)
            local on=marker=="+"
            call(r.track,"SetRGB",on and theme or (selected and 0x5d6b85 or TRACK_OFF))
            call(r.glow,"SetRGB",second)
            local kx=on and W-36 or W-50
            local was=p.markers and p.markers[i]
            if not opening and not paging and (was=="+" or was=="-") and (marker=="+" or marker=="-") and was~=marker then
                place(r.knob,kx,11,12,12,160,"outBack");place(r.glow,kx-6,5,24,24,160,"outBack")
                pcall(toggleFx,i,kx)
            else place(r.knob,kx,11,12,12);place(r.glow,kx-6,5,24,24) end
            markers[i]=marker
        end
        local toggle=shown and (marker=="+" or marker=="-")
        call(r.icon,"SetAlpha",icon and 1 or 0)
        call(r.chev,"SetAlpha",marker==">" and 1 or 0)
        call(r.track,"SetAlpha",toggle and 1 or 0)
        call(r.knob,"SetAlpha",toggle and 1 or 0)
        call(r.glow,"SetAlpha",marker=="+" and .6 or 0)
        if not (opening or paging) then call(r.box,"SetAlpha",shown and 1 or 0) end
    end
    -- rows slide in from +26 px, one every 2 ticks
    if opening or paging then
        S.cgen=S.cgen+1
        for i=1,VIS do
            local r,y=S.line[i],ROWS_TOP+(i-1)*ROW
            call(r.box,"SetAlpha",0)
            if i<=n then
                place(r.box,26,y,W,ROW)
                later((opening and 22 or 2)+(i-1)*2,function() place(r.box,0,y,W,ROW,230);call(r.box,"SetAlpha",1,230) end,true)
            end
        end
    end
    local cy=ROWS_TOP+cursor*ROW
    local fw=math.max(3,math.floor((W-40)*(tonumber(at) or 1)/math.max(1,tonumber(total) or 1)))
    if opening then
        place(S.cur,PAD,cy,W-2*PAD,ROW);place(S.ghost,PAD,cy,W-2*PAD,ROW);place(S.fill,20,0,fw,3)
    else
        place(S.cur,PAD,cy,W-2*PAD,ROW,140);place(S.ghost,PAD,cy,W-2*PAD,ROW,310)
        if cursor~=p.cursor then fade(S.count,.35,1,160);place(S.fill,20,0,fw,3,200) else place(S.fill,20,0,fw,3) end
    end
    if opening then
        -- a line stretches from the centre, the panel unfolds from it, then header, cursor and rows arrive
        call(S.frame,"SetAlpha",1,60)
        resetFx()
        for _,g in ipairs({S.head,S.cur,S.ghost,S.foot}) do call(g,"SetAlpha",0) end
        local mid=math.floor(h/2)
        panel(mid-CAP,mid+CAP)
        place(S.boot,W/2-1,mid-2,2,4);fade(S.boot,0,1,80);place(S.boot,0,mid-2,W,4,180)
        later(10,function() panel(0,S.h,260);call(S.boot,"SetAlpha",0,200) end)
        later(18,function() call(S.head,"SetAlpha",1,180);pcall(titleFx) end)
        later(22,function()
            call(S.cur,"SetAlpha",1,200);call(S.ghost,"SetAlpha",.3,260);call(S.foot,"SetAlpha",1,260)
            place(S.bar,0,0,2,ROW);place(S.bar,0,0,W-2*PAD,ROW,260)
        end)
    elseif paging then
        pcall(titleFx);pcall(glitch)
    end
    S.prev={title=title,cursor=cursor,markers=markers,h=h}
    S.visible=true
end

-- runs every tick while the menu is open: timed steps, then the idle loops
local function animate()
    local q=S.q;S.q={}
    for _,e in ipairs(q) do
        if e[2] and e[2]~=S.cgen then
        elseif S.ticks>=e[1] then pcall(e[3])
        else S.q[#S.q+1]=e end
    end
    if not S.frame or not S.h then return end
    local t=S.ticks
    -- halo and edge breathe (2.4 s round trip)
    if t%75==0 then
        local up=t%150==0
        call(S.halo,"SetAlpha",up and .75 or .35,1200)
        call(S.edge,"SetAlpha",up and .95 or .5,1200)
    end
    -- scan band down the panel every ~4 s
    if t%260==0 then
        place(S.sweep,0,CAP,W,48);call(S.sweep,"SetAlpha",.14)
        place(S.sweep,0,S.h-CAP-48,W,48,1600)
        later(90,function() call(S.sweep,"SetAlpha",0,200) end)
    end
    -- glint across the cursor bar every ~3 s
    if t%200==100 then
        place(S.glint,0,0,80,ROW);call(S.glint,"SetAlpha",.45)
        place(S.glint,W-2*PAD-80,0,80,ROW,800,"inOutSine")
        later(40,function() call(S.glint,"SetAlpha",0,150) end)
    end
    -- sparks rise along the side edges, one every ~0.5 s
    if t%34==0 then
        S.dot=(S.dot or 0)%#S.dots+1
        local d=S.dots[S.dot]
        local x=rnd(0,1)==0 and rnd(4,28) or rnd(W-34,W-10)
        local y=rnd(math.floor(S.h/2),S.h-20)
        place(d,x,y,6,6);fade(d,0,.7,500)
        place(d,x,y-rnd(60,110),6,6,3200)
        later(30,function() call(d,"SetAlpha",0,2200) end)
    end
end

-- start logo: the GSC sets zmm_logo to "1" once the host walks after the intro (Settings > Start logo)
-- fades in, stays about 3 s (ticks are ~16 ms), fades out; once per match
local function startLogo()
    if not S.logoAt then
        if read("zmm_logo")~="1" then return end
        local parent,mat=displayParent(),material("fuzmenu_logo")
        if not parent or not mat then return end
        S.logo=newElement("UIElement")
        call(S.logo,"setPriority",1001);passive(S.logo);call(parent,"addElement",S.logo)
        call(S.logo,"SetAnchorsAndPosition",.5,.5,.5,.5,-256,256,-470,-214)
        call(rectangle(S.logo,0,0,512,256,0xffffff,1),"setImage",mat)
        call(S.logo,"SetAlpha",0);call(S.logo,"SetAlpha",1,500)
        S.logoAt=S.ticks
    elseif S.logo and S.ticks-S.logoAt>250 then
        pcall(call,S.logo,"closeTree");S.logo=nil
    elseif S.logo and S.ticks-S.logoAt>190 and not S.logoOut then
        call(S.logo,"SetAlpha",0,600);S.logoOut=true
    end
end

local function tick()
    S.ticks=S.ticks+1
    -- the GSC writes dvars every 50 ms at most: a third of the rate while closed; %3==1 keeps the %30==1 zmm_lua beat below
    if not S.visible and S.ticks%3~=1 then return end
    if not inMatch() then if S.frame then clear() end;S.hud=nil;S.hudText=nil;S.big=nil;S.bigText=nil;S.logo=nil;S.logoAt=nil;S.logoOut=nil;pcall(bossBar,"",true);pcall(typePrompt,false);return end
    pcall(startLogo)
    -- tells the GSC this script runs, so it skips its own HUD
    if S.ticks%30==1 then
        local set=get(rawget(_G,"Dvar"),"SetDvarString")
        if type(set)=="function" and read("zmm_lua")~="1" then pcall(set,HD("zmm_lua"),"1") end
    end
    -- the GSC writes zmm_exec as "<command> <time>"; the first value seen is only remembered (stale from a past match)
    local exec=read("zmm_exec") or ""
    if S.exec==nil then S.exec=exec elseif exec~=S.exec then
        S.exec=exec
        local command=exec:match("^(.-) %d+$") or "noclip"
        -- IW-engine Lua takes (command[, controller]); Treyarch Lua takes (controller, command): try both
        local engine=rawget(_G,"Engine")
        for _,name in ipairs({"Exec","ExecNow"}) do
            local run=get(engine,name)
            if exec~="" and type(run)=="function" then
                local ok=pcall(run,command)
                if not ok then ok=pcall(run,0,command) end
                if ok then break end
            end
        end
    end
    -- the GSC "No recoil" row sets zmm_recoil to "1"/"0"; originals are kept to restore them
    local recoil=read("zmm_recoil") or ""
    if recoil~=(S.recoil or "") then
        S.recoil=recoil
        local setter=get(rawget(_G,"Dvar"),"SetDvarFloat")
        S.recoilOriginal=S.recoilOriginal or {}
        for _,name in ipairs({"bg_recoil_gunkick_scale","bg_recoil_viewkick_scale"}) do
            if recoil=="1" and S.recoilOriginal[name]==nil then S.recoilOriginal[name]=tonumber(read(name)) end
            local value=recoil=="1" and 0 or S.recoilOriginal[name]
            if value and type(setter)=="function" then pcall(setter,HD(name),value) end
        end
    end
    -- zombie counter / round timer line written by the GSC into zmm_hud
    local hud=read("zmm_hud") or ""
    if hud~=(S.hudText or "") then
        local parent=displayParent()
        if hud=="" then
            if S.hud then pcall(call,S.hud,"closeTree") end
            S.hud=nil;S.hudText=hud
        elseif parent then
            if not S.hud or S.hudParent~=parent then
                if S.hud then pcall(call,S.hud,"closeTree") end
                -- same structure as the menu: a prioritised container, then the text inside it
                S.hud=newElement("UIElement")
                call(S.hud,"setPriority",1000);passive(S.hud);call(parent,"addElement",S.hud)
                call(S.hud,"SetAnchorsAndPosition",.5,.5,0,1,-250,250,115,145)
                S.hudLabel=label(S.hud,0,0,500,26,20,0xffffff)
                call(S.hud,"SetAlpha",1)
                S.hudParent=parent
            end
            call(S.hudLabel,"setText",hud)
            S.hudText=hud
        end
    end
    -- Gun Game progress written by the GSC into zmm_gg, under the zmm_hud line
    local gg=read("zmm_gg") or ""
    if gg~=(S.ggText or "") then
        local parent=displayParent()
        if gg=="" then
            if S.gg then pcall(call,S.gg,"closeTree") end
            S.gg=nil;S.ggText=gg
        elseif parent then
            if not S.gg or S.ggParent~=parent then
                if S.gg then pcall(call,S.gg,"closeTree") end
                S.gg=newElement("UIElement")
                call(S.gg,"setPriority",1000);passive(S.gg);call(parent,"addElement",S.gg)
                call(S.gg,"SetAnchorsAndPosition",.5,.5,0,1,-250,250,145,175)
                S.ggLabel=label(S.gg,0,0,500,26,20,0xffd200)
                call(S.gg,"SetAlpha",1)
                S.ggParent=parent
            end
            call(S.ggLabel,"setText",(gg:gsub("(sat_ww_[a-z0-9]+)_zm","%1"):gsub("sat_[a-z]+_[a-z0-9]+",weaponName):gsub("t10_[a-z]+_p%d+_[a-z0-9]+",weaponName)))
            S.ggText=gg
        end
    end
    -- large centred notice written by the GSC into zmm_big (boss wait)
    local big=read("zmm_big") or ""
    if big~=(S.bigText or "") then
        if S.big then pcall(call,S.big,"closeTree") end
        S.big=nil
        local parent=displayParent()
        if big=="" then S.bigText=big
        elseif parent then
            S.big=newElement("UIElement")
            call(S.big,"setPriority",1000);passive(S.big);call(parent,"addElement",S.big)
            call(S.big,"SetAnchorsAndPosition",.5,.5,.5,.5,-450,450,-140,-80)
            call(label(S.big,0,0,900,60,48,0xffd200),"setText",big)
            call(S.big,"SetAlpha",1);S.bigText=big
        end
    end
    local paused=invoke(get(rawget(_G,"LUI"),"FlowManager"),"IsInStack",H("MPPauseMenu"))==true
    pcall(bossBar,read("zmm_boss") or "",paused)
    S.typeMode=read("zmm_type") or "0"
    local typing=S.typeMode~="0" and S.typeMode~=""
    if typing and not S.typing then S.typeBuf="";S.typeSent=false end
    S.typing=typing
    pcall(typePrompt,typing,paused)
    local text=read("zmm_view") or ""
    if text=="" or paused then
        hide();return
    end
    if S.visible then pcall(animate) end
    local pad=read("zmm_pad")=="1" and "1" or "0"
    if S.footer and pad~=S.pad then
        S.pad=pad
        call(S.footer,"setText",FOOTERS[pad][1])
        call(S.footer2,"setText",FOOTERS[pad][2])
    end
    -- nothing new to draw: only look for a rebuilt UI root 4 times a second
    if text==S.last and S.ticks%15~=0 then return end
    local parent=displayParent()
    if not parent or (text==S.last and S.parent==parent) then return end
    local f,n=parse(text)
    if not f then return end
    if not S.frame or S.parent~=parent then build(parent) end
    render(f,n)
    S.last=text
    pcall(showPic,read("zmm_pic") or "")
end

-- native UI timer, as in ProjectNexus: a hidden element's Wait(16) re-armed after each tick
local function timerRoot()
    local L=rawget(_G,"LUI")
    local ok,current=pcall(invoke,L,"GetRoot")
    if ok and current then return current end
    return get(L,"primaryRoot")
end
local function ensureTimer()
    if not S.enabled then return end
    local root=timerRoot()
    if not root then return end
    local okParent,parent=pcall(call,S.timer,"getParent")
    if okParent and parent==root then return end
    if S.timer then pcall(call,S.timer,"closeTree") end
    S.timer=nil
    pcall(function()
        local host=newElement("UIElement")
        passive(host);call(root,"addElement",host);S.timer=host
        local function schedule()
            if not S.enabled or S.timer~=host then return end
            local animation=call(host,"Wait",16)
            if not animation then S.timer=nil;return end
            animation.onComplete=function()
                if not S.enabled or S.timer~=host then return end
                local ok,err=pcall(tick)
                if not ok then
                    clear()
                    -- log the first error only, a broken tick would repeat it every frame
                    if not S.tick_err then S.tick_err=1;pcall(print,"[FuzMenu] UI error: "..tostring(err)) end
                end
                pcall(schedule)
            end
        end
        schedule()
    end)
end
S.ensureTimer=ensureTimer
S.clear=function() clear();pcall(bossBar,"",true);pcall(typePrompt,false) end

-- arrow keys and D-pad move the open menu (GSC buttonpressed("uparrow") never fires): each press
-- bumps the zmm_up / zmm_down counter the GSC polls. Names and their hashes, as in Project Nexus.
local NAV={uparrow="up",arrowup="up",up="up",button_dpad_up="up",dpad_up="up",pad_up="up",dpadup="up",
    downarrow="down",arrowdown="down",down="down",button_dpad_down="down",dpad_down="down",pad_down="down",dpaddown="down",
    enter="enter",kp_enter="enter",["return"]="enter",backspace="back",ins="open",insert="open"}
-- sticks can report a plain "up"/"down" too: they keep their normal use
local STICKS={}
for _,prefix in ipairs({"apad_","apad2_","stick_","lstick_","rstick_","button_lstick_","button_rstick_"}) do
    for _,direction in ipairs({"up","down","left","right"}) do STICKS[prefix..direction]=true end
end
for _,names in ipairs({NAV,STICKS}) do
    local hashed={}
    for name,value in pairs(names) do hashed[tostring(H(name)):lower()]=value end
    for name,value in pairs(hashed) do names[name]=value end
end
-- round prompt keys (names and their hashes, like NAV)
local TYPE={enter="ok",kp_enter="ok",["return"]="ok",escape="x",esc="x",backspace="bs",
    ["-"]="-",minus="-",kp_minus="-",["+"]="+",["="]="+",equals="+",kp_plus="+"}
for d=0,9 do TYPE[tostring(d)]=tostring(d);TYPE["kp_"..d]=tostring(d) end
do
    local hashed={}
    for name,value in pairs(TYPE) do hashed[tostring(H(name)):lower()]=value end
    for name,value in pairs(hashed) do TYPE[name]=value end
end
-- shortcut keys F1-F12 (names and their hashes, like NAV)
local FKEY={}
for n=1,12 do FKEY["f"..n]=n end
do
    local hashed={}
    for name,value in pairs(FKEY) do hashed[tostring(H(name)):lower()]=value end
    for name,value in pairs(hashed) do FKEY[name]=value end
end
-- favorite key: right arrow / D-pad right (menu open only, so they keep their game use otherwise)
local FAV={rightarrow=true,arrowright=true,right=true,button_dpad_right=true,dpad_right=true,pad_right=true,dpadright=true}
do
    local hashed={}
    for name in pairs(FAV) do hashed[tostring(H(name)):lower()]=true end
    for name in pairs(hashed) do FAV[name]=true end
end
local function navKey(button,key,uiBind)
    local b,k,u=tostring(button):lower(),tostring(key):lower(),tostring(uiBind):lower()
    if STICKS[b] or STICKS[k] or STICKS[u] then return nil end
    return NAV[k] or NAV[b]
end

-- the timer dies when the UI root is rebuilt (map load): input events restart it
local installed=setmetatable({},{__mode="k"})
local function install()
    local input=get(rawget(_G,"LUI"),"UIRoot")
    local original=get(input,"QueueInput")
    if type(original)~="function" or installed[input] then return end
    local wrapped=function(...)
        if S.enabled then pcall(ensureTimer) end
        local _,c,_,down,button,_,_,_,_,_,key,uiBind=...
        -- round prompt: swallows its keys (digits would switch weapons) until the GSC closes it
        if S.enabled and S.typing and (tonumber(c) or 0)==0 then
            local t=TYPE[tostring(key):lower()] or TYPE[tostring(button):lower()]
            if t then
                if down==true and not S.typeSent then pcall(typeInput,t) end
                return true
            end
        end
        -- shortcut key: "<key>:<count>", the GSC binds it (menu open) or runs it (menu closed); swallowed so the game ignores F1-F12
        local fk=S.enabled and (tonumber(c) or 0)==0 and (FKEY[tostring(key):lower()] or FKEY[tostring(button):lower()])
        if fk then
            if down==true then
                S.hk=(S.hk or 0)+1
                pcall(invoke,rawget(_G,"Dvar"),"SetDvarString",HD("zmm_hk"),fk..":"..S.hk)
            end
            return true
        end
        -- favorite key: "fav:<count>" on zmm_hk, the GSC adds or removes the highlighted row
        local kb,kk,ku=tostring(button):lower(),tostring(key):lower(),tostring(uiBind):lower()
        if S.enabled and S.visible==true and (tonumber(c) or 0)==0 and not (STICKS[kb] or STICKS[kk] or STICKS[ku]) and (FAV[kk] or FAV[kb]) then
            if down==true then
                S.hk=(S.hk or 0)+1
                pcall(invoke,rawget(_G,"Dvar"),"SetDvarString",HD("zmm_hk"),"fav:"..S.hk)
            end
            return true
        end
        local nav=S.enabled and (tonumber(c) or 0)==0 and navKey(button,key,uiBind)
        -- Insert only acts while the menu is closed, every other key only while it is open
        if nav and (S.visible==true)==(nav~="open") then
            if down==true then
                local name="zmm_"..nav
                pcall(invoke,rawget(_G,"Dvar"),"SetDvarString",HD(name),tostring((tonumber(read(name)) or 0)+1))
            end
            -- Insert still reaches the game: it is also the Kronos menu key
            if nav~="open" then return true end
        end
        return original(...)
    end
    installed[input]=true
    input.QueueInput=wrapped;input[H("QueueInput")]=wrapped
end
pcall(ensureTimer)
pcall(install)
