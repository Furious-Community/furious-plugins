#pragma semicolon 1
#include <sourcemod>
#include <devzones>
#include <autoexecconfig>
#include <colorlib>
#include <EasySpawnProtection>

#define PROTECTION_COLOR view_as<int>({13, 117, 244, 50})

public Plugin myinfo = 
{
	name = "[Furious] Anti Jail Kill (zones implementation)", 
	author = "FrAgOrDiE", 
	description = "Furious news", 
	version = "1.0", 
	url = "https://furious-clan.com/"
};

ConVar convar_JailProtectionTime;
ConVar convar_JailCoolDown;

int g_iLastProtection[MAXPLAYERS + 1];
bool g_bIsProtectedBySpawn[MAXPLAYERS + 1];

public void OnPluginStart()
{
	LoadTranslations("furious.phrases");
	AutoExecConfig_SetFile("frs.antijailkill");
	convar_JailProtectionTime = AutoExecConfig_CreateConVar("sm_antijailkill_protection_time", "3", "Time of protection when user enters the jail zone", FCVAR_NOTIFY, true, 0.0, true, 30.0);
	convar_JailCoolDown = AutoExecConfig_CreateConVar("sm_antijailkill_cooldown_time", "5", "Time in seconds player is not allowed to get protected after round start", FCVAR_NOTIFY, true, 0.0, true, 30.0);
	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();
}

public void ESP_OnSpawnProtectionStartClient(int client, int color[4], int time)
{
	g_iLastProtection[client] = GetTime();
}

public void Zone_OnClientEntry(int client, const char[] zone)
{
	if (ESP_IsSpawnProtected(client))
	{
		g_bIsProtectedBySpawn[client] = true;
		return;
	}
	
	if (StrContains(zone, "jail_") == -1 || GetTime() - g_iLastProtection[client] < convar_JailCoolDown.IntValue)
		return;
		
	else GiveProtection(client);
}

public void ESP_OnSpawnProtectionEndClient(int client)
{
	g_bIsProtectedBySpawn[client] = false;
}

public void Zone_OnClientLeave(int client, const char[] zone)
{
	if (StrContains(zone, "jail_") == -1 || !ESP_IsSpawnProtected(client) || g_bIsProtectedBySpawn[client])
		return;
	
	ESP_RemoveSpawnProtection(client);
	g_iLastProtection[client] = GetTime();
}

public Action Timer_EnterZoneProtected(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	if (client == 0 || !IsClientInGame(client) || ESP_IsSpawnProtected(client) || Zone_IsClientInZone(client, "jail_", false, true))
		return Plugin_Stop;
	
	GiveProtection(client);
	
	return Plugin_Stop;
}

void GiveProtection(int client)
{
	ESP_GiveSpawnProtection(client, convar_JailProtectionTime.IntValue, PROTECTION_COLOR);
} 