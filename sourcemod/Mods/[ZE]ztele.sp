#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "TorNim0s"
#define PLUGIN_VERSION "1.0"
#define PLUGIN_URL "play-il.co.il"

#include <sourcemod>
#include <sdktools>
#include <cstrike>

#define PREFIX " \x04[Play-IL]\x01"

#define MAX_TELEPORT 3

#define TIMER_TO_TELEPORT 3.0

#pragma newdecls required

g_nMaxTeleports[MAXPLAYERS];

Handle g_tTeleports[MAXPLAYERS];

public Plugin myinfo = 
{
	name = "[CSGO] ZombieEscape - Ztele", 
	author = PLUGIN_AUTHOR, 
	description = "", 
	version = PLUGIN_VERSION, 
	url = PLUGIN_URL
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_ztele", Command_Ztele, "Teleport back to spawn if you are stuck.");
	
	HookEvent("round_start", OnRoundStart);
}

public void OnClientPostAdminCheck(int nPlayerIndex) {
	g_nMaxTeleports[nPlayerIndex] = 0;
}

public void OnClientDisconnect(int nPlayerIndex) {
	if (g_tTeleports[nPlayerIndex] != INVALID_HANDLE) {
		KillTimer(g_tTeleports[nPlayerIndex]);
		g_tTeleports[nPlayerIndex] = INVALID_HANDLE;
	}
}

public Action OnRoundStart(Event event, const char[] name, bool dontBroadcast) {
	resetAllTimers();
}

void resetAllTimers() {
	for (int nCurrentPlayer = 1; nCurrentPlayer <= MaxClients; nCurrentPlayer++) {
		if (IsClientInGame(nCurrentPlayer)) {
			if (g_tTeleports[nCurrentPlayer] != INVALID_HANDLE) {
				KillTimer(g_tTeleports[nCurrentPlayer]);
				g_tTeleports[nCurrentPlayer] = INVALID_HANDLE;
			}
			
			g_nMaxTeleports[nCurrentPlayer] = 0;
		}
	}
}

public Action Command_Ztele(int nPlayerIndex, int args) {
	if (!(GetClientTeam(nPlayerIndex) == CS_TEAM_CT)) {
		PrintToChat(nPlayerIndex, "%s Command allow only for CT", PREFIX);
		return;
	}
	
	if (g_nMaxTeleports[nPlayerIndex] < MAX_TELEPORT) {
		if (g_tTeleports[nPlayerIndex] != INVALID_HANDLE) {
			KillTimer(g_tTeleports[nPlayerIndex]);
			g_tTeleports[nPlayerIndex] = INVALID_HANDLE;
		}
		
		g_tTeleports[nPlayerIndex] = CreateTimer(TIMER_TO_TELEPORT, Timer_TeleportPlayer, nPlayerIndex);
		
		PrintToChat(nPlayerIndex, "%s Teleport initiate in %.0f seconds, \x04Dont Move!!\x01", PREFIX, TIMER_TO_TELEPORT);
	}
	else {
		PrintToChat(nPlayerIndex, "%s You teleported too many times...", PREFIX);
	}
	
}

public Action OnPlayerRunCmd(int nCurrentPlayer, int & buttons) {
	if (buttons == IN_MOVELEFT || buttons == IN_MOVERIGHT || buttons == IN_BACK || buttons == IN_FORWARD) {
		if (g_tTeleports[nCurrentPlayer] != INVALID_HANDLE) {
			KillTimer(g_tTeleports[nCurrentPlayer]);
			g_tTeleports[nCurrentPlayer] = INVALID_HANDLE;
			
			PrintToChat(nCurrentPlayer, "%s You moved! Teleport has been \x04cancelled!\x01", PREFIX);
		}
	}
}

public Action Timer_TeleportPlayer(Handle timer, int nPlayerIndex) {
	startTeleport(nPlayerIndex);
	
	KillTimer(timer);
	g_tTeleports[nPlayerIndex] = INVALID_HANDLE;
}

void startTeleport(int nPlayerIndex) {
	
	int nCTPlayers[MAXPLAYERS];
	int nCounter = 0;
	
	if (GetClientTeam(nPlayerIndex) == CS_TEAM_T) {
		return;
	}
	
	for (int nCurrentPlayer = 1; nCurrentPlayer <= MaxClients; nCurrentPlayer++) {
		if (!IsClientInGame(nCurrentPlayer) || !IsPlayerAlive(nCurrentPlayer) || GetClientTeam(nCurrentPlayer) == CS_TEAM_T || nCurrentPlayer == nPlayerIndex) {
			continue;
		}
		
		nCTPlayers[nCounter] = nCurrentPlayer;
		nCounter++;
	}
	
	if (nCounter < 1) {
		return;
	}
	
	int nTeleportTo = GetRandomInt(0, nCounter - 1);
	float fOrigin[3];
	float fAndlge[3];
	GetClientAbsOrigin(nCTPlayers[nTeleportTo], fOrigin);
	GetClientAbsAngles(nCTPlayers[nTeleportTo], fAndlge);
	
	TeleportEntity(nPlayerIndex, fOrigin, fAndlge, NULL_VECTOR);
	
	g_nMaxTeleports[nPlayerIndex]++;
	
	PrintToChat(nPlayerIndex, "%s You teleported [\x04%d\x01/\x02%d\x01]", PREFIX, g_nMaxTeleports[nPlayerIndex], MAX_TELEPORT);
} 