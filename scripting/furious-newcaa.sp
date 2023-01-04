#pragma semicolon 1
#include <sourcemod>
//#include <fragstocks>
#include <colorlib>

public Plugin myinfo = 
{
	name = "[Furious] Command And Answers", 
	author = "FrAgOrDiE", 
	description = "", 
	version = "1.0", 
	url = "galaxyjb.it"
};

StringMap map;

public void OnPluginStart()
{
	KeyValues kv = new KeyValues("commands_and_answers");
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/furious/furious-newcaa.cfg");
	if (!kv.ImportFromFile(sPath))
	{
		delete kv;
		SetFailState("Couldn't import %s", sPath);
	}
	if (!kv.GotoFirstSubKey())
	{
		delete kv;
		LogMessage("No entries found in %s", sPath);
		return;
	}
	map = new StringMap();
	ArrayList arr[32];
	int i;
	do
	{
		arr[i] = new ArrayList(80);
		char sCommand[64];
		kv.GetSectionName(sCommand, sizeof(sCommand));
		Format(sCommand, sizeof(sCommand), "sm_%s", sCommand);
		if (kv.GetNum("enabled", 0) == 1)
		{
			arr[i].Push(kv.GetNum("print_to_all", 0));
			if (!kv.JumpToKey("reply_lines"))
			{
				delete arr;
				delete map;
				delete kv;
				SetFailState("Error. No reply lines detected in a command");
			}
			RegConsoleCmd(sCommand, Command_Registered);
			kv.GotoFirstSubKey();
			do
			{
				char sReplyLine[256];
				kv.GetString("msg", sReplyLine, sizeof(sReplyLine));
				arr[i].PushString(sReplyLine);
			} while (kv.GotoNextKey());
			kv.GoBack();
			kv.GoBack();
			map.SetValue(sCommand, arr[i]);
		}
		i++;
	} while (kv.GotoNextKey());
	delete kv;
}

public Action Command_Registered(int client, int args)
{
	char sCommand[64];
	GetCmdArg(0, sCommand, sizeof(sCommand));
	ArrayList arr;
	if (!map.GetValue(sCommand, arr))
	{
		delete arr;
		delete map;
		SetFailState("Error.");
	}
	for (int i = 1; i < arr.Length; i++)
	{
		char sReplyLine[256];
		arr.GetString(i, sReplyLine, sizeof(sReplyLine));
		if (arr.Get(0) == 1)
		{
			CPrintToChatAll(sReplyLine);
		}
		else
		{
			CPrintToChat(client, sReplyLine);
		}
	}
	return Plugin_Handled;
}
