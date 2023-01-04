/*-- Pragmas --*/
#pragma semicolon 1

/*-- Defines --*/

/*-- Includes --*/
#include <sourcemod>
#include <cstrike>
#include <clientprefs>
#include <colorlib>
#include <autoexecconfig>

#include <furious/furious-store>

/*-- Furious Includes --*/

/*-- ConVars --*/
ConVar convar_Status;
ConVar convar_MenuDelay;

/*-- Cookies --*/
Handle g_Cookie_ToggleMenu;

/*-- Globals --*/
bool g_bDeathMenu[MAXPLAYERS + 1] = {true, ...};
bool g_ActiveRound = true;

bool g_bIsPanorama[MAXPLAYERS + 1];

/*-- Plugin Info --*/
public Plugin myinfo =
{
	name = "[Furious] Death Menu",
	author = "Drixevel",
	description = "Death Menu module for Furious Clan.",
	version = "1.0.1",
	url = "http://furious-clan.com/"
};

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("furious.phrases");

	AutoExecConfig_SetFile("frs.deathmenu");
	convar_Status = AutoExecConfig_CreateConVar("sm_furious_deathmenu_status", "1", "Status of the plugin.\n(1 = on, 0 = off)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_MenuDelay = AutoExecConfig_CreateConVar("sm_furious_deathmenu_menu_delay", "2.0", "Delay in seconds to display the death menu automatically.", FCVAR_NOTIFY, true, 0.0);
	AutoExecConfig_ExecuteFile();

	HookEvent("round_start", OnRoundStart);
	HookEvent("round_end", OnRoundEnd);
	HookEvent("player_death", OnPlayerDeath);

	g_Cookie_ToggleMenu = RegClientCookie("ToggleDeathMenu", "Toggle death menu to show up or not", CookieAccess_Public);
	SetCookiePrefabMenu(g_Cookie_ToggleMenu, CookieMenu_OnOff_Int, "Toggle DeathMenu", ToggleDeathMenu);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (AreClientCookiesCached(i))
			OnClientCookiesCached(i);
	}

	RegConsoleCmd("sm_deathmenu", DisplayDeathMenu, "Displays the death menu.");
	RegConsoleCmd("sm_toggledeathmenu", Command_ToggleDeathMenu, "Displays the death menu.");

	AutoExecConfig_CleanFile();
}

public void ToggleDeathMenu(int client, CookieMenuAction action, any info, char[] buffer, int maxlen)
{
    switch (action)
    {
        case CookieMenuAction_SelectOption:
            OnClientCookiesCached(client);
    }
}

public void OnClientCookiesCached(int client)
{
    char sValue[8];
    GetClientCookie(client, g_Cookie_ToggleMenu, sValue, sizeof(sValue));
    if (sValue[0] == '\0')
    {
    	g_bDeathMenu[client] = true;
    	return;
    }
    g_bDeathMenu[client] = view_as<bool>(StringToInt(sValue));
}

public void OnClientDisconnect_Post(int client)
{
	g_bDeathMenu[client] = true;
}

public Action DisplayDeathMenu(int client, int args)
{
	if (!convar_Status.BoolValue || client == 0)
		return Plugin_Handled;

	ShowDeathMenu(client);
	return Plugin_Handled;
}

public Action Command_ToggleDeathMenu(int client, int args)
{
	if (!convar_Status.BoolValue || client == 0)
		return Plugin_Handled;

	g_bDeathMenu[client] = !g_bDeathMenu[client];
	CPrintToChat(client, "Death Menu %s.", g_bDeathMenu[client] ? "enabled" : "disabled");
	SetClientCookie(client, g_Cookie_ToggleMenu, g_bDeathMenu[client] ? "1" : "0");

	return Plugin_Handled;
}

public void OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_ActiveRound = true;
}

public void OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	g_ActiveRound = false;
}

public void OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if (!convar_Status.BoolValue)
		return;
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client > 0 && g_bDeathMenu[client]) //TODO add phoenix kit override
		CreateTimer(convar_MenuDelay.FloatValue, Timer_DisplayDeathMenu, GetClientSerial(client), TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_DisplayDeathMenu(Handle timer, any data)
{
	int client = GetClientFromSerial(data);

	if (convar_Status.BoolValue && client > 0)
		ShowDeathMenu(client);
	
	return Plugin_Continue;
}

void ShowDeathMenu(int client)
{
	if (client < 1 || client > MaxClients || !IsClientInGame(client) || IsFakeClient(client) || !g_ActiveRound)
		return;
	Menu menu = new Menu(MenuHandle_DeathMenu);
	menu.SetTitle("%t", "death menu title");

	menu.AddItem("Redie", "Redie");
	menu.AddItem("Announcements", "Announcements");
	menu.AddItem("Vip", "Buy VIP");
	if (!g_bIsPanorama[client])
	{
		menu.AddItem("View my Profile", "View my Profile");
		menu.AddItem("Browse Player Profiles", "Browse Player Profiles");
		menu.AddItem("Browse Rank List", "Browse Rank List");
	}
	menu.AddItem("Toggle Menu On Death", g_bDeathMenu[client] ? "Toggle Menu On Death Off" : "Toggle Menu On Death On");

	menu.Display(client, 20);
}

public int MenuHandle_DeathMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			if (!convar_Status.BoolValue)
				return 0;

			char sSelect[32];
			menu.GetItem(param2, sSelect, sizeof(sSelect));

			if (StrEqual(sSelect, "Redie"))
				FakeClientCommand(param1, "sm_redie");
			else if (StrEqual(sSelect, "View my Profile"))
			{
				//char sURL[512];
				//Format(sURL, sizeof(sURL), "http://furious-clan.com/#/player/%i", GetSteamAccountID(param1));
				//CSGO_ShowMOTDPanel(param1, "Furious Profile", sURL, true);

				menu.Display(param1, MENU_TIME_FOREVER);
			}
			else if (StrEqual(sSelect, "Browse Player Profiles"))
			{
				Menu menu2 = new Menu(MenuHandle_BrowsePlayers);
				menu2.SetTitle("Pick a player:");

				char sUserID[64]; char sName[MAX_NAME_LENGTH];
				for (int i = 1; i <= MaxClients; i++)
				{
					if (!IsClientInGame(i) || IsFakeClient(i))
						continue;

					IntToString(GetSteamAccountID(i), sUserID, sizeof(sUserID));
					GetClientName(i, sName, sizeof(sName));

					menu2.AddItem(sUserID, sName);
				}

				menu2.Display(param1, MENU_TIME_FOREVER);
			}
			else if (StrEqual(sSelect, "Browse Rank List"))
			{
				//char sURL[512];
				//Format(sURL, sizeof(sURL), "http://furious-clan.com/#/players");
				//CSGO_ShowMOTDPanel(param1, "Furious Players List", sURL, true);

				menu.Display(param1, MENU_TIME_FOREVER);
			}
			else if (StrEqual(sSelect, "Toggle Menu On Death"))
			{
				Command_ToggleDeathMenu(param1, 0);
				ShowDeathMenu(param1);
			}
			else if (StrEqual(sSelect, "Announcements"))
				FakeClientCommand(param1, "sm_announcements");
			else if (StrEqual(sSelect, "Vip"))
			{
				Furious_Store_ShowVipMenu(param1);
			}
		}
	}

	return 0;
}

public int MenuHandle_BrowsePlayers(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			if (!convar_Status.BoolValue)
				return 0;

			char sInfo[64];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			//char sURL[512];
			//Format(sURL, sizeof(sURL), "http://furious-clan.com/#/player/%s", sInfo);
			//CSGO_ShowMOTDPanel(param1, "Furious Profile", sURL, true);

			ShowDeathMenu(param1);
		}
		case MenuAction_End:
			delete menu;
	}

	return 0;
}

void PanoramaCheck(int client)
{
    g_bIsPanorama[client] = false;
    QueryClientConVar(client, "@panorama_debug_overlay_opacity", ClientConVar);
}

public void ClientConVar(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue)
{
    if (result != ConVarQuery_Okay) {
        g_bIsPanorama[client] = false;
        return;
    }
    else
    {
        g_bIsPanorama[client] = true;
        return;
    }
}

public void OnClientPostAdminCheck(int client)
{
    PanoramaCheck(client);
}