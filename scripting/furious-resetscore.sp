/*-- Pragmas --*/
#pragma semicolon 1
#pragma newdecls required

/*-- Defines --*/
#define PLUGIN_VERSION "1.0"

/*-- Includes --*/
#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <colorlib>
#include <autoexecconfig>

/*-- Furious Includes --*/

/*-- ConVars --*/
ConVar convar_Status;
ConVar convar_SaveScores;
ConVar convar_ResetCost;

/*-- Globals --*/
StringMap g_Scores;

/*-- Plugin Info --*/
public Plugin myinfo =
{
	name = "[Furious] ResetScore",
	author = "Drixevel",
	description = "ResetScore module for Furious Clan.",
	version = "1.0.1",
	url = "http://furious-clan.com/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("furious_resetscore");

	CreateNative("Furious_ResetScore_ResetPlayer", Native_ResetPlayer);

	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("furious.phrases");

	AutoExecConfig_SetFile("frs.resetscore");
	convar_Status = AutoExecConfig_CreateConVar("sm_furious_resetscore_status", "1", "Enable/Disable the Plugin.");
	convar_SaveScores = AutoExecConfig_CreateConVar("sm_furious_resetscore_savescores", "1", "Save scores when players retry.");
	convar_ResetCost = AutoExecConfig_CreateConVar("sm_furious_resetscore_cost", "0", "Money cost to reset score.");

	AutoExecConfig_ExecuteFile();

	HookEvent("player_disconnect", PlayerDisconnect);

	RegConsoleCmd("resetscore", CommandResetScore);
	RegConsoleCmd("rs", CommandResetScore);

	RegAdminCmd("sm_setassists", CommandSetAssists, ADMFLAG_SLAY);
	RegAdminCmd("sm_setpoints", CommandSetPoints, ADMFLAG_SLAY);
	RegAdminCmd("sm_setscore", CommandSetScore, ADMFLAG_SLAY);
	RegAdminCmd("sm_resetplayer", CommandResetPlayer, ADMFLAG_SLAY);
	RegAdminCmd("sm_reset", CommandResetPlayer, ADMFLAG_SLAY);
	RegAdminCmd("sm_setstars", CommandSetStars, ADMFLAG_SLAY);

	ServerCommand("mp_backup_round_file \"\"");
	ServerCommand("mp_backup_round_file_last \"\"");
	ServerCommand("mp_backup_round_file_pattern \"\"");
	ServerCommand("mp_backup_round_auto 0");

	g_Scores = new StringMap();

	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i))
			OnClientPutInServer(i);

	AutoExecConfig_CleanFile();
}

public void OnMapStart()
{
	ServerCommand("mp_backup_round_file \"\"");
	ServerCommand("mp_backup_round_file_last \"\"");
	ServerCommand("mp_backup_round_file_pattern \"\"");
	ServerCommand("mp_backup_round_auto 0");
}

public void OnMapEnd()
{
	g_Scores.Clear();
}

public void OnClientPutInServer(int client)
{
	if (!convar_SaveScores.BoolValue || IsFakeClient(client))
		return;

	char steamId[64];
	if (!GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId)))
		return;

	int infoArray[5];
	if (g_Scores.GetArray(steamId, infoArray, sizeof(infoArray)))
	{
		SetEntProp(client, Prop_Data, "m_iFrags", infoArray[0]);
		SetEntProp(client, Prop_Data, "m_iDeaths", infoArray[1]);
		CS_SetMVPCount(client, infoArray[2]);
		CS_SetClientContributionScore(client, infoArray[3]);
		CS_SetClientAssists(client, infoArray[4]);

		CreateTimer(2.0, Timer_RestoredPrint, GetClientSerial(client));
	}
}

public Action Timer_RestoredPrint(Handle timer, any data)
{
	int client = GetClientFromSerial(data);

	if (client > 0)
		CPrintToChat(client, "%T", "Restored", client);
	
	return Plugin_Continue;
}

public void PlayerDisconnect(Event event,const char[] name,bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (client == 0 || client > MaxClients || !IsClientInGame(client) || IsFakeClient(client))
		return;

	if (!convar_SaveScores.BoolValue || IsFakeClient(client))
		return;

	char steamId[64];
	if (!GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId)))
		return;

	int infoArray[5];
	infoArray[0] = GetClientFrags(client);
	infoArray[1] = GetClientDeaths(client);
	infoArray[2] = CS_GetMVPCount(client);
	infoArray[3] = CS_GetClientContributionScore(client);
	infoArray[4] = CS_GetClientAssists(client);

	g_Scores.SetArray(steamId, infoArray, sizeof(infoArray));
}

public Action CommandResetScore(int client, int args)
{
	if (!convar_Status.BoolValue)
		return Plugin_Handled;

	if (GetClientDeaths(client) == 0 && GetClientFrags(client) == 0 && CS_GetMVPCount(client) == 0 && CS_GetClientAssists(client) == 0)
	{
		CPrintToChat(client, "%T", "Score 0", client);
		return Plugin_Handled;
	}

	int cost = convar_ResetCost.IntValue;
	int money = GetEntProp(client, Prop_Send, "m_iAccount");

	if (cost > 0 && money < cost)
	{
		CPrintToChat(client, "%T", "No Money", client, cost);
		return Plugin_Handled;
	}

	ResetPlayer(client);
	SetEntProp(client, Prop_Send, "m_iAccount", money-cost);

	CPrintToChat(client, "%T", "You Reset", client);

	switch (GetClientTeam(client))
	{
		case 2: CPrintToChatAll("%T", "Player Reset Red", LANG_SERVER, client);
		case 3: CPrintToChatAll("%T", "Player Reset Blue", LANG_SERVER, client);
		default: CPrintToChatAll("%T", "Player Reset Normal", LANG_SERVER, client);
	}

	return Plugin_Handled;
}

void ResetPlayer(int client)
{
	if (client == 0 || client > MaxClients || !IsClientInGame(client) || IsFakeClient(client))
		return;

	SetEntProp(client, Prop_Data, "m_iFrags", 0);
	SetEntProp(client, Prop_Data, "m_iDeaths", 0);
	CS_SetMVPCount(client, 0);
	CS_SetClientAssists(client, 0);
	CS_SetClientContributionScore(client, 0);

	char steamId[64];
	if (!GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId)))
		g_Scores.Remove(steamId);
}

public Action CommandResetPlayer(int client, int args)
{
	if (!convar_Status.BoolValue)
		return Plugin_Handled;

	if (args < 1)
		return Plugin_Handled;

	char sTarget[MAX_TARGET_LENGTH];
	GetCmdArgString(sTarget, sizeof(sTarget));

	int target_list[MAXPLAYERS];
	char target_name[MAX_TARGET_LENGTH];
	bool tn_is_ml;

	int target_count;
	if ((target_count = ProcessTargetString(sTarget, client, target_list, MAXPLAYERS, COMMAND_TARGET_NONE, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	for (int i = 0; i < target_count; i++)
		ResetPlayer(target_list[i]);

	return Plugin_Handled;
}

public Action CommandSetScore(int client, int args)
{
	if (!convar_Status.BoolValue)
		return Plugin_Handled;

	if (args != 6)
		return Plugin_Handled;

	char arg1[32];
	GetCmdArg(1, arg1, sizeof(arg1));

	char arg2[32];
	GetCmdArg(2, arg2, sizeof(arg2));
	int kills = StringToInt(arg2);

	char arg3[32];
	GetCmdArg(3, arg3, sizeof(arg3));
	int deaths = StringToInt(arg3);

	char arg4[32];
	GetCmdArg(4, arg4, sizeof(arg4));
	int assists = StringToInt(arg4);

	char arg5[32];
	GetCmdArg(5, arg5, sizeof(arg5));
	int stars = StringToInt(arg5);

	char arg6[32];
	GetCmdArg(6, arg6, sizeof(arg6));
	int points = StringToInt(arg6);

	int target_list[MAXPLAYERS];
	char target_name[MAX_TARGET_LENGTH];
	bool tn_is_ml;

	int target_count;
	if ((target_count = ProcessTargetString(arg1, client, target_list, MAXPLAYERS, COMMAND_TARGET_NONE, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	for (int i = 0; i < target_count; i++)
	{
		SetEntProp(target_list[i], Prop_Data, "m_iFrags", kills);
		SetEntProp(target_list[i], Prop_Data, "m_iDeaths", deaths);
		CS_SetClientAssists(target_list[i], assists);
		CS_SetMVPCount(target_list[i], stars);
		CS_SetClientContributionScore(target_list[i], points);
	}

	return Plugin_Handled;
}

public Action CommandSetPoints(int client, int args)
{
	if (!convar_Status.BoolValue)
		return Plugin_Handled;

	if (args != 2)
		return Plugin_Handled;

	char arg1[32];
	GetCmdArg(1, arg1, sizeof(arg1));

	char arg2[32];
	GetCmdArg(2, arg2, sizeof(arg2));
	int points = StringToInt(arg2);

	int target_list[MAXPLAYERS];
	char target_name[MAX_TARGET_LENGTH];
	bool tn_is_ml;

	int target_count;
	if ((target_count = ProcessTargetString(arg1, client, target_list, MAXPLAYERS, COMMAND_TARGET_NONE, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	for (int i = 0; i < target_count; i++)
		CS_SetClientContributionScore(target_list[i], points);

	return Plugin_Handled;
}

public Action CommandSetAssists(int client, int args)
{
	if (!convar_Status.BoolValue)
		return Plugin_Handled;

	if (args != 2)
		return Plugin_Handled;

	char arg1[32];
	GetCmdArg(1, arg1, sizeof(arg1));

	char arg2[20];
	GetCmdArg(2, arg2, sizeof(arg2));
	int assists = StringToInt(arg2);

	int target_list[MAXPLAYERS];
	char target_name[MAX_TARGET_LENGTH];
	bool tn_is_ml;

	int target_count;
	if ((target_count = ProcessTargetString(arg1, client, target_list, MAXPLAYERS, COMMAND_TARGET_NONE, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	for (int i = 0; i < target_count; i++)
		CS_SetClientAssists(target_list[i], assists);

	return Plugin_Handled;
}

public Action CommandSetStars(int client, int args)
{
	if (!convar_Status.BoolValue)
		return Plugin_Handled;

	if (args != 2)
		return Plugin_Handled;

	char arg1[32];
	GetCmdArg(1, arg1, sizeof(arg1));

	char arg2[20];
	GetCmdArg(2, arg2, sizeof(arg2));
	int stars = StringToInt(arg2);

	int target_list[MAXPLAYERS];
	char target_name[MAX_TARGET_LENGTH];
	bool tn_is_ml;

	int target_count;
	if ((target_count = ProcessTargetString(arg1, client, target_list, MAXPLAYERS, COMMAND_TARGET_NONE, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	for (int i = 0; i < target_count; i++)
		CS_SetMVPCount(target_list[i], stars);

	return Plugin_Handled;
}

public int Native_ResetPlayer(Handle plugin, int numParams)
{
	ResetPlayer(GetNativeCell(1));
	return 0;
}