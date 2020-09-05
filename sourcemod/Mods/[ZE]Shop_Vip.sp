#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "TorNim0s"
#define PLUGIN_VERSION "1.00"
#define PLUGIN_URL "play-il.co.il"

#include <sourcemod>
#include <sdktools>
#include <zombievip>

#define PREFIX " \x04[Play-IL]\x01"
#define PREFIX_MENU "[Play-IL]"

#pragma newdecls required

Database g_dbDatabase;

#define DATABASE_ENTRY "csgo_zombie"

enum struct Player {
	char auth[32];
	char name[MAX_NAME_LENGTH];
	int vipendtime;
	
	void reset() {
		this.auth[0] = 0;
		this.name[0] = 0;
		this.vipendtime = 0;
	}
}

Player g_aPlayers[MAXPLAYERS];

bool g_bLate = false;

public Plugin myinfo = 
{
	name = "[CSGO] ZombieEscape - VIP", 
	author = PLUGIN_AUTHOR, 
	description = "Zombie Escape for CS:GO", 
	version = PLUGIN_VERSION, 
	url = PLUGIN_URL
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_vip", Command_VIP);
	RegAdminCmd("sm_givevip", Commad_GiveVIP, ADMFLAG_ROOT);
	SQL_MakeConnection();
	
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
	
	CreateNative("VIP_CheckClientVip", Native_CheckClientVip);
	
	RegPluginLibrary("[CSGO] ZombieEscape - VIP");
	return APLRes_Success;
}

public void OnClientPostAdminCheck(int nPlayerIndex) {
	g_aPlayers[nPlayerIndex].reset();
	if (!GetClientAuthId(nPlayerIndex, AuthId_Steam2, g_aPlayers[nPlayerIndex].auth, sizeof(g_aPlayers[].auth))) {
		KickClient(nPlayerIndex, "Verification problem, please reconnect");
		return;
	}
	
	GetClientName(nPlayerIndex, g_aPlayers[nPlayerIndex].name, sizeof(g_aPlayers[].name));
	strcopy(g_aPlayers[nPlayerIndex].name, sizeof(g_aPlayers[].name), SQL_SecureString(g_aPlayers[nPlayerIndex].name));
	
	SQL_FetchUser(nPlayerIndex);
}

public void OnClientDisconnect(int nPlayerIndex) {
	SQL_FetchDisUser(nPlayerIndex);
}

/*
 ------   Native  -------
*/

public int Native_CheckClientVip(Handle plugin, int numParams) {
	int nPlayerIndex = GetNativeCell(1);
	if (checkPlayerVip(nPlayerIndex) > 0) {
		return true;
	}
	return false;
}

/*
 ----------------------------
*/

int checkPlayerVip(int nPlayerIndex) {
	int nTimeleft = g_aPlayers[nPlayerIndex].vipendtime - GetTime();
	if (nTimeleft > 0) {
		return nTimeleft;
	}
	return -1;
}

public Action Commad_GiveVIP(int client, int args) {
	if (args < 2) {
		PrintToChat(client, "[SM] Usage sm_givevip <client> <hours>");
		return Plugin_Handled;
	}
	
	char sPlayer[32];
	char sPlayersName[MAXPLAYERS];
	
	GetCmdArg(1, sPlayer, sizeof(sPlayer));
	
	char sTimeVip[32];
	GetCmdArg(2, sTimeVip, sizeof(sTimeVip));
	
	int nPlayerCount;
	int target_list[MAXPLAYERS];
	
	bool tn_is_ml;
	
	if ((nPlayerCount = ProcessTargetString(sPlayer, client, target_list, MAXPLAYERS, COMMAND_FILTER_CONNECTED, sPlayersName, sizeof(sPlayersName), tn_is_ml)) > 0) {
		for (int p = 0; p < nPlayerCount; p++) {
			givePlayerVIP(client, target_list[p], StringToInt(sTimeVip));
		}
	}
	return Plugin_Handled;
}

void givePlayerVIP(int nAdminIndex, int nPlayerIndex, int nHours) {
	g_aPlayers[nPlayerIndex].vipendtime = GetTime() + nHours * 3600;
	PrintToChat(nAdminIndex, "%s Player %N Got Vip for %d hours", PREFIX, nPlayerIndex, nHours);
}

public Action Command_VIP(int nPlayerIndex, int args) {
	int nVipTimeleft = checkPlayerVip(nPlayerIndex);
	if (nVipTimeleft <= 0) {
		PrintToChat(nPlayerIndex, "%s You dont have VIP", PREFIX);
		return;
	}
	
	startVipMenu(nPlayerIndex, nVipTimeleft);
	
}

void startVipMenu(int nPlayerIndex, int nTimeLeft) {
	Menus_ShowMain(nPlayerIndex, nTimeLeft);
}

void Menus_ShowMain(int nPlayerIndex, int nTimeLeft) {
	Menu menu = new Menu(Handler_MainMenu);
	int nHour = RoundToFloor((float(nTimeLeft) / 86400.0) * 24.0) % 24;
	int nMin = (RoundToFloor((float(nTimeLeft) / 86400.0) * 1440.0) % 1440) / (nHour + 1);
	
	menu.SetTitle("%s Vip - Main Menu \nVIP Time Left: \n%d Days \n%d Hours \n%d Minutes", PREFIX_MENU, nTimeLeft / 86400, nHour , nMin);
	
	menu.AddItem("", "", ITEMDRAW_NOTEXT);
	
	menu.Display(nPlayerIndex, 10);
}

public int Handler_MainMenu(Menu menu, MenuAction action, int nClient, int itemNum) {
	if (action == MenuAction_Select) {
		//
	}
}

void SQL_MakeConnection() {
	if (g_dbDatabase != null)
		delete g_dbDatabase;
	
	char szError[512];
	g_dbDatabase = SQL_Connect(DATABASE_ENTRY, true, szError, sizeof(szError));
	if (g_dbDatabase == null)
		SetFailState("Cannot connect to database error: %s", szError);
	
	g_dbDatabase.Query(SQL_CheckForErrors, "CREATE TABLE IF NOT EXISTS `shop_vip` (`auth` VARCHAR(32) NOT NULL PRIMARY KEY, `name` TEXT NOT NULL, `expiredtime` VARCHAR(32) NOT NULL)");
}

void SQL_FetchUser(int client) {
	char szQuery[512];
	FormatEx(szQuery, sizeof(szQuery), "SELECT `expiredtime` FROM `shop_vip` WHERE `auth` = '%s'", g_aPlayers[client].auth);
	g_dbDatabase.Query(SQL_FetchUser_CB, szQuery, GetClientSerial(client));
}

public void SQL_FetchUser_CB(Database db, DBResultSet results, const char[] error, any data) {
	if (!StrEqual(error, "")) {
		LogError("Databse error, %s", error);
		return;
	}
	
	int nClient = GetClientFromSerial(data);
	
	if (results.FetchRow()) {
		char sItemInfo[64];
		results.FetchString(0, sItemInfo, sizeof(sItemInfo));
		g_aPlayers[nClient].vipendtime = StringToInt(sItemInfo);
	}
	else {
		g_aPlayers[nClient].vipendtime = 0;
		
		char szQuery[512];
		
		FormatEx(szQuery, sizeof(szQuery), "INSERT INTO `shop_vip` VALUES ('%s', '%s', '%d')", g_aPlayers[nClient].auth, g_aPlayers[nClient].name, g_aPlayers[nClient].vipendtime);
		g_dbDatabase.Query(SQL_CheckForErrors, szQuery, GetClientSerial(nClient));
	}
}

void SQL_FetchDisUser(int client) {
	char szQuery[512];
	
	FormatEx(szQuery, sizeof(szQuery), "UPDATE `shop_vip` SET `expiredtime` = '%d' WHERE `auth` = '%s'", g_aPlayers[client].vipendtime, g_aPlayers[client].auth);
	g_dbDatabase.Query(SQL_CheckForErrors, szQuery, GetClientSerial(client));
}


public void SQL_CheckForErrors(Database database, DBResultSet result, const char[] error, any client) {
	if (!StrEqual(error, ""))
	{
		LogError("Databse error, %s", error);
		return;
	}
}

char SQL_SecureString(char[] string) {
	char szEscaped[256];
	g_dbDatabase.Escape(string, szEscaped, sizeof(szEscaped));
	return szEscaped;
}
