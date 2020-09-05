#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "TorNim0s"
#define PLUGIN_VERSION "1.0"
#define PLUGIN_URL "Play-IL.co.il"

#define PREFIX " \x04[Play-IL]\x01"

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <sdkhooks>
#include <zombiecash>
#include <zombiecore>
#include <zombievip>

#pragma newdecls required

#define PLAYER_DEFAULT_Cash 0

#define RECIVE_CASH_PER_MIN 3
#define RECIVE_CASH_AMOUNT 10

#define USED_SQL "csgo_zombie"
#define TABLE_NAME "shop_zold"
#define SQL_PLAYER_ID "steamid"
#define SQL_PLAYER_NAME "name"
#define SQL_PLAYER_CASH "cash"

GlobalForward g_fwdOnCashUpdate;

//SQL_Escapestring
Database g_dbDatabase;

Handle g_tGetCash;

enum struct Player {
	char auth[32];
	char name[MAX_NAME_LENGTH];
	int cash;
	int timeonserver;
	
	void reset() {
		this.auth[0] = 0;
		this.name[0] = 0;
		
		this.cash = 0;
		this.timeonserver = 0;
	}
}

Player g_aPlayers[MAXPLAYERS];

bool g_bLate = false;

public Plugin myinfo =  {
	name = "[CSGO] ZombieEscape - Cash", 
	author = PLUGIN_AUTHOR, 
	description = "", 
	version = PLUGIN_VERSION, 
	url = PLUGIN_URL
};

public void OnPluginStart() {
	RegAdminCmd("sm_givecash", Command_GiveCash, ADMFLAG_ROOT, "Admin events menu");
	RegAdminCmd("sm_gc", Command_GiveCash, ADMFLAG_ROOT, "Admin events menu");
	RegConsoleCmd("sm_c", Command_Cash, "Giving info about player cash");
	RegConsoleCmd("sm_cash", Command_Cash, "Giving info about player cash");
	
	prepareSQL();
	
	if (g_bLate) {
		for (int nCurrentPlayer = 1; nCurrentPlayer <= MaxClients; nCurrentPlayer++) {
			if (IsClientInGame(nCurrentPlayer)) {
				OnClientPostAdminCheck(nCurrentPlayer);
			}
		}
	}
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	g_bLate = late;
	
	CreateNative("GetCash", Native_GetCash);
	CreateNative("SetCash", Native_SetCash);
	
	g_fwdOnCashUpdate = CreateGlobalForward("Cash_OnCashUpdate", ET_Event, Param_Cell, Param_Cell);
	
	RegPluginLibrary("[CSGO] ZombieEscape - Cash");
	return APLRes_Success;
}

public void OnMapStart() {
	g_tGetCash = CreateTimer(1.0, TIMER_ReciveCash, _, TIMER_REPEAT);
}

public void OnPluginEnd() {
	killTimers();
}

public void OnMapEnd() {
	killTimers();
}

void killTimers() {
	if (g_tGetCash != INVALID_HANDLE) {
		KillTimer(g_tGetCash);
		g_tGetCash = INVALID_HANDLE;
	}
}

public Action TIMER_ReciveCash(Handle timer) {
	for (int nCurrentPlayer = 1; nCurrentPlayer <= MaxClients; nCurrentPlayer++) {
		if (IsClientInGame(nCurrentPlayer)) {
			if (GetClientTeam(nCurrentPlayer) == CS_TEAM_SPECTATOR) {
				continue;
			}
			
			if (!(g_aPlayers[nCurrentPlayer].timeonserver % (RECIVE_CASH_PER_MIN * 60)) && g_aPlayers[nCurrentPlayer].timeonserver != 0) {
				g_aPlayers[nCurrentPlayer].cash += RECIVE_CASH_AMOUNT;
				
				PrintToChat(nCurrentPlayer, "%s You recieved %d Zold", PREFIX, RECIVE_CASH_AMOUNT);
				
				if (VIP_CheckClientVip(nCurrentPlayer)) {
					g_aPlayers[nCurrentPlayer].cash += 5;
					PrintToChat(nCurrentPlayer, "%s You recieved extra %d Zold for being VIP", PREFIX, 5);
				}
				
				Call_StartForward(g_fwdOnCashUpdate);
				Call_PushCell(nCurrentPlayer);
				Call_PushCell(g_aPlayers[nCurrentPlayer].cash);
				Call_Finish();
			}
			g_aPlayers[nCurrentPlayer].timeonserver++;
		}
	}
}

public int Native_GetCash(Handle plugin, int numParams) {
	int nPlayer = GetNativeCell(1);
	return g_aPlayers[nPlayer].cash;
}

public int Native_SetCash(Handle plugin, int numParams) {
	int nPlayer = GetNativeCell(1);
	int nCash = GetNativeCell(2);
	g_aPlayers[nPlayer].cash = nCash;
	
	Call_StartForward(g_fwdOnCashUpdate);
	Call_PushCell(nPlayer);
	Call_PushCell(g_aPlayers[nPlayer].cash);
	Call_Finish();
}

public void OnClientPostAdminCheck(int client) {
	g_aPlayers[client].reset();
	if (!GetClientAuthId(client, AuthId_Steam2, g_aPlayers[client].auth, sizeof(g_aPlayers[].auth))) {
		KickClient(client, "Verification problem, please reconnect");
		return;
	}
	
	GetClientName(client, g_aPlayers[client].name, sizeof(g_aPlayers[].name));
	strcopy(g_aPlayers[client].name, sizeof(g_aPlayers[].name), SQL_SecureString(g_aPlayers[client].name));
	
	char query[256];
	
	Format(query, sizeof(query), "SELECT %s FROM %s WHERE %s = '%s'", SQL_PLAYER_CASH, TABLE_NAME, SQL_PLAYER_ID, g_aPlayers[client].auth);
	g_dbDatabase.Query(SQL_ReciveClientData, query, client);
}

public void OnClientDisconnect(int client) {
	char query[256];
	
	FormatEx(query, sizeof(query), "UPDATE %s SET %s = '%s', %s = '%d' WHERE %s = '%s'", TABLE_NAME, SQL_PLAYER_NAME, g_aPlayers[client].name, SQL_PLAYER_CASH, g_aPlayers[client].cash, SQL_PLAYER_ID, g_aPlayers[client].auth);
	g_dbDatabase.Query(SQL_CheckForErrors, query, client);
}

public void ZE_HumanKilledZombie(int nAttacker, int nVictim) {
	SetCash(nAttacker, (g_aPlayers[nAttacker].cash + 10));
	PrintToChat(nAttacker, "%s You have recive 10 Zold for killing zombie \x02%N\x01", PREFIX, nVictim);
}

public Action Command_GiveCash(int client, int args) {
	if (args < 2) {
		PrintToChat(client, "%s Usage: sm_givecash <target> <amount>", PREFIX);
		return Plugin_Handled;
	}
	
	//if (!(StrEqual(g_aPlayers[client].auth, "STEAM_1:0:41037171") || (StrEqual(g_aPlayers[client].auth, "STEAM_1:0:215564098"))))
	//{
	//PrintToChat(client, "%s You dont have permission use this command", PREFIX);
	//return Plugin_Handled;
	//}
	
	char sArgs[64];
	
	char sPlayer[32];
	char sPlayersName[MAXPLAYERS];
	
	GetCmdArg(1, sPlayer, sizeof(sPlayer));
	
	GetCmdArg(2, sArgs, sizeof(sArgs));
	int nAmount = StringToInt(sArgs);
	
	int nPlayerCount;
	int target_list[MAXPLAYERS];
	
	bool tn_is_ml;
	
	if ((nPlayerCount = ProcessTargetString(sPlayer, client, target_list, MAXPLAYERS, COMMAND_FILTER_CONNECTED, sPlayersName, sizeof(sPlayersName), tn_is_ml)) > 0) {
		for (int p = 0; p < nPlayerCount; p++) {
			g_aPlayers[target_list[p]].cash += nAmount;
			PrintToChat(client, "%s You added %d Zold to %s.", PREFIX, nAmount, g_aPlayers[target_list[p]].name);
			
			
			Call_StartForward(g_fwdOnCashUpdate);
			Call_PushCell(target_list[p]);
			Call_PushCell(g_aPlayers[target_list[p]].cash);
			Call_Finish();
		}
	}
	
	return Plugin_Handled;
}

public Action Command_Cash(int client, int args) {
	PrintToChat(client, "%s Your Zold balance: %d.", PREFIX, g_aPlayers[client].cash);
	return Plugin_Handled;
}

void prepareSQL() {
	char error[256];
	char query[256];
	
	g_dbDatabase = SQL_Connect(USED_SQL, true, error, sizeof(error));
	if (g_dbDatabase == INVALID_HANDLE)
	{
		SQL_GetError(g_dbDatabase, error, sizeof(error));
		SetFailState("Failed to connect to database: %s", error);
	} else {
		PrintToServer("Connected to database successfully");
		Format(query, sizeof(query), "CREATE TABLE IF NOT EXISTS %s (%s VARCHAR(64) NOT NULL PRIMARY KEY, %s TEXT NOT NULL, %s INT UNSIGNED NOT NULL);", TABLE_NAME, SQL_PLAYER_ID, SQL_PLAYER_NAME, SQL_PLAYER_CASH);
		g_dbDatabase.Query(SQL_CheckForErrors, query);
	}
}

public void SQL_CheckForErrors(Database database, DBResultSet result, const char[] error, any client) {
	if (!StrEqual(error, ""))
	{
		LogError("Databse error, %s", error);
		return;
	}
}

public void SQL_ReciveClientData(Database database, DBResultSet result, const char[] error, any client) {
	char clientID[32];
	char query[256];
	
	GetClientAuthId(client, AuthId_Steam2, clientID, sizeof(clientID));
	if (!SQL_FetchRow(result))
	{
		Format(query, sizeof(query), "INSERT INTO %s VALUES ('%s', '%N', '%s')", TABLE_NAME, clientID, client, PLAYER_DEFAULT_Cash);
		g_dbDatabase.Query(SQL_CheckForErrors, query, client);
		g_aPlayers[client].cash = PLAYER_DEFAULT_Cash;
	} else {
		g_aPlayers[client].cash = SQL_FetchInt(result, 0);
	}
}

char SQL_SecureString(char[] string) {
	char szEscaped[256];
	g_dbDatabase.Escape(string, szEscaped, sizeof(szEscaped));
	return szEscaped;
}
