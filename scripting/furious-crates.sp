/*-- Pragmas --*/
#pragma semicolon 1

/*-- Defines --*/
#define VIP_FLAGS ADMFLAG_CUSTOM5

/*-- Includes --*/
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <colorlib>
#include <autoexecconfig>

/*-- Furious Includes --*/
#include <furious/furious-stocks>
#include <furious/furious-statistics>
#undef REQUIRE_PLUGIN
#include <furious/furious-armor>
#define REQUIRE_PLUGIN

/*-- ConVars --*/
ConVar convar_Status;
ConVar convar_Status_Parachute;
ConVar convar_Model_Crate;
ConVar convar_Model_Parachute;
ConVar convar_Parachute_Offset;
ConVar convar_Sound_Spawn;
ConVar convar_Sound_Pickup;
ConVar convar_Fall_Speed;
//ConVar convar_Pickup_Distance;
ConVar convar_Spawn_Timer;
ConVar convar_Reward_Credits;

ConVar convar_Crate_Colors;
ConVar convar_Crate_Mode;
ConVar convar_Crate_Scale;

/*-- Globals --*/
bool g_Late;
int g_Crate = INVALID_ENT_REFERENCE;
float g_Ground[3];
Handle g_SpawnTimer;
int g_iAmmoOffset;
int g_iExplosionSprite = -1;

/*-- Plugin Info --*/
public Plugin myinfo =
{
	name = "[Furious] Crates",
	author = "Drixevel",
	description = "Crates module for Furious Clan.",
	version = "1.0.2",
	url = "http://furious-clan.com/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	MarkNativeAsOptional("Furious_Armor_SetBuffer");

	g_Late = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("furious.phrases");

	AutoExecConfig_SetFile("frs.crates");
	convar_Status = AutoExecConfig_CreateConVar("sm_furious_crates_status", "1", "Status of the plugin.\n(1 = on, 0 = off)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_Status_Parachute = AutoExecConfig_CreateConVar("sm_furious_crates_status_parachute", "1", "Status of the parachute.\n(1 = on, 0 = off)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_Model_Crate = AutoExecConfig_CreateConVar("sm_furious_crates_model_crate", "models/props_crates/static_crate_40.mdl", "Model to use for the crate.", FCVAR_NOTIFY);
	convar_Model_Parachute = AutoExecConfig_CreateConVar("sm_furious_crates_model_parachute", "models/parachute/parachute_ice_v2.mdl", "Model to use for the parachute.", FCVAR_NOTIFY);
	convar_Parachute_Offset = AutoExecConfig_CreateConVar("sm_furious_crates_parachute_offset", "-50.0", "Z axis offset to attach to the crate.", FCVAR_NOTIFY);
	convar_Sound_Spawn = AutoExecConfig_CreateConVar("sm_furious_crates_spawn_sound", "items/medshot4.wav", "Sound to play once the crate spawns.", FCVAR_NOTIFY);
	convar_Sound_Pickup = AutoExecConfig_CreateConVar("sm_furious_crates_spawn_pickup", "items/medshot4.wav", "Sound to play once the crate is picked up.", FCVAR_NOTIFY);
	convar_Fall_Speed = AutoExecConfig_CreateConVar("sm_furious_crates_fall_speed", "0.1", "Speed at which the crate falls to the ground.", FCVAR_NOTIFY, true, 0.01);
	//convar_Pickup_Distance = AutoExecConfig_CreateConVar("sm_furious_crates_pickup_distance", "50.0", "Distance to be near a crate to pick it up.", FCVAR_NOTIFY, true, 0.1);
	convar_Spawn_Timer = AutoExecConfig_CreateConVar("sm_furious_crates_spawn_timer", "30.0-90.0", "Random amount of time on repeat during the round to spawn crates in seconds.", FCVAR_NOTIFY);
	convar_Reward_Credits = AutoExecConfig_CreateConVar("sm_furious_crates_reward_credits", "50-100", "Random amount of credits to give the player as a reward.", FCVAR_NOTIFY);
	
	convar_Crate_Colors = AutoExecConfig_CreateConVar("sm_furious_crates_colors", "255 255 255 255", "Color to set crates to.\n(r g b a)", FCVAR_NOTIFY);
	convar_Crate_Mode = AutoExecConfig_CreateConVar("sm_furious_crates_mode", "1", "Render mode to set for crates.\n(https://sm.alliedmods.net/new-api/entity_prop_stocks/RenderMode)", FCVAR_NOTIFY);
	convar_Crate_Scale = AutoExecConfig_CreateConVar("sm_furious_crates_scale", "1.0", "Crate model scale", FCVAR_NOTIFY);
	
	AutoExecConfig_ExecuteFile();

	HookEvent("round_freeze_end", Event_OnRoundFreezeEnd);
	HookEvent("round_end", Event_OnRoundEnd);

	RegAdminCmd("sm_spawncrate", Command_SpawnCrate, ADMFLAG_ROOT, "Spawn a crate on the map.");

	g_iAmmoOffset = FindSendPropInfo("CCSPlayer", "m_iAmmo");

	AutoExecConfig_CleanFile();
}

public void OnPluginEnd()
{
	if (g_Crate != INVALID_ENT_REFERENCE)
	{
		int crate = EntRefToEntIndex(g_Crate);
		
		if (IsValidEntity(crate))
			AcceptEntityInput(crate, "Kill");
	}
}

public void OnMapStart()
{
	char sBuffer[PLATFORM_MAX_PATH];

	convar_Model_Crate.GetString(sBuffer, sizeof(sBuffer));
	if (strlen(sBuffer) > 0)
		PrecacheModel(sBuffer);
	
	convar_Model_Parachute.GetString(sBuffer, sizeof(sBuffer));
	if (strlen(sBuffer) > 0)
		PrecacheModel(sBuffer);

	convar_Sound_Spawn.GetString(sBuffer, sizeof(sBuffer));
	if (strlen(sBuffer) > 0)
		PrecacheSound(sBuffer);

	convar_Sound_Pickup.GetString(sBuffer, sizeof(sBuffer));
	if (strlen(sBuffer) > 0)
		PrecacheSound(sBuffer);
		
	g_iExplosionSprite = PrecacheModel("sprites/sprite_fire01.vmt");
}

public void OnMapEnd()
{
	g_SpawnTimer = INVALID_HANDLE;
}

public void OnConfigsExecuted()
{
	if (g_Late)
	{
		g_Late = false;
		g_SpawnTimer = CreateTimer(GetConVarRandomFloat(convar_Spawn_Timer), Timer_SpawnCrate, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public void Event_OnRoundFreezeEnd(Event event, const char[] name, bool dontBroadcast)
{
	StopTimer(g_SpawnTimer);
	g_SpawnTimer = CreateTimer(GetConVarRandomFloat(convar_Spawn_Timer), Timer_SpawnCrate, _, TIMER_FLAG_NO_MAPCHANGE);
}

public void Event_OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	StopTimer(g_SpawnTimer);
}

public Action Timer_SpawnCrate(Handle timer)
{
	SpawnCrate();
	g_SpawnTimer = CreateTimer(GetConVarRandomFloat(convar_Spawn_Timer), Timer_SpawnCrate, _, TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Continue;
}

void SpawnCrate()
{
	if (!convar_Status.BoolValue)
		return;

	if (g_Crate != INVALID_ENT_REFERENCE)
		return;
	
	float vecOrigin[3];
	GetRandomWorldPosition(vecOrigin, 0.0, 3000.0);
	
	while (TR_PointOutsideWorld(vecOrigin))
		vecOrigin[2] -= 5.0;

	int crate = -1;
	if ((crate = CreateCrate(vecOrigin)) != -1)
	{
		g_Crate = EntIndexToEntRef(crate);
		GetEntGroundCoordinates(crate, g_Ground);
		
		SDKHook(crate, SDKHook_TraceAttackPost, SDKCB_Hit);

		char sBuffer[PLATFORM_MAX_PATH];
		convar_Sound_Spawn.GetString(sBuffer, sizeof(sBuffer));

		if (strlen(sBuffer) > 0)
			EmitSoundToAll(sBuffer, crate);
	}
}

public void SDKCB_Hit(int victim, int attacker, int inflictor, float damage, int damagetype, int ammotype, int hitbox, int hitgroup)
{	
	float fPos[3];
	GetEntPropVector(g_Crate, Prop_Send, "m_vecOrigin", fPos);
	
	CreateExplosion(fPos);
	AcceptEntityInput(g_Crate, "Kill");
	CratePickup(attacker);
	
	g_Crate = INVALID_ENT_REFERENCE;
}

int CreateCrate(float origin[3])
{
	char sModel[PLATFORM_MAX_PATH];
	convar_Model_Crate.GetString(sModel, sizeof(sModel));

	if (strlen(sModel) == 0 || !IsModelPrecached(sModel))
		return -1;
	
	int crate = CreateEntityByName("prop_dynamic");

	if (IsValidEntity(crate))
	{
		DispatchKeyValueVector(crate, "origin", origin);
		DispatchKeyValue(crate, "model", sModel);
		DispatchKeyValue(crate, "solid", "1");
		DispatchSpawn(crate);

		int color[4]; color = GetConVarColor(convar_Crate_Colors);
		
		SetEntityRenderColor(crate, color[0], color[1], color[2], color[3]);
		SetEntityRenderMode(crate, view_as<RenderMode>(convar_Crate_Mode.IntValue));

		SetVariantString("ACT_SWAY");
		AcceptEntityInput(crate , "SetAnimation", -1, -1, 0);

		char sScale[32];
		Format(sScale, sizeof(sScale), "%.1f", convar_Crate_Scale.FloatValue);

		DispatchKeyValue(crate, "modelscale", sScale);

		if (convar_Status_Parachute.BoolValue)
			AttachParachute(crate, origin);
		
	}

	return crate;
}

void AttachParachute(int crate, float origin[3])
{
	char sModel[PLATFORM_MAX_PATH];
	convar_Model_Parachute.GetString(sModel, sizeof(sModel));
	
	if (strlen(sModel) == 0 || !IsModelPrecached(sModel))
		return;

	int parachute = CreateEntityByName("prop_dynamic");
	origin[2] += convar_Parachute_Offset.FloatValue;

	if (IsValidEntity(parachute))
	{
		DispatchKeyValueVector(parachute, "origin", origin);
		DispatchKeyValue(parachute, "model", sModel);
		DispatchSpawn(parachute);

		SetVariantString("!activator");
		AcceptEntityInput(parachute, "SetParent", crate, parachute);
	}
}

public void OnGameFrame()
{
	if (g_Crate == INVALID_ENT_REFERENCE)
		return;
	
	int crate;
	if ((crate = EntRefToEntIndex(g_Crate)) == -1)
	{
		g_Crate = INVALID_ENT_REFERENCE;
		return;
	}

	float origin[3];
	GetEntPropVector(crate, Prop_Send, "m_vecOrigin", origin);
	
	origin[2] -= convar_Fall_Speed.FloatValue;
	TeleportEntity(crate, origin, NULL_VECTOR, NULL_VECTOR);
}

stock void GetRandomWorldPosition(float result[3], float min_height = 10.0, float max_height = 20.0)
{
	float vWorldMins[3];
	GetEntPropVector(0, Prop_Data, "m_WorldMins", vWorldMins);
	vWorldMins[2] = min_height;

	float vWorldMaxs[3];
	GetEntPropVector(0, Prop_Data, "m_WorldMaxs", vWorldMaxs);
	vWorldMaxs[2] = max_height;

	result[0] = GetRandomFloat(vWorldMins[0], vWorldMaxs[0]);
	result[1] = GetRandomFloat(vWorldMins[1], vWorldMaxs[1]);
	result[2] = GetRandomFloat(vWorldMins[2], vWorldMaxs[2]);

	while (TR_PointOutsideWorld(result))
	{
		result[0] = GetRandomFloat(vWorldMins[0], vWorldMaxs[0]);
		result[1] = GetRandomFloat(vWorldMins[1], vWorldMaxs[1]);
		result[2] = GetRandomFloat(vWorldMins[2], vWorldMaxs[2]);
	}
}

void CratePickup(int client)
{
	if (!IsClientInGame(client) || IsFakeClient(client))
		return;
	
	char sBuffer[PLATFORM_MAX_PATH];
	convar_Sound_Pickup.GetString(sBuffer, sizeof(sBuffer));

	if (strlen(sBuffer) > 0)
		EmitSoundToAll(sBuffer, client);
	
	int credits = GetConVarRandom(convar_Reward_Credits);
	Furious_Statistics_AddCredits(client, credits);

	if (GetUserFlagBits(client) & VIP_FLAGS)
	{
		static ConVar convar_ExtraCredits = null;

		if (convar_ExtraCredits == null)
		{
			convar_ExtraCredits = FindConVar("sm_furious_vip_extra_credits");				
		}
		
		CPrintToChat(client, "%T", "vip rewarded credits", client, credits, convar_ExtraCredits.IntValue);
	}
	else 
	{
		CPrintToChat(client, "%T", "rewarded credits", client, credits);
	}

	Furious_Armor_SetBuffer(client, 10, true);
	int armor = GetRandomInt(2, 10);
	CSGO_AddClientArmor(client, armor);
	CPrintToChat(client, "%T", "rewarded armor", client, armor);

	RequestFrame(Frame_GiveAmmo, GetClientSerial(client));

	if (GetEntData(client, (FindDataMapInfo(client, "m_iAmmo") + (11 * 4))) == 0)
		GivePlayerItem(client, "weapon_hegrenade");

	CPrintToChat(client, "%T", "rewarded refill", client);
	
	CSkipNextClient(client);
	CPrintToChatAll("%t", "crate picked up", client);
}

public void Frame_GiveAmmo(any serial)
{
    int weaponEntity;
    int client = GetClientFromSerial(serial);
    if (IsValidClient(client) && !IsFakeClient(client) && IsPlayerAlive(client))
    {
        weaponEntity = GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY);
        if (weaponEntity != -1)
            Ammo_FullRefill(EntIndexToEntRef(weaponEntity), client);

        weaponEntity = GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY);
        if (weaponEntity != -1)
            Ammo_FullRefill(EntIndexToEntRef(weaponEntity), client);
    }
}

void Ammo_FullRefill(int weaponRef, any client)
{
    int weaponEntity = EntRefToEntIndex(weaponRef);
    if (IsValidEdict(weaponEntity))
    {
        char weaponName[35];
        char clipSize;
        int maxAmmoCount;
        int ammoType = GetEntProp(weaponEntity, Prop_Send, "m_iPrimaryAmmoType", 1) * 4;

        if (GetEntityClassname(weaponEntity, weaponName, sizeof(weaponName)))
        {
            clipSize = GetWeaponAmmoCount(weaponName, true);
            maxAmmoCount = GetWeaponAmmoCount(weaponName, false);
            switch (GetEntProp(weaponRef, Prop_Send, "m_iItemDefinitionIndex"))
            {
                case 60: { clipSize = 20;maxAmmoCount = 60; }
                case 61: { clipSize = 12;maxAmmoCount = 24; }
                case 63: { clipSize = 12;maxAmmoCount = 12; }
                case 64: { clipSize = 8;maxAmmoCount = 8; }
            }
        }

        SetEntData(client, g_iAmmoOffset + ammoType, maxAmmoCount, true);
        SetEntProp(weaponEntity, Prop_Send, "m_iClip1", clipSize);
    }
}

int GetWeaponAmmoCount(char[] weaponName, bool currentClip)
{
    if (StrEqual(weaponName,  "weapon_ak47"))
        return currentClip ? 30 : 90;
    else if (StrEqual(weaponName,  "weapon_m4a1"))
        return currentClip ? 30 : 90;
    else if (StrEqual(weaponName,  "weapon_m4a1_silencer"))
        return currentClip ? 20 : 60;
    else if (StrEqual(weaponName,  "weapon_awp"))
        return currentClip ? 10 : 30;
    else if (StrEqual(weaponName,  "weapon_sg552"))
        return currentClip ? 30 : 90;
    else if (StrEqual(weaponName,  "weapon_aug"))
        return currentClip ? 30 : 90;
    else if (StrEqual(weaponName,  "weapon_p90"))
        return currentClip ? 50 : 100;
    else if (StrEqual(weaponName,  "weapon_galilar"))
        return currentClip ? 35 : 90;
    else if (StrEqual(weaponName,  "weapon_famas"))
        return currentClip ? 25 : 90;
    else if (StrEqual(weaponName,  "weapon_ssg08"))
        return currentClip ? 10 : 90;
    else if (StrEqual(weaponName,  "weapon_g3sg1"))
        return currentClip ? 20 : 90;
    else if (StrEqual(weaponName,  "weapon_scar20"))
        return currentClip ? 20 : 90;
    else if (StrEqual(weaponName,  "weapon_m249"))
        return currentClip ? 100 : 200;
    else if (StrEqual(weaponName,  "weapon_negev"))
        return currentClip ? 150 : 200;
    else if (StrEqual(weaponName,  "weapon_nova"))
        return currentClip ? 8 : 32;
    else if (StrEqual(weaponName,  "weapon_xm1014"))
        return currentClip ? 7 : 32;
    else if (StrEqual(weaponName,  "weapon_sawedoff"))
        return currentClip ? 7 : 32;
    else if (StrEqual(weaponName,  "weapon_mag7"))
        return currentClip ? 5 : 32;
    else if (StrEqual(weaponName,  "weapon_mac10"))
        return currentClip ? 30 : 100;
    else if (StrEqual(weaponName,  "weapon_mp9"))
        return currentClip ? 30 : 120;
    else if (StrEqual(weaponName,  "weapon_mp7"))
        return currentClip ? 30 : 120;
    else if (StrEqual(weaponName,  "weapon_ump45"))
        return currentClip ? 25 : 100;
    else if (StrEqual(weaponName,  "weapon_bizon"))
        return currentClip ? 64 : 120;
    else if (StrEqual(weaponName,  "weapon_glock"))
        return currentClip ? 20 : 120;
    else if (StrEqual(weaponName,  "weapon_fiveseven"))
        return currentClip ? 20 : 100;
    else if (StrEqual(weaponName,  "weapon_deagle"))
        return currentClip ? 7 : 35;
    else if (StrEqual(weaponName,  "weapon_revolver"))
        return currentClip ? 8 : 8;
    else if (StrEqual(weaponName,  "weapon_hkp2000"))
        return currentClip ? 13 : 52;
    else if (StrEqual(weaponName,  "weapon_usp_silencer"))
        return currentClip ? 12 : 24;
    else if (StrEqual(weaponName,  "weapon_p250"))
        return currentClip ? 13 : 26;
    else if (StrEqual(weaponName,  "weapon_elite"))
        return currentClip ? 30 : 120;
    else if (StrEqual(weaponName,  "weapon_tec9"))
        return currentClip ? 24 : 120;
    else if (StrEqual(weaponName,  "weapon_cz75a"))
        return currentClip ? 12 : 12;
    return currentClip ? 30 : 90;
}

public Action Command_SpawnCrate(int client, int args)
{
	if (!convar_Status.BoolValue)
		return Plugin_Handled;

	if (g_Crate != INVALID_ENT_REFERENCE)
	{
		CPrintToChat(client, "%T", "crate already exists", client);
		return Plugin_Handled;
	}
	
	SpawnCrate();
	CPrintToChatAll("%t", "crate manually spawned", client);

	return Plugin_Handled;
}

void CreateExplosion(float pos[3])
{
	if (g_iExplosionSprite == -1)
		return;
	
	TE_SetupExplosion(pos, g_iExplosionSprite, 10.0, 30, 0, 100, 500);
	TE_SendToAll();
}