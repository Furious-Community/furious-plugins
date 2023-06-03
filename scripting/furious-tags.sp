/*-- Pragmas --*/
#pragma semicolon 1

/*-- Defines --*/
#define MAX_FLAG_LIMIT 32

/*-- Includes --*/
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>
#include <colorlib>
#include <autoexecconfig>
#include <chat-processor>

/*-- Furious Includes --*/
#include <furious/furious-stocks>
#include <furious/furious-tags>

#undef REQUIRE_PLUGIN
#include <furious/furious-statistics>
#include <furious/furious-store>
#define REQUIRE_PLUGIN

#define VIP_FLAGS ADMFLAG_CUSTOM5

/*-- ConVars --*/
ConVar convar_Status;
ConVar convar_Config_Location;
ConVar convar_Tags_MaxCharacters;

/*-- Globals --*/
bool plugin_statistics;
bool plugin_store;

char g_sTags_Flags[256][MAX_FLAG_LIMIT];
char g_sTags_Prefixs[256][MAXLENGTH_NAME];
char g_sTags_Prefixs_Color[256][MAXLENGTH_NAME];
char g_sTags_Groups[256][MAXLENGTH_NAME];
char g_sHud_Prefixs[256][96];
char g_sHud_Prefixs_Color[256][96];
char g_sHud_Groups[256][96];

int g_iTags_ScoreboardIcon[256];
int g_iTags;
int g_mCompetitiveRankingOffset = -1;

char g_sCustomTags[MAXPLAYERS + 1][256];

bool g_bDisable_Custom[MAXPLAYERS + 1];
bool g_bDisable_Tier[MAXPLAYERS + 1];
bool g_bDisable_Group[MAXPLAYERS + 1];

bool g_IsWaitingForTag[MAXPLAYERS + 1];

Handle g_TierTagDisabledCookie = null;
Handle g_GroupTagDisabledCookie = null;
Handle g_CustomTagDisabledCookie = null;
Handle g_CustomTagCookie = null;

/*-- Plugin Info --*/
public Plugin myinfo =
{
	name = "[Furious] Tags",
	author = "Drixevel",
	description = "Tags module for Furious Clan.",
	version = "1.0.6",
	url = "http://furious-clan.com/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("furious_tags");

	CreateNative("Furious_Tags_GetPrefixID", Native_Tags_GetPrefixID);
	CreateNative("Furious_Tags_GetPrefix", Native_Tags_GetPrefix);
	CreateNative("Furious_Tags_GetPrefixColor", Native_Tags_GetPrefixColor);

	CreateNative("Furious_Tags_GetGroup", Native_Tags_GetGroup);

	CreateNative("Furious_Tags_GetHudPrefix", Native_Tags_GetHudPrefix);
	CreateNative("Furious_Tags_GetHudPrefixColor", Native_Tags_GetHudPrefixColor);
	CreateNative("Furious_Tags_GetHudGroup", Native_Tags_GetHudGroup);
	CreateNative("Furious_Tags_ChangeTagMenu", Native_Tags_ChangeTagMenu);

	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("furious.phrases");

	AutoExecConfig_SetFile("frs.tags");
	convar_Status = AutoExecConfig_CreateConVar("sm_furious_tags_status", "1", "Status of the plugin.\n(1 = on, 0 = off)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_Config_Location = AutoExecConfig_CreateConVar("sm_furious_tags_config", "configs/furious/furious_tags.cfg", "Name of the config to parse for flag tags.", FCVAR_NOTIFY);
	convar_Tags_MaxCharacters = AutoExecConfig_CreateConVar("sm_furious_tags_max_characters", "128", "Max characters allowed per tag.", 0, true, 15.0, true, 127.0);
	AutoExecConfig_ExecuteFile();

	RegConsoleCmd("sm_changetag", Command_ChangeTag, "Change your custom tag in chat.");
	RegConsoleCmd("sm_cleartag", Command_ClearTag, "Clear or delete your custom tag in chat.");
	RegConsoleCmd("sm_deletetag", Command_ClearTag, "Clear or delete your custom tag in chat.");
	RegConsoleCmd("sm_enabletag", Command_EnableTag, "Enable your custom tag in chat if you have one.");
	RegConsoleCmd("sm_disabletag", Command_DisableTag, "Disable your custom tag in chat if you have one.");

	RegConsoleCmd("sm_enabletiertag", Command_EnableTierTag, "Enable the tier tag in chat.");
	RegConsoleCmd("sm_disabletiertag", Command_DisableTierTag, "Disable the tier tag in chat.");
	RegConsoleCmd("sm_enablegrouptag", Command_EnableGroupTag, "Enable the group tag in chat.");
	RegConsoleCmd("sm_disablegrouptag", Command_DisableGroupTag, "Disable the group tag in chat.");

	AutoExecConfig_CleanFile();

	g_TierTagDisabledCookie = RegClientCookie("tag_tier_disabled", "Enables/Disables the tier tag", CookieAccess_Protected);
	g_GroupTagDisabledCookie = RegClientCookie("tag_group_disabled", "Enables/Disables the group tag", CookieAccess_Protected);
	g_CustomTagDisabledCookie = RegClientCookie("tag_custom_disabled", "Enables/Disables the custom tag", CookieAccess_Protected);
	g_CustomTagCookie = RegClientCookie("tag_custom", "Custom tag", CookieAccess_Protected);

	AddCommandListener(ChatListener, "say");
	AddCommandListener(ChatListener, "say2");
	AddCommandListener(ChatListener, "say_team");
	
	g_mCompetitiveRankingOffset = FindSendPropInfo("CCSPlayerResource", "m_iCompetitiveRanking");
}

public void OnMapStart()
{
	int resourceEnt = GetPlayerResourceEntity();
	
	if (resourceEnt != -1)
	{	
		SDKHook(resourceEnt, SDKHook_ThinkPost, OnClientResourceEntityPostThink);
	}
}

public void OnClientResourceEntityPostThink(int entity)
{
	if (g_mCompetitiveRankingOffset == -1)
		return;
	
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
			continue;
			
		int index = GetClientPrefixesID(i);
		
		if (index == -1 || g_iTags_ScoreboardIcon[index] == -1)
			continue;
		
		SetEntData(entity, FindSendPropInfo("CCSPlayerResource", "m_iCompetitiveRanking") + (i * 4), g_iTags_ScoreboardIcon[index]);
	}
}

public void OnAllPluginsLoaded()
{
	plugin_statistics = LibraryExists("furious_statistics");
	plugin_store = LibraryExists("furious_store");
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "furious_statistics", false))
		plugin_statistics = true;
	
	if (StrEqual(name, "furious_store", false))
		plugin_store = true;
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "furious_statistics", false))
		plugin_statistics = false;
	
	if (StrEqual(name, "furious_store", false))
		plugin_store = false;
}

public void OnConfigsExecuted()
{
	if (!convar_Status.BoolValue || !IsServerProcessing())
		return;

	ParseTagsConfig();
}

public void OnClientDisconnect_Post(int client)
{
	g_bDisable_Custom[client] = false;
	g_bDisable_Tier[client] = false;
	g_bDisable_Group[client] = false;
	g_IsWaitingForTag[client] = false;
	g_sCustomTags[client][0] = '\0';
}

void ParseTagsConfig()
{
	char sConfig[PLATFORM_MAX_PATH];
	convar_Config_Location.GetString(sConfig, sizeof(sConfig));

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), sConfig);

	KeyValues kv = new KeyValues("flag_tags");

	if (kv.ImportFromFile(sPath) && kv.GotoFirstSubKey())
	{
		g_iTags = 0;

		do
		{
			kv.GetSectionName(g_sTags_Flags[g_iTags], sizeof(g_sTags_Flags[]));
			strtolower(g_sTags_Flags[g_iTags], g_sTags_Flags[g_iTags], sizeof(g_sTags_Flags[]));
			
			kv.GetString("prefix_tag", g_sTags_Prefixs[g_iTags], sizeof(g_sTags_Prefixs[]));
			kv.GetString("prefix_tag_color", g_sTags_Prefixs_Color[g_iTags], sizeof(g_sTags_Prefixs_Color[]), "{default}");
			kv.GetString("group_tag", g_sTags_Groups[g_iTags], sizeof(g_sTags_Groups[]));

			kv.GetString("hud_tag", g_sHud_Prefixs[g_iTags], sizeof(g_sHud_Prefixs[]));
			kv.GetString("hud_tag_color", g_sHud_Prefixs_Color[g_iTags], sizeof(g_sHud_Prefixs_Color[]));
			kv.GetString("hud_group", g_sHud_Groups[g_iTags], sizeof(g_sHud_Groups[]));
			
			g_iTags_ScoreboardIcon[g_iTags] = kv.GetNum("scoreboard_icon", -1);

			g_iTags++;
		}
		while (kv.GotoNextKey());
	}

	LogMessage("Tags config parsed. [%i sections loaded]", g_iTags);
	delete kv;
}

public Action CP_OnChatMessage(int& author, ArrayList recipients, char[] flagstring, char[] name, char[] message, bool& processcolors, bool& removecolors)
{
	if (!convar_Status.BoolValue)
		return Plugin_Continue;

	processcolors = true;
	removecolors = true;

	return Plugin_Stop;
}

public void CP_OnChatMessagePost(int author, ArrayList recipients, const char[] flagstring, const char[] formatstring, const char[] name, const char[] message, bool processcolors, bool removecolors)
{
	if (!convar_Status.BoolValue)
		return;

	char sPrefix[512];
	int index = GetClientPrefixesID(author);

	bool bChanged;
	if (index != -1)
	{
		if (strlen(g_sTags_Prefixs[index]) > 0)
			FormatEx(sPrefix, sizeof(sPrefix), "%s%s", g_sTags_Prefixs_Color[index], g_sTags_Prefixs[index]);

		if (!g_bDisable_Group[author] && strlen(g_sTags_Groups[index]) > 0)
			Format(sPrefix, sizeof(sPrefix), "%s%s", sPrefix, g_sTags_Groups[index]);

		bChanged = true;
	}

	char sTier[512];
	if (plugin_statistics)
		Furious_Statistics_GetTierTag(author, sTier, sizeof(sTier));

	if (!g_bDisable_Tier[author] && strlen(sTier) > 0)
		Format(sPrefix, sizeof(sPrefix), "%s%s%s", sPrefix, bChanged ? "{default}" : "", sTier);

	if (!g_bDisable_Custom[author] && strlen(g_sCustomTags[author]) > 0 && GetUserFlagBits(author) & VIP_FLAGS)
		Format(sPrefix, sizeof(sPrefix), "%s%s", sPrefix, g_sCustomTags[author]);
	else
	{
		char sStore[512];
		if (plugin_store)
			Furious_Store_GetClientTag(author, sStore, sizeof(sStore));

		if (strlen(sStore) > 0)
			Format(sPrefix, sizeof(sPrefix), "%s%s%s", sPrefix, strlen(sTier) > 0 ? "{default}" : "", sStore);
	}

	char sBuffer[255];
	strcopy(sBuffer, sizeof(sBuffer), formatstring);

	ReplaceString(sBuffer, sizeof(sBuffer), "{1}", name);
	ReplaceString(sBuffer, sizeof(sBuffer), "{2}", message);
	ReplaceString(sBuffer, sizeof(sBuffer), "*DEAD*", "");
	ReplaceString(sBuffer, sizeof(sBuffer), "*SPEC*", "");

	Format(sBuffer, sizeof(sBuffer), "%s %s", sPrefix, sBuffer);
	
	CPrintToChatAllEx(author, sBuffer);
}

int GetClientPrefixesID(int client)
{
	int index = -1;

	int flags;
	for (int i = 0; i < g_iTags; i++)
	{
		flags = ReadFlagString(g_sTags_Flags[i]);

		if (CheckCommandAccess(client, "", flags))
		{
			index = i;
			break;
		}
	}

	return index;
}

public Action Command_ChangeTag(int client, int args)
{
	if (!convar_Status.BoolValue || client == 0)
		return Plugin_Handled;

	if (!(GetUserFlagBits(client) & VIP_FLAGS))
	{
		CReplyToCommand(client, "%T", "not vip", client);
		return Plugin_Handled;
	}

	if (args == 0)
	{
		ChangeTagMenu(client);
		return Plugin_Handled;
	}

	char sTag[512];
	GetCmdArgString(sTag, sizeof(sTag));

	StripQuotes(sTag);
	
	int size = strlen(sTag);
	int maxSize = convar_Tags_MaxCharacters.IntValue;

	if (size > maxSize)
	{
		CPrintToChat(client, "%T", "tag too long", client, size, maxSize);
		return Plugin_Handled;
	}

	strcopy(g_sCustomTags[client], size + 1, sTag);
	SetClientCookie(client, g_CustomTagCookie, g_sCustomTags[client]);

	CPrintToChat(client, "%T", "tag set", client, g_sCustomTags[client]);

	return Plugin_Handled;
}

void ChangeTagMenu(int client)
{
	if (!convar_Status.BoolValue || client == 0)
		return;

	if (!(GetUserFlagBits(client) & VIP_FLAGS))
	{
		CReplyToCommand(client, "%T", "not vip", client);
		return;
	}

	Menu menu = new Menu(MenuHandler_ChangeTag);
	menu.SetTitle("Change Tag");

	menu.AddItem("change", g_IsWaitingForTag[client] ? "Cancel" : "Change Tag");
	menu.AddItem("clear", "Delete Tag");
	menu.AddItem("print", "Print Tag\n \n", strlen(g_sCustomTags[client]) > 0 ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	menu.AddItem("colors", "Show available colors");
	menu.AddItem("showhide", "Show/hide tags");

//	menu.AddItem("message", "Change Message Color");
//	menu.AddItem("name", "Change Name");
	
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);			
}

public void OnClientCookiesCached(int client)
{
	static char buffer[4];

	GetClientCookie(client, g_TierTagDisabledCookie, buffer, sizeof(buffer));	
	g_bDisable_Tier[client] = !!StringToInt(buffer);

	GetClientCookie(client, g_GroupTagDisabledCookie, buffer, sizeof(buffer));	
	g_bDisable_Group[client] = !!StringToInt(buffer);

	GetClientCookie(client, g_CustomTagDisabledCookie, buffer, sizeof(buffer));	
	g_bDisable_Custom[client] = !!StringToInt(buffer);

	GetClientCookie(client, g_CustomTagCookie, g_sCustomTags[client], sizeof(g_sCustomTags[]));	
}
public int MenuHandler_ChangeTag(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			if (!convar_Status.BoolValue)
				return 0;

			if (!(GetUserFlagBits(param1) & VIP_FLAGS))
			{
				CReplyToCommand(param1, "%T", "not vip", param1);
				return 0;
			}

			char sInfo[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			if (StrEqual(sInfo, "clear"))
			{
				Command_ClearTag(param1, 0);				
			}
			else if (StrEqual(sInfo, "change"))
			{
				if (g_IsWaitingForTag[param1])
				{
					CPrintToChat(param1, "%T", "no longer waiting for tag", param1);
				}
				else 
				{
					CPrintToChat(param1, "%T", "tag change enabled", param1);					
				}

				g_IsWaitingForTag[param1] = !g_IsWaitingForTag[param1];
			}
			else if (StrEqual(sInfo, "print") )
			{
				if (strlen(g_sCustomTags[param1]) > 0)
				{				
					PrintToChat(param1, "\x01 \x0C[ \x0BVIP \x0C]\x0A Your current tag is: %s", g_sCustomTags[param1]);
				}
				else 
				{
					PrintToChat(param1, "\x01 \x0C[ \x0BVIP \x0C]\x0A You don't have any tag set.");
				}			
			}
			else if (StrEqual(sInfo, "colors"))
			{
				PrintToChat(param1, "\x01 \x0C[ \x0BVIP \x0C]\x0A Available colors for writting tags: \n");
				
				PrintToChat(param1, "\x01 {default}\t \x07{red}\t \x0F{lightred}\t \x02{darkred}");
				PrintToChat(param1, "\x01 \x0A{bluegrey}\t \x0B{blue}\t \x0C{darkblue}\t \x03{purple}");
				PrintToChat(param1, "\x01 \x0E{pink}\t \x09{yellow}\t \x10{gold}\t \x05{lightgreen}");
				PrintToChat(param1, "\x01 \x04{green}\t \x06{lime}\t \x08{grey}\t \x0D{grey2}");

				PrintToChat(param1, "\x01 \x0A Use these codes to assign colors, i.e.");
				PrintToChat(param1, "\x01 \x07 {red}\x0A 1\x09{yellow}\x0A 3\x04{green}\x0A 3\x0E{pink}\x0A 7 ===> \x07 1\x09 3\x04 3\x0E 7");
			}
			else if (StrEqual(sInfo, "showhide"))
			{
				ShowHideTagsMenu(param1);
			}
			
			if (!StrEqual(sInfo, "showhide"))
				ChangeTagMenu(param1);
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
				FakeClientCommand(param1, "sm_vip");
		}
		case MenuAction_End:
			delete menu;
	}

	return 0;
}

void ShowHideTagsMenu(int client)
{
	Menu menusht = new Menu(MenuHandler_ShowHideTags);
	menusht.SetTitle("Show/hide tags");
	menusht.ExitBackButton = true;
	menusht.AddItem("group", g_bDisable_Group[client] ? "Group Tag (Disabled ◎)" : "Group Tag (Enabled ◉)");
	menusht.AddItem("tier", g_bDisable_Tier[client] ? "Tier Tag (Disabled ◎)" : "Tier Tag (Enabled ◉)");
	menusht.AddItem("custom", g_bDisable_Custom[client] ? "Custom Tag (Disabled ◎)" : "Custom Tag (Enabled ◉)");	
	menusht.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_ShowHideTags(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			if (!convar_Status.BoolValue)
				return 0;

			if (!(GetUserFlagBits(param1) & VIP_FLAGS))
			{
				CReplyToCommand(param1, "%T", "not vip", param1);
				return 0;
			}

			char sInfo[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			if (StrEqual(sInfo, "tier"))
			{
				g_bDisable_Tier[param1] = !g_bDisable_Tier[param1];	

				if (g_bDisable_Tier[param1])
				{
					SetClientCookie(param1, g_TierTagDisabledCookie, "1");						
				}
				else 
				{
					SetClientCookie(param1, g_TierTagDisabledCookie, "0");							
				}		
			}
			else if (StrEqual(sInfo, "group"))
			{
				g_bDisable_Group[param1] = !g_bDisable_Group[param1];

				if (g_bDisable_Group[param1])
				{
					SetClientCookie(param1, g_GroupTagDisabledCookie, "1");						
				}
				else 
				{
					SetClientCookie(param1, g_GroupTagDisabledCookie, "0");						
				}				
			}
			else if (StrEqual(sInfo, "custom"))
			{
				g_bDisable_Custom[param1] = !g_bDisable_Custom[param1];

				if (g_bDisable_Custom[param1])
				{
					SetClientCookie(param1, g_CustomTagDisabledCookie, "1");								
				}
				else 
				{
					SetClientCookie(param1, g_CustomTagDisabledCookie, "0");								
				}			
			}
			ShowHideTagsMenu(param1);
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
				ChangeTagMenu(param1);
		}
		case MenuAction_End:
			delete menu;
	}

	return 0;
}

public Action Command_ClearTag(int client, int args)
{
	if (!convar_Status.BoolValue || client == 0)
		return Plugin_Handled;

	if (!(GetUserFlagBits(client) & VIP_FLAGS))
	{
		CReplyToCommand(client, "%T", "not vip", client);
		return Plugin_Handled;
	}

	if (strlen(g_sCustomTags[client]) == 0)
	{
		CPrintToChat(client, "%T", "no tag", client);
		return Plugin_Handled;
	}

	g_sCustomTags[client][0] = '\0';
	SetClientCookie(client, g_CustomTagCookie, "");

	CPrintToChat(client, "%T", "tag deleted", client);

	return Plugin_Handled;
}

//Custom
public Action Command_EnableTag(int client, int args)
{
	if (!convar_Status.BoolValue || client == 0)
		return Plugin_Handled;

	if (!(GetUserFlagBits(client) & VIP_FLAGS))
	{
		CReplyToCommand(client, "%T", "not vip", client);
		return Plugin_Handled;
	}

	g_bDisable_Custom[client] = false;
	CPrintToChat(client, "%T", "tag enabled", client);

	return Plugin_Handled;
}

public Action Command_DisableTag(int client, int args)
{
	if (!convar_Status.BoolValue || client == 0)
		return Plugin_Handled;

	g_bDisable_Custom[client] = true;
	CPrintToChat(client, "%T", "tag disabled", client);

	return Plugin_Handled;
}

//Tier
public Action Command_EnableTierTag(int client, int args)
{
	if (!convar_Status.BoolValue || client == 0)
		return Plugin_Handled;

	if (!(GetUserFlagBits(client) & VIP_FLAGS))
	{
		CReplyToCommand(client, "%T", "not vip", client);
		return Plugin_Handled;
	}

	g_bDisable_Tier[client] = true;
	CPrintToChat(client, "%T", "showtiers on", client);

	return Plugin_Handled;
}

public Action Command_DisableTierTag(int client, int args)
{
	if (!convar_Status.BoolValue || client == 0)
		return Plugin_Handled;

	if (!(GetUserFlagBits(client) & VIP_FLAGS))
	{
		CReplyToCommand(client, "%T", "not vip", client);
		return Plugin_Handled;
	}

	g_bDisable_Tier[client] = false;
	CPrintToChat(client, "%T", "showtiers off", client);

	return Plugin_Handled;
}

//Group
public Action Command_EnableGroupTag(int client, int args)
{
	if (!convar_Status.BoolValue || client == 0)
		return Plugin_Handled;

	if (!(GetUserFlagBits(client) & VIP_FLAGS))
	{
		CReplyToCommand(client, "%T", "not vip", client);
		return Plugin_Handled;
	}

	g_bDisable_Group[client] = true;
	CPrintToChat(client, "%T", "showgroups on", client);

	return Plugin_Handled;
}

public Action Command_DisableGroupTag(int client, int args)
{
	if (!convar_Status.BoolValue || client == 0)
		return Plugin_Handled;

	if (!(GetUserFlagBits(client) & VIP_FLAGS))
	{
		CReplyToCommand(client, "%T", "not vip", client);
		return Plugin_Handled;
	}

	g_bDisable_Group[client] = false;
	CPrintToChat(client, "%T", "showgroups off", client);

	return Plugin_Handled;
}

public Action ChatListener(int client, const char[] command, int args)
{
	static char msg[128];
	GetCmdArgString(msg, sizeof(msg));

	StripQuotes(msg);

	if (client < 1 || client > MaxClients)
	{
		return Plugin_Continue;
	}

	if (!g_IsWaitingForTag[client])
	{
		return Plugin_Continue;
	}

	int size = strlen(msg);
	int maxSize = convar_Tags_MaxCharacters.IntValue;

	if (size > maxSize)
	{
		CPrintToChat(client, "%T", "tag too long", client, size, maxSize);
		return Plugin_Handled;
	}

	g_IsWaitingForTag[client] = false;

	strcopy(g_sCustomTags[client], size + 1, msg);
	SetClientCookie(client, g_CustomTagCookie, g_sCustomTags[client]);
	
	CPrintToChat(client, "%T", "tag set", client, g_sCustomTags[client]);	

	ChangeTagMenu(client);
	return Plugin_Handled;
}

public int Native_Tags_GetPrefixID(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (client < 1 || client > MaxClients)
		return -1;

	return GetClientPrefixesID(client);
}

public int Native_Tags_GetPrefix(Handle plugin, int numParams)
{
	int index = GetNativeCell(1);
	SetNativeString(2, g_sTags_Prefixs[index], GetNativeCell(3));
	return 0;
}

public int Native_Tags_GetPrefixColor(Handle plugin, int numParams)
{
	int index = GetNativeCell(1);
	SetNativeString(2, g_sTags_Prefixs_Color[index], GetNativeCell(3));
	return 0;
}

public int Native_Tags_GetGroup(Handle plugin, int numParams)
{
	int index = GetNativeCell(1);
	SetNativeString(2, g_sTags_Groups[index], GetNativeCell(3));
	return 0;
}

public int Native_Tags_GetHudPrefix(Handle plugin, int numParams)
{
	int index = GetNativeCell(1);
	SetNativeString(2, g_sHud_Prefixs[index], GetNativeCell(3));
	return 0;
}

public int Native_Tags_GetHudPrefixColor(Handle plugin, int numParams)
{
	int index = GetNativeCell(1);
	SetNativeString(2, g_sHud_Prefixs_Color[index], GetNativeCell(3));
	return 0;
}

public int Native_Tags_GetHudGroup(Handle plugin, int numParams)
{
	int index = GetNativeCell(1);
	SetNativeString(2, g_sHud_Groups[index], GetNativeCell(3));
	return 0;
}

public int Native_Tags_ChangeTagMenu(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (client < 1 || client > MaxClients)
		return -1;

	ChangeTagMenu(client);
	return 1;
}

public void OnPlayerRunCmdPost(int iClient, int iButtons)
{
	static int iOldButtons[MAXPLAYERS+1];

	if (iButtons & IN_SCORE && !(iOldButtons[iClient] & IN_SCORE))
	{
		StartMessageOne("ServerRankRevealAll", iClient, USERMSG_BLOCKHOOKS);
		EndMessage();
	}

	iOldButtons[iClient] = iButtons;
}