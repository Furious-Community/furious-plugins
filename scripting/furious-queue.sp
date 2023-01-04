#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <autoexecconfig>

public Plugin myinfo = 
{
	name = "[Furious] Join Queue", 
	author = "FrAgOrDiE", 
	description = "", 
	version = "1.0", 
	url = "https://furious-clan.com/"
};

ConVar cvar_fQueueSeconds;
ConVar cvar_iNumberOfPlayers;
Handle g_hTimer;
bool g_bTimer;
ArrayList g_Queue;
StringMap g_AllowConnection;

public void OnPluginStart()
{
	AutoExecConfig_SetFile("frs.queue");
	cvar_fQueueSeconds = AutoExecConfig_CreateConVar("sm_furious_queue_seconds", "2", "Seconds of dalay which with users will be allowed to join the server", FCVAR_NOTIFY, true, 1.0, true, 10.0);
	cvar_iNumberOfPlayers = AutoExecConfig_CreateConVar("sm_furious_queue_players", "5", "Numbers of players to allow connection every x seconds, x is \"sm_furious_queue_seconds\"", FCVAR_NOTIFY, true, 1.0, true, 20.0);
	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();
	g_Queue = new ArrayList(ByteCountToCells(32));
	g_AllowConnection = new StringMap();
	HookConVarChange(cvar_fQueueSeconds, OnCVarChange);
	ResetTimer(cvar_fQueueSeconds.FloatValue);
}

public void OnCVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	ResetTimer(StringToFloat(newValue));
}

public Action Timer_QueueCheck(Handle timer)
{
	if (g_Queue.Length == 0)
		return Plugin_Continue;
	
	char sSteam64[32];
	
	for (int ix = 0; ix < cvar_iNumberOfPlayers.IntValue; ++ix)
	{
		int i;
		for (i = 0; i < g_Queue.Length; ++i)
		{
			bool bAllow;
			g_Queue.GetString(i, sSteam64, sizeof(sSteam64));
			g_AllowConnection.GetValue(sSteam64, bAllow);
			if (!bAllow)break;
		}
		
		g_AllowConnection.SetValue(sSteam64, true);
	}
	
	return Plugin_Continue;
}

public void ResetTimer(float seconds)
{
	if (g_bTimer)
	{
		KillTimer(g_hTimer);
		g_bTimer = false;
	}
	
	TriggerTimer(g_hTimer = CreateTimer(seconds, Timer_QueueCheck, _, TIMER_REPEAT), true);
	g_bTimer = true;
}

public void OnClientAuthorized(int client, const char[] auth)
{
	char sSteam64[32];
	int iPosition;
	
	GetClientAuthId(client, AuthId_SteamID64, sSteam64, sizeof(sSteam64));
	iPosition = g_Queue.FindString(sSteam64) + 1;
	if (iPosition == 0)
		iPosition = g_Queue.PushString(sSteam64) + 1;
		
	bool bAllow;
	g_AllowConnection.GetValue(sSteam64, bAllow);
	
	LogMessage("[Furious-Queue] %N is positioned %i/%i", client, bAllow ? 1 : iPosition, g_Queue.Length);
	
	
	if (!bAllow)
	{
		ClientCommand(client, "disconnect;retry");
		LogMessage("[Furious-Queue] Forcing retry: %N", client);
		return;
	}
	
	LogMessage("[Furious-Queue] Connection allowed: %N", client);
	g_AllowConnection.SetValue(sSteam64, false);
	g_Queue.Erase(iPosition - 1);
} 