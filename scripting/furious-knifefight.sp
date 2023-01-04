#include <sourcemod>
#include <sdktools>
#include <autoexecconfig>
#include <sdkhooks>
#include <colorlib>

#pragma semicolon 1
#pragma newdecls required

#define CS_SLOT_KNIFE 2

public Plugin myinfo =
{
	name = "[Furious] Knife Fight",
	author = "FrAgOrDiE",
	description = "",
	version = "1.2",
	url = "https://furious-clan.com"
};

int g_iRoundStart;
int g_iFighters;
int g_iKFRound;
int g_iKFRoundStart;
int g_iKFArmor[MAXPLAYERS + 1];
int g_iMaxArmorDefaultValue = -1;

bool g_bProposal;
bool g_bKnifeFightStarted;
bool g_bIsRoundEnd;
bool g_bLateLoaded;
bool g_bVote[MAXPLAYERS + 1];
bool g_bIsKnifeFight[MAXPLAYERS + 1];

float g_fPositions[3][3];
float g_fAngles[3][3];

ConVar cv_DuelDuration;
ConVar cv_DuelMaxPlayers;
ConVar cv_MaxArmor = null;

Handle g_hTimerCD;

public void OnPluginStart()
{
	LoadTranslations("furious.phrases");

	RegConsoleCmd("sm_kf", Command_KnifeFight);
	RegConsoleCmd("sm_knifefight", Command_KnifeFight);
	RegAdminCmd("sm_kf_reloadcfg", Command_ReloadConfig, ADMFLAG_ROOT);

	AutoExecConfig_SetFile("frs.knifefight");
	cv_DuelDuration = AutoExecConfig_CreateConVar("sm_furious_knifefight_duration", "30", "Duration in seconds of the knife fight", FCVAR_NOTIFY);
	cv_DuelMaxPlayers = AutoExecConfig_CreateConVar("sm_furious_knifefight_maxplayers", "4", "Max required players to enable knife fight", FCVAR_NOTIFY);
	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();

	ReoadConfigFile();

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("item_pickup", Event_ItemPickUp, EventHookMode_Pre);

	if (g_bLateLoaded)
	{
		for (int i = 1; i <= MaxClients; ++i)
		{
			if (!IsClientInGame(i))
				continue;

			OnClientPutInServer(i);
		}
	}
}

public void OnAllPluginsLoaded()
{
	if (cv_MaxArmor == null)
		cv_MaxArmor = FindConVar("sm_furious_max_armor");

	if (cv_MaxArmor != null)
	{
		g_iMaxArmorDefaultValue = cv_MaxArmor.IntValue;
		//HookConVarChange(cv_MaxArmor, OnArmorDefaultValueChange);
	}
}

/*public void OnArmorDefaultValueChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_iMaxArmorDefaultValue = StringToInt(newValue);
}*/

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_WeaponCanUse, SDKHCB_WeaponCanUse);
	g_bIsKnifeFight[client] = false;
	g_iKFArmor[client] = 0;
}

public void OnMapStart()
{
	ReoadConfigFile();
}

public Action SDKHCB_WeaponCanUse(int client, int weapon)
{
	if (g_bIsKnifeFight[client])
		return Plugin_Stop;

	return Plugin_Continue;
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLateLoaded = late;
	return APLRes_Success;
}

public void OnClientDisconnect(int client)
{
	g_bVote[client] = false;
	g_bIsKnifeFight[client] = false;
}

int GetFreezeTime()
{
	ConVar cv_FreezeTime = FindConVar("mp_freezetime");
	return cv_FreezeTime.IntValue;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	++g_iKFRound;

	g_iRoundStart = GetTime();
	g_bProposal = false;
	g_bIsRoundEnd = false;
	g_bKnifeFightStarted = false;
	g_iFighters = 0;

	for (int i = 1; i <= MaxClients; ++i)
	{
		g_bVote[i] = false;
		g_bIsKnifeFight[i] = false;
		if (!IsClientInGame(i))
			continue;

		//SetEntProp(i, Prop_Data, "m_ArmorValue", GetEntProp(i, Prop_Data, "m_ArmorValue") + g_iKFArmor[i]);
	}

	CreateTimer(float(GetFreezeTime()), Timer_FreezeTime, _, TIMER_FLAG_NO_MAPCHANGE);
}

void ClearTimer(Handle &timer)
{
	if (timer == null)
	{
		return;
	}

	KillTimer(timer);
	timer = null;
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	g_bIsRoundEnd = true;

	for (int i = 1; i <= MaxClients; ++i)
	g_bIsKnifeFight[i] = false;

	ClearTimer(g_hTimerCD);

	if (cv_MaxArmor != null)
	{
		HookEvent("server_cvar", Event_ServerCVar, EventHookMode_Pre);
		cv_MaxArmor.SetInt(g_iMaxArmorDefaultValue);
		RequestFrame(Frame_ResetNotification);
	}
}

public void Frame_ResetNotification()
{
	UnhookEvent("server_cvar", Event_ServerCVar, EventHookMode_Pre);
}

public Action Event_ServerCVar(Event event, const char[] name, bool dontBroadcast)
{
	return Plugin_Stop;
}

public Action Timer_FreezeTime(Handle timer)
{
	if (!CanKnifeFight())
		return Plugin_Continue;
	ProposeKnifeFight();
	return Plugin_Continue;
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(event.GetInt("attacker"));

	if (g_bIsKnifeFight[attacker])
	{
		ConfettiEffectOnClient(attacker);
		return;
	}

	if (!CanKnifeFight())
		return;

	ProposeKnifeFight();
}

public Action Event_ItemPickUp(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!IsClientInGame(client))
		return Plugin_Continue;

	if (g_bIsKnifeFight[client])
		return Plugin_Stop;

	return Plugin_Continue;
}

public int GetCurrentRoundTime()
{
	return GetTime() - g_iRoundStart - GetFreezeTime();
}

void SetRoundTime(int time)
{
	GameRules_SetProp("m_iRoundTime", GetCurrentRoundTime() + time, 4, 0, true);
}

int GetAlivePlayers()
{
	int nAlive;
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || !IsPlayerAlive(i))
			continue;

		++nAlive;
	}
	return nAlive;
}

bool CanKnifeFight()
{
	return g_iRoundStart != -1 && GetAlivePlayers() <= cv_DuelMaxPlayers.IntValue && GetAlivePlayers() >= 2 && !g_bProposal && !g_bIsRoundEnd && !g_bKnifeFightStarted;
}

bool IsKnifeFightEnabled()
{
	return g_iRoundStart != -1 && GetAlivePlayers() <= cv_DuelMaxPlayers.IntValue && GetAlivePlayers() >= 2 && g_bProposal && ArePointsSet() && !g_bIsRoundEnd && !g_bKnifeFightStarted;
}

void ProposeKnifeFight()
{
	g_bProposal = true;

	if (!ArePointsSet())
	{
		CPrintToChatAll("%t", "knife fight proposal positions not set");
		return;
	}

	CPrintToChatAll("%t", "knife fight proposal");
}

public Action Command_KnifeFight(int client, int args)
{
	VoteForKnifeFight(client);

	return Plugin_Handled;
}

void VoteForKnifeFight(int client)
{
	if (!IsKnifeFightEnabled())
	{
		CPrintToChat(client, "%t", "knife fight not available now");
		return;
	}

	if (!IsPlayerAlive(client))
	{
		CPrintToChat(client, "%t", "knife fight not available for dead players");
		return;
	}

	if (g_bVote[client])
	{
		CPrintToChat(client, "%t", "knife fight you already voted");
		return;
	}

	++g_iFighters;
	g_bVote[client] = true;

	CPrintToChat(client, "%t", "knife fight you voted");

	if (TryStartKnifeFight())
	{
		CPrintToChat(client, "%t", "knife fight started");
		return;
	}

	for (int i = 1; i <= MaxClients; ++i)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || !IsPlayerAlive(i) || i == client)
			continue;

		Menu menu = new Menu(MH_KnifeFight);
		menu.SetTitle("%t", "menu knife fight title");
		menu.AddItem("", "Yes");
		menu.AddItem("", "No");
		menu.ExitButton = false;
		menu.Display(i, MENU_TIME_FOREVER);
	}
}

public int MH_KnifeFight(Menu menu, MenuAction action, int arg1, int arg2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			switch (arg2)
			{
				case 0:
				{
					VoteForKnifeFight(arg1);
					TryStartKnifeFight();
				}
			}
		}
		case MenuAction_End:delete menu;
	}

	return 0;
}

bool TryStartKnifeFight()
{
	if (g_iFighters != GetAlivePlayers() || g_bKnifeFightStarted)
		return false;

	StartKnifeFight();

	return true;
}

void StartKnifeFight()
{
	g_bKnifeFightStarted = true;

	g_iKFRoundStart = g_iKFRound;

	for (int i = 1; i <= MaxClients; ++i)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || !IsPlayerAlive(i))
			continue;

		PrintHintText(i, "%t", "knife fight start hintmessage");
	}
	CPrintToChatAll("%t", "knife fight start allchat");
	SetRoundTime(cv_DuelDuration.IntValue);
	CreateTimer(float(cv_DuelDuration.IntValue - 6), Timer_CountDownFirst, _, TIMER_FLAG_NO_MAPCHANGE);

	if (cv_MaxArmor != null)
	{
		HookEvent("server_cvar", Event_ServerCVar, EventHookMode_Pre);
		cv_MaxArmor.SetInt(100);
		RequestFrame(Frame_ResetNotification);
	}

	int ix;
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || !IsPlayerAlive(i))
			continue;

		TeleportEntity(i, g_fPositions[ix], g_fAngles[ix], view_as<float>( { 0.0, 0.0, 0.0 } ));
		++ix;

		RemoveClientWeapons(i);

		CreateTimer(0.1, Timer_KnifeFight, GetClientSerial(i), TIMER_FLAG_NO_MAPCHANGE);
		GivePlayerItem(i, "weapon_knife");
	}
}

public Action Timer_KnifeFight(Handle timer, any serial)
{
	int client = GetClientFromSerial(serial);

	if (!client)
		return Plugin_Continue;

	g_bIsKnifeFight[client] = true;
	SetEntProp(client, Prop_Data, "m_iMaxHealth", 100);
	SetEntityHealth(client, 100);
	SetEntProp(client, Prop_Data, "m_ArmorValue", 100, 1);


	for (int i = 0; i < 4; ++i)
	{
		if (i == CS_SLOT_KNIFE)
			continue;

		int entityIndex;
		while ((entityIndex = GetPlayerWeaponSlot(client, i)) != -1)
		{
			RemovePlayerItem(client, entityIndex);
			AcceptEntityInput(entityIndex, "Kill");
		}
	}
	return Plugin_Continue;
}

public Action Timer_CountDownFirst(Handle timer)
{
	g_hTimerCD = CreateTimer(1.0, Timer_CountDown, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
	return Plugin_Continue;
}

public Action Timer_CountDown(Handle timer)
{
	if (g_bIsRoundEnd || g_iKFRoundStart != g_iKFRound)
	{
		ClearTimer(g_hTimerCD);
		return Plugin_Stop;
	}

	static int counter = 5;

	CPrintToChatAll("%i", counter);

	if (counter == 0)
	{
		counter = 5;

		ClearTimer(g_hTimerCD);
		return Plugin_Stop;
	}

	--counter;

	return Plugin_Continue;
}

public Action Command_ReloadConfig(int client, int args)
{
	ReoadConfigFile();
	if (!IsClientInGame(client) || IsFakeClient(client) || client == 0)
		return Plugin_Handled;
	CPrintToChat(client, "Config file reloaded");
	return Plugin_Handled;
}

void ReoadConfigFile()
{
	KeyValues kv = new KeyValues("KnifeFight");
	char sFile[PLATFORM_MAX_PATH];

	BuildPath(Path_SM, sFile, sizeof(sFile), "configs/furious/furious_knifefight.cfg");

	if (!kv.ImportFromFile(sFile))
		SetFailState("Couldn't import: \"%s\"", sFile);

	kv.JumpToKey("Maps");
	kv.GotoFirstSubKey();

	do
	{
		char sSection[64], sMap[64];
		kv.GetSectionName(sSection, sizeof(sSection));
		GetCurrentMap(sMap, sizeof(sMap));

		if (!StrEqual(sSection, sMap))
			continue;

		kv.GetVector("1", g_fPositions[0]);
		kv.GetVector("2", g_fPositions[1]);
		kv.GetVector("3", g_fPositions[2]);

		kv.GetVector("1_ang", g_fAngles[0]);
		kv.GetVector("2_ang", g_fAngles[1]);
		kv.GetVector("3_ang", g_fAngles[2]);

		break;
	}
	while (kv.GotoNextKey());

	delete kv;
}

bool ArePointsSet()
{
	return !(
		g_fPositions[0][0] == 0.0
		 && g_fPositions[0][1] == 0.0
		 && g_fPositions[0][2] == 0.0
		 && g_fPositions[1][0] == 0.0
		 && g_fPositions[1][1] == 0.0
		 && g_fPositions[1][2] == 0.0
		 && g_fPositions[2][0] == 0.0
		 && g_fPositions[2][1] == 0.0
		 && g_fPositions[2][2] == 0.0
		);
}

void RemoveClientWeapons(int client)
{
	for (int i = 0; i < 4; ++i)
	{
		int entityIndex;
		while ((entityIndex = GetPlayerWeaponSlot(client, i)) != -1)
		{
			RemovePlayerItem(client, entityIndex);
			AcceptEntityInput(entityIndex, "Kill");
		}
	}
}

public Action Timer_DeleteEdict(Handle timer, any particleRef)
{
	int particle = EntRefToEntIndex(particleRef);

	if (particle != INVALID_ENT_REFERENCE)
	{
		RemoveEdict(particle);
	}

	return Plugin_Continue;
}

void ConfettiEffectOnClient(int client)
{
	float fClientPos[3];
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", fClientPos);

	int particle = CreateEntityByName("info_particle_system");
	DispatchKeyValue(particle, "targetname", "uc_zeus_fire_confetti");
	DispatchKeyValue(particle, "effect_name", "weapon_confetti");
	DispatchSpawn(particle);
	ActivateEntity(particle);
	AcceptEntityInput(particle, "start");
	TeleportEntity(particle, fClientPos, view_as<float>( { 271.0, 0.0, 0.0 } ), NULL_VECTOR);
	CreateTimer(2.0, Timer_DeleteEdict, EntIndexToEntRef(particle), TIMER_FLAG_NO_MAPCHANGE);
}