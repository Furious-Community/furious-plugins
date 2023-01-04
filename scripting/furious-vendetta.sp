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

/*-- Globals --*/

/*-- Plugin Info --*/
public Plugin myinfo =
{
	name = "[Furious] Vendetta",
	author = "Drixevel",
	description = "Vendetta module for Furious Clan.",
	version = "1.0.0",
	url = "http://furious-clan.com/"
};

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("furious.phrases");

	AutoExecConfig_SetFile("frs.vendetta");
	convar_Status = AutoExecConfig_CreateConVar("sm_furious_vendetta_status", "1", "Status of the plugin.\n(1 = on, 0 = off)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	AutoExecConfig_ExecuteFile();

	AutoExecConfig_CleanFile();
}

public void OnConfigsExecuted()
{
	if (convar_Status.BoolValue && !convar_Status.BoolValue)
		PrintToServer("wut");
}
