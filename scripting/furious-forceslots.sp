/*-- Pragmas --*/
#pragma semicolon 1
#pragma newdecls required

/*-- Defines --*/

/*-- Includes --*/
#include <sourcemod>
#include <sdktools>
#include <autoexecconfig>

#undef REQUIRE_PLUGIN
#tryinclude <devzones>
#define REQUIRE_PLUGIN

/*-- Furious Includes --*/
#include <furious/furious-stocks>

/*-- ConVars --*/
ConVar convar_Status;
ConVar convar_Config;

/*-- Globals --*/
StringMap g_WeaponRestrictions;

char g_sCurrentZone[MAXPLAYERS + 1][256];

/*-- Plugin Info --*/
public Plugin myinfo =
{
	name = "[Furious] Forceslots",
	author = "Drixevel",
	description = "Forceslots module for Furious Clan.",
	version = "1.0.1",
	url = "http://furious-clan.com/"
};

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("furious.phrases");

	AutoExecConfig_SetFile("frs.forceslots");
	convar_Status = AutoExecConfig_CreateConVar("sm_furious_forceslots_status", "1", "Status of the plugin.\n(1 = on, 0 = off)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_Config = AutoExecConfig_CreateConVar("sm_furious_forceslots_config", "configs/furious/furious_forceslots.cfg", "Name of the config to use.", FCVAR_NOTIFY);
	AutoExecConfig_ExecuteFile();

	RegAdminCmd("sm_reloadforceslots", Command_ReloadForceSlots, ADMFLAG_ROOT, "Reload the plugin data for devzones forced slots.");

	g_WeaponRestrictions = new StringMap();

	AutoExecConfig_CleanFile();
}

public void OnConfigsExecuted()
{
	if (!convar_Status.BoolValue || !IsServerProcessing())
		return;

	ParseWeaponRestrictionsConfig();
}

#if defined _devzones_included_
public void Zone_OnClientEntry(int client, const char[] zone)
{
	if (convar_Status.BoolValue)
		strcopy(g_sCurrentZone[client], 256, zone);
}

public void Zone_OnClientLeave(int client, const char[] zone)
{
	if (convar_Status.BoolValue && StrEqual(g_sCurrentZone[client], zone, false))
		g_sCurrentZone[client][0] = '\0';
}
#endif

public void OnClientDisconnect_Post(int client)
{
	g_sCurrentZone[client][0] = '\0';
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (!convar_Status.BoolValue || !IsPlayerAlive(client) || strlen(g_sCurrentZone[client]) == 0)
		return Plugin_Continue;

	StringMap trie;
	if (!g_WeaponRestrictions.GetValue(g_sCurrentZone[client], trie) ||	trie == null)
		return Plugin_Continue;

	char sWeapon[64];
	GetClientWeapon(client, sWeapon, sizeof(sWeapon));

	if (strlen(sWeapon) == 0)
		return Plugin_Continue;

	int slot;
	if (GetTrieValue(trie, sWeapon, slot) && slot > -1)
	{
		int set = GetPlayerWeaponSlot(client, slot);

		if (IsValidEntity(set))
		{
			weapon = set;
			PrintHintText(client, "WEAPON RESTRICTED");
			SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", set);
		}
		else
		{
			set = GetPlayerWeaponSlot(client, 2);
			PrintHintText(client, "WEAPON RESTRICTED");
			SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", set);
		}
	}

	return Plugin_Continue;
}

public Action Command_ReloadForceSlots(int client, int args)
{
	if (!convar_Status.BoolValue)
		return Plugin_Handled;

	ParseWeaponRestrictionsConfig();
	ReplyToCommand(client, "Devzones Forced Slots config data reloaded.");

	return Plugin_Handled;
}

void ParseWeaponRestrictionsConfig()
{
	char sConfig[PLATFORM_MAX_PATH];
	convar_Config.GetString(sConfig, sizeof(sConfig));

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), sConfig);

	KeyValues kv = new KeyValues("furious_forceslots");

	if (kv.ImportFromFile(sPath) && kv.GotoFirstSubKey())
	{
		ClearTrieSafe(g_WeaponRestrictions);

		do
		{
			char sName[128];
			kv.GetSectionName(sName, sizeof(sName));

			StringMap trie = new StringMap();

			if (kv.GotoFirstSubKey(false))
			{
				do
				{
					char sEntity[128];
					kv.GetSectionName(sEntity, sizeof(sEntity));

					int slot = kv.GetNum(NULL_STRING);

					SetTrieValue(trie, sEntity, slot);
				}
				while (KvGotoNextKey(kv, false));

				kv.GoBack();
				kv.GoBack();
			}

			g_WeaponRestrictions.SetValue(sName, trie);
		}
		while (kv.GotoNextKey());
	}

	LogMessage("Devzones Forceslot config parsed. [%i sections loaded]", g_WeaponRestrictions.Size);
	delete kv;
}
