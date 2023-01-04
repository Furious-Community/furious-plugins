#include <sourcemod>

#pragma semicolon 1
#pragma newdecls required

#define HIDE_RADAR_CSGO 1<<12

public Plugin myinfo = 
{
	name = "Disable Radar", 
	author = "Internet Bully", 
	description = "Turns off Radar on spawn", 
	version = "1.2", 
	url = "http://www.sourcemod.net/"
}

public void OnPluginStart()
{
	HookEvent("player_spawn", Player_Spawn);
	RegConsoleCmd("jointeam", Command_Jointeam);
}
public void Player_Spawn(Handle event, const char[] name, bool dontBroadcast)
{
	int userid = GetEventInt(event, "userid");
	
	int client = GetClientOfUserId(userid);
	
	if (IsFakeClient(client))
	{
		return;
	}
	
	CreateTimer(0.1, RemoveRadar, userid);
}

public Action Command_Jointeam(int client, int args)
{
	char arg[4];
	GetCmdArg(1, arg, sizeof(arg));
	if (StrEqual(arg, "1"))
		CreateTimer(0.1, RemoveRadar, GetClientUserId(client));
	return Plugin_Continue;
}

public Action RemoveRadar(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	
	if (client < 1 || client > MaxClients)
	{
		return Plugin_Continue;
	}
	
	if (!IsClientInGame(client))
	{
		return Plugin_Continue;
	}
	
	SetEntProp(client, Prop_Send, "m_iHideHUD", GetEntProp(client, Prop_Send, "m_iHideHUD") | HIDE_RADAR_CSGO);
	return Plugin_Continue;
}
