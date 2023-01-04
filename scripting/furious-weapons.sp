#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
//#include <fragstocks>
#include <sdkhooks>
#include <autoexecconfig>
#include <colorlib>
#undef REQUIRE_PLUGIN
#include <furious/furious-statistics>
#define REQUIRE_PLUGIN;
#include <dbi>

#define DROPSHOT_SPEED 80.0
#define MAX_TABLE_SIZE 64

enum DropShotKillsStatus
{
	DropShotKills_Pending = -1,
	DropShotKills_Failure,
	DropShotKills_Loaded,
}

public Plugin myinfo =
{
	name = "[Furious] Weapons",
	author = "FrAgOrDiE",
	description = "",
	version = "1.4",
	url = "http://furious-clan.com/"
};

ConVar enginevar_NoSpread;
ConVar cvar_DropShot_SeasonalPoints;
ConVar cvar_NoSpreadByDefault;

bool g_bStatistics;
bool g_bIsDropping[MAXPLAYERS + 1];
bool g_bIsDropShotKill[MAXPLAYERS + 1];

int g_iGlobalDropShotKills[MAXPLAYERS + 1];
int g_iSeasonDropShotKills[MAXPLAYERS + 1];
int g_iSeason;

Database g_Database_Global;
Database g_Database_Server;

DropShotKillsStatus g_GlobalDropShotKillsStatus[MAXPLAYERS + 1] = {DropShotKills_Pending, ...};
DropShotKillsStatus g_SeasonDropShotKillsStatus[MAXPLAYERS + 1] = {DropShotKills_Pending, ...};

ConVar convar_Table_GlobalStatistics;
ConVar convar_Table_ServerSeasons;

public void OnPluginStart()
{
	enginevar_NoSpread = FindConVar("weapon_accuracy_nospread");

	HookEvent("weapon_fire", Event_OnWeaponFire, EventHookMode_Pre);
	HookEvent("player_death", Event_OnPlayerDeathPre, EventHookMode_Pre);

	LoadTranslations("furious.phrases");

	AutoExecConfig_SetFile("frs.weapons2");
	cvar_DropShot_SeasonalPoints = AutoExecConfig_CreateConVar("sm_furious_weapons_points_on_dropshot", "2", "Seasonal points to gain when a dropshot kill is made", FCVAR_NOTIFY);
	cvar_NoSpreadByDefault = AutoExecConfig_CreateConVar("sm_furious_weapons_default_nospread", "1", "Should nospread be enabled by default on AWP?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvar_NoSpreadByDefault.AddChangeHook(OnSpreadChange);

	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();

	// For late-loading
	g_Database_Global = Furious_Statistics_GetGlobalDatabase();
	g_Database_Server = Furious_Statistics_GetServerDatabase();

	g_iSeason = Furious_Statistics_GetSeason();

	convar_Table_GlobalStatistics = FindConVar("sm_furious_statistics_global_table");
	convar_Table_ServerSeasons = FindConVar("sm_furious_statistics_table_season");

	for (int i = 1; i <= MaxClients; ++i)
	{
		if (IsClientAuthorized(i))
			OnClientAuthorized(i, NULL_STRING);

		if (IsClientInGame(i))
			OnClientPutInServer(i);
	}
}

public void OnSpreadChange(ConVar convar, const char[] oldValue, const char[] newValue) {
	if (StrEqual(oldValue, newValue, false)) {
		return;
	}

	if (StrEqual(newValue, "0", false)) {
		for (int i = 1; i <= MaxClients; i++) {
			if (IsClientInGame(i) && IsPlayerAlive(i)) {
				SetClientSpread(i, 0);
			}
		}
	}
}

public void OnClientDisconnect_Post(int client)
{
	g_iGlobalDropShotKills[client] = 0;
	g_iSeasonDropShotKills[client] = 0;

	g_GlobalDropShotKillsStatus[client] = DropShotKills_Pending;
	g_SeasonDropShotKillsStatus[client] = DropShotKills_Pending;
}

public void OnClientAuthorized(int client, const char[] sAuthID)
{
	if (IsFakeClient(client))
	{
		return;
	}

	if (g_Database_Global == null
		|| g_Database_Server == null
		|| convar_Table_GlobalStatistics == null
		|| convar_Table_ServerSeasons == null
		|| !g_iSeason)
	{
		return;
	}

	static char sQuery[256];

	char sTable[MAX_TABLE_SIZE];
	convar_Table_GlobalStatistics.GetString(sTable, sizeof(sTable));

	g_Database_Global.Format(sQuery, sizeof(sQuery), "SELECT `dropshot_kills` FROM `%s` WHERE `accountid` = %i LIMIT 1;", sTable, GetSteamAccountID(client));
	g_Database_Global.Query(TQuery_OnGetGlobalDropShotKills, sQuery, GetClientSerial(client));

	convar_Table_ServerSeasons.GetString(sTable, sizeof(sTable));

	g_Database_Server.Format(sQuery, sizeof(sQuery), "SELECT `dropshot_kills` FROM `%s%d` WHERE `accountid` = %i LIMIT 1;", sTable, g_iSeason, GetSteamAccountID(client));
	g_Database_Server.Query(TQuery_OnGetSeasonDropShotKills, sQuery, GetClientSerial(client));
}

public void TQuery_OnGetGlobalDropShotKills(Database db, DBResultSet results, const char[] error, any data)
{
	int client = GetClientFromSerial(data);

	if (client)
	{
		// Backup in case any of below fails
		g_GlobalDropShotKillsStatus[client] = DropShotKills_Failure;

		if (results && results.FetchRow())
		{
			g_iGlobalDropShotKills[client] = results.FetchInt(0);

			g_GlobalDropShotKillsStatus[client] = DropShotKills_Loaded;
		}
		else
		{
			if (error[0])
			{
				ThrowError("Query Error: %s", error);
			}

			g_GlobalDropShotKillsStatus[client] = DropShotKills_Loaded;
		}
	}
	else if (error[0])
	{
		ThrowError("Query Error: %s", error);
	}
}

public void TQuery_OnGetSeasonDropShotKills(Database db, DBResultSet results, const char[] error, any data)
{
	int client = GetClientFromSerial(data);

	if (client)
	{
		// Backup in case any of below fails
		g_SeasonDropShotKillsStatus[client] = DropShotKills_Failure;

		if (results && results.FetchRow())
		{
			g_iSeasonDropShotKills[client] = results.FetchInt(0);

			g_SeasonDropShotKillsStatus[client] = DropShotKills_Loaded;
		}
		else
		{
			if (error[0])
			{
				ThrowError("Query Error: %s", error);
			}

			g_SeasonDropShotKillsStatus[client] = DropShotKills_Loaded;
		}
	}
	else if (error[0])
	{
		ThrowError("Query Error: %s", error);
	}
}

public void OnMapStart()
{
	char sBuffer[PLATFORM_MAX_PATH];
	FormatEx(sBuffer, sizeof(sBuffer), "materials/panorama/images/icons/equipment/awp_dropshot_bz.svg");
	AddFileToDownloadsTable(sBuffer);
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	MarkNativeAsOptional("Furious_Weapons_IsDropshotKill");
	RegPluginLibrary("furious_weapons");
	CreateNative("Furious_Weapons_IsDropshotKill", Native_IsDropshotKill);
	return APLRes_Success;
}

public void OnAllPluginsLoaded()
{
	g_bStatistics = LibraryExists("furious_statistics");

	convar_Table_GlobalStatistics = FindConVar("sm_furious_statistics_global_table");
	convar_Table_ServerSeasons = FindConVar("sm_furious_statistics_table_season");
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "furious_statistics"))
		g_bStatistics = true;
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "furious_statistics"))
		g_bStatistics = false;
}

void UpdateGlobalAndSeasonDropShotKills(int client)
{
	if (IsFakeClient(client))
	{
		return;
	}

	if (g_Database_Global == null
		|| g_Database_Server == null
		|| convar_Table_GlobalStatistics == null
		|| convar_Table_ServerSeasons == null
		|| !g_iSeason)
	{
		return;
	}

	if (g_GlobalDropShotKillsStatus[client] != DropShotKills_Loaded
		|| g_SeasonDropShotKillsStatus[client] != DropShotKills_Loaded)
	{
		return;
	}

	static char sQuery[256];

	char sTable[MAX_TABLE_SIZE];
	convar_Table_GlobalStatistics.GetString(sTable, sizeof(sTable));

	g_Database_Global.Format(sQuery, sizeof(sQuery), "UPDATE `%s` SET `dropshot_kills` = %u WHERE `accountid` = %i LIMIT 1;",
		sTable,
		g_iGlobalDropShotKills[client],
		GetSteamAccountID(client));
	g_Database_Global.Query(TQuery_OnUpdateGlobalDropShotKills, sQuery);

	convar_Table_ServerSeasons.GetString(sTable, sizeof(sTable));

	g_Database_Server.Format(sQuery, sizeof(sQuery), "UPDATE `%s%d` SET `dropshot_kills` = %u WHERE `accountid` = %i LIMIT 1;",
		sTable,
		g_iSeason,
		g_iSeasonDropShotKills[client],
		GetSteamAccountID(client));
	g_Database_Server.Query(TQuery_OnUpdateSeasonDropShotKills, sQuery);
}

public Action Event_OnPlayerDeathPre(Event event, const char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("userid");
	int attacker = event.GetInt("attacker");
	int iAttacker = GetClientOfUserId(attacker);

	char sWeapon[32];
	event.GetString("weapon", sWeapon, sizeof(sWeapon));

	if (!StrEqual(sWeapon, "awp") || !g_bIsDropShotKill[iAttacker])
		return Plugin_Continue;

	event.BroadcastDisabled = true;

	Event event_fake = CreateEvent("player_death", true);

	event_fake.SetString("weapon", "awp_dropshot_bz");
	event_fake.SetInt("userid", userid);
	event_fake.SetInt("attacker", attacker);
	event_fake.SetInt("assister", event.GetInt("assister"));
	event_fake.SetBool("headshot", event.GetBool("headshot"));
	event_fake.SetBool("penetrated", event.GetBool("penetrated"));
	event_fake.SetBool("revenge", event.GetBool("revenge"));
	event_fake.SetBool("dominated", event.GetBool("dominated"));
	event_fake.SetBool("noscope", event.GetBool("noscope"));

	for (int i = 1; i <= MaxClients; ++i)
	if (IsClientInGame(i) && !IsFakeClient(i))
		event_fake.FireToClient(i);

	event_fake.Cancel();

	if (g_bStatistics && cvar_DropShot_SeasonalPoints.IntValue && Furious_Statistics_IsRankedEnabled())
	{
		g_iGlobalDropShotKills[iAttacker]++;
		g_iSeasonDropShotKills[iAttacker]++;

		UpdateGlobalAndSeasonDropShotKills(iAttacker);

		Furious_Statistics_AddSeasonalPoints(iAttacker, cvar_DropShot_SeasonalPoints.FloatValue);
		CPrintToChat(iAttacker, "%t", "dropshot points", Furious_Statistics_GetRankPointsGain(iAttacker), GetClientOfUserId(userid), cvar_DropShot_SeasonalPoints.IntValue);
	}

	return Plugin_Changed;
}

public void TQuery_OnUpdateGlobalDropShotKills(Database db, DBResultSet results, const char[] error, any data)
{
	if (error[0])
	{
		ThrowError("Query Error: %s", error);
	}
}

public void TQuery_OnUpdateSeasonDropShotKills(Database db, DBResultSet results, const char[] error, any data)
{
	if (error[0])
	{
		ThrowError("Query Error: %s", error);
	}
}

public int Native_IsDropshotKill(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (client == 0 || client > MaxClients)
		return -1;

	return g_bIsDropShotKill[client];
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitch);
	SDKHook(client, SDKHook_PostThinkPost, OnClientThink);
	SDKHook(client, SDKHook_Touch, OnClientTouch);
}

void SetClientSpread(int client, const int spread)
{
	//not removed
	char sSpread[16];
	IntToString(spread, sSpread, sizeof(sSpread));
	
	SendConVarValue(client, enginevar_NoSpread, sSpread);

	int observerMode;
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || !IsClientObserver(i))
			continue;

		observerMode = GetEntProp(i, Prop_Send, "m_iObserverMode");

		if (observerMode != 4 && observerMode != 5)
			continue;

		if (GetEntPropEnt(i, Prop_Send, "m_hObserverTarget") == client)
			SendConVarValue(i, enginevar_NoSpread, sSpread);
	}
}

public void OnWeaponSwitch(int client, int weapon)
{
	if (IsFakeClient(client) || weapon == -1)
		return;

	if (weapon == -1)
		return;

	char sWeapon[32];
	GetEntityClassname(weapon, sWeapon, sizeof(sWeapon));
	if (!cvar_NoSpreadByDefault.BoolValue || StrEqual(sWeapon, "weapon_awp") && !g_bIsDropShotKill[client]) {
		SetClientSpread(client, 0);
	} else {
		SetClientSpread(client, 1);
	}
}

public void Event_OnWeaponFire(Event event, const char[] name, bool dontBroadcast)
{	
	int client = GetClientOfUserId(event.GetInt("userid"));
	int weapon = GetActiveWeapon(client);

	if (weapon == -1)
		return;

	char sWeapon[32];
	GetEntityClassname(weapon, sWeapon, sizeof(sWeapon));

	if ((cvar_NoSpreadByDefault.BoolValue && (!StrEqual(sWeapon, "weapon_awp") || StrEqual(sWeapon, "weapon_awp") && (GetEntProp(client, Prop_Send, "m_bIsScoped") || g_bIsDropShotKill[client]))) || !cvar_NoSpreadByDefault.BoolValue && (!StrEqual(sWeapon, "weapon_awp") || StrEqual(sWeapon, "weapon_awp") && g_bIsDropShotKill[client])) {
		SetClientSpread(client, 1);
	} else {
		SetClientSpread(client, 0);
	}
}

public void Frame_EnableNospread(any data)
{
	enginevar_NoSpread.SetInt(1);
}

public void OnClientThink(int client)
{
	int weapon = GetActiveWeapon(client);

	if (weapon == -1)
		return;

	int flags = GetEntityFlags(client);
	MoveType movetype = GetEntityMoveType(client);

	if ((flags & FL_ONGROUND) != FL_ONGROUND && movetype != MOVETYPE_NOCLIP && movetype != MOVETYPE_FLY && movetype != MOVETYPE_LADDER)
		g_bIsDropping[client] = true;
	else g_bIsDropping[client] = false;

	if (GetSpeed(client) > DROPSHOT_SPEED || (flags & FL_ONGROUND) == FL_ONGROUND)
	{
		g_bIsDropShotKill[client] = false;
		return;
	}

	if (g_bIsDropping[client] && !g_bIsDropShotKill[client])
	{
		g_bIsDropShotKill[client] = true;

		if (cvar_NoSpreadByDefault.BoolValue)
			SetClientSpread(client, 1);
	}
}

public void OnClientTouch(int client, int other)
{
	g_bIsDropping[client] = false;
	g_bIsDropShotKill[client] = false;

	int weapon = GetActiveWeapon(client);
	if (weapon == -1)
		return;

	char sWeapon[32];
	GetEntityClassname(weapon, sWeapon, sizeof(sWeapon));

	if (!StrEqual(sWeapon, "weapon_awp") || cvar_NoSpreadByDefault.BoolValue && StrEqual(sWeapon, "weapon_awp")) {
		SetClientSpread(client, 1);
	} else {
		SetClientSpread(client, 0);
	}
}

public void Furious_Statistics_StatsMe_OnSeasonStats(int client, char[] text, int maxlength, int& cells)
{
    cells += Format(text[cells], maxlength - cells, "\nDropshot Kills: %d", g_iSeasonDropShotKills[client]);
}

public void Furious_Statistics_OnConnectGlobal()
{
	delete g_Database_Global;

	g_Database_Global = Furious_Statistics_GetGlobalDatabase();
}

public void Furious_Statistics_OnConnectServer()
{
	delete g_Database_Server;

	g_Database_Server = Furious_Statistics_GetServerDatabase();
}

public void Furious_Statistics_OnSeasonRetrieved(int season)
{
	g_iSeason = season;
}

public void Furious_Statistics_SeasonTable_OnCreateTable(char[] queryEnd, int maxlength, int& cells)
{
	cells += Format(queryEnd, maxlength, ", `dropshot_kills` INT(11) UNSIGNED NOT NULL DEFAULT '0'");
}

public void Furious_Statistics_SeasonTable_OnResetData(int client, char[] queryEnd, int maxlength, int& cells)
{
	cells += Format(queryEnd, maxlength, ", `dropshot_kills` = 0");
}

public void Furious_Statistics_OnSeasonalStatsReset(int client)
{
	g_iSeasonDropShotKills[client] = 0;
}

int GetActiveWeapon(int client)
{
	if (client == 0 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client) || !HasEntProp(client, Prop_Send, "m_hActiveWeapon"))
		return 0;

	return GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
}

float GetSpeed(int client)
{
	float vel[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vel);
	return SquareRoot(vel[0] * vel[0] + vel[1] * vel[1]);
}