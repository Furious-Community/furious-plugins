#include <sourcemod>
#include <autoexecconfig>
#include <cstrike>

#pragma newdecls required
#pragma semicolon 1 

public Plugin myinfo =
{
	name = "[Furious] Maps",
	author = "DS",
	description = "A plugin that changes the map to a more popular one whenever the server is empty.",
	version = "1.0.2",
	url = "http://furious-clan.com/"
};

ConVar g_MapChangeDelayConvar;

Handle g_ChangeMapTimer = null;

bool g_MapJustGotChanged = false;
ArrayList g_PopularMapsList = null;

char g_ConfigPath[PLATFORM_MAX_PATH];

public void OnPluginStart()
{
    AutoExecConfig_SetFile("frs.maps");
    g_MapChangeDelayConvar = AutoExecConfig_CreateConVar("sm_furious_map_change_delay", "120.0", "Delay until map change happens when server is empty (in seconds)", FCVAR_NOTIFY, true, 30.0);
    AutoExecConfig_ExecuteFile();

    g_PopularMapsList = new ArrayList(64);
    
    BuildPath(Path_SM, g_ConfigPath, sizeof(g_ConfigPath), "configs/furious/furious_popular_maps.cfg");  
    CreateTimer(5.0, Timer_CheckPlayers, _, TIMER_REPEAT);        
}

public void OnPluginEnd()
{
    if( g_PopularMapsList != null )
    {
        delete g_PopularMapsList; g_PopularMapsList = null;
    }
}

public void OnMapStart()
{
    File mapList = OpenFile(g_ConfigPath, "rt");

    if( mapList )
    {      
        while( !mapList.EndOfFile() )
        {
            char mapName[32];
            if( !mapList.ReadLine(mapName, sizeof(mapName)) )
            {
                break;
            }

            if( mapName[0] == '\0' )
            {
                continue;
            }

            TrimString(mapName);   

            // Make sure the map file exists
            char mapPath[PLATFORM_MAX_PATH];           
            BuildPath(Path_SM, mapPath, sizeof(mapPath), "maps/%s.bsp", mapName); 
            ReplaceString(mapPath, sizeof(mapPath), "addons/sourcemod/", "");

            if( !FileExists(mapPath) )
            {
                LogMessage("Warning: a map \"%s\" is found in \"furious_popular_maps.cfg\" but not in maps folder.", mapName);
                continue;
            }

            g_PopularMapsList.PushString(mapName);            
        }

        delete mapList;
    } 

    if( g_PopularMapsList.Length < 1 )
    {
        LogMessage("Warning: no maps were found in \"furious_popular_maps.cfg\".");
        return;
    }        
}

public void OnMapEnd()
{
    if( g_ChangeMapTimer != null )
    {
        delete g_ChangeMapTimer; g_ChangeMapTimer = null;
    }    
}

public void OnClientPutInServer(int client)
{
    if( g_PopularMapsList.Length < 1 )
    {
        return;
    }

    if( IsFakeClient(client) || IsClientSourceTV(client) || IsClientReplay(client) )
    {
        return;
    }

    if( g_MapJustGotChanged )
    {
        g_MapJustGotChanged = false;  
    }

    if( GetRealClientsCount(client) > 0 )
    {
        return;
    }    

    // Stop any task of map changing

    if( g_ChangeMapTimer != null )
    {
        delete g_ChangeMapTimer; g_ChangeMapTimer = null;
    }    

    static char name[32];
    GetClientName(client, name, sizeof(name));

    LogMessage("Server is getting full again... Gaben said, Let %s be! and all was light.", name);
}

public Action Timer_CheckPlayers(Handle timer)
{
    if( g_MapJustGotChanged )
    {
        return Plugin_Continue;
    }

    if( GetRealClientsCount() > 0 )
    {
        if( g_ChangeMapTimer != null )
        {
            delete g_ChangeMapTimer; g_ChangeMapTimer = null;
        }

        return Plugin_Continue;
    }
    
    if( g_ChangeMapTimer == null )
    {
        g_ChangeMapTimer = CreateTimer(g_MapChangeDelayConvar.FloatValue, Timer_ChangeMap);  
    }

    return Plugin_Continue;
}

public Action Timer_ChangeMap(Handle timer)
{
    g_ChangeMapTimer = null;

    if( !g_PopularMapsList )
    {
        return Plugin_Continue;
    }

    int maxMaps = g_PopularMapsList.Length;

    if( maxMaps < 1 )
    {
        return Plugin_Continue;
    }

    static char mapName[32], currentMapName[32];
    GetCurrentMap(currentMapName, sizeof(currentMapName));

    int randomMap = -1, trials = 0;

    do 
    {
        randomMap = GetRandomInt(0, maxMaps - 1);
        g_PopularMapsList.GetString(randomMap, mapName, sizeof(mapName));

        // We don't wanna keep on looping forever, this should be more than sufficient to insure we've looped all maps
        if( ++trials >= maxMaps )
        {
            break;
        }
    } while( maxMaps > 1 && strcmp(mapName, currentMapName) == 0 );

    // After all trial, is it still the same map? don't change it then
    if( strcmp(mapName, currentMapName) == 0 )
    {
        return Plugin_Continue;
    }

    g_MapJustGotChanged = true;

    ServerCommand("changelevel %s", mapName);
    LogMessage("Server is empty... let's make the server great again by switching to a more popular map \"%s\".", mapName);

    return Plugin_Continue;
}

int GetRealClientsCount(int skip = 0)
{
    int clients = 0;

    for( int i = 1; i <= MaxClients; i++ )
    {
        if( i == skip )
        {
            continue;
        }

        if( !IsClientInGame(i) )
        {
            continue;
        }

        if( IsFakeClient(i) || IsClientSourceTV(i) || IsClientReplay(i) )
        {
            continue;
        }       
        
        if (GetClientTeam(i) == CS_TEAM_SPECTATOR)
        {
        	continue;
        }

        clients++;
    }

    return clients;
}