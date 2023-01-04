/*-- Pragmas --*/
#pragma semicolon 1
#pragma newdecls required

/*-- Defines --*/

/*-- Includes --*/
#include <sourcemod>
#include <sdktools>
#include <colorlib>
#include <autoexecconfig>

/*-- Furious Includes --*/

/*-- ConVars --*/
ConVar convar_Status;
ConVar convar_Config;

/*-- Globals --*/
bool g_bLate;

int g_iKillstreak[MAXPLAYERS + 1];

StringMap g_Overlays;
StringMap g_CenterTextAll, g_CenterTextClient;
StringMap g_HintTextAll, g_HintTextClient;
StringMap g_PrintTextAll, g_PrintTextClient;
StringMap g_SoundsAll, g_SoundsClient;

/*-- Plugin Info --*/
public Plugin myinfo =
{
	name = "[Furious] Killstreaks",
	author = "Drixevel",
	description = "Killstreaks module for Furious Clan.",
	version = "1.0.2",
	url = "http://furious-clan.com/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLate = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("furious.phrases");

	AutoExecConfig_SetFile("frs.killstreaks");
	convar_Status = AutoExecConfig_CreateConVar("sm_furious_killstreaks_status", "1", "Status of the plugin.\n(1 = on, 0 = off)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_Config = AutoExecConfig_CreateConVar("sm_furious_killstreaks_config", "configs/furious/furious_killstreaks.cfg", "Name of the configuration file to use for killstreaks.", FCVAR_NOTIFY);
	AutoExecConfig_ExecuteFile();

	HookEvent("player_death", OnPlayerDeath);

	g_Overlays = new StringMap();
	g_CenterTextAll = new StringMap();
	g_CenterTextClient = new StringMap();
	g_HintTextAll = new StringMap();
	g_HintTextClient = new StringMap();
	g_PrintTextAll = new StringMap();
	g_PrintTextClient = new StringMap();
	g_SoundsAll = new StringMap();
	g_SoundsClient = new StringMap();

	AutoExecConfig_CleanFile();
}

public void OnConfigsExecuted()
{
	if (!convar_Status.BoolValue || !IsServerProcessing())
		return;

	if (g_bLate)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
				OnClientPutInServer(i);
		}

		g_bLate = false;
	}
}

public void OnMapStart()
{
	if (!convar_Status.BoolValue)
		return;

	LoadKillstreaksConfig();
}

public void OnClientPutInServer(int client)
{
	if (!convar_Status.BoolValue || IsFakeClient(client))
		return;

	g_iKillstreak[client] = 0;
}

public void OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if (!convar_Status.BoolValue)
		return;

	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));

	if (victim == 0 || victim > MaxClients || attacker == 0 || attacker > MaxClients)
		return;

	g_iKillstreak[victim] = 0;
	g_iKillstreak[attacker]++;

	char sKills[12];
	IntToString(g_iKillstreak[attacker], sKills, sizeof(sKills));

	char sOverlay[PLATFORM_MAX_PATH];
	if (g_Overlays.GetString(sKills, sOverlay, sizeof(sOverlay)) && strlen(sOverlay) > 0)
	{
		int iFlags = GetCommandFlags("r_screenoverlay");
		SetCommandFlags("r_screenoverlay", iFlags & ~FCVAR_CHEAT);
		ClientCommand(attacker, "r_screenoverlay \"%s\"", sOverlay);
		SetCommandFlags("r_screenoverlay", iFlags);

		CreateTimer(3.0, Timer_ResetOverlayForClient, GetClientSerial(attacker), TIMER_FLAG_NO_MAPCHANGE);
	}

	char sTextCenterAll[PLATFORM_MAX_PATH];
	if (g_CenterTextAll.GetString(sKills, sTextCenterAll, sizeof(sTextCenterAll)) && strlen(sTextCenterAll) > 0)
		PrintCenterTextAll(sTextCenterAll);

	char sTextCenterClient[PLATFORM_MAX_PATH];
	if (g_CenterTextClient.GetString(sKills, sTextCenterClient, sizeof(sTextCenterClient)) && strlen(sTextCenterClient) > 0)
		PrintCenterText(attacker, sTextCenterClient);

	char sTextHintAll[PLATFORM_MAX_PATH];
	if (g_HintTextAll.GetString(sKills, sTextHintAll, sizeof(sTextHintAll)) && strlen(sTextHintAll) > 0)
		PrintHintTextToAll(sTextHintAll);

	char sTextHintClient[PLATFORM_MAX_PATH];
	if (g_HintTextClient.GetString(sKills, sTextHintClient, sizeof(sTextHintClient)) && strlen(sTextHintClient) > 0)
		PrintHintText(attacker, sTextHintClient);

	char sTextPrintAll[PLATFORM_MAX_PATH];
	if (g_PrintTextAll.GetString(sKills, sTextPrintAll, sizeof(sTextPrintAll)) && strlen(sTextPrintAll))
		CPrintToChatAll(sTextPrintAll);

	char sTextPrintClient[PLATFORM_MAX_PATH];
	if (g_PrintTextClient.GetString(sKills, sTextPrintClient, sizeof(sTextPrintClient)) && strlen(sTextPrintClient))
		CPrintToChat(attacker, sTextPrintClient);

	char sSoundAll[PLATFORM_MAX_PATH];
	if (g_SoundsAll.GetString(sKills, sSoundAll, sizeof(sSoundAll)) && strlen(sSoundAll) > 0)
		EmitSoundToAll(sSoundAll);

	char sSoundClient[PLATFORM_MAX_PATH];
	if (g_SoundsClient.GetString(sKills, sSoundClient, sizeof(sSoundClient)) && strlen(sSoundClient) > 0)
		EmitSoundToClient(attacker, sSoundClient);
}

public Action Timer_ResetOverlayForClient(Handle timer, any data)
{
	int client = GetClientFromSerial(data);

	if (client > 0)
	{
		int iFlags = GetCommandFlags("r_screenoverlay");
		SetCommandFlags("r_screenoverlay", iFlags & ~FCVAR_CHEAT);
		ClientCommand(client, "r_screenoverlay \"\"");
		SetCommandFlags("r_screenoverlay", iFlags);
	}

	return Plugin_Continue;
}

void LoadKillstreaksConfig()
{
	char sConfig[PLATFORM_MAX_PATH];
	convar_Config.GetString(sConfig, sizeof(sConfig));

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), sConfig);

	KeyValues kv = new KeyValues("furious_killstreaks");
	int sections;

	if (kv.ImportFromFile(sPath) && kv.GotoFirstSubKey())
	{
		g_Overlays.Clear();
		g_CenterTextAll.Clear();
		g_CenterTextClient.Clear();
		g_HintTextAll.Clear();
		g_HintTextClient.Clear();
		g_PrintTextAll.Clear();
		g_PrintTextClient.Clear();
		g_SoundsAll.Clear();
		g_SoundsClient.Clear();

		do
		{
			char sKills[12];
			kv.GetSectionName(sKills, sizeof(sKills));

			char sOverlay[PLATFORM_MAX_PATH];
			kv.GetString("overlay", sOverlay, sizeof(sOverlay));
			g_Overlays.SetString(sKills, sOverlay);

			if( strlen(sOverlay) > 0 )
			{
				Format(sOverlay, sizeof(sOverlay), "materials/%s", sOverlay);

				char buffer[PLATFORM_MAX_PATH];

				Format(buffer, sizeof(buffer), "%s.vtf", sOverlay);
				AddFileToDownloadsTable(buffer);

				Format(buffer, sizeof(buffer), "%s.vmt", sOverlay);
				AddFileToDownloadsTable(buffer);
			}

			char sTextCenterAll[PLATFORM_MAX_PATH];
			kv.GetString("text_center_all", sTextCenterAll, sizeof(sTextCenterAll));
			g_CenterTextAll.SetString(sKills, sTextCenterAll);

			char sTextCenterClient[PLATFORM_MAX_PATH];
			kv.GetString("text_center_client", sTextCenterClient, sizeof(sTextCenterClient));
			g_CenterTextClient.SetString(sKills, sTextCenterClient);

			char sTextHintAll[PLATFORM_MAX_PATH];
			kv.GetString("text_hint_all", sTextHintAll, sizeof(sTextHintAll));
			g_HintTextAll.SetString(sKills, sTextHintAll);

			char sTextHintClient[PLATFORM_MAX_PATH];
			kv.GetString("text_hint_client", sTextHintClient, sizeof(sTextHintClient));
			g_HintTextClient.SetString(sKills, sTextHintClient);

			char sTextPrintAll[PLATFORM_MAX_PATH];
			kv.GetString("text_print_all", sTextPrintAll, sizeof(sTextPrintAll));
			g_PrintTextAll.SetString(sKills, sTextPrintAll);

			char sTextPrintClient[PLATFORM_MAX_PATH];
			kv.GetString("text_print_client", sTextPrintClient, sizeof(sTextPrintClient));
			g_PrintTextClient.SetString(sKills, sTextPrintClient);

			char sSoundAll[PLATFORM_MAX_PATH];
			kv.GetString("sound_all", sSoundAll, sizeof(sSoundAll));
			g_SoundsAll.SetString(sKills, sSoundAll);

			if( strlen(sSoundAll) > 0 )
			{
				PrecacheSound(sSoundAll);

				Format(sSoundAll, sizeof(sSoundAll), "sound/%s", sSoundAll);
				AddFileToDownloadsTable(sSoundAll);
			}

			char sSoundClient[PLATFORM_MAX_PATH];
			kv.GetString("sound_client", sSoundClient, sizeof(sSoundClient));
			g_SoundsClient.SetString(sKills, sSoundClient);

			if( strlen(sSoundClient) > 0 )
			{
				PrecacheSound(sSoundClient);

				Format(sSoundClient, sizeof(sSoundClient), "sound/%s", sSoundAll);
				AddFileToDownloadsTable(sSoundClient);
			}

			sections++;
		}
		while (kv.GotoNextKey());
	}

	LogMessage("Killstreaks config parsed. [%i sections loaded]", sections);
	delete kv;
}
