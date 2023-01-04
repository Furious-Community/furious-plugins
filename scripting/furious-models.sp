#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <autoexecconfig>

#undef REQUIRE_PLUGIN
#include <furious/furious-vip>
#define REQUIRE_PLUGIN

#define PLUGIN_VERSION "2.1.1"
#define LoopAllPlayers(%1) for(int %1=1;%1<=MaxClients;++%1)\
if(IsClientInGame(%1))

char defaultTmodel[PLATFORM_MAX_PATH], defaultCTmodel[PLATFORM_MAX_PATH], Tarmmodel[PLATFORM_MAX_PATH], CTarmmodel[PLATFORM_MAX_PATH],
	vipTmodel[PLATFORM_MAX_PATH], vipCTmodel[PLATFORM_MAX_PATH], adminTmodel[PLATFORM_MAX_PATH], adminCTmodel[PLATFORM_MAX_PATH];

char def_defaultTmodel[PLATFORM_MAX_PATH], def_defaultCTmodel[PLATFORM_MAX_PATH], def_Tarmmodel[PLATFORM_MAX_PATH], def_CTarmmodel[PLATFORM_MAX_PATH],
	def_vipTmodel[PLATFORM_MAX_PATH], def_vipCTmodel[PLATFORM_MAX_PATH], def_adminTmodel[PLATFORM_MAX_PATH], def_adminCTmodel[PLATFORM_MAX_PATH];

bool g_FoundModels = false;

char g_CustomModel[MAXPLAYERS + 1][PLATFORM_MAX_PATH];
char g_CustomArms[MAXPLAYERS + 1][PLATFORM_MAX_PATH];

public Plugin:myinfo = 
{
	name = "Furious models",
	author = "Aes",
	description = "Force Player skins and arms",
	version = PLUGIN_VERSION,
	url = "http://aes.website/"
}

public OnPluginStart(){
	HookEvent("player_spawn", 	Furious_PlayerSpawn);
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{	
	RegPluginLibrary("furious_playerskins");

	CreateNative("Furious_PlayerSkins_GetCustomModel", Native_PlayerSkins_GetCustomModel);
	CreateNative("Furious_PlayerSkins_SetCustomModel", Native_PlayerSkins_SetCustomModel);
	CreateNative("Furious_PlayerSkins_ResetCustomModel", Native_PlayerSkins_ResetCustomModel);

	CreateNative("Furious_PlayerSkins_GetCustomArms", Native_PlayerSkins_GetCustomArms);
	CreateNative("Furious_PlayerSkins_SetCustomArms", Native_PlayerSkins_SetCustomArms);
	CreateNative("Furious_PlayerSkins_ResetCustomArms", Native_PlayerSkins_ResetCustomArms);

	return APLRes_Success;
}

public OnMapStart(){
	g_FoundModels = false;

	Tarmmodel = "";
	CTarmmodel = "";
	defaultTmodel = "";
	defaultCTmodel = "";	
	vipTmodel = "";
	vipCTmodel = "";
	adminTmodel = "";
	adminCTmodel = "";
	def_Tarmmodel = "";
	def_CTarmmodel = "";
	def_defaultTmodel = "";
	def_defaultCTmodel = "";	
	def_vipTmodel = "";
	def_vipCTmodel = "";
	def_adminTmodel = "";
	def_adminCTmodel = "";

	ParseSkins();
}

void ParseSkins()
{
	char map[32];
	GetCurrentMap(map, sizeof(map));

	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "configs/furious/furious_models.cfg");

	KeyValues kv = new KeyValues("skins");    

	kv.ImportFromFile(path);

	if( !kv.GotoFirstSubKey() )
	{
		delete kv;
		return;
	}

	char section[32];

	do 
	{
		kv.GetSectionName(section, sizeof(section));		

		if( StrEqual(section, map) )
		{
			kv.GetString("defaultTmodel", defaultTmodel, sizeof(defaultTmodel));

			if(!StrEqual(defaultTmodel,""))
			{
				PrecacheModel(defaultTmodel, true);
				AddFileToDownloadsTable(defaultTmodel);
				ParseMaterialsFile(defaultTmodel);
			}


			kv.GetString("defaultCTmodel", defaultCTmodel, sizeof(defaultCTmodel));

			if(!StrEqual(defaultCTmodel,""))
			{
				PrecacheModel(defaultCTmodel, true);
				AddFileToDownloadsTable(defaultCTmodel);
				ParseMaterialsFile(defaultCTmodel);
			}


			kv.GetString("vipTmodel", vipTmodel, sizeof(vipTmodel));

			if(!StrEqual(vipTmodel,""))
			{
				PrecacheModel(vipTmodel, true);
				AddFileToDownloadsTable(vipTmodel);
				ParseMaterialsFile(vipTmodel);
			}


			kv.GetString("vipCTmodel", vipCTmodel, sizeof(vipCTmodel));

			if(!StrEqual(vipCTmodel,""))
			{
				PrecacheModel(vipCTmodel, true);
				AddFileToDownloadsTable(vipCTmodel);
				ParseMaterialsFile(vipCTmodel);
			}


			kv.GetString("adminTmodel", adminTmodel, sizeof(adminTmodel));

			if(!StrEqual(adminTmodel,""))
			{
				PrecacheModel(adminTmodel, true);
				AddFileToDownloadsTable(adminTmodel);
				ParseMaterialsFile(adminTmodel);
			}


			kv.GetString("adminCTmodel", adminCTmodel, sizeof(adminCTmodel));

			if(!StrEqual(adminCTmodel,""))
			{
				PrecacheModel(adminCTmodel, true);
				AddFileToDownloadsTable(adminCTmodel);
				ParseMaterialsFile(adminCTmodel);
			}


			kv.GetString("Tarmmodel", Tarmmodel, sizeof(Tarmmodel));

			if(!StrEqual(Tarmmodel,""))
			{
				PrecacheModel(Tarmmodel, true);
				AddFileToDownloadsTable(Tarmmodel);
				ParseMaterialsFile(Tarmmodel);
			}


			kv.GetString("CTarmmodel", CTarmmodel, sizeof(CTarmmodel));			

			if(!StrEqual(CTarmmodel,""))
			{
				PrecacheModel(CTarmmodel, true);
				AddFileToDownloadsTable(CTarmmodel);
				ParseMaterialsFile(CTarmmodel);
			}


			g_FoundModels = true;
			break;					
		}
		else if( StrEqual(section, "default") )
		{
			kv.GetString("defaultTmodel", def_defaultTmodel, sizeof(def_defaultTmodel));

			if(!StrEqual(def_defaultTmodel,""))
			{
				PrecacheModel(def_defaultTmodel, true);
				AddFileToDownloadsTable(def_defaultTmodel);
				ParseMaterialsFile(def_defaultTmodel);
			}


			kv.GetString("defaultCTmodel", def_defaultCTmodel, sizeof(def_defaultCTmodel));

			if(!StrEqual(def_defaultCTmodel,""))
			{
				PrecacheModel(def_defaultCTmodel, true);
				AddFileToDownloadsTable(def_defaultCTmodel);
				ParseMaterialsFile(def_defaultCTmodel);
			}


			kv.GetString("vipTmodel", def_vipTmodel, sizeof(def_vipTmodel));

			if(!StrEqual(def_vipTmodel,""))
			{
				PrecacheModel(def_vipTmodel, true);
				AddFileToDownloadsTable(def_vipTmodel);
				ParseMaterialsFile(def_vipTmodel);
			}


			kv.GetString("vipCTmodel", def_vipCTmodel, sizeof(def_vipCTmodel));

			if(!StrEqual(def_vipCTmodel,""))
			{
				PrecacheModel(def_vipCTmodel, true);
				AddFileToDownloadsTable(def_vipCTmodel);
				ParseMaterialsFile(def_vipCTmodel);
			}


			kv.GetString("adminTmodel", def_adminTmodel, sizeof(def_adminTmodel));

			if(!StrEqual(def_adminTmodel,""))
			{
				PrecacheModel(def_adminTmodel, true);
				AddFileToDownloadsTable(def_adminTmodel);
				ParseMaterialsFile(def_adminTmodel);
			}


			kv.GetString("adminCTmodel", def_adminCTmodel, sizeof(def_adminCTmodel));

			if(!StrEqual(def_adminCTmodel,""))
			{
				PrecacheModel(def_adminCTmodel, true);
				AddFileToDownloadsTable(def_adminCTmodel);
				ParseMaterialsFile(def_adminCTmodel);
			}


			kv.GetString("Tarmmodel", def_Tarmmodel, sizeof(def_Tarmmodel));

			if(!StrEqual(def_Tarmmodel,""))
			{
				PrecacheModel(def_Tarmmodel, true);
				AddFileToDownloadsTable(def_Tarmmodel);
				ParseMaterialsFile(def_Tarmmodel);
			}


			kv.GetString("CTarmmodel", def_CTarmmodel, sizeof(def_CTarmmodel));			

			if(!StrEqual(def_CTarmmodel,""))
			{
				PrecacheModel(def_CTarmmodel, true);
				AddFileToDownloadsTable(def_CTarmmodel);
				ParseMaterialsFile(def_CTarmmodel);
			}

			g_FoundModels = true;			
		}		
	} while( kv.GotoNextKey() );

	delete kv;	
}

void ParseMaterialsFile(char[] model)
{
	int len = strlen(model) + 5;
	char[] path = new char[len];
	
	strcopy(path, len, model);
	ReplaceString(path, len, ".mdl", "_mat.txt");

	if( !FileExists(path) )
	{
		return;
	}

	File file = OpenFile(path, "rt");

	if( file )
    {      
		char material[PLATFORM_MAX_PATH];
		while( file.ReadLine(material, sizeof(material)) )
		{
			if( material[0] == '\0' || material[0] == '/' )
			{
				continue;
			}

			if( !FileExists(material) )
			{
				LogMessage("Warning: a material file \"%s\" doesn't exist and thus players won't be able to download it.", material);
				continue;
			}

			AddFileToDownloadsTable(material);     
		}

		delete file;
    } 
}

public void OnClientConnected(int client)
{
	g_CustomModel[client] = "";
	g_CustomArms[client] = "";
}

public Action Furious_PlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
	if( !g_FoundModels )
	{
		return Plugin_Continue;
	}

	CreateTimer(0.1, PlayerModel, GetEventInt(event, "userid"));
	return Plugin_Continue;
}

public Action PlayerModel(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);

	if (client == 0)	return Plugin_Continue;
	if(!IsClientInGame(client)) return Plugin_Continue;

	bool customModel = !StrEqual(g_CustomModel[client], "") && IsModelPrecached(g_CustomModel[client]);
	bool customArms = !StrEqual(g_CustomArms[client], "") && IsModelPrecached(g_CustomArms[client]);

	int flags = GetUserFlagBits(client);
	int team = GetClientTeam(client);
	bool modelEnabled = Furious_VIP_IsModelEnabled(client);

	switch (team)
	{
		case CS_TEAM_T:
		{
			if (customModel)
			{
				SetEntityModel(client, g_CustomModel[client]);				
			}
			else
			{
				if ((flags & ADMFLAG_ROOT || flags & ADMFLAG_CUSTOM2) && modelEnabled)
				{
					if (!StrEqual(adminTmodel,"") && IsModelPrecached(adminTmodel))
					{
						SetEntityModel(client, adminTmodel);
					}
					else if (!StrEqual(def_adminTmodel,"") && IsModelPrecached(def_adminTmodel))
					{
						SetEntityModel(client, def_adminTmodel);
					}
				}
				else if ((flags & ADMFLAG_CUSTOM5 || flags & ADMFLAG_CUSTOM1) && modelEnabled)
				{
					if (!StrEqual(vipTmodel,"") && IsModelPrecached(vipTmodel))
					{
						SetEntityModel(client, vipTmodel);
					}
					else if (!StrEqual(def_vipTmodel,"") && IsModelPrecached(def_vipTmodel))
					{
						SetEntityModel(client, def_vipTmodel);
					}
				}				
				else
				{
					if (!StrEqual(defaultTmodel,"") && IsModelPrecached(defaultTmodel))
					{
						SetEntityModel(client, defaultTmodel);
					}
					else if (!StrEqual(def_defaultTmodel,"") && IsModelPrecached(def_defaultTmodel))
					{
						SetEntityModel(client, def_defaultTmodel);
					}
				}
			}

			if (customArms)
			{
				SetEntPropString(client, Prop_Send, "m_szArmsModel", g_CustomArms[client]);				
			}
			else 
			{
				if (!StrEqual(Tarmmodel,"") && IsModelPrecached(Tarmmodel))
				{
					SetEntPropString(client, Prop_Send, "m_szArmsModel", Tarmmodel);				
				}
				else if (!StrEqual(def_Tarmmodel,"") && IsModelPrecached(def_Tarmmodel))
				{
					SetEntPropString(client, Prop_Send, "m_szArmsModel", def_Tarmmodel);					
				}
			}
		}

		case CS_TEAM_CT:
		{
			if (customModel)
			{
				SetEntityModel(client, g_CustomModel[client]);
			}
			else
			{				
				if ((flags & ADMFLAG_ROOT || flags & ADMFLAG_CUSTOM2) && modelEnabled)
				{
					if (!StrEqual(adminCTmodel,"") && IsModelPrecached(adminCTmodel))
					{
						SetEntityModel(client, adminCTmodel);
					}
					else if (!StrEqual(def_adminCTmodel,"") && IsModelPrecached(def_adminCTmodel))
					{
						SetEntityModel(client, def_adminCTmodel);
					}
				}
				else if ((flags & ADMFLAG_CUSTOM5 || flags & ADMFLAG_CUSTOM1) && modelEnabled)
				{
					if (!StrEqual(vipCTmodel,"") && IsModelPrecached(vipCTmodel))
					{
						SetEntityModel(client, vipCTmodel);
					}
					else if (!StrEqual(def_vipCTmodel,"") && IsModelPrecached(def_vipCTmodel))
					{
						SetEntityModel(client, def_vipCTmodel);
					}
				}				
				else
				{
					if (!StrEqual(defaultCTmodel,"") && IsModelPrecached(defaultCTmodel))
					{
						SetEntityModel(client, defaultCTmodel);
					}
					else if (!StrEqual(def_defaultCTmodel,"") && IsModelPrecached(def_defaultCTmodel))
					{
						SetEntityModel(client, def_defaultCTmodel);
					}
				}
			}

			if (customArms)
			{
				SetEntPropString(client, Prop_Send, "m_szArmsModel", g_CustomArms[client]);				
			}
			else 
			{
				if (!StrEqual(CTarmmodel,"") && IsModelPrecached(CTarmmodel))
				{
					SetEntPropString(client, Prop_Send, "m_szArmsModel", CTarmmodel);									
				}
				else if (!StrEqual(def_CTarmmodel,"") && IsModelPrecached(def_CTarmmodel))
				{
					SetEntPropString(client, Prop_Send, "m_szArmsModel", def_CTarmmodel);									
				}
			}
		}
	}

	return Plugin_Continue;
}

public int Native_PlayerSkins_GetCustomModel(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	if (client < 1 || client > MaxClients)
		return false;
	
	SetNativeString(2, g_CustomModel[client], GetNativeCell(3));
	return true;
}

public int Native_PlayerSkins_SetCustomModel(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	if (client < 1 || client > MaxClients)
		return false;

	int len;
	GetNativeStringLength(2, len);

	int maxLen = sizeof(g_CustomModel[]);
	if (len < 1 || len >= maxLen)
	{
		return false;
	}

	GetNativeString(2, g_CustomModel[client], ++len);
	return true;
}

public int Native_PlayerSkins_ResetCustomModel(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	if (client < 1 || client > MaxClients)
		return false;
	
	g_CustomModel[client] = "";
	return true;
}

public int Native_PlayerSkins_GetCustomArms(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	if (client < 1 || client > MaxClients)
		return false;
	
	SetNativeString(2, g_CustomArms[client], GetNativeCell(3));
	return true;
}

public int Native_PlayerSkins_SetCustomArms(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	if (client < 1 || client > MaxClients)
		return false;

	int len;
	GetNativeStringLength(2, len);

	int maxLen = sizeof(g_CustomArms[]);
	if (len < 1 || len >= maxLen)
	{
		return false;
	}

	GetNativeString(2, g_CustomArms[client], ++len);
	return true;
}

public int Native_PlayerSkins_ResetCustomArms(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	if (client < 1 || client > MaxClients)
		return false;
	
	g_CustomArms[client] = "";
	return true;
}