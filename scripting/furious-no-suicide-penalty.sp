#include <sourcemod>
#include <sdktools>
#include <cstrike>

#define GAMEDATA_FILE	"furious-no-suicide-penalty"

Handle g_hSDKCall_CBasePlayer_IncrementFragCount = null;
Handle g_hSDKCall_CBasePlayer_IncrementDeathCount = null;

public void EventFrame_player_death( DataPack hDataPack )
{
    // Set to the beginning and unpack it
    hDataPack.Reset();

    int nVictimSerial = hDataPack.ReadCell();
    int nFrags = hDataPack.ReadCell();

    int iVictim = GetClientFromSerial( nVictimSerial );

    if ( iVictim && GetClientTeam( iVictim ) == CS_TEAM_SPECTATOR && nFrags != GetClientFrags( iVictim ) )
    {
        const int nCount = 1;

        // subtract 1 to frags to balance out the 1 added for killing yourself
        CBasePlayer_IncrementFragCount( iVictim, -nCount );
    }

    delete hDataPack;
}

public void Event_player_death( Event hEvent, const char[] szName, bool bDontBroadcast )
{
    int iVictim = GetClientOfUserId( hEvent.GetInt( "userid" ) );
    int iAttacker = GetClientOfUserId( hEvent.GetInt( "attacker" ) );

    if ( iVictim == iAttacker )
    {
        const int nCount = 1;

        CBasePlayer_IncrementFragCount( iVictim, nCount );
        CBasePlayer_IncrementDeathCount( iVictim, -nCount );

        DataPack hDataPack = new DataPack();
        RequestFrame( EventFrame_player_death, hDataPack );
        hDataPack.WriteCell( GetClientSerial( iVictim ) );
        hDataPack.WriteCell( GetClientFrags( iVictim ) );
    }
}

void CBasePlayer_IncrementFragCount( int iClient, int nCount, int nHeadshots = 0 )
{
    SDKCall( g_hSDKCall_CBasePlayer_IncrementFragCount, iClient, nCount, nHeadshots );
}

void CBasePlayer_IncrementDeathCount( int iClient, int nCount )
{
    SDKCall( g_hSDKCall_CBasePlayer_IncrementDeathCount, iClient, nCount );
}

public void OnPluginStart()
{
    GameData hGameData = new GameData( GAMEDATA_FILE );

    if ( hGameData == null )
    {
        SetFailState("Unable to load gamedata file \"" ... GAMEDATA_FILE ... ".txt\"");
    }

    // void CBasePlayer::IncrementFragCount( int nCount, int nHeadshots )
    StartPrepSDKCall( SDKCall_Player );
    if ( !PrepSDKCall_SetFromConf( hGameData, SDKConf_Virtual, "CBasePlayer::IncrementFragCount" ) )
    {
        delete hGameData;

        SetFailState( "Unable to find gamedata offset entry for \"CBasePlayer::IncrementFragCount\"" );
    }

    PrepSDKCall_AddParameter( SDKType_PlainOldData, SDKPass_Plain );
    PrepSDKCall_AddParameter( SDKType_PlainOldData, SDKPass_Plain );
    g_hSDKCall_CBasePlayer_IncrementFragCount = EndPrepSDKCall();

    // void CBasePlayer::IncrementDeathCount( int nCount )
    StartPrepSDKCall( SDKCall_Player );
    if ( !PrepSDKCall_SetFromConf( hGameData, SDKConf_Virtual, "CBasePlayer::IncrementDeathCount" ) )
    {
        delete hGameData;

        SetFailState( "Unable to find gamedata offset entry for \"CBasePlayer::IncrementDeathCount\"" );
    }

    PrepSDKCall_AddParameter( SDKType_PlainOldData, SDKPass_Plain );
    g_hSDKCall_CBasePlayer_IncrementDeathCount = EndPrepSDKCall();

    delete hGameData;

    HookEvent( "player_death", Event_player_death, EventHookMode_Post );
}

public Plugin myinfo =
{
	name = "[FURIOUS] No Suicide Penalty",
	author = "Sir Jay",
	description = "No longer applies suicide penalty to players",
	version = "1.0.0",
	url = "https://furious-clan.com/"
};