#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdkhooks>

public Plugin myinfo = 
{
	name = "[Furious] AWP Management (hotfix)",
	author = "FrAgOrDiE",
	description = "",
	version = "1.0",
	url = "http://furious-clan.com/"
};

ConVar enginevar_NoSpread;

public void OnPluginStart()
{
	enginevar_NoSpread = FindConVar("weapon_accuracy_nospread");
	HookEvent("weapon_fire", Event_OnWeaponFire, EventHookMode_Pre);
	HookEvent("player_spawn", PlayerSpawn, EventHookMode_Pre);
}

public Action PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if(!IsPlayerAlive(client) || IsFakeClient(client))
		return Plugin_Continue;
	
	SetClientSpread(client, "1");
	
	return Plugin_Continue;
}

void SetClientSpread(int client, const char[] spread)
{
	SendConVarValue(client, enginevar_NoSpread, spread);
	
	int observerMode;
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || !IsClientObserver(i))
			continue;
		
		observerMode = GetEntProp(i, Prop_Send, "m_iObserverMode");
		
		if (observerMode != 4 && observerMode != 5)
			continue;
		
		if (GetEntPropEnt(i, Prop_Send, "m_hObserverTarget") == client)
			SendConVarValue(i, enginevar_NoSpread, spread);
	}
}

public void Event_OnWeaponFire(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	char sWeapon[32];
	GetEntityClassname(GetActiveWeapon(client), sWeapon, sizeof(sWeapon));

	if (StrEqual(sWeapon, "weapon_awp") && !GetEntProp(client, Prop_Send, "m_bIsScoped"))
	{
		enginevar_NoSpread.SetInt(0);
		RequestFrame(Frame_EnableNospread, client);
	}	
}

public void Frame_EnableNospread(any data)
{
	enginevar_NoSpread.SetInt(1);
}

int GetActiveWeapon(int client)
{
	if (client == 0 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client) || !HasEntProp(client, Prop_Send, "m_hActiveWeapon"))
		return 0;

	return GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
}