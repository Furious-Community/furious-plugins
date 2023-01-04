/*-- Pragmas --*/
#pragma semicolon 1
#pragma newdecls required

/*-- Defines --*/

/*-- Includes --*/
#include <sourcemod>
#include <cstrike>
#include <colorlib>
#include <autoexecconfig>

/*-- Furious Includes --*/

/*-- ConVars --*/
ConVar convar_Status;

/*-- Globals --*/
int g_iSwitch;
int g_iSwitchAmount;
ArrayList g_SwitchPlayers;

/*-- Plugin Info --*/
public Plugin myinfo =
{
	name = "[Furious] Autobalance",
	author = "Drixevel",
	description = "Autobalance module for Furious Clan.",
	version = "1.0.2",
	url = "http://furious-clan.com/"
};

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("furious.phrases");

	AutoExecConfig_SetFile("frs.autobalance");
	convar_Status = AutoExecConfig_CreateConVar("sm_furious_autobalance_status", "1", "Status of the plugin.\n(1 = on, 0 = off)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	AutoExecConfig_ExecuteFile();

	HookEvent("round_start", OnRoundStart);
	HookEvent("round_end", OnRoundEnd);

	g_SwitchPlayers = new ArrayList();

	AutoExecConfig_CleanFile();
}

public void OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (!convar_Status.BoolValue)
		return;

	int client;
	for (int i = 0; i < g_SwitchPlayers.Length; i++)
	{
		client = GetClientFromSerial(g_SwitchPlayers.Get(i));

		if (client == 0)
			continue;

		switch (GetClientTeam(client))
		{
			case CS_TEAM_CT: Client_ScreenFade(client, 1, 0x0001, 6, 0, 0, 255, 150);
			case CS_TEAM_T: Client_ScreenFade(client, 1, 0x0001, 6, 255, 0, 0, 150);
		}
	}
}

public void OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	if (!convar_Status.BoolValue)
		return;

	g_SwitchPlayers.Clear();

	g_iSwitch = 0;
	g_iSwitchAmount = 0;

	int iT = GetTeamClientCount2(CS_TEAM_T);
	int iCT = GetTeamClientCount2(CS_TEAM_CT);

	if (iT - iCT >= 2)
	{
		g_iSwitch = CS_TEAM_T;
		g_iSwitchAmount = (iT - iCT) / 2;
		AskSwitchMenu(CS_TEAM_T);
	}
	else if (iCT - iT >= 2)
	{
		g_iSwitch = CS_TEAM_CT;
		g_iSwitchAmount = (iCT - iT) / 2;
		AskSwitchMenu(CS_TEAM_CT);
	}

	CreateTimer(6.5, Timer_SwitchTeams, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_SwitchTeams(Handle timer)
{
	switch (g_iSwitch)
	{
		case CS_TEAM_T: SwitchPlayers(CS_TEAM_T, CS_TEAM_CT, "Counter-Terrorists");
		case CS_TEAM_CT: SwitchPlayers(CS_TEAM_CT, CS_TEAM_T, "Terrorists");
	}

	g_iSwitch = 0;
	return Plugin_Continue;
}

void SwitchPlayers(int iTeam, const int iEnemyTeam, char[] sEnemyTeamName)
{
	int client;

	if (g_SwitchPlayers.Length < g_iSwitchAmount)
	{
		int teamCount = GetTeamClientCount2(iTeam);
		if (teamCount < g_iSwitchAmount)
			g_iSwitchAmount = teamCount;

		ArrayList player_array = new ArrayList();

		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == iTeam && g_SwitchPlayers.FindValue(GetClientSerial(i)) == -1)
				player_array.Push(i);
		}

		if( player_array.Length > 0 )
		{
			int random;
			for (int i = 0; i < g_iSwitchAmount - g_SwitchPlayers.Length; i++)
			{
				random = GetRandomInt(0, player_array.Length - 1);
				client = player_array.Get(random);

				g_SwitchPlayers.Push(GetClientSerial(client));
				player_array.Erase(random);
			}
		}

		delete player_array;
	}

	int min = g_iSwitchAmount > g_SwitchPlayers.Length ? g_SwitchPlayers.Length : g_iSwitchAmount;
	for (int i = 0; i < min; i++)
	{
		client = GetClientFromSerial(g_SwitchPlayers.Get(i));

		if (client == 0)
			continue;

		CS_SwitchTeam(client, iEnemyTeam);
		CPrintToChatAll("%T", "player switched team", client, client, sEnemyTeamName);
	}
}

void AskSwitchMenu(int iTeam)
{
	Menu menu = new Menu(MenuHandle_AskSwitchMenu);
	menu.SetTitle("%t", "join the other team autobalance");

	menu.AddItem("yes", "Yes");
	menu.AddItem("no", "No");

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == iTeam)
			menu.Display(i, 7);
	}
}

public int MenuHandle_AskSwitchMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			if (!convar_Status.BoolValue)
				return 0;

			char sDecision[12];
			menu.GetItem(param2, sDecision, sizeof(sDecision));

			if (g_iSwitch == 0)
			{
				CPrintToChat(param1, "%T", "switch time over", param1);
				return 0;
			}

			if (StrEqual(sDecision, "yes"))
			{
				if (g_SwitchPlayers.Length < g_iSwitchAmount)
				{
					g_SwitchPlayers.Push(GetClientSerial(param1));
					CPrintToChat(param1, "%T", "added to queue", param1);
				}
				else
					CPrintToChat(param1, "%T", "switch too slow", param1);
			}
		}
	}

	return 0;
}

bool Client_ScreenFade(int client, int duration, int mode, int holdtime = -1, int r = 0, int g = 0, int b = 0, int a = 255, bool reliable = true)
{
	Handle userMessage = StartMessageOne("Fade", client, (reliable?USERMSG_RELIABLE:0));

	if (userMessage == INVALID_HANDLE)
		return false;

	if (GetFeatureStatus(FeatureType_Native, "GetUserMessageType") == FeatureStatus_Available && GetUserMessageType() == UM_Protobuf)
	{
		int color[4];
		color[0] = r;
		color[1] = g;
		color[2] = b;
		color[3] = a;

		PbSetInt(userMessage, "duration", duration);
		PbSetInt(userMessage, "hold_time", holdtime);
		PbSetInt(userMessage, "flags", mode);
		PbSetColor(userMessage, "clr", color);
	}
	else
	{
		BfWriteShort(userMessage, duration);
		BfWriteShort(userMessage, holdtime);
		BfWriteShort(userMessage, mode);
		BfWriteByte(userMessage, r);
		BfWriteByte(userMessage, g);
		BfWriteByte(userMessage, b);
		BfWriteByte(userMessage, a);
	}

	EndMessage();

	return true;
}

int GetTeamClientCount2(int team)
{
	int iTotal;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == team)
			iTotal++;
	}

	return iTotal;
}
