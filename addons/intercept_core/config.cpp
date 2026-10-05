//config.cpp
class CfgPatches {
    class Intercept_Core {
        name = "Intercept - Core";
        units[] = {};
        weapons[] = {};
        requiredVersion = 1.88;
        requiredAddons[] = {
            "A3_Data_F_Loadorder",
            "A3_Data_F_Curator_Loadorder",
            "A3_Data_F_Kart_Loadorder",
            "A3_Data_F_Bootcamp_Loadorder",
            "A3_Data_F_Heli_Loadorder",
            "A3_Data_F_Mark_Loadorder",
            "A3_Data_F_Exp_A_Loadorder",
            "A3_Data_F_Exp_B_Loadorder",
            "A3_Data_F_Exp_Loadorder",
            "A3_Data_F_Jets_Loadorder",
            "A3_Data_F_Argo_Loadorder",
            "A3_Data_F_Patrol_Loadorder",
            "A3_Data_F_Orange_Loadorder",
            // CBA
            "cba_xeh"
        };
        version = 0.1;
    };
};

class CfgFunctions {
	init = "z\root_amet\addons\intercept_core\initFunctionsWrapper.sqf";
	//init = "A3\functions_f\initFunctions.sqf";
};

#define QUOTE(var1) #var1
#define ARR_2(ARG1,ARG2) ARG1, ARG2
#define EVENT_ARGS(x) rv_event:##x
// x = intercept event name, y = the engine/XEH event handler name (the inner
// entry, which must keep its own casing), z = the PascalCase form CBA uses for
// the Extended_*_EventHandlers class. z is passed separately because the
// preprocessor cannot change the case of y.
#define EH_CLASS_DEF(x,y,z) class Extended_##z##_EventHandlers { \
    class All { \
        class Intercept { \
            y = QUOTE([ARR_2('x',_this)] call (uiNamespace getVariable 'intercept_fnc_event');); \
        }; \
    }; \
}

EH_CLASS_DEF(anim_changed,animChanged,AnimChanged);
EH_CLASS_DEF(anim_done,animDone,AnimDone);
EH_CLASS_DEF(anim_state_changed,animStateChanged,AnimStateChanged);
EH_CLASS_DEF(container_closed,containerClosed,ContainerClosed);
EH_CLASS_DEF(container_opened,containerOpened,ContainerOpened);
EH_CLASS_DEF(controls_shifted,controlsShifted,ControlsShifted);
EH_CLASS_DEF(dammaged,dammaged,Dammaged);
EH_CLASS_DEF(engine,engine,Engine);
EH_CLASS_DEF(epe_contact,epeContact,EpeContact);
EH_CLASS_DEF(epe_contact_end,epeContactEnd,EpeContactEnd);
EH_CLASS_DEF(epe_contact_start,epeContactStart,EpeContactStart);
EH_CLASS_DEF(explosion,explosion,Explosion);
EH_CLASS_DEF(fired,firedBIS,FiredBIS);
EH_CLASS_DEF(fired_near,firedNear,FiredNear);
EH_CLASS_DEF(fuel,fuel,Fuel);
EH_CLASS_DEF(gear,gear,Gear);
EH_CLASS_DEF(get_in,getIn,GetIn);
EH_CLASS_DEF(get_out,getOut,GetOut);
EH_CLASS_DEF(handle_heal,handleHeal,HandleHeal);
EH_CLASS_DEF(hit,hit,Hit);
EH_CLASS_DEF(hit_part,hitPart,HitPart);
EH_CLASS_DEF(init,init,Init);
EH_CLASS_DEF(incoming_missile,incomingMissile,IncomingMissile);
EH_CLASS_DEF(inventory_closed,inventoryClosed,InventoryClosed);
EH_CLASS_DEF(inventory_opened,inventoryOpened,InventoryOpened);
EH_CLASS_DEF(killed,killed,Killed);
EH_CLASS_DEF(landed_touch_down,landedTouchDown,LandedTouchDown);
EH_CLASS_DEF(landed_stopped,landedStopped,LandedStopped);
EH_CLASS_DEF(local,local,Local);
EH_CLASS_DEF(put,put,Put);
EH_CLASS_DEF(respawn,respawn,Respawn);
EH_CLASS_DEF(seat_switched,seatSwitched,SeatSwitched);
EH_CLASS_DEF(sound_played,soundPlayed,SoundPlayed);
EH_CLASS_DEF(take,take,Take);
EH_CLASS_DEF(weapon_assembled,weaponAssembled,WeaponAssembled);
EH_CLASS_DEF(weapon_disassembled,weaponDisassembled,WeaponDisassembled);

// These events don't have XEH on CBA yet
//EH_CLASS_DEF(handle_damage,handleDamage,HandleDamage);
//EH_CLASS_DEF(handle_rating,handleRating,HandleRating);
//EH_CLASS_DEF(handle_score,handleScore,HandleScore);
//EH_CLASS_DEF(post_reset,postReset,PostReset);
//EH_CLASS_DEF(rope_attach,ropeAttach,RopeAttach);
//EH_CLASS_DEF(rope_break,ropeBreak,RopeBreak);
//EH_CLASS_DEF(task_set_as_current,taskSetAsCurrent,TaskSetAsCurrent);
//EH_CLASS_DEF(weapon_deployed,weaponDeployed,WeaponDeployed);
//EH_CLASS_DEF(weapon_rested,weaponRested);
/*
class Intercept {
    class example_dll_project {
        class example_dll_module {
            pluginName = "example_dll";
        };
    };
};
*/

class Extended_PreStart_EventHandlers {
    class Intercept_Core {
        init = "['post_start', _this] call (uiNamespace getVariable 'intercept_fnc_event');";
    };
};

class Extended_PreInit_EventHandlers {
    class Intercept_Core {
        init = "['pre_init',[]] call (uiNamespace getVariable 'intercept_fnc_event');";
    };
};


class Extended_PostInit_EventHandlers {
    class Intercept_Core {
        init = "call compile preprocessFileLineNumbers '\z\root_amet\addons\intercept_core\post_init.sqf';";
    };
};

class Extended_DisplayUnload_EventHandlers {
    class RscDisplayMission {
        Intercept_MissionEnded = "['mission_ended', []] call (uiNamespace getVariable 'intercept_fnc_event');";
    };
};
