#include <sourcemod>
#include <colorlib>

#pragma newdecls required
#pragma semicolon 1

#define MAX_LINE_BUFFER 256

public Plugin myinfo =
{
	name = "[Furious] Commands & Answers",
	author = "DS",
	description = "Reply to player commands in chat.",
	version = "1.1.3",
	url = "http://furious-clan.com/"
};

enum struct CommandAnswer
{    
    ArrayList answer;
    bool print_to_all;
    bool shown;
}

StringMap g_CommandsAndAnswers = null;

public void OnPluginStart()
{
    g_CommandsAndAnswers = new StringMap();
}

public void OnConfigsExecuted()
{
    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), "configs/furious/furious_caa.cfg");

    KeyValues kv = new KeyValues("commands_and_answers");    

    kv.ImportFromFile(path);

    if( !kv.GotoFirstSubKey() )
    {
        delete kv;
        return;
    }

    char command[64], buffer[MAX_LINE_BUFFER];

    do 
    {
        kv.GetString("command", command, sizeof(command));

        if( strlen(command) < 1 )
        {
            continue;
        }

        CommandAnswer data;
        data.print_to_all = !!kv.GetNum("print_to_all");
        data.shown = !!kv.GetNum("shown", 1);

        if( !kv.GotoFirstSubKey() )
        {
            continue;
        }
             
        kv.GetSectionName(buffer, sizeof(buffer));

        if( !StrEqual(buffer, "answers") )
        {
            kv.GoBack();
            continue;
        }

        delete data.answer;
        data.answer = new ArrayList(ByteCountToCells(MAX_LINE_BUFFER));

        if( !kv.GotoFirstSubKey() )
        {            
            continue;            
        }

        do 
        {
            kv.GetSectionName(buffer, sizeof(buffer)); 

            if( strlen(buffer) > 0 )
            {           
                data.answer.PushString(buffer);               
            }
        } while( kv.GotoNextKey() );

        kv.GoBack();
        kv.GoBack();

        if( data.answer.Length < 1 )
        {
            continue;
        }

        g_CommandsAndAnswers.SetArray(command, data, sizeof(CommandAnswer));
    } while( kv.GotoNextKey() );

    delete kv;
}

public Action OnClientSayCommand(int client, const char[] command, const char[] args)
{
    int len = strlen(args);
    if( len++ < 1 )
    {
        return Plugin_Continue;
    }

    if( client < 1 || client > MaxClients )
    {
        return Plugin_Continue;
    }

    if( !IsClientInGame(client) )
    {
        return Plugin_Continue;
    }

    int step = (args[0] == '!' || args[0] == '/') ? 1 : 0;

    char[] cmd = new char[len];         
    strcopy(cmd, len, args[step]);

    StringMapSnapshot snapshot = g_CommandsAndAnswers.Snapshot();   

    for( int i = 0; i < snapshot.Length; i++ )
    {
        char keyName[64];
        snapshot.GetKey(i, keyName, sizeof(keyName));       

        if( !KeyContains(keyName, cmd) )
        {
            continue;
        }        

        CommandAnswer data;    
        if( g_CommandsAndAnswers.GetArray(keyName, data, sizeof(CommandAnswer)) )
        {
            bool print_to_all = data.print_to_all;
            ArrayList answers = data.answer;

            for( int j = 0; j < answers.Length; j++ )
            {
                char buffer[MAX_LINE_BUFFER];
                answers.GetString(j, buffer, sizeof(buffer));               

                ReplaceName(client, buffer, sizeof(buffer));

                if( print_to_all )
                {
                    CPrintToChatAll(buffer);
                }
                else 
                {
                    CPrintToChat(client, buffer);
                }
            }

            delete snapshot;
            return data.shown ? Plugin_Continue : Plugin_Stop;     
        }

        break;
    }

    delete snapshot;
    return Plugin_Continue;
}

// TODO: add more like these... {rank} etc.. if it's needed at all
int ReplaceName(int client, char[] buffer, int maxLen)
{
    char name[32];
    GetClientName(client, name, sizeof(name));

    return ReplaceString(buffer, maxLen, "{name}", name);    
}

bool KeyContains(const char[] key, const char[] cmd)
{
    int cmdsCount = FindStringsCount(key, ",") + 1;

    char[][] buffers = new char[cmdsCount][32];
    ExplodeString(key, ",", buffers, cmdsCount, 32);

    for( int i = 0; i < cmdsCount; i++ )
    {
        TrimString(buffers[i]);

        if( StrEqual(buffers[i], cmd) )
        {
            return true;
        }
    }

    return false;
}

int FindStringsCount(const char[] buffer, const char[] str)
{
    int len = strlen(str);
    int pos = -len, strCount = 0;

    while( (pos = StrContains(buffer[pos + len], str)) != -1 )
    {
        strCount++;
    }

    return strCount;
}