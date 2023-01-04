/*-- Pragmas --*/
#pragma semicolon 1
#pragma newdecls required

/*-- Defines --*/

/*-- Includes --*/
#include <sourcemod>
#include <sdktools>
#include <colorlib>

/*-- Furious Includes --*/

/*-- ConVars --*/

/*-- Globals --*/
bool g_bCanZoom[MAXPLAYERS + 1];
int g_iZoomLevel[MAXPLAYERS + 1];
char sNoScopeSound[PLATFORM_MAX_PATH] = "weapons/party_horn_01.wav";

/*-- Plugin Info --*/
public Plugin myinfo =
{
	name = "[Furious] Noscope",
	author = "Drixevel",
	description = "Noscope module for Furious Clan.",
	version = "1.0.1",
	url = "http://furious-clan.com/"
};

public void OnPluginStart()
{
	HookEvent("item_equip", Event_ItemEquip);
	HookEvent("player_death", Event_Death);
	HookEvent("weapon_zoom", Event_WeaponZoom);
}

public void OnMapStart()
{
	PrecacheSound(sNoScopeSound);

	char sBuffer[PLATFORM_MAX_PATH];
	FormatEx(sBuffer, sizeof(sBuffer), "sound/%s", sNoScopeSound);
	AddFileToDownloadsTable(sBuffer);
}

public void Event_ItemEquip(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (client > 0)
	{
		g_bCanZoom[client] = event.GetBool("canzoom");
		g_iZoomLevel[client] = 0;
	}
}

public void Event_WeaponZoom(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (client > 0)
	{
		if (g_iZoomLevel[client] <= 1)
			g_iZoomLevel[client]++;
		else
			g_iZoomLevel[client] = 0;
	}
}

public void OnGameFrame()
{
	int i = 1; int weapon;
	while (i <= MaxClients)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i) && !IsFakeClient(i) && g_bCanZoom[i] && g_iZoomLevel[i] > 0)
		{
			weapon = GetEntPropEnt(i, Prop_Send, "m_hActiveWeapon");

			if (IsValidEntity(weapon))
				SetEntPropFloat(weapon, Prop_Send, "m_fAccuracyPenalty", 0.0);
		}

		i++;
	}
}

public void Event_Death(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));

	if (attacker == 0 || attacker > MaxClients)
		return;

	if (g_bCanZoom[attacker] && !g_iZoomLevel[attacker])
	{
		CPrintToChatAll("{lightred}[ Furious {lightred}] %N {bluegrey}Noscoped %N{bluegrey}!", attacker, client);
		EmitSoundToClient(client, sNoScopeSound);
	}
}
