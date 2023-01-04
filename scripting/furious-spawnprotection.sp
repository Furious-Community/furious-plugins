#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
//#include <fragstocks>
#include <EasySpawnProtection>
#include <devzones>

public Plugin myinfo =
{
	name = "[Furious] Spawn Protection",
	author = "Drixevel",
	description = "",
	version = "1.0",
	url = "http://furious-clan.com/"
};

int iSecondsLeft[MAXPLAYERS + 1];

public void OnPluginStart()
{
	LoadTranslations("furious.phrases");
}

public void ESP_OnSpawnProtectionStartClient(int client, int color[4], int time)
{
	iSecondsLeft[client] = time;

	if (client > 0 && IsClientInGame(client))
	{
		SendWinPanel(client, "%T", "spawn protection panel", client, time);
	}

	CreateTimer(1.0, Timer_TimeLeft, GetClientSerial(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_TimeLeft(Handle timer, any serial)
{
	int client = GetClientFromSerial(serial);

	if (client < 1 || !IsClientInGame(client)) {
		return Plugin_Stop;
	}

	if (iSecondsLeft[client] <= 0)
	{

		return Plugin_Stop;
	}

	if (ESP_IsSpawnProtected(client) && IsPlayerAlive(client))
	{
		SendWinPanel(client, "%T", "spawn protection panel", client, iSecondsLeft[client]);

		if (iSecondsLeft[client] <= 0)
			return Plugin_Stop;
	}
	else if (!ESP_IsSpawnProtected(client) && IsPlayerAlive(client) && GetAlivePlayers() > 0 || GetAlivePlayers() == 0)
		return Plugin_Stop;
	
	iSecondsLeft[client]--;
	return Plugin_Continue;
}

public void Zone_OnClientLeave(int client, const char[] zone)
{
	if (StrContains(zone, "jail_") == -1 || !ESP_IsSpawnProtected(client))
		return;

	
}

int GetAlivePlayers()
{
	int iAlive;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i))
			continue;

		iAlive++;
	}

	return iAlive;
}

void SendWinPanel(int client, const char[] format, any ...) {
	char sBuffer[5192];
	VFormat(sBuffer, sizeof(sBuffer), format, 3);

	Event newevent_message = CreateEvent("cs_win_panel_round");
	newevent_message.SetString("funfact_token", sBuffer);

	newevent_message.FireToClient(client);
	newevent_message.Cancel();
}