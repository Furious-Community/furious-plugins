/*-- Pragmas --*/
#pragma semicolon 1
#pragma newdecls required

/*-- Defines --*/
#define MAX_TABLE_SIZE 64

/*-- Includes --*/
#include <sourcemod>
#include <sdktools>
#include <colorlib>
#include <autoexecconfig>

/*-- Furious Includes --*/
#include <furious/furious-stocks>

/*-- ConVars --*/
ConVar convar_Status;
ConVar convar_Table_Announcements;
ConVar convar_Table_AnnouncementsSeen;

/*-- Globals --*/
Database g_Database;

ArrayList g_AnnouncementIDs;
StringMap g_AnnouncementNames;
StringMap g_AnnouncementOverlay;
StringMap g_AnnouncementPanelTitle;
StringMap g_AnnouncementPanelContents;
StringMap g_AnnouncementPrintChat;
StringMap g_AnnouncementPrintCenter;
StringMap g_AnnouncementPrintHint;
StringMap g_AnnouncementSound;

ArrayList g_ShowAnnouncements[MAXPLAYERS + 1];

/*-- Plugin Info --*/
public Plugin myinfo =
{
	name = "[Furious] Announcements",
	author = "Drixevel",
	description = "Announcements module for Furious Clan.",
	version = "1.0.0",
	url = "http://furious-clan.com/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	//RegPluginLibrary("furious_announcements");

	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("furious.phrases");

	AutoExecConfig_SetFile("frs.vip");
	convar_Status = AutoExecConfig_CreateConVar("sm_furious_announcements_status", "1", "Status of the plugin.\n(1 = on, 0 = off)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_Table_Announcements = AutoExecConfig_CreateConVar("sm_furious_announcements_table_announcements", "furious_global_announcements", "Name of the database table to use in side the global database for announcements.", FCVAR_NOTIFY);
	convar_Table_AnnouncementsSeen = AutoExecConfig_CreateConVar("sm_furious_announcements_table_announcementsseen", "furious_global_announcements_seen", "Name of the database table to use in side the global database for announcements seen.", FCVAR_NOTIFY);
	AutoExecConfig_ExecuteFile();

	HookEvent("player_spawn", Event_OnPlayerSpawn);

	RegAdminCmd("sm_announcement", Command_Announcement, ADMFLAG_ROOT, "Test a specific announcement.");

	g_AnnouncementIDs = new ArrayList();
	g_AnnouncementNames = new StringMap();
	g_AnnouncementOverlay = new StringMap();
	g_AnnouncementPanelTitle = new StringMap();
	g_AnnouncementPanelContents = new StringMap();
	g_AnnouncementPrintChat = new StringMap();
	g_AnnouncementPrintCenter = new StringMap();
	g_AnnouncementPrintHint = new StringMap();
	g_AnnouncementSound = new StringMap();

	AutoExecConfig_CleanFile();
}

public void OnConfigsExecuted()
{
	if (!convar_Status.BoolValue)
		return;
	
	if (g_Database == null)
		Database.Connect(OnSQLConnect, "furious_global");
	else
		ParseAnnouncements();
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
	
	g_Database.SetCharset("utf8mb4");

	char sTable[MAX_TABLE_SIZE];
	char sQuery[4096];

	convar_Table_Announcements.GetString(sTable, sizeof(sTable));
	g_Database.Format(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS `%s` ( `id` int(12) NOT NULL AUTO_INCREMENT, `name` varchar(64) NOT NULL, `overlay` varchar(256) NOT NULL DEFAULT '', `panel_title` varchar(64) NOT NULL DEFAULT '', `panel_contents` varchar(255) NOT NULL DEFAULT '', `print_chat` varchar(255) NOT NULL DEFAULT '', `print_center` varchar(255) NOT NULL DEFAULT '', `print_hint` varchar(255) DEFAULT '', `sound` varchar(256) NOT NULL DEFAULT '', `first_created` int(12) NOT NULL DEFAULT '0', `last_updated` int(12) NOT NULL DEFAULT '0' ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 DEFAULT COLLATE=utf8mb4_unicode_ci;", sTable);
	g_Database.Query(TQuery_OnTableCreation_Announcements, sQuery);

	convar_Table_AnnouncementsSeen.GetString(sTable, sizeof(sTable));
	g_Database.Format(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS `%s` ( `id` int(12) NOT NULL AUTO_INCREMENT, `accountid` int(12) NOT NULL, `announcement` int(12) NOT NULL, `seen_date` int(12) NOT NULL ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 DEFAULT COLLATE=utf8mb4_unicode_ci;", sTable);
	g_Database.Query(TQuery_OnTableCreation_AnnouncementsSeen, sQuery);

	ParseAnnouncements();
}

public void TQuery_OnTableCreation_Announcements(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
		ThrowError("Error creating announcements table: %s", error);
}

public void TQuery_OnTableCreation_AnnouncementsSeen(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
		ThrowError("Error creating announcements seen table: %s", error);
}

void ParseAnnouncements()
{
	char sTable[MAX_TABLE_SIZE];
	convar_Table_Announcements.GetString(sTable, sizeof(sTable));
	
	char sQuery[4096];
	g_Database.Format(sQuery, sizeof(sQuery), "SELECT * FROM `%s`;", sTable);
	g_Database.Query(TQuery_OnParseAnnouncements, sQuery);
}

public void TQuery_OnParseAnnouncements(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
		ThrowError("Error while parsing announcements: %s", error);

	g_AnnouncementIDs.Clear();
	g_AnnouncementNames.Clear();
	g_AnnouncementOverlay.Clear();
	g_AnnouncementPanelTitle.Clear();
	g_AnnouncementPanelContents.Clear();
	g_AnnouncementPrintChat.Clear();
	g_AnnouncementPrintCenter.Clear();
	g_AnnouncementPrintHint.Clear();
	g_AnnouncementSound.Clear();

	while (results.FetchRow())
	{
		int id = results.FetchInt(0);
		g_AnnouncementIDs.Push(id);

		char sID[12];
		IntToString(id, sID, sizeof(sID));

		char sName[64];
		results.FetchString(1, sName, sizeof(sName));
		g_AnnouncementNames.SetString(sID, sName);

		char sOverlay[256];
		results.FetchString(2, sOverlay, sizeof(sOverlay));
		g_AnnouncementOverlay.SetString(sID, sOverlay);

		char sPanelTitle[64];
		results.FetchString(3, sPanelTitle, sizeof(sPanelTitle));
		g_AnnouncementPanelTitle.SetString(sID, sPanelTitle);

		char sPanelContents[255];
		results.FetchString(4, sPanelContents, sizeof(sPanelContents));
		g_AnnouncementPanelContents.SetString(sID, sPanelContents);

		char sPrintChat[255];
		results.FetchString(5, sPrintChat, sizeof(sPrintChat));
		g_AnnouncementPrintChat.SetString(sID, sPrintChat);

		char sPrintCenter[255];
		results.FetchString(6, sPrintCenter, sizeof(sPrintCenter));
		g_AnnouncementPrintCenter.SetString(sID, sPrintCenter);

		char sPrintHint[255];
		results.FetchString(7, sPrintHint, sizeof(sPrintHint));
		g_AnnouncementPrintHint.SetString(sID, sPrintHint);

		char sSound[PLATFORM_MAX_PATH];
		results.FetchString(8, sSound, sizeof(sSound));
		g_AnnouncementSound.SetString(sID, sSound);
	}

	LogMessage("%i announcements are now preloaded.", g_AnnouncementIDs.Length);
}

public void OnClientAuthorized(int client, const char[] auth)
{
	if (!convar_Status.BoolValue || IsFakeClient(client))
		return;
	
	char sTable1[MAX_TABLE_SIZE];
	convar_Table_Announcements.GetString(sTable1, sizeof(sTable1));

	char sTable2[MAX_TABLE_SIZE];
	convar_Table_AnnouncementsSeen.GetString(sTable2, sizeof(sTable2));
	
	char sQuery[4096];
	g_Database.Format(sQuery, sizeof(sQuery), "SELECT id FROM %s WHERE id NOT IN (SELECT announcement FROM %s WHERE accountid = '%i');", sTable1, sTable2, GetSteamAccountID(client));
	g_Database.Query(TQuery_OnCheckAnnouncements, sQuery, GetClientUserId(client));
}

public void TQuery_OnCheckAnnouncements(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
		ThrowError("Error while parsing seen announcements: %s", error);

	if (results.RowCount == 0)
		return;

	int client;
	if ((client = GetClientOfUserId(data)) == 0)
		return;
	
	delete g_ShowAnnouncements[client];
	g_ShowAnnouncements[client] = new ArrayList();
	
	while (results.FetchRow())
		g_ShowAnnouncements[client].Push(results.FetchInt(0));
	
	if (g_ShowAnnouncements[client].Length == 0)
		delete g_ShowAnnouncements[client];
}

public void Event_OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if (!convar_Status.BoolValue)
		return;
	
	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);

	if (client > 0 && IsClientInGame(client) && !IsFakeClient(client) && g_ShowAnnouncements[client] != null)
		CreateTimer(0.5, Timer_DelaySpawn, userid, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_DelaySpawn(Handle timer, any data)
{
	if (!convar_Status.BoolValue)
		return Plugin_Stop;
	
	int client;
	if ((client = GetClientOfUserId(data)) == 0)
		return Plugin_Stop;
	
	if (!IsClientInGame(client) || g_ShowAnnouncements[client] == null)
		return Plugin_Stop;

	float delay;
	for (int i = 0; i < g_ShowAnnouncements[client].Length; i++)
	{
		int id = g_ShowAnnouncements[client].Get(i);

		DataPack pack = new DataPack();
		CreateDataTimer(delay, Timer_ShowAnnouncement, pack, TIMER_FLAG_NO_MAPCHANGE);
		pack.WriteCell(data);
		pack.WriteCell(id);

		delay += 5.0;
	}
	
	return Plugin_Stop;
}

public Action Timer_ShowAnnouncement(Handle timer, DataPack data)
{
	if (!convar_Status.BoolValue)
		return Plugin_Stop;
	
	data.Reset();
	int userid = data.ReadCell();
	int id = data.ReadCell();

	int client;
	if ((client = GetClientOfUserId(userid)) > 0)
		DisplayAnnouncement(client, id);
	
	return Plugin_Stop;
}

public Action Command_Announcement(int client, int args)
{
	if (!convar_Status.BoolValue || client == 0)
		return Plugin_Handled;
	
	int id = GetCmdArgInt(1);
	DisplayAnnouncement(client, id);
	PrintToChat(client, "Displaying Announcement ID: %i", id);
	
	return Plugin_Handled;
}

void DisplayAnnouncement(int client, int id)
{
	char sID[12];
	IntToString(id, sID, sizeof(sID));

	char sOverlay[256];
	if (g_AnnouncementOverlay.GetString(sID, sOverlay, sizeof(sOverlay)))
		ShowOverlay(client, sOverlay);

	char sPanelTitle[64];
	if (g_AnnouncementPanelTitle.GetString(sID, sPanelTitle, sizeof(sPanelTitle)))
	{
		Panel panel = new Panel();
		panel.SetTitle(sPanelTitle);

		char sPanelContents[255];
		g_AnnouncementPanelContents.GetString(sID, sPanelContents, sizeof(sPanelContents));
		panel.DrawText(sPanelContents);

		panel.Send(client, PanelHandler_Void, MENU_TIME_FOREVER);
		delete panel;
	}

	char sPrintChat[255];
	if (g_AnnouncementPrintChat.GetString(sID, sPrintChat, sizeof(sPrintChat)))
		CPrintToChat(client, sPrintChat);

	char sPrintCenter[255];
	if (g_AnnouncementPrintCenter.GetString(sID, sPrintCenter, sizeof(sPrintCenter)))
		PrintCenterText(client, sPrintCenter);

	char sPrintHint[255];
	if (g_AnnouncementPrintHint.GetString(sID, sPrintHint, sizeof(sPrintHint)))
		PrintHintText(client, sPrintHint);

	char sSound[PLATFORM_MAX_PATH];
	if (g_AnnouncementSound.GetString(sID, sSound, sizeof(sSound)))
		EmitSoundToClient(client, sSound);
}

public int PanelHandler_Void(Menu menu, MenuAction action, int param1, int param2)
{
	delete menu;
	return 0;
}