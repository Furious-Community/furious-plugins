#include <sourcemod>
#include <cstrike>
#include <dhooks>
#include <sdkhooks>

public Plugin:myinfo =
{
    name = "Remove Recoil Per Gun Per Client (hotfix)",
    author = "backwards",
    description = "Removes Weapon Recoil",
    version = "1.6",
    url = "http://steamcommunity.com/id/mypassword"
};

ConVar hConVar_Recoil_Scale;
ConVar hConVar_Recoil_ViewPunchExtra;

bool NoRecoilOnCurrentWeapon[MAXPLAYERS+1] = {false, ...};

public void OnPluginStart()
{
	hConVar_Recoil_Scale = FindConVar("weapon_recoil_scale");

	new flags = GetConVarFlags(hConVar_Recoil_Scale);
	flags &= ~FCVAR_REPLICATED;
	flags &= ~FCVAR_CHEAT;
	SetConVarFlags(hConVar_Recoil_Scale, flags);

	hConVar_Recoil_ViewPunchExtra = FindConVar("weapon_recoil_view_punch_extra");
	
	flags = GetConVarFlags(hConVar_Recoil_ViewPunchExtra);
	flags &= ~FCVAR_REPLICATED;
	flags &= ~FCVAR_CHEAT;
	SetConVarFlags(hConVar_Recoil_ViewPunchExtra, flags);
	
	ConVar hConVar_Weapon_Nospread = FindConVar("weapon_accuracy_nospread");
	
	flags = GetConVarFlags(hConVar_Weapon_Nospread);
	flags &= ~FCVAR_REPLICATED;
	flags &= ~FCVAR_CHEAT;
	SetConVarFlags(hConVar_Weapon_Nospread, flags);
	
	CreateTimer(0.0, CheckWeaponType, _, TIMER_REPEAT);
	
	HookEvent("player_spawn", PlayerSpawn, EventHookMode_Pre);
}

CSWeaponID GetWeaponType_CS(int weaponIndex)
{
	return CS_ItemDefIndexToID(GetEntProp(weaponIndex, Prop_Send, "m_iItemDefinitionIndex"));
}

public OnClientPutInServer(client)
{
    SDKHook(client, SDKHook_WeaponSwitch, Hook_WeaponSwitch);
}

bool IsWeaponNospread(int entity)
{
	char WeaponClassName[512];
	GetEntityClassname(entity, WeaponClassName, 512);
	
	if(StrEqual(WeaponClassName, "weapon_incgrenade", false))
		return true;
		
	if(StrEqual(WeaponClassName, "weapon_hegrenade", false))
		return true;

	if(StrEqual(WeaponClassName, "weapon_molotov", false))
		return true;

	if(StrEqual(WeaponClassName, "weapon_flashbang", false))
		return true;
		
	if(StrEqual(WeaponClassName, "weapon_smokegrenade", false))
		return true;		
	
	if(StrEqual(WeaponClassName, "weapon_decoy", false))
		return true;
	
	if(StrEqual(WeaponClassName, "weapon_taser", false))
		return true;
	
	if(StrEqual(WeaponClassName, "weapon_knife", false))
		return true;

	return false;
}

public Action:PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(!IsValidClient(client) || IsFakeClient(client))
		return Plugin_Continue;
	
	SendConVarValue(client, hConVar_Recoil_Scale, "0");
	SendConVarValue(client, hConVar_Recoil_ViewPunchExtra, "0")
	
	return Plugin_Continue;
}


public Action:CheckWeaponDelay(Handle:timer, any:client)
{
	if(!IsValidClient(client))
		return Plugin_Stop;
	
	if(!IsPlayerAlive(client))
		return Plugin_Stop;
	
	new weapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
	
	if(IsValidEntity(weapon) && IsValidEdict(weapon))
	{
		bool OldNoRecoil = NoRecoilOnCurrentWeapon[client];
	
	
		CSWeaponID id = GetWeaponType_CS(weapon);
		if(id == CSWeapon_AWP || id == CSWeapon_USP_SILENCER || id == CSWeapon_USP 
		|| id == CSWeapon_SAWEDOFF || id == CSWeapon_SSG08 || id == CSWeapon_REVOLVER
		|| id == CSWeapon_GLOCK || id == CSWeapon_P250 || id == CSWeapon_NOVA || id == CSWeapon_MAG7 
		|| IsWeaponNospread(weapon))
		{
			//if(OldNoRecoil)
			//	return Plugin_Stop;
				
			NoRecoilOnCurrentWeapon[client] = true;
			////SendConVarValue(client, hConVar_Recoil_Scale, "0");
			////SendConVarValue(client, hConVar_Recoil_ViewPunchExtra, "0");
		}
		else
		{
			//if(!OldNoRecoil)
			//	return Plugin_Stop;
			
			NoRecoilOnCurrentWeapon[client] = false;
			////SendConVarValue(client, hConVar_Recoil_Scale, "2.0");
			////SendConVarValue(client, hConVar_Recoil_ViewPunchExtra, "0.055");
		}
	}
	return Plugin_Stop;
}

public Action:Hook_WeaponSwitch(client, weapon_notused)
{
	if(!IsValidClient(client))
		return Plugin_Continue;
	
	if(!IsPlayerAlive(client))
		return Plugin_Continue;
	
	CreateTimer(0.6, CheckWeaponDelay, client);
	
	return Plugin_Continue;
} 

public Action:CheckWeaponType(Handle:timer, any:unused)
{
	for(int i = 1;i<MaxClients+1;i++)
	{
		if(!IsValidClient(i))
			continue;
		
		if(!IsPlayerAlive(i))
			continue;
			
		new weapon = GetEntPropEnt(i, Prop_Data, "m_hActiveWeapon");
		
		if(IsValidEntity(weapon) && IsValidEdict(weapon))
		{
			bool OldNoRecoil = NoRecoilOnCurrentWeapon[i];
		

			CSWeaponID id = GetWeaponType_CS(weapon);
			if(id == CSWeapon_AWP || id == CSWeapon_USP_SILENCER || id == CSWeapon_USP 
			|| id == CSWeapon_SAWEDOFF || id == CSWeapon_SSG08 || id == CSWeapon_REVOLVER
			|| id == CSWeapon_GLOCK || id == CSWeapon_P250 || id == CSWeapon_NOVA || id == CSWeapon_MAG7 || IsWeaponNospread(weapon))
			{
				//if(OldNoRecoil)
				//	continue;
					
				NoRecoilOnCurrentWeapon[i] = true;
				/////SendConVarValue(i, hConVar_Recoil_Scale, "0");
				/////SendConVarValue(i, hConVar_Recoil_ViewPunchExtra, "0");
			}
			else
			{
				//if(!OldNoRecoil)
				//	continue;
				
				NoRecoilOnCurrentWeapon[i] = false;
				/////SendConVarValue(i, hConVar_Recoil_Scale, "2.0");
				/////SendConVarValue(i, hConVar_Recoil_ViewPunchExtra, "0.055");
			}
		}
	}
		
	return Plugin_Continue;
}

public Action OnStartLagComp(int client)
{
	if(NoRecoilOnCurrentWeapon[client])
	{
		hConVar_Recoil_Scale.FloatValue = 0.0;
		hConVar_Recoil_ViewPunchExtra.FloatValue = 0.0;
	}
	else
	{
		hConVar_Recoil_Scale.FloatValue = 2.0;
		hConVar_Recoil_ViewPunchExtra.FloatValue = 0.055;
	}
	
	return Plugin_Continue;
}

bool IsValidClient(int client)
{
    if (!(1 <= client <= MaxClients) || !IsClientConnected(client) || !IsClientInGame(client) || IsClientSourceTV(client) || IsClientReplay(client))
        return false;
		
    return true;
}