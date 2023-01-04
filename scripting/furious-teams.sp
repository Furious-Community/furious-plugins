/*-- Pragmas --*/
#pragma semicolon 1
#pragma newdecls required

/*-- Defines --*/

/*-- Includes --*/
#include <sourcemod>
#include <autoexecconfig>

/*-- Furious Includes --*/

/*-- ConVars --*/
ConVar convar_Status;
ConVar convar_URL_Clans;
ConVar convar_URL_Teams;
ConVar convar_URL_TopClans;
ConVar convar_URL_TopTeams;

/*-- Globals --*/

/*-- Plugin Info --*/
public Plugin myinfo =
{
	name = "[Furious] Teams",
	author = "Drixevel",
	description = "Teams module for Furious Clan.",
	version = "1.0.0",
	url = "http://furious-clan.com/"
};

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("furious.phrases");

	AutoExecConfig_SetFile("frs.teams");
	convar_Status = AutoExecConfig_CreateConVar("sm_furious_teams_status", "1", "Status of the plugin.\n(1 = on, 0 = off)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_URL_Clans = AutoExecConfig_CreateConVar("sm_furious_teams_url_clans", "", "URL to open for this command.", FCVAR_NOTIFY);
	convar_URL_Teams = AutoExecConfig_CreateConVar("sm_furious_teams_url_teams", "", "URL to open for this command.", FCVAR_NOTIFY);
	convar_URL_TopClans = AutoExecConfig_CreateConVar("sm_furious_teams_url_topclans", "", "URL to open for this command.", FCVAR_NOTIFY);
	convar_URL_TopTeams = AutoExecConfig_CreateConVar("sm_furious_teams_url_topteams", "", "URL to open for this command.", FCVAR_NOTIFY);
	AutoExecConfig_ExecuteFile();

	RegConsoleCmd("sm_clans", Command_Clans, "Opens MOTD to clans page.");
	RegConsoleCmd("sm_teams", Command_Teams, "Opens MOTD to teams page.");
	RegConsoleCmd("sm_topclans", Command_TopClans, "Opens MOTD to top clans page.");
	RegConsoleCmd("sm_topteams", Command_TopTeams, "Opens MOTD to top teams page.");

	AutoExecConfig_CleanFile();
}

public Action Command_Clans(int client, int args)
{
	if (!convar_Status.BoolValue || client == 0)
		return Plugin_Handled;

	char sURL[256];
	convar_URL_Clans.GetString(sURL, sizeof(sURL));

	//CSGO_ShowMOTDPanel(client, "Furious Clans", sURL, true);

	return Plugin_Handled;
}

public Action Command_Teams(int client, int args)
{
	if (!convar_Status.BoolValue || client == 0)
		return Plugin_Handled;

	char sURL[256];
	convar_URL_Teams.GetString(sURL, sizeof(sURL));

	//CSGO_ShowMOTDPanel(client, "Furious Clans", sURL, true);

	return Plugin_Handled;
}

public Action Command_TopClans(int client, int args)
{
	if (!convar_Status.BoolValue || client == 0)
		return Plugin_Handled;

	char sURL[256];
	convar_URL_TopClans.GetString(sURL, sizeof(sURL));

	//CSGO_ShowMOTDPanel(client, "Furious Clans", sURL, true);

	return Plugin_Handled;
}

public Action Command_TopTeams(int client, int args)
{
	if (!convar_Status.BoolValue || client == 0)
		return Plugin_Handled;

	char sURL[256];
	convar_URL_TopTeams.GetString(sURL, sizeof(sURL));

	//CSGO_ShowMOTDPanel(client, "Furious Clans", sURL, true);

	return Plugin_Handled;
}