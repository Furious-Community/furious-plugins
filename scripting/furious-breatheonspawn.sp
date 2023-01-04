#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
//#include <fragstocks>
#include <EasySpawnProtection>
#include <devzones>

public Plugin myinfo =
{
	name = "[Furious] Spawn Protection Addons",
	author = "FrAgOrDiE",
	description = "",
	version = "1.0",
	url = "http://furious-clan.com/"
};

Handle HTM;
int iSecondsLeft[MAXPLAYERS + 1];

public void OnPluginStart()
{
	HTM = CreateHudSynchronizer();
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/furious/furious_breatheonspawn.cfg");
	LoadTranslations("furious.phrases");
}

public void ESP_OnSpawnProtectionStartClient(int client, int color[4], int time)
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/furious/furious_breatheonspawn.cfg");
	KeyValues kv = new KeyValues("breathe_effect");
	if (!kv.ImportFromFile(sPath))
		SetFailState("Couldn't import \"%s\"", sPath);
	if (!kv.GetNum("plugin_enabled", 0))
		return;
	iSecondsLeft[client] = time;
	if (client > 0 && IsClientInGame(client))
	{
		float fPosx = kv.GetFloat("hudsync_pos_x");
		float fPosy = kv.GetFloat("hudsync_pos_y");
		SetHudTextParams(fPosx, fPosy, 1.0, 13, 117, 244, 50, 1, 0.0, 0.0); //hardcoded values https://app.asana.com/0/716673139475202/1200047765120499/f
		ShowSyncHudText(client, HTM, "%t", "breathe effect hudsync", iSecondsLeft[client], 0);
		if (kv.GetNum("breathe_enabled", 0))
		{
			ShowBreathe(client, 2);
			DataPack pack = new DataPack();
			pack.WriteCell(GetClientSerial(client));
			pack.WriteCell(2); //fade out (that will be converted)
			pack.Reset();
			CreateTimer(1.0, Timer_Breathe, pack, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	delete kv;
	CreateTimer(1.0, Timer_TimeLeft, GetClientSerial(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_TimeLeft(Handle timer, any serial)
{
	int client = GetClientFromSerial(serial);

	if (iSecondsLeft[client] <= 0 && client > 0 && IsClientInGame(client))
	{
		ShowSyncHudText(client, HTM, "ᅟ");
		return Plugin_Stop;
	}

	if (client < 1 || !IsClientInGame(client))
		return Plugin_Stop;

	ClearSyncHud(client, HTM);
	if (ESP_IsSpawnProtected(client) && IsPlayerAlive(client))
	{
		char sLine[128];
		Format(sLine, sizeof(sLine), "%t", "breathe effect hudsync", iSecondsLeft[client]);
		char sPath[PLATFORM_MAX_PATH];
		BuildPath(Path_SM, sPath, sizeof(sPath), "configs/furious/furious_breatheonspawn.cfg");
		KeyValues kv = new KeyValues("breathe_effect");
		if (!kv.ImportFromFile(sPath))
			SetFailState("Couldn't import \"%s\"", sPath);
		float fPosx = kv.GetFloat("hudsync_pos_x");
		float fPosy = kv.GetFloat("hudsync_pos_y");
		delete kv;
		SetHudTextParams(fPosx, fPosy, 1.0, 13, 117, 244, 50, 1, 0.0, 0.0); //hardcoded values https://app.asana.com/0/716673139475202/1200047765120499/f
		ShowSyncHudText(client, HTM, sLine, iSecondsLeft[client]);
		if (iSecondsLeft[client] <= 0)
			return Plugin_Stop;
	}
	else if (!ESP_IsSpawnProtected(client) && IsPlayerAlive(client) && GetAlivePlayers() > 0 || GetAlivePlayers() == 0)
		return Plugin_Stop;
	--iSecondsLeft[client];
	return Plugin_Continue;
}

public void Zone_OnClientLeave(int client, const char[] zone)
{
	if (StrContains(zone, "jail_") == -1 || !ESP_IsSpawnProtected(client))
		return;

	ShowSyncHudText(client, HTM, "ᅟ");
}

int GetAlivePlayers()
{
	int iAlive;
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i))
			continue;

		++iAlive;
	}
	return iAlive;
}

public Action Timer_Breathe(Handle timer, DataPack pack)
{
	int client = GetClientFromSerial(pack.ReadCell());
	if (client < 1 || !IsClientInGame(client))
		return Plugin_Stop;
	int type = pack.ReadCell();
	type = type == 1 ? 2 : 1;
	if (ESP_IsSpawnProtected(client) && iSecondsLeft[client] >= 0 && IsPlayerAlive(client))
	{
		ShowBreathe(client, type);
		pack.Close();
		pack = new DataPack();
		pack.WriteCell(GetClientSerial(client));
		pack.WriteCell(type);
		pack.Reset();
		CreateTimer(1.0, Timer_Breathe, pack, TIMER_FLAG_NO_MAPCHANGE);
	}
	else pack.Close();
	return Plugin_Continue;
}

void ShowBreathe(int client, int type) //1 = (fade) in, 2 = (fade) out
{
	int color[4] =  { 0, 0, 255, 20 };
	Handle message = StartMessageOne("Fade", client);
	PbSetInt(message, "duration", 500);
	PbSetInt(message, "hold_time", 100);
	PbSetInt(message, "flags", type);
	PbSetColor(message, "clr", color);
	EndMessage();
}
