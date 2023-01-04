#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <dhooks>

public Plugin myinfo =
{
	name = "HitReg Fix (v2.4 linux with forward (s)) by backwards",
	author = "backwards",
	description = "HitReg Fix (v2.4 linux with forward (s)) by backwards",
	version = "2.4",
	url = "http://steamcommunity.com/id/mypassword"
};

Handle g_hOnStartLagComp;
Handle hStartLagCompDetour;
Handle hFinishLagCompDetour;
Address StartLagCompSig = view_as<Address>(0x0);

ConVar sv_maxunlag;
ConVar hitreg_small;

public OnPluginStart()
{
	MakeFilesReady();
	
	hitreg_small = CreateConVar("hitreg_small", "1", "Modify Hit Reg Params For Smaller");
	
	CreateTimer(0.25, Timer_FindValues, _, TIMER_REPEAT);
	HookEvent("player_death", PlayerDeath, EventHookMode_Pre);
	HookEvent("player_spawn", PlayerSpawn);

	StartLagCompSig = GameConfGetAddress(LoadGameConfigFile("FixHitRegV2_linux_1"), "StartLagComp");

	if(!StartLagCompSig)
		SetFailState("'Gamedata\\FixHitRegV2_linux_1.txt' needs updated (StartLagComp).");
	
	//PrintToServer("the value  = 0x%X", LoadFromAddress(view_as<Address>(StartLagCompSig + Address:0x729), NumberType_Int16));

	//StoreToAddress(view_as<Address>(StartLagCompSig + Address:0x729), 0xE990, NumberType_Int16);
	//PrintToServer("after the value  = 0x%X", LoadFromAddress(view_as<Address>(StartLagCompSig + Address:0x729), NumberType_Int16));
	

	Handle hGameData = LoadGameConfigFile("FixHitRegV2_linux");
	if (!hGameData)
	{
		SetFailState("Failed to load FixHitRegV2_linux gamedata.");
		return;
	}
	
	hStartLagCompDetour = DHookCreateFromConf(hGameData, "StartLagComp");
	if (!hStartLagCompDetour)
		SetFailState("Failed to setup detour for StartLagComp");
	
	if (!DHookEnableDetour(hStartLagCompDetour, false, Detour_OnStartLagComp))
		SetFailState("Failed to detour StartLagComp.");

	//PrintToServer("StartLagComp detoured!");
	
	hFinishLagCompDetour = DHookCreateFromConf(hGameData, "FinishLagComp");
	if (!hFinishLagCompDetour)
		SetFailState("Failed to setup detour for FinishLagComp");
	
	if (!DHookEnableDetour(hFinishLagCompDetour, false, Detour_OnFinishLagComp))
		SetFailState("Failed to detour FinishLagComp.");
		
	//PrintToServer("FinishLagComp detoured!");
	
	delete hGameData;
	
	sv_maxunlag  = FindConVar("sv_maxunlag");
}

public OnMapStart()
{
	MakeFilesReady();
}

new PrecachedModelIndexs[5];

public MakeFilesReady()
{	
	PrecachedModelIndexs[0] = PrecacheModel("models/player/custom_player/legacy/colored/counter-terrorist.mdl");
	PrecachedModelIndexs[1] = PrecacheModel("models/player/custom_player/legacy/colored/counter-terrorist_backwards_small.mdl");
	PrecachedModelIndexs[2] = PrecacheModel("models/player/custom_player/legacy/colored/counter-terrorist_backwards_medium.mdl");
	PrecachedModelIndexs[3] = PrecacheModel("models/player/custom_player/legacy/colored/counter-terrorist_backwards_large.mdl");
	PrecachedModelIndexs[4] = PrecacheModel("models/player/custom_player/legacy/colored/counter-terrorist_backwards_verylarge.mdl");	
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
  g_hOnStartLagComp = CreateGlobalForward("OnStartLagComp", ET_Event, Param_Cell);

  RegPluginLibrary("HitRegFixV2");
  return APLRes_Success;
}

char ClientModelName[MAXPLAYERS+1][512];
new g_VelocityState[MAXPLAYERS+1] = {0, ...};

public Action Timer_FindValues(Handle timer, any unused)
{
	if(sv_maxunlag.FloatValue != 1.0)
		sv_maxunlag.FloatValue = 1.0;

	for(int i = 1;i < MaxClients+1;i++)
	{
		if(!IsValidClient(i))
			continue;
		
		float flVelocity[3];
		GetEntPropVector(i, Prop_Data, "m_vecVelocity", flVelocity);
		
		float vel = GetVectorLength(flVelocity, false);
		
		bool VelocityChanged = false;
		
		if(hitreg_small.IntValue == 0)
		{
			if(vel <= 300)
			{
				if(g_VelocityState[i] != 0)
					VelocityChanged = true;
					
				g_VelocityState[i] = 0;
			}
			else if(vel <= 750)
			{
				if(g_VelocityState[i] != 1)
					VelocityChanged = true;
			
				g_VelocityState[i] = 1;
			}
			else if(vel <= 1250)
			{
				if(g_VelocityState[i] != 2)
					VelocityChanged = true;
					
				g_VelocityState[i] = 2;
			}
			else if(vel <= 1500)
			{
				if(g_VelocityState[i] != 3)
					VelocityChanged = true;
					
				g_VelocityState[i] = 3;
			}
			else
			{
				if(g_VelocityState[i] != 4)
					VelocityChanged = true;
					
				g_VelocityState[i] = 4;
			}
		}
		else
		{
			if(vel <= 350)
			{
				if(g_VelocityState[i] != 0)
					VelocityChanged = true;
					
				g_VelocityState[i] = 0;
			}
			else if(vel <= 850)
			{
				if(g_VelocityState[i] != 1)
					VelocityChanged = true;
			
				g_VelocityState[i] = 1;
			}
			else if(vel <= 1350)
			{
				if(g_VelocityState[i] != 2)
					VelocityChanged = true;
					
				g_VelocityState[i] = 2;
			}
			else
			{
				if(g_VelocityState[i] != 3)
					VelocityChanged = true;
					
				g_VelocityState[i] = 3;
			}
		}
		
		//GetClientModel(i, ClientModelName[i], 512);
	}
	
	return Plugin_Continue;
}

void PrintClientHitbox(int client, int attacker)
{
	PrintToChatAll("\x01\x02 \x01------------");
	PrintToChatAll("\x01\x02 \x10Attacker: \x01%N", attacker);
	PrintToChatAll("\x01\x02 \x01------------");
	
	for(int i = 1;i<MaxClients+1;i++)
	{
		if(i == attacker)
			continue;
			
		if(IsValidClient(i) && IsPlayerAlive(i))
		{
			PrintToChatAll("\x01\x02 \x06Client: \x01%N", i);
			
			char ModelName[512];
			GetClientModel(i, ModelName, 512);
			
			int stage = 1;
			if(StrContains(ModelName, "_verylarge", false) != -1)
				stage = 5;
			else if(StrContains(ModelName, "_large", false) != -1)
				stage = 4;
			else if(StrContains(ModelName, "_medium", false) != -1)
				stage = 3;
			else if(StrContains(ModelName, "_small", false) != -1)
				stage = 2;
			else
				stage = 1;
				
			PrintToChatAll("\x01\x02 \x02Stage: \x01%i", stage);
			
			float flVelocity[3];
			GetEntPropVector(i, Prop_Data, "m_vecVelocity", flVelocity);
		
			float vel = GetVectorLength(flVelocity, false);
		
			PrintToChatAll("\x01\x02 \x03Velocity: \x01%.2f", vel);
			
			float attacker_pos[3];
			GetClientAbsOrigin(attacker, attacker_pos);
	
			float target_pos[3];
			GetClientAbsOrigin(i, target_pos);
		
			float distance = GetVectorDistance(target_pos, attacker_pos);
			//PrintToChatAll("\x01\x02 \x04Distance: \x01%.2f", distance);
		}
	}
	//PrintToChatAll("\x01\x02 \x01------------");
}

bool TempChangedModel[MAXPLAYERS+1] = {false, ...};
int OldModelIndex[MAXPLAYERS+1] = {-1, ...};

public MRESReturn Detour_OnStartLagComp(Handle hParams)
{
	new attacker = DHookGetParam(hParams, 1);
	
	Action result = Plugin_Continue;
	Call_StartForward(g_hOnStartLagComp);
	Call_PushCell(attacker);
	Call_Finish(result);

	float attacker_pos[3];
	GetClientAbsOrigin(attacker, attacker_pos);
	
	//PrintToChatAll("StartLagComp Called!");
	for(int i = 1;i<MaxClients+1;i++)
	{
		if(i == attacker)
			continue;
			
		if(IsValidClient(i) && IsPlayerAlive(i))
		{
			//distance
			float target_pos[3];
			GetClientAbsOrigin(i, target_pos);
		
			float distance = GetVectorDistance(target_pos, attacker_pos);
			
			//Save index
			OldModelIndex[i] = GetEntProp(i, Prop_Send, "m_nModelIndex");
			GetClientModel(i, ClientModelName[i], 512);
			
			if(g_VelocityState[i] == 0)
			{
				TempChangedModel[i] = false;
				GetClientModel(i, ClientModelName[i], 512);
				//SetEntProp(i, Prop_Send, "m_nModelIndex", PrecachedModelIndexs[0]);
				//SetEntityModel(i, "models/player/custom_player/legacy/colored/counter-terrorist.mdl");
			}
			else if(g_VelocityState[i] == 1)
			{
				TempChangedModel[i] = true;
				//SetEntProp(i, Prop_Send, "m_nModelIndex", PrecachedModelIndexs[1]);
				SetEntityModel(i, "models/player/custom_player/legacy/colored/counter-terrorist_backwards_small.mdl");
			}
			else if(g_VelocityState[i] == 2)
			{
				TempChangedModel[i] = true;
				//SetEntProp(i, Prop_Send, "m_nModelIndex", PrecachedModelIndexs[2]);
				SetEntityModel(i, "models/player/custom_player/legacy/colored/counter-terrorist_backwards_medium.mdl");
			}
			else if(g_VelocityState[i] == 3)
			{
				if(distance <= 200)
				{
					TempChangedModel[i] = true;
					SetEntityModel(i, "models/player/custom_player/legacy/colored/counter-terrorist_backwards_medium.mdl");
					return MRES_Ignored;
				}
				
				TempChangedModel[i] = true;
				//SetEntProp(i, Prop_Send, "m_nModelIndex", PrecachedModelIndexs[3]);
				SetEntityModel(i, "models/player/custom_player/legacy/colored/counter-terrorist_backwards_large.mdl");
			}
			else if(g_VelocityState[i] == 4)
			{
				if(distance <= 200)
				{
					TempChangedModel[i] = true;
					SetEntityModel(i, "models/player/custom_player/legacy/colored/counter-terrorist_backwards_medium.mdl");
					return MRES_Ignored;
				}
				
				if(distance <= 400)
				{
					TempChangedModel[i] = true;
					SetEntityModel(i, "models/player/custom_player/legacy/colored/counter-terrorist_backwards_large.mdl");
					return MRES_Ignored;
				}
				
				TempChangedModel[i] = true;
				//SetEntProp(i, Prop_Send, "m_nModelIndex", PrecachedModelIndexs[4]);
				SetEntityModel(i, "models/player/custom_player/legacy/colored/counter-terrorist_backwards_verylarge.mdl");
			}
			//PrintClientHitbox(i, attacker);
		}
	}
	
	return MRES_Ignored;
}

public MRESReturn Detour_OnFinishLagComp(Handle hParams)
{
	//PrintToChatAll("FinishLagComp Called!");
	for(int i = 1;i<MaxClients+1;i++)
	{
		if(IsValidClient(i) && IsPlayerAlive(i))
		{
			if(TempChangedModel[i])
				SetEntityModel(i, ClientModelName[i]);
		}
	}
	return MRES_Ignored;
}

public Action:PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!IsValidClient(client))
		return Plugin_Continue;
		
	OldModelIndex[client] = GetEntProp(client, Prop_Send, "m_nModelIndex");
	
	return Plugin_Continue;
}

public Action:PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!IsValidClient(client))
		return Plugin_Continue;
		
	new ragdoll = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");	
	
	if(ragdoll > 0)
		SetEntProp(ragdoll, Prop_Send, "m_nModelIndex", OldModelIndex[client]);
	
	
	return Plugin_Continue;
}

bool IsValidClient(int client)
{
    if (!(1 <= client <= MaxClients) || !IsClientInGame(client) || IsClientSourceTV(client) || IsClientReplay(client) || !IsClientConnected(client))
        return false;
		
    return true;
}