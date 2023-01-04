#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>

#define HITMARKER_MDL "models/props/eminem/skull/skull.mdl"
#define FLAG_NO_COLLISION "256"

/*
	prop_dynamic flags:
	[64] : Use Hitboxes for Renderbox
	[256] : Start with collision disabled
*/

int g_iModel[MAXPLAYERS + 1] = {-1, ...};

public Plugin myinfo = 
{
	name = "[Furious] Hirmarker", 
	author = "FrAgOrDiE", 
	description = "", 
	version = "1.0", 
	url = "https://furious-clan.com/"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_skull", Command_TestSkull, _, ADMFLAG_ROOT);
	RegConsoleCmd("sm_skullr", Command_TestRemove, _, ADMFLAG_ROOT);
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	MarkNativeAsOptional("Furious_HitMarker2_Begin");
	MarkNativeAsOptional("Furious_HitMarker2_End");
	
	RegPluginLibrary("furious_hitmarker2");
	
	CreateNative("Furious_HitMarker2_Begin", Native_HitMarker_Begin);
	CreateNative("Furious_HitMarker2_End", Native_HitMarker_End);
	
	return APLRes_Success;
}

public int Native_HitMarker_Begin(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	if (client == 0 || client > MaxClients)
		return false;
	
	InitHitMarker(client);
	return true;
}

public int Native_HitMarker_End(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	if (client == 0 || client > MaxClients)
		return false;
	
	RemoveHitMarker(client);
	return true;
}

public Action Command_TestSkull(int client, int args)
{
	InitHitMarker(client);
	return Plugin_Handled;
}

public Action Command_TestRemove(int client, int args)
{
	RemoveHitMarker(client);
	return Plugin_Handled;
}

public void OnGameFrame()
{
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || g_iModel[i] == -1)
			continue;
			
		float fPos[3], fAng[3];
		GetPositions(i, fPos, fAng);
		
		TeleportEntity(g_iModel[i], fPos, fAng, NULL_VECTOR);
	}
}

public void OnClientDisconnect(int client)
{
	g_iModel[client] = -1;
}

void InitHitMarker(int client)
{
	if (g_iModel[client] != -1)
		return;
	
	float fPos[3], fAng[3];
	GetPositions(client, fPos, fAng);
	
	int iModel = CreateEntityByName("prop_dynamic_override"); //https://developer.valvesoftware.com/wiki/Prop_dynamic_override
	
	if (!IsValidEntity(iModel))
		return;
	
	DispatchKeyValue(iModel, "model", HITMARKER_MDL);
	DispatchKeyValue(iModel, "spawnflags", FLAG_NO_COLLISION);
	DispatchKeyValue(iModel, "solid", "0");
	DispatchKeyValue(iModel, "disableshadows", "true"); //not working
	DispatchKeyValue(iModel, "disablereceiveshadows", "true"); //not working
	
	
	DispatchSpawn(iModel);
	
	AcceptEntityInput(iModel, "TurnOn", iModel, iModel, 0);
	
	
	TeleportEntity(iModel, fPos, fAng, NULL_VECTOR);
	
	g_iModel[client] = iModel;
	
}

void RemoveHitMarker(int client)
{
	if (!IsValidEntity(g_iModel[client]))
		return;
		
	RemoveEntity(g_iModel[client]);
}

void GetPositions(int client, float posBuffer[3], float angBuffer[3])
{
	float fHitPos[3], fEyePos[3], fEyeAng[3];
	GetClientEyePosition(client, fEyePos);
	GetClientEyeAngles(client, fEyeAng);
	
	TR_TraceRayFilter(fEyePos, fEyeAng, MASK_SOLID, RayType_Infinite, Trace_Filter, client);
	if (!TR_DidHit())
		return;
	
	TR_GetEndPosition(fHitPos);
	SubtractVectors(fEyePos, fHitPos, posBuffer);
	ScaleVector(posBuffer, 1 - 155.0 / GetVectorDistance(fHitPos, fEyePos));
	AddVectors(fHitPos, posBuffer, posBuffer);
	
	TR_TraceRayFilter(fEyePos, posBuffer, MASK_SOLID, RayType_EndPoint, Trace_Filter, client);
	if (TR_DidHit())
		return;
		
	for (int i = 0; i < 3; ++i)
		angBuffer[i] = fEyeAng[i];
	
	RotateRelatively(angBuffer, 190.0);
}

bool Trace_Filter(int entity, int contentsMask, any data)
{
	return entity != data;
}

void RotateRelatively(float angles[3], float degree)
{
	float direction[3], normal[3];
	
	GetAngleVectors(angles, direction, NULL_VECTOR, normal);
	
	float sin = Sine(degree * 0.01745328); // Pi/180
	float cos = Cosine(degree * 0.01745328);
	float a = normal[0] * sin;
	float b = normal[1] * sin;
	float c = normal[2] * sin;
	float x = direction[2] * b + direction[0] * cos - direction[1] * c;
	float y = direction[0] * c + direction[1] * cos - direction[2] * a;
	float z = direction[1] * a + direction[2] * cos - direction[0] * b;
	direction[0] = x;
	direction[1] = y;
	direction[2] = z;
	
	GetVectorAngles(direction, angles);
	
	float up[3];
	GetVectorVectors(direction, NULL_VECTOR, up);
	
	float roll = GetAngleBetweenVectors(up, normal, direction);
	angles[2] += roll;
}

float GetAngleBetweenVectors(const float vector1[3], const float vector2[3], const float direction[3])
{
	float vector1_n[3], vector2_n[3], direction_n[3], cross[3];
	NormalizeVector(direction, direction_n);
	NormalizeVector(vector1, vector1_n);
	NormalizeVector(vector2, vector2_n);
	float degree = ArcCosine(GetVectorDotProduct(vector1_n, vector2_n)) * 57.29677951; // 180/Pi | okay so it should actually be 57.29577951 but this other number makes the model more centered in the screen
	GetVectorCrossProduct(vector1_n, vector2_n, cross);
	
	if (GetVectorDotProduct(cross, direction_n) < 0.0)
	{
		degree *= -1.0;
	}
	
	return degree;
}