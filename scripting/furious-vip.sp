/*-- Pragmas --*/
#pragma semicolon 1
#pragma newdecls required

/*-- Defines --*/

/*-- Includes --*/
#include <sourcemod>
#include <sdktools>
#include <clientprefs>
#include <colorlib>
#include <autoexecconfig>
//#include <fragstocks>
//#include <smlib>

#include <furious/furious-stocks>
#include <furious/furious-vip>

#undef REQUIRE_PLUGIN
#include <furious/furious-statistics>
#include <furious/furious-store>
#include <furious/furious-tags>
#define REQUIRE_PLUGIN

#define VIP_FLAGS ADMFLAG_CUSTOM5

/*-- Furious Includes --*/

enum struct ExtensionVote
{
	int ExtensionVote_None;
	int ExtensionVote_Yes;
	int ExtensionVote_No;

	void Reset()
	{
		this.ExtensionVote_None = 0;
		this.ExtensionVote_Yes = 0;
		this.ExtensionVote_No = 0;
	}
}

/*-- ConVars --*/
ConVar convar_Status;
ConVar convar_DoorName;
ConVar convar_Distance;
ConVar convar_Delay;
ConVar convar_CloseTime;
ConVar convar_MaxExtendedVotes;
ConVar convar_ExtendedVoteDelay;
ConVar convar_Table_Donations;
ConVar convar_Sound_Donations;
//ConVar convar_ExtraCredits;

ExtensionVote g_ExtensionVotes;
int g_ExtendedVotesCount = 0;
float g_LastVoteTime = 0.0;
char g_MenuTitle[256];
//char g_sLatestVip[128];

/*-- Globals --*/
int g_iCooldown_Open[MAXPLAYERS + 1];
bool g_IsModelEnabled[MAXPLAYERS + 1] =  { true, ... };
bool g_IsSpecListEnabled[MAXPLAYERS + 1];
bool g_Voted[MAXPLAYERS + 1];
//bool g_bIsShowingVipAnnounce;
Menu g_VoteMenu[MAXPLAYERS + 1] =  { null, ... };
float g_RemainingTime[MAXPLAYERS + 1];

Handle g_ModelCookie = null;
Handle g_SpecListCookie = null;

Handle g_ReloadVIPTimer = null;

//Handle g_hVipAnnounceHud = INVALID_HANDLE;

int g_LastTimeCheck;
Database g_Database = null;

int g_JailDoorEntityRef = INVALID_ENT_REFERENCE;
int g_JailDoorEntity2Ref = INVALID_ENT_REFERENCE;
int g_iJailClip = -1;

/*-- Plugin Info --*/
public Plugin myinfo =
{
	name = "[Furious] VIP",
	author = "Drixevel",
	description = "VIP module for Furious Clan.",
	version = "1.2.1",
	url = "http://furious-clan.com/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("furious_vip");

	CreateNative("Furious_VIP_IsModelEnabled", Native_VIP_IsModelEnabled);
	CreateNative("Furious_VIP_IsSpecListEnabled", Native_VIP_IsSpecListEnabled);
	CreateNative("Furious_VIP_AddVIP", Native_VIP_AddVIP);

	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("furious.phrases");

	AutoExecConfig_SetFile("frs.vip");
	convar_Status = AutoExecConfig_CreateConVar("sm_furious_vip_status", "1", "Status of the plugin.\n(1 = on, 0 = off)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_DoorName = AutoExecConfig_CreateConVar("sm_furious_vip_door_name", "pd", "Name of the door entity to open.", FCVAR_NOTIFY);
	convar_Distance = AutoExecConfig_CreateConVar("sm_furious_vip_open_distance", "999.0", "Distance between the client and the door for it to be detected.", FCVAR_NOTIFY, true, 1.0);
	convar_Delay = AutoExecConfig_CreateConVar("sm_furious_vip_open_delay", "20.0", "Time to delay clients from opening doors again.", FCVAR_NOTIFY, true, 0.0);
	convar_CloseTime = AutoExecConfig_CreateConVar("sm_furious_vip_open_close_time", "8.0", "Time in seconds for the door the client opened to close.", FCVAR_NOTIFY, true, 1.0);
	convar_MaxExtendedVotes = AutoExecConfig_CreateConVar("sm_furious_vip_max_extended_votes", "2", "How many map extension votes are allowed by VIP players each map.", FCVAR_NOTIFY);
	convar_ExtendedVoteDelay = AutoExecConfig_CreateConVar("sm_furious_vip_extended_vote_delay", "10", "Delay between 2 successive votes.", FCVAR_NOTIFY, true, 1.0);
	convar_Table_Donations = AutoExecConfig_CreateConVar("sm_furious_vip_table_donations", "donors", "Name of the donations database table prefix to use.", FCVAR_NOTIFY);
	convar_Sound_Donations = AutoExecConfig_CreateConVar("sm_furious_vip_sound_donations", "frs-misc/frs-donation.mp3", "Sound file to play on donations.", FCVAR_NOTIFY);
	//convar_ExtraCredits = AutoExecConfig_CreateConVar("sm_furious_vip_extra_credits", "2", "Extra credits a vip gets.", FCVAR_NOTIFY, true, 1.0);
	AutoExecConfig_ExecuteFile();

	RegConsoleCmd("sm_vip", Command_VIPMenu, "Open the VIP menu.");
	RegConsoleCmd("sm_donate", Command_VIPMenu, "Open the VIP menu.");
	RegConsoleCmd("sm_voteextend", Command_VoteExtend, "Start the map extension vote if available");
	RegConsoleCmd("sm_ve", Command_VoteExtend, "Start the map extension vote if available");
	RegConsoleCmd("sm_open", Command_Open, "Open the closest door on the map.");
	//RegConsoleCmd("sm_testa", Command_TestAnnounce);

	AutoExecConfig_CleanFile();

	g_ModelCookie = RegClientCookie("model_disabled", "Enables/Disables the player model", CookieAccess_Protected);
	g_SpecListCookie = RegClientCookie("speclist_enabled", "Enables/Disables the speclist", CookieAccess_Protected);

	for (int i = 1; i <= MaxClients; i++)
	if (AreClientCookiesCached(i))
		OnClientCookiesCached(i);

	HookEvent("round_start", OnRoundStart);

	//CreateTimer(0.5, Timer_VipHudAnnounce, _, TIMER_REPEAT);
}

public void OnConfigsExecuted()
{
	if (g_Database == null)
	{
		Database.Connect(DBCallback_Connect, "furious_donations");
	}
}

public void DBCallback_Connect(Database db, const char[] error, any data)
{
	if (db == null)
	{
		ThrowError("DB - Failed to connect: %s", error);
	}

	if (g_Database != null)
	{
		delete db;
		return;
	}

	g_Database = db;
	LogMessage("DB - A connection to the database is established.");
}

public void OnMapStart()
{
	char sBuffer[PLATFORM_MAX_PATH];
	convar_Sound_Donations.GetString(sBuffer, sizeof(sBuffer));

	if (strlen(sBuffer) > 0)
	{
		PrecacheSound(sBuffer);
		Format(sBuffer, sizeof(sBuffer), "sound/%s", sBuffer);
		AddFileToDownloadsTable(sBuffer);
	}

	g_ExtendedVotesCount = 0;
	g_LastVoteTime = GetGameTime();
	g_LastTimeCheck = GetTime();

	CreateTimer(GetRandomFloat(20.0, 60.0), Timer_CheckDonations, _, TIMER_FLAG_NO_MAPCHANGE);
	//	CreateTimer(2.0, Timer_RemoveVIPs, _, TIMER_FLAG_NO_MAPCHANGE);

	delete g_ReloadVIPTimer;
	g_ReloadVIPTimer = CreateTimer(2.5, Timer_ReloadVIPs);
}

public void OnRebuildAdminCache(AdminCachePart part)
{
	delete g_ReloadVIPTimer;
	g_ReloadVIPTimer = CreateTimer(2.5, Timer_ReloadVIPs);
}

public Action Timer_ReloadVIPs(Handle timer)
{
	g_ReloadVIPTimer = null;

	if (g_Database == null)
	{
		return Plugin_Continue;
	}

	char table[64];
	convar_Table_Donations.GetString(table, sizeof(table));

	char buffer[4096];
	g_Database.Format(buffer, sizeof(buffer), "SELECT `username`, `steam_id`, `sign_up_date`, `email`, `renewal_date`, `current_amount`, `total_amount`, `expiration_date` FROM `%s` WHERE `expiration_date` > %i OR `expiration_date` = 0;", table, GetTime()); //expiration_date = 0 is for permanent vips
	g_Database.Query(DBCallback_ReloadVIPsQuery, buffer);

	return Plugin_Continue;
}

public void DBCallback_ReloadVIPsQuery(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
	{
		ThrowError("DB - Error on reload VIPs query: %s", error);
	}

	while (results.FetchRow())
	{
		char steamId[32];
		results.FetchString(1, steamId, sizeof(steamId));

		if (strlen(steamId) > 0)
		{
			bool bound = false;

			AdminId vip;
			if ((vip = FindAdminByIdentity(AUTHMETHOD_STEAM, steamId)) == INVALID_ADMIN_ID)
			{
				vip = CreateAdmin();
			}
			else
			{
				bound = true;
			}

			GroupId vipGroup;
			if ((vipGroup = FindAdmGroup("furious_vip")) == INVALID_GROUP_ID)
			{
				vipGroup = CreateAdmGroup("furious_vip");
			}

			vipGroup.SetFlag(Admin_Custom5, true);
			vipGroup.ImmunityLevel = 66;
			vip.InheritGroup(vipGroup);

			if (!bound && !vip.BindIdentity(AUTHMETHOD_STEAM, steamId))
			{
				RemoveAdmin(vip);
				LogMessage("Could not bind identity: %s", steamId);
			}
		}
	}
}

public Action Timer_CheckDonations(Handle timer, any data)
{
	if (g_Database == null)
	{
		return Plugin_Continue;
	}

	int time = GetTime();

	char table[64];
	convar_Table_Donations.GetString(table, sizeof(table));

	char buffer[4096];
	g_Database.Format(buffer, sizeof(buffer), "SELECT `username`, `steam_id`, `sign_up_date`, `email`, `renewal_date`, `current_amount`, `total_amount`, `expiration_date`, `tier` FROM `%s` WHERE `sign_up_date` BETWEEN %i AND %i OR `renewal_date` BETWEEN %i AND %i;", table, g_LastTimeCheck, time, g_LastTimeCheck, time);
	g_Database.Query(DBCallback_NewDonationsQuery, buffer);

	CreateTimer(GetRandomFloat(20.0, 60.0), Timer_CheckDonations, _, TIMER_FLAG_NO_MAPCHANGE);

	return Plugin_Continue;
}

public void DBCallback_NewDonationsQuery(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
	{
		ThrowError("DB - Error on new donations check query: %s", error);
	}

	bool newDonations = false;

	while (results.FetchRow())
	{
		char name[32];
		results.FetchString(0, name, sizeof(name));

		char steamId[32];
		results.FetchString(1, steamId, sizeof(steamId));

		int sign_up_date = results.FetchInt(2);

		char email[32];
		results.FetchString(3, email, sizeof(email));

		int renewal_date = results.FetchInt(4);
		int total_amount = results.FetchInt(6);
		int expiration_date = results.FetchInt(7);
		/*int tier = results.FetchInt(8);

		if (tier < 1)
		{
			continue;
		}*/

		float diff = float(expiration_date - sign_up_date);

		char time[64];
		FormatSeconds2(diff, time, sizeof(time), "%D days");
		if (!total_amount)
		{
			CPrintToChatAll("%t", "gifted donation", name, time);
			//here
		}
		else if (renewal_date == 0)
		{
			CPrintToChatAll("%t", "new donation", name, time);
			//here
		}
		else
		{
			CPrintToChatAll("%t", "renewed donation", name, time);
			//here
		}
		if (strlen(steamId) > 0)
		{
			AddVIP(steamId, name, email, total_amount, sign_up_date, expiration_date);
		}
		newDonations = true;
	}

	if (newDonations)
	{
		char sBuffer[PLATFORM_MAX_PATH];
		convar_Sound_Donations.GetString(sBuffer, sizeof(sBuffer));

		if (strlen(sBuffer) > 0)
		{
			EmitSoundToAll(sBuffer);
		}
	}

	g_LastTimeCheck = GetTime();
}

public Action Timer_RemoveVIPs(Handle timer, any data)
{
	if (g_Database == null)
	{
		return Plugin_Continue;
	}

	char table[64];
	convar_Table_Donations.GetString(table, sizeof(table));

	char buffer[4096];
	g_Database.Format(buffer, sizeof(buffer), "SELECT `username`, `steam_id`, `sign_up_date`, `email`, `renewal_date`, `current_amount`, `total_amount`, `expiration_date` FROM `%s` WHERE `expiration_date` <= %i AND `expiration_date` <> 0;", table, GetTime());
	g_Database.Query(DBCallback_RemoveVIPsQuery, buffer);

	return Plugin_Continue;
}

public void DBCallback_RemoveVIPsQuery(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
	{
		ThrowError("DB - Error on remove VIPs query: %s", error);
	}

	while (results.FetchRow())
	{
		char name[32];
		results.FetchString(0, name, sizeof(name));

		char steamId[32];
		results.FetchString(1, steamId, sizeof(steamId));

		int sign_up_date = results.FetchInt(2);

		char email[32];
		results.FetchString(3, email, sizeof(email));

		int total_amount = results.FetchInt(4);
		int expiration_date = results.FetchInt(7);

		if (strlen(steamId) > 0)
		{
			RemoveVIP(steamId, name, email, total_amount, sign_up_date, expiration_date);
		}
	}
}

void AddVIP(const char[] steamId, const char[] name, const char[] email, int total_amount, int sign_up_date, int expiration_date)
{
	bool bound = false;

	AdminId vip;
	if ((vip = FindAdminByIdentity(AUTHMETHOD_STEAM, steamId)) == INVALID_ADMIN_ID)
	{
		vip = CreateAdmin();
	}
	else
	{
		bound = true;
	}

	GroupId vipGroup;
	if ((vipGroup = FindAdmGroup("furious_vip")) == INVALID_GROUP_ID)
	{
		vipGroup = CreateAdmGroup("furious_vip");
	}

	vipGroup.SetFlag(Admin_Custom5, true);
	vipGroup.ImmunityLevel = 66;
	vip.InheritGroup(vipGroup);

	if (!bound && !vip.BindIdentity(AUTHMETHOD_STEAM, steamId))
	{
		RemoveAdmin(vip);
		LogMessage("Could not bind identity: %s", steamId);
		return;
	}

	char sStartDate[128], sExpirationDate[128];
	FormatTime(sStartDate, sizeof(sStartDate), "%A, %B %d, %Y at %R", sign_up_date);
	FormatTime(sExpirationDate, sizeof(sExpirationDate), "%A, %B %d, %Y at %R", expiration_date);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))continue;
		char sSteamId[64];
		GetClientAuthId(i, AuthId_Steam2, sSteamId, sizeof(sSteamId));
		if (StrEqual(sSteamId, steamId))
		{
			g_RemainingTime[i] = float(expiration_date - GetTime());
			SetUserFlagBits(i, GetUserFlagBits(i) | VIP_FLAGS);
			break;
		}
	}

	LogToFile("furious_vip.txt", "Added new VIP \"%s\" - steamID: %s, email: %s, total amount: $%d, start date: %s, expiration date: %s", name, steamId, email, total_amount, sStartDate, sExpirationDate);
}

void RemoveVIP(const char[] steamId, const char[] name, const char[] email, int total_amount, int sign_up_date, int expiration_date)
{
	AdminId vip;
	if ((vip = FindAdminByIdentity(AUTHMETHOD_STEAM, steamId)) == INVALID_ADMIN_ID)
	{
		return;
	}

	for (int i = 0; i < vip.GroupCount; i++)
	{
		char group[32];
		vip.GetGroup(i, group, sizeof(group));

		if (StrEqual(group, "furious_vip"))
		{
			vip.SetFlag(Admin_Custom5, false);

			char sStartDate[128], sExpirationDate[128];
			FormatTime(sStartDate, sizeof(sStartDate), "%A, %B %d, %Y at %R", sign_up_date);
			FormatTime(sExpirationDate, sizeof(sExpirationDate), "%A, %B %d, %Y at %R", expiration_date);

			LogToFile("furious_vip.txt", "Removed a VIP \"%s\" - steamID: %s, email: %s, total amount: $%d, start date: %s, expiration date: %s", name, steamId, email, total_amount, sStartDate, sExpirationDate);

			break;
		}
	}
}

public void OnClientCookiesCached(int client)
{
	static char buffer[4];

	GetClientCookie(client, g_ModelCookie, buffer, sizeof(buffer));
	g_IsModelEnabled[client] = !(!!StringToInt(buffer));

	GetClientCookie(client, g_SpecListCookie, buffer, sizeof(buffer));
	g_IsSpecListEnabled[client] = !!StringToInt(buffer);
}

public void OnClientPutInServer(int client)
{
	if (IsFakeClient(client))
	{
		return;
	}

	g_RemainingTime[client] = 0.0;
	g_VoteMenu[client] = null;

	CreateTimer(1.0, Timer_CheckVIPStatus, GetClientSerial(client), TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_CheckVIPStatus(Handle timer, any serial)
{
	if (g_Database == null)
	{
		return Plugin_Continue;
	}

	int client = GetClientFromSerial(serial);

	if (client == 0)
	{
		return Plugin_Continue;
	}

	char steamId[32];
	GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId));

	char table[64];
	convar_Table_Donations.GetString(table, sizeof(table));

	char buffer[4096];
	g_Database.Format(buffer, sizeof(buffer), "SELECT `expiration_date` FROM `%s` WHERE `steam_id` = '%s' AND `expiration_date` > 0 ORDER BY `user_id` DESC;", table, steamId);
	g_Database.Query(DBCallback_CheckVIPStatusQuery, buffer, serial);

	return Plugin_Continue;
}

public void DBCallback_CheckVIPStatusQuery(Database db, DBResultSet results, const char[] error, any serial)
{
	if (results == null)
	{
		ThrowError("DB - Error on check VIP status query: %s", error);
	}

	int client = GetClientFromSerial(serial);

	if (client == 0)
	{
		return;
	}

	if (results.FetchRow())
	{
		int expiration_date = results.FetchInt(0);
		float remaining = g_RemainingTime[client] = float(expiration_date - GetTime());

		if (remaining > 0.0)
		{
			DataPack pack = new DataPack();
			pack.WriteCell(serial);
			pack.WriteFloat(remaining);
			CreateTimer(15.0, Timer_AnnounceVip, pack, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public Action Timer_AnnounceVip(Handle timer, DataPack pack)
{
	pack.Reset();
	int client = GetClientFromSerial(pack.ReadCell());
	float remaining = pack.ReadFloat();
	pack.Close();
	if (!client)return Plugin_Stop;
	char time[64];
	FormatSeconds2(remaining, time, sizeof(time), "%D day(s) and %H hour(s)");
	if (remaining <= 86400.0 * 5)
	{
		CPrintToChat(client, "%T", "vip short remaining days", client, time);
	}
	else
	{
		CPrintToChat(client, "%T", "vip remaining days", client, time);
	}
	return Plugin_Stop;
}

public void OnClientDisconnect_Post(int client)
{
	g_iCooldown_Open[client] = 0;
}

public Action OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (!convar_Status.BoolValue)
		return Plugin_Continue;

	g_JailDoorEntityRef = INVALID_ENT_REFERENCE;

	char sDoor[256], sName[128];
	convar_DoorName.GetString(sDoor, sizeof(sDoor));

	if (strlen(sDoor) == 0)
		strcopy(sDoor, sizeof(sDoor), "pd");

	int entity = INVALID_ENT_REFERENCE;
	while ((entity = FindEntityByClassname(entity, "func_door")) != INVALID_ENT_REFERENCE)
	{
		GetEntPropString(entity, Prop_Data, "m_iName", sName, sizeof(sName));
		if (!StrEqual(sName, sDoor, false) && !StrEqual(sName, "jail_open", false))
			continue;

		if (g_JailDoorEntityRef == INVALID_ENT_REFERENCE)
		{
			g_JailDoorEntityRef = EntIndexToEntRef(entity);
			continue;
		}
		g_JailDoorEntity2Ref = EntIndexToEntRef(entity);
		break;
	}

	g_iJailClip = FindEntityByName("pb_clip", "func_brush");

	return Plugin_Continue;
}

public Action Command_VIPMenu(int client, int args)
{
	ShowVIPMenu(client);
	return Plugin_Handled;
}

public Action Command_VoteExtend(int client, int args)
{
	StartExtensionVote(client);
	return Plugin_Handled;
}

void StartExtensionVote(int client, bool fromMenu = false)
{
	if (!convar_Status.BoolValue || client == 0 || !IsClientInGame(client))
		return;

	if (IsVoteInProgress())
	{
		CReplyToCommand(client, "%T", "vip vote in progress", client);
		return;
	}

	if (!(GetUserFlagBits(client) & VIP_FLAGS))
	{
		CReplyToCommand(client, "%T", "not vip", client);
		return;
	}

	int time = 0;
	if (!GetMapTimeLimit(time) || time <= 0)
	{
		CPrintToChat(client, "%T", "no time left", client);

		if (fromMenu)
		{
			ShowVIPMenu(client);
		}

		return;
	}

	float currentTime = GetGameTime();

	float delay = convar_ExtendedVoteDelay.FloatValue;
	float passedTime = (currentTime - g_LastVoteTime) / 60.0;

	if (passedTime < delay)
	{
		CPrintToChat(client, "%T", "wait for delay", client, RoundToNearest(delay - passedTime + 0.5));

		if (fromMenu)
		{
			ShowVIPMenu(client);
		}

		return;
	}

	int maxExtendedVotes = convar_MaxExtendedVotes.IntValue;

	if (g_ExtendedVotesCount >= maxExtendedVotes)
	{
		CPrintToChat(client, "%T", "max votes reached", client, maxExtendedVotes);

		if (fromMenu)
		{
			ShowVIPMenu(client);
		}

		return;
	}

	ConVar mce_extend_timestep = FindConVar("mce_extend_timestep");

	if (mce_extend_timestep != null)
	{
		static char name[32];
		GetClientName(client, name, sizeof(name));

		Format(g_MenuTitle, sizeof(g_MenuTitle), "%s\nWants to extend the map by %i min(s)", name, mce_extend_timestep.IntValue);

		char buffer[2][64];
		Format(buffer[0], sizeof(buffer[]), "Yes: 0");
		Format(buffer[1], sizeof(buffer[]), "No: 0");

		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i))
			{
				continue;
			}

			if (!IsFakeClient(i))
			{
				Menu menu = new Menu(MenuHandler_SendConfirmation);
				menu.SetTitle(g_MenuTitle);

				menu.AddItem("", "---", ITEMDRAW_DISABLED);
				menu.AddItem("yes", buffer[0]);
				menu.AddItem("no", buffer[1]);

				menu.Display(i, MENU_TIME_FOREVER);

				g_Voted[i] = false;
				g_VoteMenu[i] = menu;
			}
		}

		g_LastVoteTime = currentTime;
		g_ExtendedVotesCount++;

		CreateTimer(10.0, Timer_CheckVotes, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action Timer_CheckVotes(Handle timer)
{
	g_MenuTitle = "";

	// Reset the vote
	g_ExtensionVotes.Reset();

	for (int i = 1; i <= MaxClients; i++)
	{
		if (g_VoteMenu[i] != null)
		{
			delete g_VoteMenu[i]; g_VoteMenu[i] = null;
		}
	}

	ConVar mce_extend_timestep = FindConVar("mce_extend_timestep");

	if (mce_extend_timestep == null)
	{
		return Plugin_Continue;
	}

	int time = 0;

	if (!GetMapTimeLimit(time) || time <= 0)
	{
		CPrintToChatAll("%t", "no time left 2");
		return Plugin_Continue;
	}

	int extendTime = mce_extend_timestep.IntValue;
	int yesVotes = g_ExtensionVotes.ExtensionVote_Yes;
	int noVotes = g_ExtensionVotes.ExtensionVote_No;
	int totalVotes = yesVotes + noVotes;

	if (yesVotes > noVotes)
	{
		CPrintToChatAll("%t", "extending map", yesVotes, totalVotes, extendTime);
		ExtendMapTimeLimit(extendTime * 60);
		g_ExtendedVotesCount = 0;

		return Plugin_Continue;
	}

	CPrintToChatAll("%t", "not enough players to extend", noVotes, totalVotes);
	return Plugin_Continue;
}

public int MenuHandler_SendConfirmation(Menu menuHandle, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[12];
			menuHandle.GetItem(param2, sInfo, sizeof(sInfo));

			if (StrEqual(sInfo, "yes"))
			{
				g_ExtensionVotes.ExtensionVote_Yes++;
				g_Voted[param1] = true;
			}
			else if (StrEqual(sInfo, "no"))
			{
				g_ExtensionVotes.ExtensionVote_No++;
				g_Voted[param1] = true;
			}
			else
			{
				g_ExtensionVotes.ExtensionVote_None++;
				g_Voted[param1] = false;
			}

			g_VoteMenu[param1] = null;

			if (g_Voted[param1])
			{
				char buffer[2][64];
				Format(buffer[0], sizeof(buffer[]), "Yes: %d", g_ExtensionVotes.ExtensionVote_Yes);
				Format(buffer[1], sizeof(buffer[]), "No: %d", g_ExtensionVotes.ExtensionVote_No);

				for (int i = 1; i <= MaxClients; i++)
				{
					if (i == param1)
					{
						continue;
					}

					if (!IsClientInGame(i))
					{
						continue;
					}

					if (!IsFakeClient(i) && !g_Voted[i])
					{
						if (g_VoteMenu[i] != null)
						{
							delete g_VoteMenu[i]; g_VoteMenu[i] = null;
						}

						Menu menu = new Menu(MenuHandler_SendConfirmation);
						menu.SetTitle(g_MenuTitle);

						menu.AddItem("", "---", ITEMDRAW_DISABLED);
						menu.AddItem("yes", buffer[0]);
						menu.AddItem("no", buffer[1]);

						menu.Display(i, MENU_TIME_FOREVER);

						g_VoteMenu[i] = menu;
					}
				}
			}
		}
	}

	return 0;
}

void ShowVIPMenu(int client)
{
	if (!convar_Status.BoolValue || client == 0 || !IsClientInGame(client))
		return;

	if (!(GetUserFlagBits(client) & VIP_FLAGS))
	{
		CReplyToCommand(client, "%T", "not vip", client);
		return;
	}

	char title[128];

	float remaining = g_RemainingTime[client];
	if (remaining < 0.0)
	{
		remaining = 0.0;
		Format(title, sizeof(title), "VIP Menu");
	}
	else if (remaining == 0.0)
	{
		Format(title, sizeof(title), "VIP Menu (Permanent)");
	}
	else
	{
		FormatSeconds2(remaining, title, sizeof(title), "VIP Menu (%D days left)");
	}

	Menu menu = new Menu(MenuHandler_VIP);
	menu.SetTitle(title);

	menu.AddItem("model", g_IsModelEnabled[client] ? "Player Model (Enabled ◉)" : "Player Model (Disabled ◎)");
	menu.AddItem("speclist", g_IsSpecListEnabled[client] ? "Spectators List (Enabled ◉)" : "Spectators list (Disabled ◎)");
	menu.AddItem("map_extend", "Vote Map Extend", g_ExtendedVotesCount < convar_MaxExtendedVotes.IntValue ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	menu.AddItem("tag", "Change Tag");

	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_VIP(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			if (!(GetUserFlagBits(param1) & VIP_FLAGS))
			{
				CPrintToChat(param1, "%T", "not vip", param1);
				return 0;
			}

			char info[32];
			menu.GetItem(param2, info, sizeof(info));

			if (StrEqual(info, "model"))
			{
				g_IsModelEnabled[param1] = !g_IsModelEnabled[param1];

				if (g_IsModelEnabled[param1])
				{
					SetClientCookie(param1, g_ModelCookie, "0");
					CPrintToChat(param1, "%T", "model enabled", param1);
				}
				else
				{
					SetClientCookie(param1, g_ModelCookie, "1");
					CPrintToChat(param1, "%T", "model disabled", param1);
				}

				ShowVIPMenu(param1);
			}
			else if (StrEqual(info, "speclist"))
			{
				g_IsSpecListEnabled[param1] = !g_IsSpecListEnabled[param1];

				if (g_IsSpecListEnabled[param1])
				{
					SetClientCookie(param1, g_SpecListCookie, "1");
					CPrintToChat(param1, "%T", "speclist enabled", param1);
				}
				else
				{
					SetClientCookie(param1, g_SpecListCookie, "0");
					CPrintToChat(param1, "%T", "speclist disabled", param1);

					// This will make the Hud from furious-statistics plugin disappear asap
					PrintHintText(param1, "");
				}

				ShowVIPMenu(param1);
			}
			else if (StrEqual(info, "map_extend"))
			{
				StartExtensionVote(param1, true);
			}
			else if (StrEqual(info, "tag"))
			{
				Furious_Tags_ChangeTagMenu(param1);
			}
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}

	return 0;
}

public Action Command_Open(int client, int args)
{
	if (!convar_Status.BoolValue || client == 0)
		return Plugin_Handled;

	if (!client || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Handled;

	CPrintToChat(client, "%T", "attempting to open", client);

	int flags = GetUserFlagBits(client);
	bool isVIP = flags & VIP_FLAGS != 0;

	if (!isVIP)
	{
		CReplyToCommand(client, "%T", "not authorized", client);
		//return Plugin_Handled;
	}

	int time = GetTime();
	int delay = convar_Delay.IntValue;

	if (time - g_iCooldown_Open[client] <= delay)
	{
		int timeleft = delay - (time - g_iCooldown_Open[client]);
		CPrintToChat(client, "%T", "need to wait", client, timeleft);

		return Plugin_Handled;
	}
	int charges = Furious_Store_GetClientCharges(client, "Charges");
	if (!isVIP && !(flags & ADMFLAG_RESERVATION))
	{

		if (charges < 1)
		{
			CPrintToChat(client, "%T", "not enough charges", client, "Charges", charges);
			return Plugin_Handled;
		}

		Furious_Store_SetClientCharges(client, "Charges", ITEM_DEFINE_OPENCHARGES, --charges);
	}

	if (g_JailDoorEntityRef != INVALID_ENT_REFERENCE)
	{
		int iJailDoorEntity = EntRefToEntIndex(g_JailDoorEntityRef);

		float vecPlayerOrigin[3];
		GetClientAbsOrigin(client, vecPlayerOrigin);

		float vecEntityOrigin[3];
		GetEntPropVector(iJailDoorEntity, Prop_Send, "m_vecOrigin", vecEntityOrigin);

		if (GetVectorDistance(vecPlayerOrigin, vecEntityOrigin) > convar_Distance.FloatValue)
		{
			CPrintToChat(client, "%T", "distance too long", client);
			Furious_Store_SetClientCharges(client, "Charges", ITEM_DEFINE_OPENCHARGES, ++charges);
			return Plugin_Handled;
		}

		AcceptEntityInput(iJailDoorEntity, "Open");
		CreateTimer(convar_CloseTime.FloatValue, Timer_CloseDoor, g_JailDoorEntityRef, TIMER_FLAG_NO_MAPCHANGE);

		char sMap[64];
		GetCurrentMap(sMap, sizeof(sMap));
		if (StrContains(sMap, "surf_ski_3_frs") != -1)
		{
			int iJailDoorEntity2 = EntRefToEntIndex(g_JailDoorEntity2Ref);

			AcceptEntityInput(iJailDoorEntity2, "Open");
			CreateTimer(convar_CloseTime.FloatValue, Timer_CloseDoor, g_JailDoorEntity2Ref, TIMER_FLAG_NO_MAPCHANGE);
		}
		//here
		g_iCooldown_Open[client] = time;
		if (g_iJailClip != -1)
			AcceptEntityInput(g_iJailClip, "Disable");
		CPrintToChatAll("%t", "jail opened", client);
	}
	else
	{
		CPrintToChatAll("%t", "no jail found", client);
		Furious_Store_SetClientCharges(client, "Charges", ITEM_DEFINE_OPENCHARGES, ++charges);
	}

	return Plugin_Handled;
}

public Action Timer_CloseDoor(Handle timer, any data)
{
	int entity = EntRefToEntIndex(data);

	if (IsValidEntity(entity))
		AcceptEntityInput(entity, "Close");
	
	return Plugin_Continue;
}

public int Native_VIP_IsModelEnabled(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (client == 0 || client > MaxClients)
		return false;

	return g_IsModelEnabled[client];
}

public int Native_VIP_IsSpecListEnabled(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (client == 0 || client > MaxClients)
		return false;

	return g_IsSpecListEnabled[client];
}

public int Native_VIP_AddVIP(Handle plugin, int numParams)
{
	if (g_Database == null)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Not connected to DB.");
	}

	int usernameLen;
	GetNativeStringLength(1, usernameLen);

	if (usernameLen < 1)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Cannot process with empty username.");
	}

	char[] username = new char[++usernameLen];
	GetNativeString(1, username, usernameLen);

	int steamIdLen;
	GetNativeStringLength(2, steamIdLen);

	if (steamIdLen < 1)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Cannot process with empty username.");
	}

	char[] steamId = new char[++steamIdLen];
	GetNativeString(2, steamId, steamIdLen);

	int duration = GetNativeCell(3);
	bool tryout = view_as<bool>(GetNativeCell(4));

	char table[64];
	convar_Table_Donations.GetString(table, sizeof(table));

	char buffer[4096];
	g_Database.Format(buffer, sizeof(buffer), "SELECT `sign_up_date`, `expiration_date`, `tryout_used`, `tier` FROM `%s` WHERE `steam_id` = '%s';", table, steamId);

	SQL_LockDatabase(g_Database);
	DBResultSet results = SQL_Query(g_Database, buffer);
	SQL_UnlockDatabase(g_Database);

	if (results == null)
	{
		char error[255];
		SQL_GetError(g_Database, error, sizeof(error));
		ThrowError("DB - Error on add VIP query: %s", error);
	}

	int sign_up_date = 0, expiration_date = 0;
	bool tryout_used = false;
	int tier = 0;

	int time = GetTime();

	if (results.FetchRow())
	{
		sign_up_date = results.FetchInt(0);
		expiration_date = results.FetchInt(1);
		tryout_used = view_as<bool>(results.FetchInt(2));
		tier = results.FetchInt(3);

		if (tryout)
		{
			if (expiration_date >= time)
			{
				delete results;
				return view_as<int>(ADDVIP_ALREADY_VIP); // Currently VIP
			}
			else if (tryout_used)
			{
				delete results;
				return view_as<int>(ADDVIP_ALREADY_TRIED_VIP); // Already tried the VIP out
			}
		}
	}

	delete results;

	bool bound = false;

	AdminId vip;
	if ((vip = FindAdminByIdentity(AUTHMETHOD_STEAM, steamId)) == INVALID_ADMIN_ID)
	{
		vip = CreateAdmin();
	}
	else
	{
		bound = true;
	}

	GroupId vipGroup;
	if ((vipGroup = FindAdmGroup("furious_vip")) == INVALID_GROUP_ID)
	{
		vipGroup = CreateAdmGroup("furious_vip");
	}

	vipGroup.SetFlag(Admin_Custom5, true);
	vipGroup.ImmunityLevel = 66;
	vip.InheritGroup(vipGroup);

	if (!bound && !vip.BindIdentity(AUTHMETHOD_STEAM, steamId))
	{
		RemoveAdmin(vip);
		return view_as<int>(ADDVIP_CANNOT_BIND);
	}

	bool newRow = false;

	if (sign_up_date == 0)
	{
		sign_up_date = time;
		expiration_date = sign_up_date + duration;
		newRow = true;
	}
	else
	{
		expiration_date += duration;
	}

	char sStartDate[128], sExpirationDate[128];
	FormatTime(sStartDate, sizeof(sStartDate), "%A, %B %d, %Y at %R", sign_up_date);
	FormatTime(sExpirationDate, sizeof(sExpirationDate), "%A, %B %d, %Y at %R", expiration_date);

	LogToFile("furious_vip.txt", "Added new VIP - steamID: %s, start date: %s, expiration date: %s", steamId, sStartDate, sExpirationDate);

	char sQuery[512];
	if (newRow)
	{
		int escapedUsernameLen = usernameLen * 2;
		char[] escapedUsername = new char[escapedUsernameLen];
		g_Database.Escape(username, escapedUsername, escapedUsernameLen);

		g_Database.Format(sQuery, sizeof(sQuery), "INSERT INTO `%s` (`username`, `steam_id`, `sign_up_date`, `current_amount`, `expiration_date`, `tryout_used`, `tier`) VALUES ('%s', '%s', '%i', '0', '%i', '%i', '0');", table, escapedUsername, steamId, sign_up_date, expiration_date, tryout ? 1 : 0);
		g_Database.Query(TQuery_OnAddVIP, sQuery);
	}
	else
	{
		if (tier == 0)
		{
			if (tryout_used)
			{
				g_Database.Format(sQuery, sizeof(sQuery), "UPDATE `%s` SET `renewal_date` = '%i', `expiration_date` = '%i', `tier` = '0' WHERE `steam_id` = '%s';", table, sign_up_date, expiration_date, steamId);
				g_Database.Query(TQuery_OnUpdateVIP, sQuery);
			}
			else
			{
				g_Database.Format(sQuery, sizeof(sQuery), "UPDATE `%s` SET `renewal_date` = '%i', `expiration_date` = '%i', `tryout_used` = '%i', `tier` = '0' WHERE `steam_id` = '%s';", table, sign_up_date, expiration_date, tryout ? 1 : 0, steamId);
				g_Database.Query(TQuery_OnUpdateVIP, sQuery);
			}
		}
		else
		{
			if (tryout_used)
			{
				g_Database.Format(sQuery, sizeof(sQuery), "UPDATE `%s` SET `renewal_date` = '%i', `expiration_date` = '%i' WHERE `steam_id` = '%s';", table, sign_up_date, expiration_date, steamId);
				g_Database.Query(TQuery_OnUpdateVIP, sQuery);
			}
			else
			{
				g_Database.Format(sQuery, sizeof(sQuery), "UPDATE `%s` SET `renewal_date` = '%i', `expiration_date` = '%i', `tryout_used` = '%i' WHERE `steam_id` = '%s';", table, sign_up_date, expiration_date, tryout ? 1 : 0, steamId);
				g_Database.Query(TQuery_OnUpdateVIP, sQuery);
			}
		}
	}

	return view_as<int>(ADDVIP_SUCCESS);
}

public void TQuery_OnAddVIP(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
		ThrowError("Error while adding VIP: %s", error);
}

public void TQuery_OnUpdateVIP(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
		ThrowError("Error while updating VIP: %s", error);
}

void FormatSeconds2(float seconds, char[] buffer, int maxlength, const char[] format, bool precision = false)
{
	int t = RoundToFloor(seconds);

	int day; char sDay[32];
	if (t >= 86400)
	{
		day = RoundToFloor(t / 86400.0);
		t %= 86400;

		IntToString(day, sDay, sizeof(sDay));
	}

	int hour; char sHour[32];
	if (t >= 3600)
	{
		hour = RoundToFloor(t / 3600.0);
		t %= 3600;

		IntToString(hour, sHour, sizeof(sHour));
	}

	int mins; char sMinute[32];
	if (t >= 60)
	{
		mins = RoundToFloor(t / 60.0);
		t %= 60;

		IntToString(mins, sMinute, sizeof(sMinute));
	}

	char sSeconds[32];
	switch (precision)
	{
		case true:Format(sSeconds, sizeof(sSeconds), "%05.2f", float(t) + seconds - RoundToFloor(seconds));
		case false:Format(sSeconds, sizeof(sSeconds), "%02d", t);
	}

	strcopy(buffer, maxlength, format);

	int pos = -1, removeLen = 0;

	ReplaceString(buffer, maxlength, "%D", strlen(sDay) > 0 ? sDay : "0");

	if ((pos = StrContains(buffer[removeLen], "%H")) == -1)
	{
		strcopy(buffer, maxlength, buffer[removeLen]);
		return;
	}
	else if (day < 1)
	{
		removeLen += pos + strlen(sDay);
	}

	ReplaceString(buffer, maxlength, "%H", strlen(sHour) > 0 ? sHour : "0");

	if ((pos = StrContains(buffer[removeLen], "%M")) == -1)
	{
		strcopy(buffer, maxlength, buffer[removeLen]);
		return;
	}
	else if (hour < 1)
	{
		removeLen += pos + strlen(sHour);
	}

	ReplaceString(buffer, maxlength, "%M", strlen(sMinute) > 0 ? sMinute : "0");

	if ((pos = StrContains(buffer[removeLen], "%S")) == -1)
	{
		strcopy(buffer, maxlength, buffer[removeLen]);
		return;
	}
	else if (mins < 1)
	{
		removeLen += pos + strlen(sMinute);
	}

	strcopy(buffer, maxlength, buffer[removeLen]);
	ReplaceString(buffer, maxlength, "%S", strlen(sSeconds) > 0 ? sSeconds : "0");
}
/*
public Action Command_TestAnnounce(int client, int args)
{
	VipHudsyncAnnounce("Player");
	return Plugin_Handled;
}

void VipHudsyncAnnounce(char[] name)
{
	g_bIsShowingVipAnnounce = true;
	strcopy(g_sLatestVip, sizeof(g_sLatestVip), name);
	g_hVipAnnounceHud = CreateHudSynchronizer();
}

public Action Timer_VipHudAnnounce(Handle timer)
{
	static int index;

	if (g_hVipAnnounceHud == INVALID_HANDLE || index == 5)
	{
		index = 0;
		if (g_hVipAnnounceHud == INVALID_HANDLE)
			delete g_hVipAnnounceHud;
		g_hVipAnnounceHud = INVALID_HANDLE;
		return Plugin_Continue;
	}

	SetHudTextParams(-1.0, -1.0, 5.0, 255, 0, 0, 255);

	for (int i = 1; i <= MaxClients; ++i)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
			continue;

		ShowSyncHudText(i, g_hVipAnnounceHud, "%s has just bought VIP!", g_sLatestVip);
	}
	++index;
} */