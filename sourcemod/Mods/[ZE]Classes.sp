#pragma semicolon 1

#define DEBUG

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <zombiecore>
#include <zombieclasses>

#define PLUGIN_AUTHOR "TorNim0s"
#define PLUGIN_VERSION "1.00"
#define PLUGIN_URL "play-il.co.il"

#define PREFIX_MENU "[Play-IL]"
#define PREFIX " \x04[Play-IL]\x01"

#define DEFAULTZOMBIECLASS 0

#define MAX_ZOMBIE_CLASSES 32

#define HUMAN_TAG "Human"

#pragma newdecls required

enum struct ZombieClass {
	char unique[32];
	char name[64];
	char description[128];
	char model[256];
	int health;
	int hperplayer;
	float knockback;
}

int g_nZombiesCount = 0; // required in the struct

enum struct Player {
	char auth[32];
	char name[MAX_NAME_LENGTH];
	int zombieclass;
	
	void reset() {
		this.auth[0] = 0;
		this.name[0] = 0;
		
		this.zombieclass = DEFAULTZOMBIECLASS;
	}
}

ZombieClass g_aZombie[MAX_ZOMBIE_CLASSES];
Player g_aPlayers[MAXPLAYERS];

Handle g_hClassSelected = INVALID_HANDLE;

bool g_bLate = false;

public Plugin myinfo = 
{
	name = "[CSGO] ZombieEscape - Classes", 
	author = PLUGIN_AUTHOR, 
	description = "", 
	version = PLUGIN_VERSION, 
	url = PLUGIN_URL
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_zclass", Command_Class, "View the Zombies Classes menu");
	
	HookEvent("player_spawn", OnPlayerSpawn);
	
	if (g_bLate) {
		for (int nCurrentPlayer = 1; nCurrentPlayer <= MaxClients; nCurrentPlayer++) {
			if (IsClientInGame(nCurrentPlayer)) {
				OnClientPostAdminCheck(nCurrentPlayer);
			}
		}
	}
}

public Action OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if (ZE_IsZeEnabled()) {
		int nPlayerIndex = GetClientOfUserId(GetEventInt(event, "userid"));
		if (GetClientTeam(nPlayerIndex) == CS_TEAM_CT) {
			CS_SetClientClanTag(nPlayerIndex, HUMAN_TAG);
		}
		
		if (ZE_IsRoundStarted()) {
			if (GetClientTeam(nPlayerIndex) == CS_TEAM_T) {
				players_Fade(nPlayerIndex);
				CS_SetClientClanTag(nPlayerIndex, g_aZombie[g_aPlayers[nPlayerIndex].zombieclass].name);
				
				SetEntityModel(nPlayerIndex, g_aZombie[g_aPlayers[nPlayerIndex].zombieclass].model);
			}
		}
	}
}

public void ZE_OnNewZombieSpawn(int nPlayerIndex) {
	CS_SetClientClanTag(nPlayerIndex, g_aZombie[g_aPlayers[nPlayerIndex].zombieclass].name);
	SetEntityModel(nPlayerIndex, g_aZombie[g_aPlayers[nPlayerIndex].zombieclass].model);
}

public void OnClientPostAdminCheck(int client) {
	g_aPlayers[client].reset();
	if (!GetClientAuthId(client, AuthId_Steam2, g_aPlayers[client].auth, sizeof(g_aPlayers[].auth))) {
		KickClient(client, "Verification problem, please reconnect");
		return;
	}
	
	GetClientName(client, g_aPlayers[client].name, sizeof(g_aPlayers[].name));
}

/* Natives */

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	g_bLate = late;
	
	CreateNative("ZE_CreateClass", Native_CreateClass);
	CreateNative("ZE_IsPlayerClassEnabled", Native_IsPlayerClassEnabled);
	CreateNative("ZE_GetZombieKnockBack", Native_GetZombieKnockBack);
	CreateNative("ZE_GetZombieMaxHealth", Native_GetZombieMaxHealth);
	
	g_hClassSelected = CreateGlobalForward("ZE_OnClassSelected", ET_Event, Param_Cell, Param_Cell);
	
	RegPluginLibrary("[CSGO] ZombieEscape - Classes");
	return APLRes_Success;
}

public int Native_CreateClass(Handle plugin, int numParams) {
	GetNativeString(1, g_aZombie[g_nZombiesCount].unique, sizeof(g_aZombie[].unique));
	if (getClassId(g_aZombie[g_nZombiesCount].unique) != -1)
		return getClassId(g_aZombie[g_nZombiesCount].unique);
	
	GetNativeString(2, g_aZombie[g_nZombiesCount].name, sizeof(g_aZombie[].name));
	GetNativeString(3, g_aZombie[g_nZombiesCount].description, sizeof(g_aZombie[].description));
	GetNativeString(4, g_aZombie[g_nZombiesCount].model, sizeof(g_aZombie[].model));
	
	char sInfo[32];
	
	GetNativeString(5, sInfo, sizeof(sInfo));
	g_aZombie[g_nZombiesCount].health = StringToInt(sInfo);
	
	GetNativeString(6, sInfo, sizeof(sInfo));
	g_aZombie[g_nZombiesCount].hperplayer = StringToInt(sInfo);
	
	GetNativeString(7, sInfo, sizeof(sInfo));
	g_aZombie[g_nZombiesCount].knockback = StringToFloat(sInfo);
	
	g_nZombiesCount++;
	return g_nZombiesCount - 1;
}

public int Native_IsPlayerClassEnabled(Handle plugin, int numParams) {
	int nPlayerIndex = GetNativeCell(1);
	int nClassID = GetNativeCell(2);
	
	if (g_aPlayers[nPlayerIndex].zombieclass == nClassID) {
		return true;
	}
	return false;
}

public any Native_GetZombieKnockBack(Handle plugin, int numParams) {
	int nPlayerIndex = GetNativeCell(1);
	return g_aZombie[g_aPlayers[nPlayerIndex].zombieclass].knockback;
}

public int Native_GetZombieMaxHealth(Handle plugin, int numParams) {
	int nPlayerIndex = GetNativeCell(1);
	return (g_aZombie[g_aPlayers[nPlayerIndex].zombieclass].health + (GetClientCount() * g_aZombie[g_aPlayers[nPlayerIndex].zombieclass].hperplayer));
}

public Action Command_Class(int nPlayerIndex, int args) {
	if (!ZE_IsZeEnabled()) {
		PrintToChat(nPlayerIndex, "%s Zombie Escape is not enabled!", PREFIX);
		return Plugin_Handled;
	}
	Menus_ShowMain(nPlayerIndex);
	return Plugin_Handled;
}

void Menus_ShowMain(int nPlayerIndex) {
	Menu menu = new Menu(Handler_MainMenu);
	menu.SetTitle("%s Zombie Classes Menu\n ", PREFIX_MENU);
	
	for (int i = 0; i < g_nZombiesCount; i++) {
		char szName[128];
		Format(szName, sizeof(szName), "%s \n[%s]", g_aZombie[i].name, g_aZombie[i].description);
		
		menu.AddItem(g_aZombie[i].unique, szName, g_aPlayers[nPlayerIndex].zombieclass == i ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	}
	
	if (g_nZombiesCount <= 0)
		menu.AddItem("", "No classes were found.", ITEMDRAW_DISABLED);
	
	menu.ExitBackButton = true;
	menu.Display(nPlayerIndex, MENU_TIME_FOREVER);
}

public int Handler_MainMenu(Menu menu, MenuAction action, int nClient, int itemNum) {
	if (action == MenuAction_Select) {
		char szInfo[32];
		menu.GetItem(itemNum, szInfo, sizeof(szInfo));
		
		int nClass = getClassId(szInfo);
		
		g_aPlayers[nClient].zombieclass = nClass;
		
		Call_StartForward(g_hClassSelected);
		Call_PushCell(nClient);
		Call_PushCell(nClass);
		Call_Finish();
		
		makeLog("Player %N has switched to %s zombie class", nClient, g_aZombie[nClass].name);
		PrintToChat(nClient, "%s You have switched to \x02%s\x01 zombie class", PREFIX, g_aZombie[nClass].name);
	}
}

int getClassId(char[] unique) {
	int id = -1;
	for (int nCurrentClass = 0; nCurrentClass < g_nZombiesCount && id == -1; nCurrentClass++) {
		if (!strcmp(g_aZombie[nCurrentClass].unique, unique)) {
			id = nCurrentClass;
		}
	}
	return id;
}

void makeLog(char[] buffer, any...) {
	char szBuffer[1024];
	VFormat(szBuffer, sizeof(szBuffer), buffer, 2);
	
	static char szPath[128];
	if (strlen(szPath) < 1) {
		char szFile[64];
		
		Handle hPlugin = GetMyHandle();
		GetPluginFilename(hPlugin, szFile, sizeof(szFile));
		ReplaceString(szFile, sizeof(szFile), ".smx", "");
		CloseHandle(hPlugin);
		
		FormatTime(szPath, sizeof(szPath), "%Y%m%d", GetTime());
		BuildPath(Path_SM, szPath, sizeof(szPath), "logs/%s_%s.log", szFile, szPath);
	}
	
	LogToFile(szPath, szBuffer);
}

void players_Fade(int clientIndex, int duration = 750, int hold = 50, int flags = 0x0009, int color[4] =  { 255, 0, 0, 255 } )
{
	Handle hFade = StartMessageOne("Fade", clientIndex, USERMSG_RELIABLE);
	PbSetInt(hFade, "duration", duration);
	PbSetInt(hFade, "hold_time", hold);
	PbSetInt(hFade, "flags", flags);
	PbSetColor(hFade, "clr", color);
	EndMessage();
	
	Handle hShake = StartMessageOne("Shake", clientIndex, 1);
	PbSetInt(hShake, "command", 0);
	PbSetFloat(hShake, "local_amplitude", 2.5);
	PbSetFloat(hShake, "frequency", 255.0);
	PbSetFloat(hShake, "duration", 5.0);
	EndMessage();
}


// if useing SQL

/*
char SQL_SecureString(char[] string) {
	char szEscaped[256];
	g_dbDatabase.Escape(string, szEscaped, sizeof(szEscaped));
	return szEscaped;
} 
*/