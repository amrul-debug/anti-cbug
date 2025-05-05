#include <a_samp>

#if defined _ANTI_CBUG_INCLUDED
    #endinput
#endif
#define _ANTI_CBUG_INCLUDED

#define CBUG_TIME_THRESHOLD  250
#define CBUG_RESET_TIME      1500
#define CBUG_WARNING_LIMIT   3
#define CBUG_KICK_MESSAGE    "You have been kicked for using C-Bug."
#define CBUG_WARNING_COLOR   0xFF0000FF

enum _:PlayerCBugState {
    bool:PCB_IsFiring,
    bool:PCB_IsUsingAction,
    bool:PCB_IsDucking,
    PCB_FireStartTime,
    PCB_ActionStartTime,
    PCB_DuckStartTime,
    PCB_WarningCount,
    PCB_LastWarningTime,
    bool:PCB_JustSpawned,
    PCB_TimerID
}

static PlayerCBugData[MAX_PLAYERS][PlayerCBugState];

forward ProcessCBugDetection(playerid);
forward ResetSpawnProtection(playerid);
forward KickPlayerForCBug(playerid);
forward ResetPlayerCBugWarnings(playerid);
forward DeferredKick(playerid);

public OnFilterScriptInit() {
    print("\n--------------------------------------");
    print(" Anti-CBug System Loaded ");
    print("--------------------------------------\n");
    
    for(new playerid = 0; playerid < MAX_PLAYERS; playerid++) {
        if(IsPlayerConnected(playerid)) {
            InitializePlayerCBugData(playerid);
        }
    }
    return 1;
}

public OnFilterScriptExit() {
    print("\n--------------------------------------");
    print(" Anti-CBug System Unloaded ");
    print("--------------------------------------\n");
    
    for(new playerid = 0; playerid < MAX_PLAYERS; playerid++) {
        if(IsPlayerConnected(playerid)) {
            CleanupPlayerCBugData(playerid);
        }
    }
    return 1;
}

public OnPlayerConnect(playerid) {
    InitializePlayerCBugData(playerid);
    return 1;
}

public OnPlayerDisconnect(playerid, reason) {
    CleanupPlayerCBugData(playerid);
    return 1;
}

public OnPlayerSpawn(playerid) {
    PlayerCBugData[playerid][PCB_JustSpawned] = true;
    SetTimerEx("ResetSpawnProtection", 3000, false, "i", playerid);
    PlayerCBugData[playerid][PCB_WarningCount] = 0;
    ResetPlayerCBugStates(playerid);
    return 1;
}

public OnPlayerDeath(playerid, killerid, reason) {
    ResetPlayerCBugStates(playerid);
    return 1;
}

public OnPlayerKeyStateChange(playerid, newkeys, oldkeys) {
    if(!IsPlayerConnected(playerid) || GetPlayerState(playerid) != PLAYER_STATE_ONFOOT || PlayerCBugData[playerid][PCB_JustSpawned]) {
        return 1;
    }
    
    new currentTime = GetTickCount();
    
    if((newkeys & KEY_FIRE) && !(oldkeys & KEY_FIRE)) {
        PlayerCBugData[playerid][PCB_IsFiring] = true;
        PlayerCBugData[playerid][PCB_FireStartTime] = currentTime;
        
        if(PlayerCBugData[playerid][PCB_IsDucking]) {
            new timeDiff = currentTime - PlayerCBugData[playerid][PCB_DuckStartTime];
            if(timeDiff >= 0 && timeDiff < CBUG_TIME_THRESHOLD) {
                ProcessCBugDetection(playerid);
            }
        }
    }
    else if((oldkeys & KEY_FIRE) && !(newkeys & KEY_FIRE)) {
        PlayerCBugData[playerid][PCB_IsFiring] = false;
    }
    
    if((newkeys & KEY_ACTION) && !(oldkeys & KEY_ACTION)) {
        PlayerCBugData[playerid][PCB_IsUsingAction] = true;
        PlayerCBugData[playerid][PCB_ActionStartTime] = currentTime;
        
        if(PlayerCBugData[playerid][PCB_IsDucking]) {
            new timeDiff = currentTime - PlayerCBugData[playerid][PCB_DuckStartTime];
            if(timeDiff >= 0 && timeDiff < CBUG_TIME_THRESHOLD) {
                ProcessCBugDetection(playerid);
            }
        }
    }
    else if((oldkeys & KEY_ACTION) && !(newkeys & KEY_ACTION)) {
        PlayerCBugData[playerid][PCB_IsUsingAction] = false;
    }
    
    if((newkeys & KEY_CROUCH) && !(oldkeys & KEY_CROUCH)) {
        PlayerCBugData[playerid][PCB_IsDucking] = true;
        PlayerCBugData[playerid][PCB_DuckStartTime] = currentTime;
        
        if(PlayerCBugData[playerid][PCB_IsFiring]) {
            new timeDiff = currentTime - PlayerCBugData[playerid][PCB_FireStartTime];
            if(timeDiff >= 0 && timeDiff < CBUG_TIME_THRESHOLD) {
                ProcessCBugDetection(playerid);
            }
        }
        
        if(PlayerCBugData[playerid][PCB_IsUsingAction]) {
            new timeDiff = currentTime - PlayerCBugData[playerid][PCB_ActionStartTime];
            if(timeDiff >= 0 && timeDiff < CBUG_TIME_THRESHOLD) {
                ProcessCBugDetection(playerid);
            }
        }
    }
    else if((oldkeys & KEY_CROUCH) && !(newkeys & KEY_CROUCH)) {
        PlayerCBugData[playerid][PCB_IsDucking] = false;
    }
    
    return 1;
}

public OnPlayerUpdate(playerid) {
    if(!IsPlayerConnected(playerid)) return 1;
    
    new currentTime = GetTickCount();
    
    if(PlayerCBugData[playerid][PCB_IsFiring] && 
       (currentTime - PlayerCBugData[playerid][PCB_FireStartTime] > CBUG_RESET_TIME)) {
        PlayerCBugData[playerid][PCB_IsFiring] = false;
    }
    
    if(PlayerCBugData[playerid][PCB_IsUsingAction] && 
       (currentTime - PlayerCBugData[playerid][PCB_ActionStartTime] > CBUG_RESET_TIME)) {
        PlayerCBugData[playerid][PCB_IsUsingAction] = false;
    }
    
    if(PlayerCBugData[playerid][PCB_IsDucking] && 
       (currentTime - PlayerCBugData[playerid][PCB_DuckStartTime] > CBUG_RESET_TIME)) {
        PlayerCBugData[playerid][PCB_IsDucking] = false;
    }
    
    return 1;
}

InitializePlayerCBugData(playerid) {
    ResetPlayerCBugStates(playerid);
    PlayerCBugData[playerid][PCB_WarningCount] = 0;
    PlayerCBugData[playerid][PCB_LastWarningTime] = 0;
    PlayerCBugData[playerid][PCB_JustSpawned] = true;
    PlayerCBugData[playerid][PCB_TimerID] = SetTimerEx("ResetPlayerCBugWarnings", 300000, true, "i", playerid);
    SetTimerEx("ResetSpawnProtection", 3000, false, "i", playerid);
}

CleanupPlayerCBugData(playerid) {
    if(PlayerCBugData[playerid][PCB_TimerID] != -1) {
        KillTimer(PlayerCBugData[playerid][PCB_TimerID]);
        PlayerCBugData[playerid][PCB_TimerID] = -1;
    }
}

ResetPlayerCBugStates(playerid) {
    PlayerCBugData[playerid][PCB_IsFiring] = false;
    PlayerCBugData[playerid][PCB_IsUsingAction] = false;
    PlayerCBugData[playerid][PCB_IsDucking] = false;
    PlayerCBugData[playerid][PCB_FireStartTime] = 0;
    PlayerCBugData[playerid][PCB_ActionStartTime] = 0;
    PlayerCBugData[playerid][PCB_DuckStartTime] = 0;
}

public ResetSpawnProtection(playerid) {
    if(IsPlayerConnected(playerid)) {
        PlayerCBugData[playerid][PCB_JustSpawned] = false;
    }
    return 1;
}

public ProcessCBugDetection(playerid) {
    new currentTime = GetTickCount();
    
    if(currentTime - PlayerCBugData[playerid][PCB_LastWarningTime] < 3000) {
        return 1;
    }
    
    new weaponID = GetPlayerWeapon(playerid);
    if(weaponID < 22 || weaponID > 38) {
        return 1;
    }
    
    PlayerCBugData[playerid][PCB_LastWarningTime] = currentTime;
    PlayerCBugData[playerid][PCB_WarningCount]++;
    
    new warningMsg[128];
    format(warningMsg, sizeof(warningMsg), "[ANTI-CBUG] Warning: %d/%d. Stop using crouch-bug or you will be kicked.", 
        PlayerCBugData[playerid][PCB_WarningCount], CBUG_WARNING_LIMIT);
    SendClientMessage(playerid, CBUG_WARNING_COLOR, warningMsg);
    
    new playerName[MAX_PLAYER_NAME + 1];
    GetPlayerName(playerid, playerName, sizeof(playerName));
    
    new logMessage[256];
    format(logMessage, sizeof(logMessage), "[ANTI-CBUG] Player %s[%d] was detected using C-Bug (Warning: %d/%d)",
        playerName, playerid, PlayerCBugData[playerid][PCB_WarningCount], CBUG_WARNING_LIMIT);
    printf(logMessage);
    
    if(PlayerCBugData[playerid][PCB_WarningCount] >= CBUG_WARNING_LIMIT) {
        SetTimerEx("KickPlayerForCBug", 500, false, "i", playerid);
    }
    
    return 1;
}

public KickPlayerForCBug(playerid) {
    if(!IsPlayerConnected(playerid)) return 0;
    
    new playerName[MAX_PLAYER_NAME + 1];
    GetPlayerName(playerid, playerName, sizeof(playerName));
    
    new logMessage[128];
    format(logMessage, sizeof(logMessage), "[ANTI-CBUG] Player %s[%d] was kicked for using C-Bug", playerName, playerid);
    printf(logMessage);
    
    SendClientMessage(playerid, CBUG_WARNING_COLOR, CBUG_KICK_MESSAGE);
    SetTimerEx("DeferredKick", 100, false, "i", playerid);
    
    return 1;
}

public DeferredKick(playerid) {
    if(IsPlayerConnected(playerid)) {
        Kick(playerid);
    }
    return 1;
}

public ResetPlayerCBugWarnings(playerid) {
    if(!IsPlayerConnected(playerid)) return 0;
    
    new currentTime = GetTickCount();
    if(PlayerCBugData[playerid][PCB_WarningCount] > 0 && 
       currentTime - PlayerCBugData[playerid][PCB_LastWarningTime] > 300000) {
        
        PlayerCBugData[playerid][PCB_WarningCount] = 0;
        SendClientMessage(playerid, 0x00FF00FF, "[ANTI-CBUG] Your warning count has been reset due to clean play.");
    }
    
    return 1;
}

public OnPlayerCommandText(playerid, cmdtext[]) {
    if(strcmp(cmdtext, "/resetcbugwarnings", true, 18) == 0) {
        if(!IsPlayerAdmin(playerid)) {
            SendClientMessage(playerid, 0xFF0000FF, "You don't have permission to use this command.");
            return 1;
        }
        
        new tmp[128], targetid;
        new idx;
        
        tmp = strtok(cmdtext, idx);
        tmp = strtok(cmdtext, idx);
        
        if(!strlen(tmp)) {
            SendClientMessage(playerid, 0xFFFFFFFF, "USAGE: /resetcbugwarnings [playerid]");
            return 1;
        }
        
        targetid = strval(tmp);
        
        if(!IsPlayerConnected(targetid)) {
            SendClientMessage(playerid, 0xFF0000FF, "This player is not connected.");
            return 1;
        }
        
        PlayerCBugData[targetid][PCB_WarningCount] = 0;
        
        new playerName[MAX_PLAYER_NAME + 1], adminName[MAX_PLAYER_NAME + 1];
        GetPlayerName(targetid, playerName, sizeof(playerName));
        GetPlayerName(playerid, adminName, sizeof(adminName));
        
        new message[128];
        format(message, sizeof(message), "Admin %s has reset %s's cbug warnings.", adminName, playerName);
        SendClientMessageToAll(0x00FF00FF, message);
        
        return 1;
    }
    return 0;
}

strtok(const string[], &index)
{
	new length = strlen(string);
	while ((index < length) && (string[index] <= ' '))
	{
		index++;
	}
 
	new offset = index;
	new result[20];
	while ((index < length) && (string[index] > ' ') && ((index - offset) < (sizeof(result) - 1)))
	{
		result[index - offset] = string[index];
		index++;
	}
	result[index - offset] = EOS;
	return result;
}