#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#define HITMARKER_MDL "models/props/eminem/skull/skull.mdl"

public Plugin myinfo = 
{
	name = "[Furious] Hirmarker", 
	author = "FrAgOrDiE", 
	description = "", 
	version = "1.0", 
	url = "https://furious-clan.com/"
};

int g_iModel[MAXPLAYERS + 1] = {-1, ...};

public void OnPluginStart()
{
	RegConsoleCmd("sm_skull", Command_TestSkull, _, ADMFLAG_ROOT);
	RegConsoleCmd("sm_skullr", Command_TestRemove, _, ADMFLAG_ROOT);
}

public void OnClientDisconnect(int client)
{
	g_iModel[client] = -1;
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

public void Frame_SetParent(DataPack pack)
{
	pack.Reset();
	int iViewModel = EntRefToEntIndex(pack.ReadCell());
	int iSkin = EntRefToEntIndex(pack.ReadCell());
	delete pack;
	
	if (!IsValidEntity(iSkin))
		return;
		
	SetVariantString("!activator");
	AcceptEntityInput(iSkin, "SetParent", iViewModel, iSkin);
}

int Weapon_GetViewModelIndex(int client, int index)
{
	while ((index = FindEntityByClassname2(index, "predicted_viewmodel")) != -1)
	{
		int iOwner = GetEntPropEnt(index, Prop_Send, "m_hOwner");
		
		if (iOwner != client)
			continue;
		
		return index;
	}
	return -1;
}

int FindEntityByClassname2(int startEnt, char[] classname)
{
	while (startEnt > -1 && !IsValidEntity(startEnt))
		--startEnt;
	return FindEntityByClassname(startEnt, classname);
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
	float degree = ArcCosine(GetVectorDotProduct(vector1_n, vector2_n)) * 57.29577951; // 180/Pi | okay so it should actually be 57.29577951 but this other number makes the model more centered in the screen | 57.29677951
	GetVectorCrossProduct(vector1_n, vector2_n, cross);
	
	if (GetVectorDotProduct(cross, direction_n) < 0.0)
	{
		degree *= -1.0;
	}
	
	return degree;
}

void InitHitMarker(int client)
{
	if (g_iModel[client] != -1)
		return;
		
	int iModel = CreateEntityByName("prop_dynamic_override");
	DispatchKeyValue(iModel, "model", HITMARKER_MDL);
	SetEntProp(iModel, Prop_Send, "m_CollisionGroup", 0);
	DispatchSpawn(iModel);
	
	float fPos[3], fAng[3];
	GetPositions(client, fPos, fAng);
	TeleportEntity(iModel, fPos, fAng, NULL_VECTOR);
	
	g_iModel[client] = iModel;
	int iViewModel = Weapon_GetViewModelIndex(client, -1);
	
	DataPack pack = new DataPack();
	pack.WriteCell(EntIndexToEntRef(iViewModel));
	pack.WriteCell(EntIndexToEntRef(iModel));
	RequestFrame(Frame_SetParent, pack);
}

void RemoveHitMarker(int client)
{
	if (!IsValidEntity(g_iModel[client]))
		return;
		
	RemoveEntity(g_iModel[client]);
	g_iModel[client] = -1;
}