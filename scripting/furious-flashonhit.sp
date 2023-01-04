#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
//#include <fragstocks>
#include <clientprefs>

public Plugin myinfo = 
{
	name = "", 
	author = "FrAgOrDiE", 
	description = "", 
	version = "1.0", 
	url = "galaxyjb.it"
};

Handle c_FlashOnHit;
int g_iFlashOnHit[MAXPLAYERS + 1];

public void OnPluginStart()
{
	HookEvent("player_hurt", Event_PlayerHurt);
	c_FlashOnHit = RegClientCookie("flashonhit", "display a small flash effect on damage taken", CookieAccess_Public);
	SetCookiePrefabMenu(c_FlashOnHit, CookieMenu_OnOff_Int, "Toggle Damage Taken Glow", CMH_Flash);
	for (int i = 1; i <= MaxClients; i++)
	{
		if (AreClientCookiesCached(i))
			OnClientCookiesCached(i);
	}
}

public void CMH_Flash(int client, CookieMenuAction action, any info, char[] buffer, int maxlen)
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
	GetClientCookie(client, c_FlashOnHit, sValue, sizeof(sValue));
	g_iFlashOnHit[client] = (sValue[0] != '\0' && StringToInt(sValue));
}

public void Event_PlayerHurt(Event event, char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client > 0 && IsClientInGame(client) && IsPlayerAlive(client) && g_iFlashOnHit[client])
		Flash(client);
}

void Flash(int client)
{
	int color[4] =  { 255, 0, 0, 17 };
	Handle message = StartMessageOne("Fade", client);
	PbSetInt(message, "duration", 100);
	PbSetInt(message, "hold_time", 100);
	PbSetInt(message, "flags", 1);
	PbSetColor(message, "clr", color);
	EndMessage();
} 