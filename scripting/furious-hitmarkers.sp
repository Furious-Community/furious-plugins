#include <sourcemod>
#include <sdktools>
#include <autoexecconfig>
#include <clientprefs>
#include <furious/furious-weapons>
#include <furious/furious-stocks>

#pragma semicolon 1
#pragma newdecls required

#define NO_TIME -1
#define KILLSTREAK_MAX 10

Handle g_HudSyncHealth;
Handle g_HudSyncDamage;

int g_iLastVictim[MAXPLAYERS + 1];
int g_iLastHitTime[MAXPLAYERS + 1];
int g_iTotalDmg[MAXPLAYERS + 1];
int g_Attacked[MAXPLAYERS + 1] =  { NO_TIME, ... };

ConVar g_cvSoundArmorHit;
ConVar g_cvSoundArmorBreak;
ConVar g_cvSoundHit;
ConVar g_cvSoundKill;
ConVar g_cvSoundDropShotKill;

ConVar g_cvOverlayArmorHit;
ConVar g_cvOverlayArmorBreak;
ConVar g_cvOverlayHit;
ConVar g_cvOverlayKill;
ConVar g_cvOverlayDropShotKill;

ConVar g_cvHudSyncDamageX;
ConVar g_cvHudSyncDamageY;
ConVar g_cvHudSyncDamageR;
ConVar g_cvHudSyncDamageG;
ConVar g_cvHudSyncDamageB;

ConVar g_cvHudSyncHealthX;
ConVar g_cvHudSyncHealthY;
ConVar g_cvHudSyncHealthR;
ConVar g_cvHudSyncHealthG;
ConVar g_cvHudSyncHealthB;

ConVar g_cvHitmarkLifetime;

ConVar convar_DamageBuffer;

ArrayList g_VictimNames[MAXPLAYERS + 1];

StringMap g_DamageCache[MAXPLAYERS + 1];
StringMap g_ArmorCache[MAXPLAYERS + 1];
StringMap g_ArmorBroken[MAXPLAYERS + 1];

Handle c_Overlay;
Handle c_HudSync;

int g_iHudSync[MAXPLAYERS + 1];
int g_iOverlay[MAXPLAYERS + 1];

int g_cKillStreak[MAXPLAYERS + 1];
char g_sKillStreakSound[KILLSTREAK_MAX][PLATFORM_MAX_PATH];
char g_sKillStreakOverlay[KILLSTREAK_MAX][PLATFORM_MAX_PATH];

public Plugin myinfo = 
{
	name = "[Furious] Hitmarkers", 
	author = "Drixevel & Dysphie", 
	description = "Hitmarkers module for Furious Clan.", 
	version = "2.0.1", 
	url = "http://furious-clan.com/"
};

public void OnPluginStart()
{
	HookEvent("player_hurt", OnPlayerHurt);
	HookEvent("round_start", OnRoundStart, EventHookMode_PostNoCopy);
	
	g_HudSyncHealth = CreateHudSynchronizer();
	g_HudSyncDamage = CreateHudSynchronizer();
	
	LoadTranslations("furious.phrases");
	
	AutoExecConfig_SetFile("frs.hitmarkers");
	
	
	g_cvSoundArmorHit = AutoExecConfig_CreateConVar("sm_furious_hitmarkers_sound_armorhit", "", 
		"Sound to play on armor hit.");
	
	g_cvSoundArmorBreak = AutoExecConfig_CreateConVar("sm_furious_hitmarkers_sound_armorbreak", "", 
		"Sound to play on armor broken.");
	
	g_cvSoundHit = AutoExecConfig_CreateConVar("sm_furious_hitmarkers_sound_hit", "", 
		"Sound to play on raw hit.");
	
	g_cvSoundKill = AutoExecConfig_CreateConVar("sm_furious_hitmarkers_sound_kill", "", 
		"Sound to play on kill.");
	
	g_cvSoundDropShotKill = AutoExecConfig_CreateConVar("sm_furious_hitmarkers_sound_dropshot_kill", "", 
		"Sound to play on dropshot kill.");
	
	
	g_cvOverlayArmorHit = AutoExecConfig_CreateConVar("sm_furious_hitmarkers_overlay_armorhit", "", 
		"Overlay to display on armor hit.");
	g_cvOverlayArmorHit.AddChangeHook(OnOverlayCvarChange);
	
	g_cvOverlayArmorBreak = AutoExecConfig_CreateConVar("sm_furious_hitmarkers_overlay_armorbreak", "", 
		"Overlay to display on armor broken.");
	g_cvOverlayArmorBreak.AddChangeHook(OnOverlayCvarChange);
	
	g_cvOverlayHit = AutoExecConfig_CreateConVar("sm_furious_hitmarkers_overlay_hit", "", 
		"Overlay to display on raw hit.");
	g_cvOverlayHit.AddChangeHook(OnOverlayCvarChange);
	
	g_cvOverlayKill = AutoExecConfig_CreateConVar("sm_furious_hitmarkers_overlay_kill", "", 
		"Overlay to display on kill.");
	g_cvOverlayKill.AddChangeHook(OnOverlayCvarChange);
	
	g_cvOverlayDropShotKill = AutoExecConfig_CreateConVar("sm_furious_hitmarkers_overlay_dropshot_kill", "", 
		"Overlay to display on dropshot kill.");
	g_cvOverlayDropShotKill.AddChangeHook(OnOverlayCvarChange);
	
	g_cvHudSyncDamageX = AutoExecConfig_CreateConVar("sm_furious_hitmarkers_hp_taken_offset_x", "0.422", 
		"X offset for HP taken. Range [0, 0.7] or -1 for center.", _, true, -1.0, true, 0.7);
	g_cvHudSyncDamageY = AutoExecConfig_CreateConVar("sm_furious_hitmarkers_hp_taken_offset_y", "0.47", 
		"Y offset for HP taken. Range [0, 0.7] or -1 for center.", _, true, -1.0, true, 0.7);
	
	
	g_cvHudSyncDamageR = AutoExecConfig_CreateConVar("sm_furious_hitmarkers_hp_taken_color_r", "240", 
		"Red tint for HP taken.", _, true, 0.0, true, 255.0);
	
	g_cvHudSyncDamageG = AutoExecConfig_CreateConVar("sm_furious_hitmarkers_hp_taken_color_g", "43", 
		"Green tint for HP taken.", _, true, 0.0, true, 255.0);
	
	g_cvHudSyncDamageB = AutoExecConfig_CreateConVar("sm_furious_hitmarkers_hp_taken_color_b", "89", 
		"Blue tint for HP taken.", _, true, 0.0, true, 255.0);
	
	
	g_cvHudSyncHealthX = AutoExecConfig_CreateConVar("sm_furious_hitmarkers_hp_left_offset_x", "0.43", 
		"X offset for HP remaining. Range [0, 0.7] or -1 for center.", _, true, -1.0, true, 0.7);
	
	g_cvHudSyncHealthY = AutoExecConfig_CreateConVar("sm_furious_hitmarkers_hp_left_offset_y", "0.50", 
		"Y offset for HP remaining. Range [0, 0.7] or -1 for center.", _, true, -1.0, true, 0.7);
	
	
	g_cvHudSyncHealthR = AutoExecConfig_CreateConVar("sm_furious_hitmarkers_hp_left_color_r", "69", 
		"Red tint for HP remaining.", _, true, 0.0, true, 255.0);
	g_cvHudSyncHealthG = AutoExecConfig_CreateConVar("sm_furious_hitmarkers_hp_left_color_g", "161", 
		"Green tint for HP remaining.", _, true, 0.0, true, 255.0);
	g_cvHudSyncHealthB = AutoExecConfig_CreateConVar("sm_furious_hitmarkers_hp_left_color_b", "55", 
		"Blue tint for HP remaining.", _, true, 0.0, true, 255.0);
	
	g_cvHitmarkLifetime = AutoExecConfig_CreateConVar("sm_furious_hitmarkers_lifetime", "1.0", 
		"Duration of hitmarker on screen. Damage display will stack up if another hitmarker is active.");
	
	convar_DamageBuffer = AutoExecConfig_CreateConVar("sm_furious_hitmarkers_damage_buffer", "0", 
		"Time in seconds for the hit marker to show up after stacking.", FCVAR_NOTIFY, true, 0.0);
	
	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();
	
	c_Overlay = RegClientCookie("hitoverlays", "Hit Overlays", CookieAccess_Public);
	c_HudSync = RegClientCookie("hittexthudsync", "Hit Text Indicator", CookieAccess_Public);
	
	SetCookieMenuItem(CMH_hitmarkers, 0, "Hitmarkers");
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && AreClientCookiesCached(i))
			OnClientCookiesCached(i);
	}
	
	RegConsoleCmd("sm_hitmarker", Command_Hitmarkers);
	RegConsoleCmd("sm_hitmarkers", Command_Hitmarkers);
	RegConsoleCmd("sm_hs", Command_Hitmarkers);
	
	RegAdminCmd("sm_refreshconfigs_hitmarkers", Command_RefreshConfigs, ADMFLAG_ROOT);
	
	PrecacheOverlays();
}

public void OnMapStart()
{
	RefreshConfigs();
	for (int i = 0; i < sizeof(g_sKillStreakSound); ++i)
	{
		PrecacheSoundF(g_sKillStreakSound[i]);
	}
}

void PrecacheOverlays()
{
	char sOverlay[256];
	
	g_cvOverlayKill.GetString(sOverlay, sizeof(sOverlay));
	if (sOverlay[0])
		PrecacheDecalAnyDownload(sOverlay);
	
	g_cvOverlayDropShotKill.GetString(sOverlay, sizeof(sOverlay));
	if (sOverlay[0])
		PrecacheDecalAnyDownload(sOverlay);
	
	g_cvOverlayHit.GetString(sOverlay, sizeof(sOverlay));
	if (sOverlay[0])
		PrecacheDecalAnyDownload(sOverlay);
	
	g_cvOverlayArmorBreak.GetString(sOverlay, sizeof(sOverlay));
	if (sOverlay[0])
		PrecacheDecalAnyDownload(sOverlay);
	
	g_cvOverlayArmorHit.GetString(sOverlay, sizeof(sOverlay));
	if (sOverlay[0])
		PrecacheDecalAnyDownload(sOverlay);
	
	for (int i = 0; i < sizeof(g_sKillStreakOverlay); ++i)
	{
		PrecacheDecalAnyDownload(g_sKillStreakOverlay[i]);
	}
}

public void OnOverlayCvarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (newValue[0])
		PrecacheDecalAnyDownload(newValue);
}

stock void PrecacheDecalAnyDownload(const char[] sOverlay)
{
	char sBuffer[256];
	Format(sBuffer, sizeof(sBuffer), "%s.vmt", sOverlay);
	PrecacheDecal(sBuffer, true);
	Format(sBuffer, sizeof(sBuffer), "materials/%s.vmt", sOverlay);
	AddFileToDownloadsTable(sBuffer);
	
	Format(sBuffer, sizeof(sBuffer), "%s.vtf", sOverlay);
	PrecacheDecal(sBuffer, true);
	Format(sBuffer, sizeof(sBuffer), "materials/%s.vtf", sOverlay);
	AddFileToDownloadsTable(sBuffer);
}

public Action Command_Hitmarkers(int client, int args)
{
	ShowHitMarkersMenu(client);
	return Plugin_Handled;
}

public Action Command_RefreshConfigs(int client, int args)
{
	RefreshConfigs();
	return Plugin_Handled;
}

public void CMH_hitmarkers(int client, CookieMenuAction action, any info, char[] buffer, int maxlen)
{
	switch (action)
	{
		case CookieMenuAction_SelectOption:
		{
			ShowHitMarkersMenu(client);
		}
	}
}

void ShowHitMarkersMenu(int client)
{
	Menu menu = new Menu(MH_Hitmarkers);
	menu.ExitBackButton = true;
	menu.SetTitle("Hitmarkers");
	menu.AddItem("", "Hit overlay");
	menu.AddItem("", "Hit text indicator");
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MH_Hitmarkers(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0:
				{
					ShowOverlayMenu(param1);
				}
				case 1:
				{
					ShowHitTextMenu(param1);
				}
			}
			OnClientCookiesCached(param1);
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				FakeClientCommand(param1, "sm_settings");
			}
		}
		case MenuAction_End:delete menu;
	}

	return 0;
}

public int MH_Overlay(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0:SetClientCookie(param1, c_Overlay, "0");
				case 1:SetClientCookie(param1, c_Overlay, "1");
				case 2:SetClientCookie(param1, c_Overlay, "2");
			}
			OnClientCookiesCached(param1);
			ShowOverlayMenu(param1);
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				FakeClientCommand(param1, "sm_hitmarkers");
			}
		}
		case MenuAction_End:delete menu;
	}

	return 0;
}

public int MH_Hittext(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0:SetClientCookie(param1, c_HudSync, "0");
				case 1:SetClientCookie(param1, c_HudSync, "1");
				case 2:SetClientCookie(param1, c_HudSync, "2");
			}
			OnClientCookiesCached(param1);
			ShowHitTextMenu(param1);
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				FakeClientCommand(param1, "sm_hitmarkers");
			}
		}
		case MenuAction_End:delete menu;
	}

	return 0;
}

public void OnClientCookiesCached(int client)
{
	char sValue[8];
	GetClientCookie(client, c_Overlay, sValue, sizeof(sValue));
	g_iOverlay[client] = StringToInt(sValue);
	
	GetClientCookie(client, c_HudSync, sValue, sizeof(sValue));
	g_iHudSync[client] = StringToInt(sValue);
}

public void OnClientPutInServer(int client)
{
	g_VictimNames[client] = new ArrayList(ByteCountToCells(MAX_NAME_LENGTH));
	g_DamageCache[client] = new StringMap();
	g_ArmorCache[client] = new StringMap();
	g_ArmorBroken[client] = new StringMap();
}

public void OnClientConnected(int client)
{
	g_iLastVictim[client] = -1;
	g_iLastHitTime[client] = -1;
	g_iTotalDmg[client] = 0;
}

public void OnClientDisconnect_Post(int client)
{
	g_Attacked[client] = NO_TIME;
	delete g_VictimNames[client];
	delete g_DamageCache[client];
	delete g_ArmorCache[client];
	delete g_ArmorBroken[client];
}

public Action OnPlayerRunCmd(int client, int & buttons, int & impulse, float vel[3], float angles[3], int & weapon, int & subtype, int & cmdnum, int & tickcount, int & seed, int mouse[2])
{
	if (g_Attacked[client] != NO_TIME && g_Attacked[client] <= GetTime())
	{
		g_Attacked[client] = NO_TIME;
		
		char sName[MAX_NAME_LENGTH];
		int value;
		
		int total = g_VictimNames[client].Length;
		
		int total_damage;
		for (int i = 0; i < total; i++)
		{
			g_VictimNames[client].GetString(i, sName, sizeof(sName));
			g_DamageCache[client].GetValue(sName, value);
			total_damage += value;
		}
		
		int total_armor;
		for (int i = 0; i < total; i++)
		{
			g_VictimNames[client].GetString(i, sName, sizeof(sName));
			g_ArmorCache[client].GetValue(sName, value);
			total_armor += value;
		}
		
		int dummy;
		if (total >= 4)
		{
			ShowDamage(client, "you hit %i players\n%.2f", total, total_damage);
		}
		else if (total == 3)
		{
			ShowDamage(client, "%T", "hitmarker multiple players", client, total_damage, total_armor);
		}
		else if (total == 2)
		{
			//victim1 - name
			char sVictim1[MAX_NAME_LENGTH];
			g_VictimNames[client].GetString(0, sVictim1, sizeof(sVictim1));
			
			//victim1 - damage
			int iVictim1_Damage;
			g_DamageCache[client].GetValue(sVictim1, iVictim1_Damage);
			
			//victim1 - armor
			int iVictim1_Armor; char sVictim1_Armor[16];
			g_ArmorCache[client].GetValue(sVictim1, iVictim1_Armor);
			IntToString(iVictim1_Armor, sVictim1_Armor, sizeof(sVictim1_Armor));
			
			if (g_ArmorBroken[client].GetValue(sVictim1, dummy))
				strcopy(sVictim1_Armor, sizeof(sVictim1_Armor), "BROKEN");
			
			//victim2 - name
			char sVictim2[MAX_NAME_LENGTH];
			g_VictimNames[client].GetString(1, sVictim2, sizeof(sVictim2));
			
			//victim2 - damage
			int iVictim2_Damage;
			g_DamageCache[client].GetValue(sVictim2, iVictim2_Damage);
			
			//victim2 - armor
			int iVictim2_Armor; char sVictim2_Armor[16];
			g_ArmorCache[client].GetValue(sVictim2, iVictim2_Armor);
			IntToString(iVictim2_Armor, sVictim2_Armor, sizeof(sVictim2_Armor));
			
			if (g_ArmorBroken[client].GetValue(sVictim2, dummy))
				strcopy(sVictim2_Armor, sizeof(sVictim2_Armor), "BROKEN");
			
			ShowDamage(client, "%T", "hitmarker 2 players", client, sVictim1, iVictim1_Damage, sVictim1_Armor, sVictim2, iVictim2_Damage, sVictim2_Armor);
		}
		else
		{
			char sVictim[MAX_NAME_LENGTH];
			g_VictimNames[client].GetString(0, sVictim, sizeof(sVictim));
			
			int iDamage;
			g_DamageCache[client].GetValue(sVictim, iDamage);
			
			int iArmor; char sArmor[16];
			g_ArmorCache[client].GetValue(sVictim, iArmor);
			IntToString(iArmor, sArmor, sizeof(sArmor));
			
			if (g_ArmorBroken[client].GetValue(sVictim, dummy))
				strcopy(sArmor, sizeof(sArmor), "BROKEN");
			
			ShowDamage(client, "%T", "hitmarker", client, sVictim, iDamage, sArmor);
		}
		
		g_VictimNames[client].Clear();
		g_DamageCache[client].Clear();
		g_ArmorCache[client].Clear();
		g_ArmorBroken[client].Clear();
	}
	
	return Plugin_Continue;
}

public Action OnPlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (attacker < 1 || attacker > MaxClients || !IsClientInGame(attacker))
		return Plugin_Continue;
	
	int victim = GetClientOfUserId(event.GetInt("userid"));
	/*if (!IsValidClient(victim))
		return Plugin_Continue;*/
	
	char sName[MAX_NAME_LENGTH];
	//GetClientName(victim, sName, sizeof(sName));
	strcopy(sName, sizeof(sName), "bot");
	if (g_VictimNames[attacker].FindString(sName) == -1)
		g_VictimNames[attacker].PushString(sName);
	
	int iHealthDmg = event.GetInt("dmg_health");
	int iHealthLeft = event.GetInt("health");
	int iArmorLeft = event.GetInt("armor");
	int iArmorDmg = event.GetInt("dmg_armor");
	char sWeapon[32];
	event.GetString("weapon", sWeapon, sizeof(sWeapon));
	char szSound[PLATFORM_MAX_PATH];
	char szOverlay[PLATFORM_MAX_PATH];
	int iTime = GetTime();
	
	int damage;
	g_DamageCache[attacker].GetValue(sName, damage);
	damage += iHealthDmg;
	g_DamageCache[attacker].SetValue(sName, damage);
	
	int armor;
	g_ArmorCache[attacker].GetValue(sName, armor);
	armor += iArmorDmg;
	g_ArmorCache[attacker].SetValue(sName, armor);
	
	
	// Reset damage counter on timeout or target switch
	if (iTime - g_iLastHitTime[attacker] > g_cvHitmarkLifetime.FloatValue || victim != g_iLastVictim[attacker])
	{
		g_iTotalDmg[attacker] = 0;
	}
	
	g_iTotalDmg[attacker] += iHealthDmg;
	
	if (iHealthLeft <= 0)
	{
		++g_cKillStreak[attacker];
		if (g_cKillStreak[attacker] >= 2 && strlen(g_sKillStreakSound[g_cKillStreak[attacker] - 2]) && strlen(g_sKillStreakOverlay[g_cKillStreak[attacker] - 2]))
		{
			strcopy(szSound, sizeof(szSound), g_sKillStreakSound[g_cKillStreak[attacker] - 2]);
			strcopy(szOverlay, sizeof(szOverlay), g_sKillStreakOverlay[g_cKillStreak[attacker] - 2]);
		}
		else
		{
			if (Furious_Weapons_IsDropshotKill(attacker) && StrEqual(sWeapon, "awp"))
			{
				g_cvSoundDropShotKill.GetString(szSound, sizeof(szSound));
				g_cvOverlayDropShotKill.GetString(szOverlay, sizeof(szOverlay));
			}
			else
			{
				g_cvSoundKill.GetString(szSound, sizeof(szSound));
				g_cvOverlayKill.GetString(szOverlay, sizeof(szOverlay));
			}
		}
	}
	else
	{
		if (iArmorDmg)
		{
			if (iArmorLeft > 0)
			{
				g_cvSoundArmorHit.GetString(szSound, sizeof(szSound));
				g_cvOverlayArmorHit.GetString(szOverlay, sizeof(szOverlay));
			}
			else
			{
				g_cvSoundArmorBreak.GetString(szSound, sizeof(szSound));
				g_cvOverlayArmorBreak.GetString(szOverlay, sizeof(szOverlay));
			}
		}
		else
		{
			g_cvSoundHit.GetString(szSound, sizeof(szSound));
			g_cvOverlayHit.GetString(szOverlay, sizeof(szOverlay));
		}
	}
	
	g_iLastHitTime[attacker] = iTime;
	g_iLastVictim[attacker] = victim;
	
	// Display to player
	DisplayHitMarker(attacker, szSound, szOverlay, g_iTotalDmg[attacker], iHealthLeft);
	
	// Display to player spectators
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || !IsClientObserver(i) || i == attacker)
			continue;
		
		int iObserverMode = GetEntProp(i, Prop_Send, "m_iObserverMode");
		if (iObserverMode != 4 && iObserverMode != 5)
			continue;
		
		if (GetEntPropEnt(i, Prop_Send, "m_hObserverTarget") != attacker)
			continue;
		
		DisplayHitMarker(i, szSound, szOverlay, g_iTotalDmg[attacker], iHealthLeft);
	}
	
	if (iHealthLeft <= 0)
	{
		g_iTotalDmg[attacker] = 0;
	}
	g_Attacked[attacker] = GetTime() + convar_DamageBuffer.IntValue;
	return Plugin_Continue;
}

public void OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients; ++i)
	{
		g_cKillStreak[i] = 0;
	}
}

public void DisplayHitMarker(int client, const char[] szSound, const char[] szOverlay, int iHealthDmg, int iHealthLeft)
{
	float flDuration = g_cvHitmarkLifetime.FloatValue;
	
	// Don't show remaining health if victim is dead
	
	SetHudTextParams(g_cvHudSyncHealthX.FloatValue, 
		g_cvHudSyncHealthY.FloatValue, 
		flDuration, 
		g_cvHudSyncHealthR.IntValue, 
		g_cvHudSyncHealthG.IntValue, 
		g_cvHudSyncHealthB.IntValue, 
		255);
	
	if (!g_iHudSync[client])
	{
		if (!iHealthLeft)
			ShowSyncHudText(client, g_HudSyncHealth, "");
		else
			ShowSyncHudText(client, g_HudSyncHealth, "%d", iHealthLeft);
		
		
		SetHudTextParams(g_cvHudSyncDamageX.FloatValue, 
			g_cvHudSyncDamageY.FloatValue, 
			flDuration, 
			g_cvHudSyncDamageR.IntValue, 
			g_cvHudSyncDamageG.IntValue, 
			g_cvHudSyncDamageB.IntValue, 
			255);
		
		ShowSyncHudText(client, g_HudSyncDamage, "-%d", iHealthDmg);
	}
	
	if (strlen(szSound) > 0)
		ClientCommand(client, "play \"%s\"", szSound);
	
	if (strlen(szOverlay) > 0 && (!(g_iOverlay[client] == 2 || g_iOverlay[client] == 1 && iHealthLeft <= 0)))
		ShowOverlay(client, szOverlay, flDuration);
}

void ShowDamage(int client, char[] format, any...)
{
	if (g_iHudSync[client] != 1)return;
	char sBuffer[256];
	VFormat(sBuffer, sizeof(sBuffer), format, 3);
	
	if (g_iHudSync[client])
	{
		PrintHintText(client, sBuffer);
	}
	
	int observerMode;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || !IsClientObserver(i))
			continue;
		
		observerMode = GetEntProp(i, Prop_Send, "m_iObserverMode");
		
		if (observerMode != 4 && observerMode != 5)
			continue;
		
		if (GetEntPropEnt(i, Prop_Send, "m_hObserverTarget") != client)
			continue;
		
		PrintHintText(i, sBuffer);
	}
}

void ShowHitTextMenu(int client)
{
	Menu smenu = new Menu(MH_Hittext);
	smenu.ExitBackButton = true;
	smenu.SetTitle("Hit text indicator");
	char sText[3][64];
	Format(sText[0], sizeof(sText[]), "Screen message %s", !g_iHudSync[client] ? "◉" : "◎");
	Format(sText[1], sizeof(sText[]), "Hint message %s", g_iHudSync[client] == 1 ? "◉" : "◎");
	Format(sText[2], sizeof(sText[]), "Off %s", g_iHudSync[client] == 2 ? "◉" : "◎");
	smenu.AddItem("", sText[0]);
	smenu.AddItem("", sText[1]);
	smenu.AddItem("", sText[2]);
	smenu.Display(client, MENU_TIME_FOREVER);
}

void ShowOverlayMenu(int client)
{
	Menu smenu = new Menu(MH_Overlay);
	smenu.ExitBackButton = true;
	smenu.SetTitle("Hit overlay");
	char sText[3][64];
	Format(sText[0], sizeof(sText[]), "On %s", !g_iOverlay[client] ? "◉" : "◎");
	Format(sText[1], sizeof(sText[]), "Kill overlay only %s", g_iOverlay[client] == 1 ? "◉" : "◎");
	Format(sText[2], sizeof(sText[]), "Off %s", g_iOverlay[client] == 2 ? "◉" : "◎");
	smenu.AddItem("", sText[0]);
	smenu.AddItem("", sText[1]);
	smenu.AddItem("", sText[2]);
	smenu.Display(client, MENU_TIME_FOREVER);
}

public Action Timer_ResetOverlayForClient(Handle timer, any data)
{
	int client;
	if ((client = GetClientOfUserId(data)) > 0 && IsClientInGame(client))
	{
		int iFlags = GetCommandFlags("r_screenoverlay");
		SetCommandFlags("r_screenoverlay", iFlags & ~FCVAR_CHEAT);
		ClientCommand(client, "r_screenoverlay \"\"");
		SetCommandFlags("r_screenoverlay", iFlags);
	}

	return Plugin_Continue;
}

void RefreshConfigs()
{
	static char sConfig[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sConfig, sizeof(sConfig), "configs/furious/furious_hitmarkers.cfg");
	
	KeyValues kv = new KeyValues("furious_hitmarkers");
	if (!kv.ImportFromFile(sConfig))
		SetFailState("Couldn't import: \"%s\"", sConfig);
	
	for (int i = 0; i < KILLSTREAK_MAX - 2; ++i)
	{
		char sFind[32];
		Format(sFind, sizeof(sFind), "sound_killstreak_%i", i + 2);
		kv.GetString(sFind, g_sKillStreakSound[i], sizeof(g_sKillStreakSound[]));
		
		Format(sFind, sizeof(sFind), "overlay_killstreak_%i", i + 2);
		kv.GetString(sFind, g_sKillStreakOverlay[i], sizeof(g_sKillStreakOverlay[]));
	}
	delete kv;
}

void PrecacheSoundF(char[] sound)
{
	char sBuffer[PLATFORM_MAX_PATH];
	
	strcopy(sBuffer, sizeof(sBuffer), sound);
	if (strlen(sBuffer) > 0)
	{
		PrecacheSound(sBuffer);
		
		Format(sBuffer, sizeof(sBuffer), "sound/%s", sBuffer);
		AddFileToDownloadsTable(sBuffer);
	}
} 