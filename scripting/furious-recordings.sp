/*-- Pragmas --*/
#pragma semicolon 1
#pragma newdecls required

/*-- Defines --*/

/*-- Includes --*/
#include <sourcemod>
#include <sdktools>
#include <colorlib>
#include <autoexecconfig>
#include <system2>

/*-- Furious Includes --*/

/*-- ConVars --*/
ConVar convar_Status;
ConVar convar_UserDir;
ConVar convar_CompressionLevel;

/*-- Globals --*/
bool force32Bit;
bool g_IsRecording;
char g_FileName[PLATFORM_MAX_PATH];

/*-- Plugin Info --*/
public Plugin myinfo =
{
	name = "[Furious] Recordings",
	author = "Drixevel",
	description = "Recordings module for Furious Clan.",
	version = "1.0.2",
	url = "http://furious-clan.com/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("furious_recordings");
	
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("furious.phrases");

	AutoExecConfig_SetFile("frs.recordings");
	convar_Status = AutoExecConfig_CreateConVar("sm_furious_recordings_status", "1", "Status of the plugin.\n(1 = on, 0 = off)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_UserDir = AutoExecConfig_CreateConVar("sm_furious_recordings_user_dir", "testserver", "User directory to use at: /home/<user_dir>/", FCVAR_PROTECTED);
	convar_CompressionLevel = AutoExecConfig_CreateConVar("sm_furious_recordings_compression_level", "1", "What level of compression should the System2 extension use for demo files?", FCVAR_PROTECTED, true, 1.0, true, 9.0);
	AutoExecConfig_ExecuteFile();
	
	AutoExecConfig_CleanFile();
	
	char binDir[PLATFORM_MAX_PATH];
	char binDir32Bit[PLATFORM_MAX_PATH];

	if (!System2_Check7ZIP(binDir, sizeof(binDir)))
	{
		if (!System2_Check7ZIP(binDir32Bit, sizeof(binDir32Bit), true))
		{
			if (StrEqual(binDir, binDir32Bit))
				LogError("ERROR: 7-ZIP was not found or is not executable at '%s'", binDir);
			else
				LogError("ERROR: 7-ZIP was not found or is not executable at '%s' or '%s'", binDir, binDir32Bit);
		}
		else
			force32Bit = true;
	}
	
	RegConsoleCmd("sm_demos", Command_Demos);
}

public Action Command_Demos(int client, int args)
{
	char sUserDir[256];
	convar_UserDir.GetString(sUserDir, sizeof(sUserDir));
	
	char sTime[32];
	FormatTime(sTime, sizeof(sTime), "%Y%m%d-%H%M%S");
	
	CPrintToChat(client, "%T", "demos available", client, sUserDir);
	CPrintToChat(client, "%T", "server time", client, sTime);
	
	return Plugin_Handled;
}

public void OnPluginEnd()
{
	if (!convar_Status.BoolValue)
		return;
	
	if (!g_IsRecording)
		return;
	
	ServerCommand("tv_stoprecord");
	g_IsRecording = false;
	
	char sFile[PLATFORM_MAX_PATH];
	FormatEx(sFile, sizeof(sFile), "%s.dem", g_FileName);
	
	if (!FileExists(sFile))
		return;
	
	char sCompressed[PLATFORM_MAX_PATH];
	FormatEx(sCompressed, sizeof(sCompressed), "%s.bz2", sFile);
	
	CompressLevel level = LEVEL_1;
	switch (convar_CompressionLevel.IntValue)
	{
		case 1:
			level = LEVEL_1;
		case 3:
			level = LEVEL_3;
		case 5:
			level = LEVEL_5;
		case 7:
			level = LEVEL_7;
		case 9:
			level = LEVEL_9;
	}
	
	//Compress the file into BZ2 to upload.
	if (!System2_Compress(CompressCallback, sFile, sCompressed, ARCHIVE_BZIP2, level, _, force32Bit))
		LogError("7-ZIP was not found or is not executable!");
}

public void OnMapStart()
{
	if (!convar_Status.BoolValue)
		return;
	
	if (g_IsRecording)
		ServerCommand("tv_stoprecord");
	
	char sMap[32];
	GetCurrentMap(sMap, sizeof(sMap));
	
	char sTime[32];
	FormatTime(sTime, sizeof(sTime), "%Y%m%d-%H%M%S");
	
	FormatEx(g_FileName, sizeof(g_FileName), "%s-%s", sMap, sTime);
	ServerCommand("tv_record \"%s\"", g_FileName);
	g_IsRecording = true;
}

public void OnMapEnd()
{
	if (!convar_Status.BoolValue)
		return;
	
	if (!g_IsRecording)
		return;
	
	ServerCommand("tv_stoprecord");
	g_IsRecording = false;
	
	char sFile[PLATFORM_MAX_PATH];
	FormatEx(sFile, sizeof(sFile), "%s.dem", g_FileName);
	
	if (!FileExists(sFile))
		ThrowError("Error while compressiong .dem file at the end of a map: File doesn't exist.");
	
	char sCompressed[PLATFORM_MAX_PATH];
	FormatEx(sCompressed, sizeof(sCompressed), "%s.bz2", sFile);
	
	DataPack pack = new DataPack();
	pack.WriteString(sFile);
	pack.WriteString(sCompressed);
	
	CompressLevel level = LEVEL_1;
	switch (convar_CompressionLevel.IntValue)
	{
		case 1:
			level = LEVEL_1;
		case 3:
			level = LEVEL_3;
		case 5:
			level = LEVEL_5;
		case 7:
			level = LEVEL_7;
		case 9:
			level = LEVEL_9;
	}
	
	//Compress the file into BZ2 to upload.
	if (!System2_Compress(CompressCallback, sFile, sCompressed, ARCHIVE_BZIP2, level, pack, force32Bit))
		LogError("7-ZIP was not found or is not executable!");
}

public void CompressCallback(bool success, const char[] command, System2ExecuteOutput output, DataPack pack)
{
	pack.Reset();
	
	char sFile[PLATFORM_MAX_PATH];
	pack.ReadString(sFile, sizeof(sFile));
	DeleteFile(sFile);
	
	char sCompressed[PLATFORM_MAX_PATH];
	pack.ReadString(sCompressed, sizeof(sCompressed));
	
	delete pack;
	
	if (!success)
	{
		delete pack;
		ThrowError("Unknown error while compressing file.");
	}
	
	char sUserDir[256];
	convar_UserDir.GetString(sUserDir, sizeof(sUserDir));
	
	if (strlen(sUserDir) == 0)
	{
		delete pack;
		ThrowError("Error while moving demo file: User directory isn't set.");
	}
	
	//Executes a system command to move files manually through the system for Linux.
	System2_ExecuteFormattedThreaded(onMoveFile, pack, "mv -f /home/%s/serverfiles/csgo/%s /var/www/html/csgo/demos/%s/%s", sUserDir, sCompressed, sUserDir, sCompressed);
}

public void onMoveFile(bool success, const char[] command, System2ExecuteOutput output, DataPack pack)
{
	pack.Reset();
	
	char sFile[PLATFORM_MAX_PATH];
	pack.ReadString(sFile, sizeof(sFile));
	
	delete pack;
	
	if (!success)
		ThrowError("Error while moving file with command: %s", command);
	
	char sMap[32];
	GetCurrentMap(sMap, sizeof(sMap));
	GetMapDisplayName(sMap, sMap, sizeof(sMap));
	
	CPrintToChatAll("%t", "demo uploaded successfully part 1", sMap, sFile);
	CPrintToChatAll("%t", "demo uploaded successfully part 2");
}