#include <sourcemod>
#include <sdkhooks>
#include <colorlib>
#include <autoexecconfig>
#include <redie>
#include <EasySpawnProtection>
#include <sdktools>

#pragma newdecls required
#pragma semicolon 1

#define OBS_MODE_FPV 4
#define OBS_MODE_TPV 5

ConVar g_MinimumPlayersToDisable = null;
ConVar g_SpectatorsSeeAsSpectated = null;
ConVar convar_soundDeployingMorePlayers;

bool g_WasMapChanged = false;
bool g_IsTeamKillingEnabled = true;
bool g_FFAEnabled;

bool g_IsRoundFreezeEnd;
bool g_IsRoundEnd;

Handle HTM;

public Plugin myinfo = 
{
	name = "[Furious] Free For All", 
	author = "DS / FrAgOrDiE", 
	description = "Enables/Disables FFA mode", 
	version = "1.0.4", 
	url = "http://furious-clan.com/"
};

public void OnPluginStart()
{
	HTM = CreateHudSynchronizer();
	
	LoadTranslations("furious.phrases");
	
	AutoExecConfig_SetFile("frs.ffa");
	g_MinimumPlayersToDisable = AutoExecConfig_CreateConVar("sm_furious_ffa_min_players_to_disable", "14", "Minimum number of players to finally disable the FFA mode.", FCVAR_NOTIFY, true, 0.0, true, float(MaxClients));
	g_SpectatorsSeeAsSpectated = AutoExecConfig_CreateConVar("sm_furious_ffa_spectators_see_as_spectated", "1", "Should spectators see exactly what the player they're spectating is seeing?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_soundDeployingMorePlayers = AutoExecConfig_CreateConVar("sm_furious_ffa_deploying_more_players_sound", "commander/gamecommander_18.wav", "Sound to play when ffa is about to show more players middle round", FCVAR_NOTIFY);
	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();
	
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("round_freeze_end", Event_RoundFreezeEnd, EventHookMode_PostNoCopy);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_PostNoCopy);
	
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (!IsClientInGame(i))
			continue;
		
		SDKHook(i, SDKHook_SetTransmit, OnPrePlayerSetTransmit);
	}
}

public void OnMapStart()
{
	g_WasMapChanged = true;
	
	char sBuffer[PLATFORM_MAX_PATH];
	PrecacheSoundF(sBuffer, sizeof(sBuffer), convar_soundDeployingMorePlayers);
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_SetTransmit, OnPrePlayerSetTransmit);
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_IsRoundFreezeEnd = false;
	g_IsRoundEnd = false;
	g_FFAEnabled = false;
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	g_IsRoundEnd = true;
}

public void Event_RoundFreezeEnd(Event event, const char[] name, bool dontBroadcast)
{
	g_IsRoundFreezeEnd = true;
	
	int current, max;
	bool teamKilling;
	
	if (CheckFFA(current, max, teamKilling) && !g_FFAEnabled)
		SetFFA(teamKilling);
	
	g_WasMapChanged = false;
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_IsRoundFreezeEnd || Redie_IsClientGhost(GetClientOfUserId(event.GetInt("userid"))))
		return;
	
	int current, max;
	bool teamKilling;
	if (CheckFFA(current, max, teamKilling) && !g_FFAEnabled)
	{
		DataPack pack = new DataPack();
		
		pack.WriteCell(teamKilling);
		
		CreateTimer(2.0, Timer_SetFFA, pack, TIMER_FLAG_NO_MAPCHANGE | TIMER_DATA_HNDL_CLOSE);
		
		SetHudTextParams(-1.0, -0.4, 2.0, 13, 117, 244, 50, 1, 0.0, 0.0);
		for (int i = 1; i <= MaxClients; ++i)
		{
			if (!IsClientInGame(i) || IsFakeClient(i))
				continue;
			
			ShowSyncHudText(i, HTM, "Deploying more players");
			char sSound[PLATFORM_MAX_PATH];
			convar_soundDeployingMorePlayers.GetString(sSound, sizeof(sSound));
			
			if (strlen(sSound) > 0)
				EmitSoundToClient(i, sSound);
		}
	}
}

public Action Timer_SetFFA(Handle timer, DataPack pack)
{
	if (g_IsRoundEnd)
		return Plugin_Stop;
	pack.Reset();
	SetFFA(pack.ReadCell());
	
	delete pack;
	
	return Plugin_Stop;
}

public void Frame_ResetNotification()
{
	UnhookEvent("server_cvar", Event_ServerCVar, EventHookMode_Pre);
}

public Action Event_ServerCVar(Event event, const char[] name, bool dontBroadcast)
{
	return Plugin_Stop;
}

public Action OnPrePlayerSetTransmit(int client, int other)
{
	if (g_IsTeamKillingEnabled)
	{
		return Plugin_Continue;
	}
	
	if (client == other)
	{
		return Plugin_Continue;
	}
	
	if (!IsPlayerAlive(client) || Redie_IsClientGhost(client))
	{
		return Plugin_Continue;
	}
	
	int team = GetClientTeam(client);
	int otherTeam = GetClientTeam(other);
	
	if (IsPlayerAlive(other))
	{
		if (team == otherTeam)
		{
			return Plugin_Handled;
		}
	}
	else if (g_SpectatorsSeeAsSpectated.BoolValue)
	{
		int observerMode = GetEntProp(other, Prop_Send, "m_iObserverMode");
		
		if (observerMode != OBS_MODE_FPV && observerMode != OBS_MODE_TPV)
		{
			return Plugin_Continue;
		}
		
		int spectated = GetEntPropEnt(other, Prop_Send, "m_hObserverTarget");
		
		if (spectated != -1)
		{
			if (spectated == client)
			{
				return Plugin_Continue;
			}
			
			return team == GetClientTeam(spectated) ? Plugin_Handled : Plugin_Continue;
		}
	}
	
	return Plugin_Continue;
}

int CountPlayingPlayers()
{
	int count = 0;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
		{
			continue;
		}
		
		if (!IsPlayerAlive(i))
		{
			continue;
		}
		
		count++;
	}
	
	return count;
}

bool CheckFFA(int & current, int & max, bool & teamKilling)
{
	static bool wasTeamKillingEnabled = true;
	bool bAllowed;
	bool bTeamKilling;
	
	int playingCount = CountPlayingPlayers();
	int requiredCount = g_MinimumPlayersToDisable.IntValue;
	
	if (playingCount >= requiredCount)
	{
		bTeamKilling = false;
	}
	else
	{
		bTeamKilling = true;
	}
	
	if (wasTeamKillingEnabled != bTeamKilling || g_WasMapChanged)
	{
		bAllowed = true;
	}
	
	wasTeamKillingEnabled = bTeamKilling;
	teamKilling = bTeamKilling;
	//g_IsTeamKillingEnabled = bTeamKilling;
	current = playingCount;
	max = requiredCount;
	return bAllowed;
}

void SetFFA(bool teamKilling)
{
	g_FFAEnabled = true;
	
	HookEvent("server_cvar", Event_ServerCVar, EventHookMode_Pre);
	
	g_IsTeamKillingEnabled = teamKilling;
	
	if (g_IsTeamKillingEnabled)
	{
		FindConVar("mp_teammates_are_enemies").SetInt(1, false, false);
		FindConVar("mp_limitteams").SetInt(30, false, false);
		//ServerCommand("mp_teammates_are_enemies 1");
		//ServerCommand("mp_limitteams 30");
		
		//CPrintToChatAll("%t", "ffa enabled print", current, max);
	}
	else
	{
		//ServerCommand("mp_teammates_are_enemies 0");
		FindConVar("mp_teammates_are_enemies").SetInt(0, false, false);
		FindConVar("mp_limitteams").SetInt(0, false, false);
		//ServerCommand("mp_limitteams 0");
		
		//CPrintToChatAll("%t", "ffa disabled print");
	}
	
	RequestFrame(Frame_ResetNotification);
}

void PrecacheSoundF(char[] buffer, int maxlength, ConVar convar)
{
	convar.GetString(buffer, maxlength);
	if (strlen(buffer) > 0)
	{
		PrecacheSound(buffer);
		
		Format(buffer, maxlength, "sound/%s", buffer);
		AddFileToDownloadsTable(buffer);
	}
} 