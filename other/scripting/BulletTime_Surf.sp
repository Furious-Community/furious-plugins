#include <sourcemod>
#include <sdktools>

public Plugin:myinfo =
{
	name = "Bullet Time",
	author = "backwards",
	description = "Slows Down End of Round After Last Kill",
	version = "1.1",
	url = "http://www.steamcommunity.com/id/mypassword"
}

ConVar hosttimescale_convar;
ConVar sv_cheats_convar;

public OnPluginStart()
{
	HookEvent("player_death", OnPlayerDeath);
	HookEvent("round_start", OnRoundStart);
	
	hosttimescale_convar = FindConVar("host_timescale");
	new flags = GetConVarFlags(hosttimescale_convar);
	flags &= ~FCVAR_CHEAT;
	SetConVarFlags(hosttimescale_convar, flags);
	
	sv_cheats_convar = FindConVar("sv_cheats");
	flags = GetConVarFlags(sv_cheats_convar);
	flags &= ~FCVAR_NOTIFY;
	SetConVarFlags(sv_cheats_convar, flags);
	
	AddCommandListener(Command_Block, "");
	
	CreateTimer(0.5, SendTimescaleUpdate, _, TIMER_REPEAT);
}

public Action:SendTimescaleUpdate(Handle:timer, any:unused)
{
	if(hosttimescale_convar.FloatValue == 1.0)
	{
		for(new client = 1;client<=MAXPLAYERS;client++)
		{
			if(IsValidClient(client) && !IsFakeClient(client))
			{
				SendConVarValue(client, sv_cheats_convar, "0");
				SendConVarValue(client, hosttimescale_convar, "1.0");
			}
		}
	}
	
	return Plugin_Continue;
}

public Action:Command_Block(client, const String:command[], argc)
{
	if(sv_cheats_convar.IntValue == 0 || client == 0)
		return Plugin_Continue;
	
	new String:text[64], String:cmd[64]; 
	
	GetCmdArg(0, cmd, sizeof(cmd)); 
	StripQuotes(text);
	
	if (StrEqual(cmd, "ping", false) || StrEqual(cmd, "status", false) || 
		StrEqual(cmd, "sm_stats", false) || StrEqual(cmd, "drop", false) || 
		StrEqual(cmd, "say", false) || StrEqual(cmd, "say_team", false) || 
		StrEqual(cmd, "sm_admin", false) || StrEqual(cmd, "sm_rcon", false) ||
		StrEqual(cmd, "jointeam", false) || StrEqual(cmd, "joingame", false) ||
		StrEqual(cmd, "menuselect", false))
	{
		return Plugin_Continue;
	}
	
	return Plugin_Handled; 
}  

public void OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if(hosttimescale_convar.FloatValue != 1.0)
		hosttimescale_convar.FloatValue = 1.0;
}

public OnPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event,"userid"));
	new attacker = GetClientOfUserId(GetEventInt(event,"attacker"));
	if(!IsValidClient(client) || !IsValidClient(attacker) || attacker == client)
		return;

	//bool headshot = GetEventBool(event,"headshot");
	//if(/*headshot &&*/ GetClientTeam(attacker) != GetClientTeam(client) && GetTeamCountAlive(GetClientTeam(attacker)) == 1 && GetTeamCountAlive(GetClientTeam(client)) == 0)
	if(GetPlayersAlive() == 1)
	{
		ForceSpectate(attacker);
		BulletTime();
		
		new _iEntity = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");
		if(_iEntity > 0 && IsValidEdict(_iEntity))
		{
			decl Float:_fForce[3], Float:_fVelocity[3];

			GetEntPropVector(_iEntity, Prop_Send, "m_vecForce", _fForce);
			_fForce[0] *= 5.0;
			_fForce[1] *= 5.0;
			_fForce[2] *= 5.0;
			SetEntPropVector(_iEntity, Prop_Send, "m_vecForce", _fForce);

			GetEntPropVector(_iEntity, Prop_Send, "m_vecRagdollVelocity", _fVelocity);
			_fVelocity[0] *= 5.0;
			_fVelocity[1] *= 5.0;
			_fVelocity[2] *= 5.0;
			SetEntPropVector(_iEntity, Prop_Send, "m_vecRagdollVelocity", _fVelocity);
		}
	}
}

void ForceSpectate(client)
{
	for(int i = 1;i<MaxClients+1;i++)
	{
		if(IsValidClient(i))
		{
			if(!IsPlayerAlive(i))
			{
				SetEntProp(i, Prop_Send, "m_iObserverMode", 4);
				SetEntPropEnt(i, Prop_Send, "m_hObserverTarget", client);
			}
		}
	}
}

new bullettimecount = 0;
bool bullettimer_firsttick = true;
bool bullettimer_direction = true;
new bullettimer_pauseframe = 0;

public void BulletTime()
{
	sv_cheats_convar.IntValue = 1;
			
	bullettimecount++;
	DataPack pack = new DataPack();
	CreateDataTimer(0.1, bullettimeLoop, pack, TIMER_REPEAT);
	WritePackCell(pack, bullettimecount);
	bullettimer_firsttick = true;
	bullettimer_direction = true;
	bullettimer_pauseframe = 0;
}

public Action:bullettimeLoop(Handle:Timer, Handle:pack)
{
	ResetPack(pack);
	int timercount = ReadPackCell(pack);

	if(bullettimecount != timercount)
		return Plugin_Stop;

	if(hosttimescale_convar.FloatValue == 1.0 && !bullettimer_firsttick)
		return Plugin_Stop;
	
	bullettimer_firsttick = false;
	
	if(hosttimescale_convar.FloatValue <= 0.2)
		bullettimer_direction = false;
		
	if(!bullettimer_direction && bullettimer_pauseframe < 5)
	{
		bullettimer_pauseframe++;
		return Plugin_Continue;
	}
	
	if(bullettimer_direction)
		hosttimescale_convar.FloatValue -= 0.1;
	else
	{
		if(hosttimescale_convar.FloatValue != 1.0)
			hosttimescale_convar.FloatValue += 0.1;
		else
			return Plugin_Stop;
	}
	
	if(hosttimescale_convar.FloatValue == 1.0)
	{
		sv_cheats_convar.IntValue = 0;
		
		return Plugin_Stop;
	}
		
	return Plugin_Continue;
}

int GetTeamCountAlive(int team)
{
	int playercount = 0;
	for(new client = 1;client <= MAXPLAYERS;client++)
		if(IsValidClient(client) && IsPlayerAlive(client) && GetClientTeam(client) == team)
			playercount++;
			
	return playercount;
}

int GetPlayersAlive()
{
	int playercount = 0;
	for(new client = 1;client <= MAXPLAYERS;client++)
		if(IsValidClient(client) && IsPlayerAlive(client))
			playercount++;
			
	return playercount;
}

bool IsValidClient(int client)
{
    if (!(1 <= client <= MaxClients) || !IsClientConnected(client) || !IsClientInGame(client) || IsClientSourceTV(client) || IsClientReplay(client))
        return false;
		
    return true;
}