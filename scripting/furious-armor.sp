/*-- Pragmas --*/
#pragma semicolon 1

/*-- Defines --*/

/*-- Includes --*/
#include <sourcemod>
#include <sdktools>
#include <colorlib>
#include <autoexecconfig>

/*-- Furious Includes --*/
//#include <furious/furious-armor>

/*-- ConVars --*/
ConVar convar_Status;
ConVar convar_MaxArmor;

/*-- Globals --*/
int g_ArmorBuffer[MAXPLAYERS + 1];
bool g_BufferReset[MAXPLAYERS + 1];

/*-- Plugin Info --*/
public Plugin myinfo =
{
	name = "[Furious] Armor",
	author = "Drixevel",
	description = "Armor module for Furious Clan.",
	version = "1.0.1",
	url = "http://furious-clan.com/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("furious_armor");

	CreateNative("Furious_Armor_SetBuffer", Native_Armor_SetBuffer);

	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("furious.phrases");

	AutoExecConfig_SetFile("frs.armor");
	convar_Status = AutoExecConfig_CreateConVar("sm_furious_armor_status", "1", "Status of the plugin.\n(1 = on, 0 = off)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_MaxArmor = AutoExecConfig_CreateConVar("sm_furious_max_armor", "20", "Maximum armor for players to have.", FCVAR_NOTIFY, true, 0.0);
	AutoExecConfig_ExecuteFile();

	HookEvent("player_spawn", Event_OnPlayerSpawn);

	AutoExecConfig_CleanFile();
}

public void Event_OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if (convar_Status.BoolValue)
		RequestFrame(Frame_DelaySpawn, event.GetInt("userid"));
}

public void Frame_DelaySpawn(any data)
{
	int client = GetClientOfUserId(data);

	if (client == 0 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client))
		return;
	
	if (g_BufferReset[client])
	{
		g_ArmorBuffer[client] = 0;
		g_BufferReset[client] = false;
	}
	
	SetEntProp(client, Prop_Data, "m_ArmorValue", 0);
	//GivePlayerItem(client, "item_assaultsuit");
}

public void OnGameFrame()
{
	if (!convar_Status.BoolValue)
		return;
	
	int max = convar_MaxArmor.IntValue;
	int check;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i))
			continue;
		
		check = max;

		if (g_ArmorBuffer[i] > 0)
			check += g_ArmorBuffer[i];
		
		if (GetEntProp(i, Prop_Data, "m_ArmorValue") > check)
			SetEntProp(i, Prop_Data, "m_ArmorValue", check);
	}
}

public int Native_Armor_SetBuffer(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	g_ArmorBuffer[client] = GetNativeCell(2);
	g_BufferReset[client] = GetNativeCell(3);
	return 0;
}