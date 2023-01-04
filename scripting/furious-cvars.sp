#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
//#include <fragstocks>
#include <clientprefs>

public Plugin myinfo = 
{
	name = "Convars", 
	author = "FrAgOrDiE", 
	description = "", 
	version = "1.0", 
	url = "galaxyjb.it"
};

StringMap ssAllowedCvars;
ArrayList aAllowedCvars;

public void OnPluginStart()
{
	RegAdminCmd("sm_reloadcvars", Command_ReloadCvars, ADMFLAG_ROOT);
	ssAllowedCvars = new StringMap();
	aAllowedCvars = new ArrayList(ByteCountToCells(64));
}

public void OnClientAuthorized(int client, const char[] auth)
{
	for (int i = 0; i < aAllowedCvars.Length; i++)
	{
		char sCvar[64], sValue[64];
		aAllowedCvars.GetString(i, sCvar, sizeof(sCvar));
		GetCustomValue(sCvar, sValue, sizeof(sValue));
		SendConVarValue(client, FindConVar(sCvar), sValue);
	}
}

public void OnConfigsExecuted()
{
	ReloadSettings();
}

public Action Command_ReloadCvars(int client, int args)
{
	ReloadSettings(true, client);
	return Plugin_Continue;
}

void ReloadSettings(bool cmd = false, int client = -1)
{
	ssAllowedCvars.Clear();
	aAllowedCvars.Clear();
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/furious/furious_cvars.cfg");
	KeyValues kv = new KeyValues("cvars");
	if (!kv.ImportFromFile(sPath))
	{
		delete kv;
		SetFailState("Couldn't read from file %s", sPath);
	}
	if (kv.GotoFirstSubKey())
	{
		do
		{
			char sSection[80], sValue[64];
			kv.GetSectionName(sSection, sizeof(sSection));
			kv.GetString("value", sValue, sizeof(sValue));
			ssAllowedCvars.SetString(sSection, sValue);
			aAllowedCvars.PushString(sSection);
		}
		while (kv.GotoNextKey());
	}
	if (cmd)
		PrintToChat(client, "You reloaded %i convars", aAllowedCvars.Length);
	delete kv;
	for (int ix = 1; ix <= MaxClients; ix++)
	{
		if (!IsClientInGame(ix))continue;
		for (int i = 0; i < aAllowedCvars.Length; i++)
		{
			char sCvar[64], sValue[64];
			aAllowedCvars.GetString(i, sCvar, sizeof(sCvar));
			GetCustomValue(sCvar, sValue, sizeof(sValue));
			SendConVarValue(ix, FindConVar(sCvar), sValue);
		}
	}
}

bool GetCustomValue(char[] sCvar, char[] sVal, int maxsize)
{
	return ssAllowedCvars.GetString(sCvar, sVal, maxsize);
} 