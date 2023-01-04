/*-- Pragmas --*/
#pragma semicolon 1
#pragma newdecls required

/*-- Defines --*/
#define MAX_ACHIEVEMENTS 256
#define MAX_ACHIEVEMENT_NAME 256
#define MAX_ACHIEVEMENT_TYPE 256
#define MAX_VARIABLE_KEY 256
#define MAX_VARIABLE_VALUE 256

#define MAX_TABLE_SIZE 64

/*-- Includes --*/
#include <sourcemod>
#include <colorlib>
#include <autoexecconfig>

/*-- Furious Includes --*/
#include <furious/furious-statistics>

/*-- ConVars --*/
ConVar convar_Status;
ConVar convar_Config;
ConVar convar_Table_Achievements;
ConVar convar_DefaultPriority;

/*-- Globals --*/
Database g_Database;
char g_sAchievement_Name[MAX_ACHIEVEMENTS][MAX_ACHIEVEMENT_NAME];
int g_iAchievement_Priority[MAX_ACHIEVEMENTS];
char g_sAchievement_Type[MAX_ACHIEVEMENTS][MAX_ACHIEVEMENT_TYPE];
StringMap g_Achievement_Variables[MAX_ACHIEVEMENTS];
int g_iAchievements;

ArrayList g_CachedAchievements[MAXPLAYERS + 1];

/*-- Plugin Info --*/
public Plugin myinfo =
{
	name = "[Furious] Achievements",
	author = "Drixevel",
	description = "Achievements module for Furious Clan.",
	version = "1.0.0",
	url = "http://furious-clan.com/"
};

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("furious.phrases");

	AutoExecConfig_SetFile("frs.achievements");
	convar_Status = AutoExecConfig_CreateConVar("sm_furious_achievements_status", "1", "Status of the plugin.\n(1 = on, 0 = off)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_Config = AutoExecConfig_CreateConVar("sm_furious_achievements_config", "configs/furious/furious_achievements.cfg", "Config to use for achievements.", FCVAR_NOTIFY);
	convar_Table_Achievements = AutoExecConfig_CreateConVar("sm_furious_achievements_table_achievements", "furious_global_achievements", "Name of the database table to use in side the global database for achievements.", FCVAR_NOTIFY);
	convar_DefaultPriority = AutoExecConfig_CreateConVar("sm_furious_achievements_default_priority", "1", "Default priority to give achievements with no priority fields specified.", FCVAR_NOTIFY);
	AutoExecConfig_ExecuteFile();

	CreateTimer(1.0, Timer_CheckForAchievements, _, TIMER_REPEAT);

	AutoExecConfig_CleanFile();
}

public void OnConfigsExecuted()
{
	if (!convar_Status.BoolValue)
		return;

	if (g_Database == null)
		Database.Connect(OnSQLConnect, "furious_global");

	ParseAchievementsConfig();
}

public void OnSQLConnect(Database db, const char[] error, any data)
{
	if (db == null)
		ThrowError("Error connecting to the global database: %s", error);

	if (g_Database != null)
	{
		delete db;
		return;
	}

	g_Database = db;
	LogMessage("Connected to global database successfully.");

	char sTable[MAX_TABLE_SIZE];
	char sQuery[4096];

	convar_Table_Achievements.GetString(sTable, sizeof(sTable));
	g_Database.Format(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS `%s` ( `id` int(12) NOT NULL AUTO_INCREMENT, `name` varchar(32) NOT NULL DEFAULT '', `accountid` int(64) NOT NULL DEFAULT 0, `steamid2` varchar(64) NOT NULL DEFAULT '', `steamid3` varchar(64) NOT NULL DEFAULT '', `steamid64` varchar(64) NOT NULL DEFAULT '', `achievement` varchar(32) NOT NULL DEFAULT '', `priority` int(12) NOT NULL DEFAULT 0, `first_created` int(12) NOT NULL, PRIMARY KEY (`id`), UNIQUE KEY `id` (`id`), UNIQUE KEY `accountid` (`accountid`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 DEFAULT COLLATE=utf8mb4_unicode_ci;", sTable);
	g_Database.Query(TQuery_OnTableCreation_Achievements, sQuery);
}

public void TQuery_OnTableCreation_Achievements(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
		ThrowError("Error creating achievements table: %s", error);
}

public void OnClientPutInServer(int client)
{
	if (!convar_Status.BoolValue || IsFakeClient(client))
		return;

	delete g_CachedAchievements[client];
	g_CachedAchievements[client] = new ArrayList(ByteCountToCells(MAX_ACHIEVEMENT_NAME));

	if (g_Database != null)
	{
		char sTable[MAX_TABLE_SIZE];
		convar_Table_Achievements.GetString(sTable, sizeof(sTable));

		char sQuery[128];
		g_Database.Format(sQuery, sizeof(sQuery), "SELECT * FROM `%s` WHERE accountid = '%i';", sTable, GetSteamAccountID(client));
		g_Database.Query(TQuery_ParseClientAchievements, sQuery, GetClientUserId(client));
	}
}

public void TQuery_ParseClientAchievements(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
		ThrowError("Error parsing a clients achievements: %s", error);

	int client;
	if ((client = GetClientOfUserId(data)) == 0 || results.RowCount == 0)
		return;

	while (results.FetchRow())
	{
		char sName[MAX_ACHIEVEMENT_NAME];
		results.FetchString(0, sName, sizeof(sName));
		g_CachedAchievements[client].PushString(sName);
	}
}

public void OnClientDisconnect(int client)
{
	delete g_CachedAchievements[client];
}

void ParseAchievementsConfig()
{
	char sConfig[PLATFORM_MAX_PATH];
	convar_Config.GetString(sConfig, sizeof(sConfig));

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), sConfig);

	KeyValues kv = new KeyValues("furious_achievements");

	if (kv.ImportFromFile(sPath) && kv.GotoFirstSubKey())
	{
		for (int i = 0; i < g_iAchievements; i++)
		{
			g_sAchievement_Name[i][0] = '\0';
			g_iAchievement_Priority[i] = 0;
			g_sAchievement_Type[i][0] = '\0';
			delete g_Achievement_Variables[i];
		}

		g_iAchievements = 0;

		do
		{
			kv.GetSectionName(g_sAchievement_Name[g_iAchievements], MAX_ACHIEVEMENT_NAME);
			g_iAchievement_Priority[g_iAchievements] = kv.GetNum("priority", convar_DefaultPriority.IntValue);
			kv.GetString("type", g_sAchievement_Type[g_iAchievements], MAX_ACHIEVEMENT_TYPE);

			if (kv.JumpToKey("variables") && kv.GotoFirstSubKey(false))
			{
				StringMap variables = new StringMap();

				do
				{
					char sKey[MAX_VARIABLE_KEY];
					kv.GetSectionName(sKey, sizeof(sKey));

					char sValue[MAX_VARIABLE_VALUE];
					kv.GetString(NULL_STRING, sValue, sizeof(sValue));

					variables.SetString(sKey, sValue);
				}
				while (kv.GotoNextKey(false));

				g_Achievement_Variables[g_iAchievements] = variables;

				kv.GoBack();
			}

			g_iAchievements++;
		}
		while (kv.GotoNextKey());
	}

	LogMessage("Achievements config parsed. [%i sections loaded]", g_iAchievements);
	delete kv;
}

public void Furious_OnGlobalStatisticUpdate_Kill(int client, int kills, const char[] weapon)
{
	if (!convar_Status.BoolValue || g_iAchievements == 0)
		return;

	char sRequiredKills[MAX_VARIABLE_VALUE]; int iRequiredKills;
	char sRequiredWeapon[MAX_VARIABLE_VALUE];
	char sRequiredDropdown[MAX_VARIABLE_VALUE];
	bool bDropdown;

	for (int i = 0; i < g_iAchievements; i++)
	{
		if (StrEqual(g_sAchievement_Type[i], "kills") && g_Achievement_Variables[i] != null)
		{
			g_Achievement_Variables[i].GetString("amount", sRequiredKills, sizeof(sRequiredKills));
			iRequiredKills = StringToInt(sRequiredKills);

			g_Achievement_Variables[i].GetString("weapon", sRequiredWeapon, sizeof(sRequiredWeapon));

			g_Achievement_Variables[i].GetString("dropdown", sRequiredDropdown, sizeof(sRequiredDropdown));
			bDropdown = view_as<bool>(StringToInt(sRequiredDropdown));

			if (strlen(sRequiredWeapon) > 0 && !StrEqual(sRequiredWeapon, weapon))
				continue;

			if (bDropdown)
			{
				if (GetSpeed(client) >= 50.0 || GetEntityFlags(client) & FL_ONGROUND || GetEntPropFloat(client, Prop_Send, "m_fAccuracyPenalty") != 0.0)
					continue;
			}

			if (kills >= iRequiredKills)
				CheckClientAchievement(client, g_sAchievement_Name[i], g_iAchievement_Priority[i]);
		}
	}
}

float GetSpeed(int client)
{
    float vel[3];
    GetEntPropVector(client, Prop_Data, "m_vecVelocity", vel);
    return SquareRoot(vel[0] * vel[0] + vel[1] * vel[1]);
}

public Action Timer_CheckForAchievements(Handle timer)
{
	if (!convar_Status.BoolValue || g_iAchievements == 0)
		return Plugin_Continue;

	char sRequiredFlags[MAX_VARIABLE_VALUE]; char sRequiredHours[MAX_VARIABLE_VALUE]; float fRequiredTime;
	for (int achievement = 0; achievement < g_iAchievements; achievement++)
	{
		if (StrEqual(g_sAchievement_Type[achievement], "flags") && g_Achievement_Variables[achievement] != null)
		{
			g_Achievement_Variables[achievement].GetString("flags", sRequiredFlags, sizeof(sRequiredFlags));

			for (int x = 1; x <= MaxClients; x++)
			{
				if (IsClientInGame(x) && !IsFakeClient(x) && CheckCommandAccess(x, "", ReadFlagString(sRequiredFlags), false))
					CheckClientAchievement(x, g_sAchievement_Name[achievement], g_iAchievement_Priority[achievement]);
			}
		}

		if (StrEqual(g_sAchievement_Type[achievement], "playtime") && g_Achievement_Variables[achievement] != null)
		{
			g_Achievement_Variables[achievement].GetString("hours", sRequiredHours, sizeof(sRequiredHours));
			fRequiredTime = StringToFloat(sRequiredHours) * 60.0 * 60.0;

			for (int x = 1; x <= MaxClients; x++)
			{
				if (IsClientInGame(x) && !IsFakeClient(x) && Furious_Statistics_GetPlaytime(x) >= fRequiredTime)
					CheckClientAchievement(x, g_sAchievement_Name[achievement], g_iAchievement_Priority[achievement]);
			}
		}
	}

	return Plugin_Continue;
}

void CheckClientAchievement(int client, const char[] name, int priority = -1)
{
	if (!convar_Status.BoolValue || g_CachedAchievements[client].FindString(name) != -1)
		return;

	char sTable[MAX_TABLE_SIZE];
	convar_Table_Achievements.GetString(sTable, sizeof(sTable));

	int iAccount = GetSteamAccountID(client);

	char sQuery[4096];
	g_Database.Format(sQuery, sizeof(sQuery), "SELECT * FROM `%s` WHERE accountid = '%i' AND achievement = '%s';", sTable, iAccount, name);

	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(client));
	pack.WriteString(name);
	pack.WriteCell(priority);

	g_Database.Query(TQuery_CheckClientAchievement, sQuery, pack);
}

public void TQuery_CheckClientAchievement(Database db, DBResultSet results, const char[] error, DataPack data)
{
	if (results == null)
	{
		delete data;
		ThrowError("Error checking an achievement in the database table: %s", error);
	}

	data.Reset();

	int client = GetClientOfUserId(data.ReadCell());

	char sName[MAX_ACHIEVEMENT_NAME];
	data.ReadString(sName, sizeof(sName));

	int priority = data.ReadCell();

	delete data;

	if (client > 0 && !results.FetchRow())
		GiveClientAchievement(client, sName, priority);
}

void GiveClientAchievement(int client, const char[] name, int priority = -1)
{
	if (!convar_Status.BoolValue)
		return;

	char sTable[MAX_TABLE_SIZE];
	convar_Table_Achievements.GetString(sTable, sizeof(sTable));

	char sName[MAX_NAME_LENGTH];
	GetClientName(client, sName, sizeof(sName));

	int size = 2 * MAX_NAME_LENGTH + 1;
	char[] sEscapedName = new char[size + 1];
	g_Database.Escape(sName, sEscapedName, size + 1);

	int iAccount = GetSteamAccountID(client);

	char sSteamID2[64];
	GetClientAuthId(client, AuthId_Steam2, sSteamID2, sizeof(sSteamID2));

	char sSteamID3[64];
	GetClientAuthId(client, AuthId_Steam3, sSteamID2, sizeof(sSteamID2));

	char sSteamID64[64];
	GetClientAuthId(client, AuthId_SteamID64, sSteamID2, sizeof(sSteamID2));

	if (priority == -1)
		priority = GetAchievementPriority(name);

	char sQuery[4096];
	g_Database.Format(sQuery, sizeof(sQuery), "INSERT INTO `%s` (name, accountid, steamid2, steamid3, steamid64, achievement, priority, first_created) VALUES ('%s', '%i', '%s', '%s', '%s', '%s', '%i', '%i');", sTable, sEscapedName, iAccount, sSteamID2, sSteamID3, sSteamID64, name, priority, GetTime());

	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(client));
	pack.WriteString(name);
	pack.WriteCell(priority);

	g_Database.Query(TQuery_GiveClientAchievement, sQuery, pack);
}

public void TQuery_GiveClientAchievement(Database db, DBResultSet results, const char[] error, DataPack data)
{
	if (results == null)
	{
		delete data;
		ThrowError(": %s", error);
	}

	data.Reset();

	int client = GetClientOfUserId(data.ReadCell());

	char sName[MAX_ACHIEVEMENT_NAME];
	data.ReadString(sName, sizeof(sName));

	int priority = data.ReadCell();

	delete data;

	if (client > 0 && IsClientInGame(client))
	{
		g_CachedAchievements[client].PushString(sName);

		CPrintToChat(client, "%T", "achievement earned", client, sName);

		//CPrintToChat(client, "%T", "achievement item received", client, item);
		//CPrintToChat(client, "%T", "achievement credits received", client, credits);

		LogMessage("%N has gained the achievement '%s'! [%i]", client, sName, priority);
	}
}

int GetAchievementPriority(const char[] name)
{
	for (int i = 0; i < g_iAchievements; i++)
	{
		if (StrEqual(name, g_sAchievement_Name[i]))
			return g_iAchievement_Priority[i];
	}

	return convar_DefaultPriority.IntValue;
}
