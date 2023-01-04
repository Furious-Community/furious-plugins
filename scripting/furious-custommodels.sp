/*-- Pragmas --*/
#pragma semicolon 1
#pragma newdecls required

/*-- Defines --*/

/*-- Includes --*/
#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <autoexecconfig>

/*-- Furious Includes --*/

/*-- ConVars --*/
ConVar convar_Status;
ConVar convar_ArmsStatus;
ConVar convar_Config;
ConVar convar_Flags_VIP;
ConVar convar_Flags_Admin;

/*-- Globals --*/
StringMap g_ModelPaths;
int g_iVIPFlag;
int g_iAdminFlag;

/*-- Plugin Info --*/
public Plugin myinfo =
{
	name = "[Furious] Custom Models",
	author = "Drixevel",
	description = "Custom Models module for Furious Clan.",
	version = "1.0.0",
	url = "http://furious-clan.com/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	//RegPluginLibrary("furious_custommodels");

	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("furious.phrases");

	AutoExecConfig_SetFile("frs.models");
	convar_Status = AutoExecConfig_CreateConVar("sm_furious_custommodels_status", "1", "Status of the plugin.\n(1 = on, 0 = off)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_ArmsStatus = AutoExecConfig_CreateConVar("sm_furious_custommodels_arm_models", "0", "Status for arms models to work.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_Config = AutoExecConfig_CreateConVar("sm_furious_custommodels_config", "configs/furious/furious_models.cfg", "Name of the models config to use.", FCVAR_NOTIFY);
	convar_Flags_VIP = AutoExecConfig_CreateConVar("sm_furious_custommodels_flags_vip", "a", "Flags for players to receive VIP models. (0 = Disabled)", FCVAR_NOTIFY);
	convar_Flags_Admin = AutoExecConfig_CreateConVar("sm_furious_custommodels_flags_admin", "c", "Flags for players to receive Admin models. (0 = Disabled)", FCVAR_NOTIFY);
	AutoExecConfig_ExecuteFile();

	convar_Flags_VIP.AddChangeHook(onVIPFlagsChange);
	convar_Flags_Admin.AddChangeHook(onAdminFlagsChange);

	HookEvent("player_spawn", OnPlayerSpawn);

	g_ModelPaths = new StringMap();

	AutoExecConfig_CleanFile();
}

public void onVIPFlagsChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_iVIPFlag = ReadFlagString(newValue);
}

public void onAdminFlagsChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_iAdminFlag = ReadFlagString(newValue);
}

public void OnConfigsExecuted()
{
	if (!convar_Status.BoolValue || !IsServerProcessing())
		return;

	char sFlags[32];

	convar_Flags_VIP.GetString(sFlags, sizeof(sFlags));
	g_iVIPFlag = ReadFlagString(sFlags);

	convar_Flags_Admin.GetString(sFlags, sizeof(sFlags));
	g_iAdminFlag = ReadFlagString(sFlags);
}

public void OnMapStart()
{
	if (!convar_Status.BoolValue || !IsServerProcessing())
		return;

	ParseModelsConfig();
}

public void OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!convar_Status.BoolValue || client == 0 || !IsClientInGame(client) || IsFakeClient(client))
		return;

	char sEquipModel[PLATFORM_MAX_PATH];
	char sEquipArmModel[PLATFORM_MAX_PATH];

	switch (GetClientTeam(client))
	{
		case 2:
		{
			g_ModelPaths.GetString("T Default", sEquipModel, sizeof(sEquipModel));
			g_ModelPaths.GetString("T Default Arms", sEquipArmModel, sizeof(sEquipArmModel));

			if (g_iVIPFlag > 0 && CheckCommandAccess(client, "furious_vip_models", g_iVIPFlag, true))
				g_ModelPaths.GetString("T VIP", sEquipModel, sizeof(sEquipModel));

			if (g_iAdminFlag > 0 && CheckCommandAccess(client, "furious_admin_models", g_iAdminFlag, true))
				g_ModelPaths.GetString("T Admin", sEquipModel, sizeof(sEquipModel));
		}
		case 3:
		{
			g_ModelPaths.GetString("CT Default", sEquipModel, sizeof(sEquipModel));
			g_ModelPaths.GetString("CT Default Arms", sEquipArmModel, sizeof(sEquipArmModel));

			if (g_iVIPFlag > 0 && CheckCommandAccess(client, "furious_vip_models", g_iVIPFlag, true))
				g_ModelPaths.GetString("CT VIP", sEquipModel, sizeof(sEquipModel));

			if (g_iAdminFlag > 0 && CheckCommandAccess(client, "furious_admin_models", g_iAdminFlag, true))
				g_ModelPaths.GetString("CT Admin", sEquipModel, sizeof(sEquipModel));
		}
	}

	if (strlen(sEquipModel) > 0 && IsModelPrecached(sEquipModel))
		SetEntityModel(client, sEquipModel);

	if (convar_ArmsStatus.BoolValue && strlen(sEquipArmModel) > 0 && IsModelPrecached(sEquipArmModel))
		SetArmsModel(client, sEquipArmModel);
}

void SetArmsModel(int client, const char[] sArmsModel)
{
	SetEntPropString(client, Prop_Send, "m_szArmsModel", sArmsModel);

	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");

	DataPack pack;
	CreateDataTimer(0.1, Timer_UpdateArms, pack, TIMER_FLAG_NO_MAPCHANGE);
	pack.WriteCell(GetClientUserId(client));
	pack.WriteCell(EntIndexToEntRef(weapon));

	RemovePlayerItem(client, weapon);
}

public Action Timer_UpdateArms(Handle timer, DataPack data)
{
	data.Reset();
	int client = GetClientOfUserId(data.ReadCell());
	int weapon = EntRefToEntIndex(data.ReadCell());

	if (client > 0 && IsClientInGame(client) && IsPlayerAlive(client) && weapon > 0 && IsValidEntity(weapon))
		EquipPlayerWeapon(client, weapon);
	
	return Plugin_Continue;
}

void ParseModelsConfig()
{
	char sConfig[256];
	convar_Config.GetString(sConfig, sizeof(sConfig));

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), sConfig);

	KeyValues kv = new KeyValues("furious_models");

	if (kv.ImportFromFile(sPath) && kv.GotoFirstSubKey(false))
	{
		g_ModelPaths.Clear();

		do
		{
			char sName[64];
			kv.GetSectionName(sName, sizeof(sName));

			char sModel[PLATFORM_MAX_PATH];
			kv.GetString(NULL_STRING, sModel, sizeof(sModel));

			if (strlen(sName) == 0 || strlen(sModel) == 0)
				continue;

			Format(sModel, sizeof(sModel), "models/%s", sModel);

			if (!FileExists(sModel))
				continue;

			g_ModelPaths.SetString(sName, sModel);
			PrecacheModel(sModel, true);
			AddFileToDownloadsTable(sModel);
		}
		while (kv.GotoNextKey(false));
	}

	LogMessage("Models config parsed. [%i sections loaded]", g_ModelPaths.Size);
	delete kv;
}
