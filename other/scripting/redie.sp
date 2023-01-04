#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <sdkhooks>
#include <colorlib>

#pragma semicolon 1

#define PLUGIN_VERSION	 "2.4"

new blockCommand;
new g_Collision;
new Handle:cvar_adverts = INVALID_HANDLE;
new Handle:cvar_bhop = INVALID_HANDLE;
new Handle:cvar_dm = INVALID_HANDLE;
new bool:g_IsGhost[MAXPLAYERS + 1];
new bool:g_dm_redie[MAXPLAYERS + 1];
float g_iSpawnPos[MAXPLAYERS + 1][3];
float g_iSpawnAng[MAXPLAYERS + 1][3];
ConVar Redie_Disable_Trigger_Multiple;

public Plugin:myinfo =
{
	name = "CS:GO Redie",
	author = "Pyro, originally by MeoW",
	description = "Return as a ghost after you died.",
	version = PLUGIN_VERSION,
	url = "http://steamcommunity.com/profiles/76561198051084603"
};

public OnPluginStart()
{
	HookEvent("round_end", Event_Round_End, EventHookMode_Pre);
	HookEvent("round_start", Event_Round_Start, EventHookMode_Pre);
	HookEvent("player_spawn", Event_Player_Spawn);
	HookEvent("player_death", Event_Player_Death);
	RegConsoleCmd("sm_redie", Command_Redie);
	RegConsoleCmd("sm_ghost", Command_Redie);
	RegConsoleCmd("sm_restart", Command_BackToSpawn);
	RegConsoleCmd("sm_tele", Command_BackToSpawn);
	RegConsoleCmd("sm_stuck", Command_BackToSpawn);
	CreateTimer(120.0, advert, _, TIMER_REPEAT);
	CreateConVar("sm_redie_version", PLUGIN_VERSION, "Redie Version", FCVAR_PLUGIN | FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY);
	cvar_adverts = CreateConVar("sm_redie_adverts", "1", "If enabled, redie will produce an advert every 2 minutes.");
	cvar_bhop = CreateConVar("sm_redie_bhop", "0", "If enabled, ghosts will be able to autobhop by holding space.");
	cvar_dm = CreateConVar("sm_redie_dm", "0", "If enabled, using redie while alive will make you a ghost next time you die.");
	Redie_Disable_Trigger_Multiple = CreateConVar("Redie_Disable_Trigger_Multiple", "1", "Disable the trigger multiples for ghosts");
	g_Collision = FindSendPropInfo("CBaseEntity", "m_CollisionGroup");

	AddCommandListener(OnSay, "say");
	AddCommandListener(OnSay, "say_team");
	AddNormalSoundHook(OnNormalSoundPlayed);

	LoadTranslations("furious.phrases");
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	RegPluginLibrary("redie");

	CreateNative("Redie_IsClientGhost", Native_IsClientGhost);
	return APLRes_Success;
}

public Native_IsClientGhost(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	return g_IsGhost[client];
}

public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
}

public OnClientPostAdminCheck(client)
{
	g_IsGhost[client] = false;
}

public Action:Event_Round_End(Handle:event, const String:name[], bool:dontBroadcast)
{
	blockCommand = false;
}

public Action:Event_Round_Start(Handle:event, const String:name[], bool:dontBroadcast)
{
	blockCommand = true;
	new ent = MaxClients + 1;
	while ((ent = FindEntityByClassname(ent, "trigger_multiple")) != -1)
	{
		SDKHookEx(ent, SDKHook_EndTouch, brushentCollide);
		SDKHookEx(ent, SDKHook_StartTouch, brushentCollide);
		SDKHookEx(ent, SDKHook_Touch, brushentCollide);
	}
	while ((ent = FindEntityByClassname(ent, "func_door")) != -1)
	{
		SDKHookEx(ent, SDKHook_EndTouch, brushentCollide);
		SDKHookEx(ent, SDKHook_StartTouch, brushentCollide);
		SDKHookEx(ent, SDKHook_Touch, brushentCollide);
	}
	while ((ent = FindEntityByClassname(ent, "func_button")) != -1)
	{
		SDKHookEx(ent, SDKHook_EndTouch, brushentCollide);
		SDKHookEx(ent, SDKHook_StartTouch, brushentCollide);
		SDKHookEx(ent, SDKHook_Touch, brushentCollide);
	}
	for (new i = 1; i < MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			SDKHook(i, SDKHook_TraceAttack, OnTraceAttack);
		}
	}
}

public Action:brushentCollide(entity, other)
{
	if (Redie_Disable_Trigger_Multiple.IntValue == 0)
		return Plugin_Continue;

	if
		(
		(0 < other && other <= MaxClients) &&
		(g_IsGhost[other]) &&
		(IsClientInGame(other))
		)
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action:OnTraceAttack(victim, &attacker, &inflictor, &Float:damage, &damagetype, &ammotype, hitbox, hitgroup)
{
	if (IsValidEntity(victim))
	{
		if (g_IsGhost[victim])
		{
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}


public Action:Event_Player_Spawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	SDKHook(client, SDKHook_SetTransmit, Hook_SetTransmit);
	if (g_IsGhost[client])
	{
		g_IsGhost[client] = false;
		return;
	}
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", g_iSpawnPos[client]);
	GetEntPropVector(client, Prop_Data, "m_angRotation", g_iSpawnAng[client]);
}

public Action:Hook_SetTransmit(entity, client)
{
	if (g_IsGhost[entity] && entity != client)
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action:Event_Player_Death(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (g_dm_redie[client])
	{
		g_dm_redie[client] = false;
		CreateTimer(0.1, bringback, client);
	}
	else
	{
		CPrintToChat(client, "%t", "redie on death");

		if (GetClientTeam(client) == 3)
		{
			new ent = -1;
			while ((ent = FindEntityByClassname(ent, "item_defuser")) != -1)
			{
				if (IsValidEntity(ent))
				{
					AcceptEntityInput(ent, "kill");
				}
			}
		}
	}
}

public Action:bringback(Handle:timer, any:client)
{
	if (GetClientTeam(client) > 1)
	{
		g_IsGhost[client] = false;
		CS_RespawnPlayer(client);
		g_IsGhost[client] = true;
		new weaponIndex;
		for (new i = 0; i <= 3; i++)
		{
			if ((weaponIndex = GetPlayerWeaponSlot(client, i)) != -1)
			{
				RemovePlayerItem(client, weaponIndex);
				RemoveEdict(weaponIndex);
			}
		}
		SetEntProp(client, Prop_Send, "m_lifeState", 1);
		SetEntData(client, g_Collision, 2, 4, true);
		SetEntProp(client, Prop_Data, "m_ArmorValue", 0);
		SetEntProp(client, Prop_Send, "m_bHasDefuser", 0);
		CPrintToChat(client, "%t", "redie you are a ghost");
	}
	else
	{
		CPrintToChat(client, "%t", "redie you must be on a team");
	}
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if (g_IsGhost[client])
	{
		buttons &= ~IN_USE;
		if (GetConVarInt(cvar_bhop))
		{
			if (buttons & IN_JUMP)
			{
				if (GetEntProp(client, Prop_Data, "m_nWaterLevel") <= 1 && !(GetEntityMoveType(client) & MOVETYPE_LADDER) && !(GetEntityFlags(client) & FL_ONGROUND))
				{
					SetEntPropFloat(client, Prop_Send, "m_flStamina", 0.0);
					buttons &= ~IN_JUMP;
				}
			}
		}
	}
	return Plugin_Continue;
}

public Action:Command_Redie(client, args)
{
	if (!IsPlayerAlive(client))
	{
		if (blockCommand)
		{
			if (GetClientTeam(client) == CS_TEAM_SPECTATOR)
			{
				CS_SwitchTeam(client, GetRandomInt(CS_TEAM_T, CS_TEAM_CT));
			}

			if (GetClientTeam(client) > CS_TEAM_SPECTATOR)
			{
				g_IsGhost[client] = false; //Allows them to pick up knife and gun to then have it removed from them
				CS_RespawnPlayer(client);
				g_IsGhost[client] = true;
				new weaponIndex;
				for (new i = 0; i <= 3; i++)
				{
					if ((weaponIndex = GetPlayerWeaponSlot(client, i)) != -1)
					{
						RemovePlayerItem(client, weaponIndex);
						RemoveEdict(weaponIndex);
					}
				}
				SetEntProp(client, Prop_Send, "m_lifeState", 1);
				SetEntData(client, g_Collision, 2, 4, true);
				SetEntProp(client, Prop_Data, "m_ArmorValue", 0);
				SetEntProp(client, Prop_Send, "m_bHasDefuser", 0);
				CPrintToChat(client, "%t", "redie you are a ghost");
			}
			else
			{
				CPrintToChat(client, "redie you must be on a team");
			}
		}
		else
		{
			CPrintToChat(client, "%t", "redie wait for round");
		}
	}
	else
	{
		if (GetConVarInt(cvar_dm))
		{
			if (g_dm_redie[client])
			{
				CPrintToChat(client, "%t", "redie no longer back");
			}
			else
			{
				CPrintToChat(client, "%t", "redie ghost next time");
			}
			g_dm_redie[client] = !g_dm_redie[client];
		}
		else
		{
			CPrintToChat(client, "%t", "redie you must be dead");
		}
	}
	return Plugin_Handled;
}

public Action Command_BackToSpawn(int client, int args)
{
	if (!g_IsGhost[client])
	{
		return Plugin_Handled;
	}

	if (g_iSpawnPos[client][0] == 0.0)
	{
		CReplyToCommand(client, "%t", "redie cant back to spawn now");
		return Plugin_Handled;
	}
	TeleportEntity(client, g_iSpawnPos[client], g_iSpawnAng[client], view_as<float>( { 0.0, 0.0, 0.0 } ));
	return Plugin_Handled;
}

public Action:OnWeaponCanUse(client, weapon)
{
	if (g_IsGhost[client])
		return Plugin_Handled;

	return Plugin_Continue;
}

public Action:advert(Handle:timer)
{
	if (GetConVarInt(cvar_adverts))
	{
		CPrintToChatAll("%t", "this server is running redie");
	}
	return Plugin_Continue;
}

public Action:OnSay(client, const String:command[], args)
{
	decl String:messageText[200];
	GetCmdArgString(messageText, sizeof(messageText));

	if (strcmp(messageText, "\"!redie\"", false) == 0)
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action:OnNormalSoundPlayed(clients[64], &numClients, String:sample[PLATFORM_MAX_PATH], &entity, &channel, &Float:volume, &level, &pitch, &flags)
{
	if (entity && entity <= MaxClients && g_IsGhost[entity])
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
}