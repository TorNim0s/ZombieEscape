#pragma semicolon 1

#define DEBUG

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <zombiecore>
#include <zombiecash>
#include <zombievip>
#include <zombiezshop>

#define PLUGIN_AUTHOR "TorNim0s"
#define PLUGIN_VERSION "1.00"
#define PLUGIN_URL "play-il.co.il"

#define PREFIX_MENU "[Play-IL]"
#define PREFIX " \x04[Play-IL]\x01"

#define MAX_ITEMS 32

#pragma newdecls required

enum struct Shop {
	char unique[32];
	char name[64];
	char description[128];
	char itemtag[64];
	int price;
	int vip;
}

enum struct Player {
	char auth[32];
	char name[MAX_NAME_LENGTH];
	int cash;
	
	void reset() {
		this.auth[0] = 0;
		this.name[0] = 0;
		this.cash = 0;
	}
}

Shop g_aShop[MAX_ITEMS];
Player g_aPlayers[MAXPLAYERS];

int g_nItemCount = 0; // required in the struct

GlobalForward g_fwdItemSelected;

bool g_bLate = false;

public Plugin myinfo = 
{
	name = "[CSGO] ZombieEscape - ZShop", 
	author = PLUGIN_AUTHOR, 
	description = "", 
	version = PLUGIN_VERSION, 
	url = PLUGIN_URL
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_zshop", Command_Shop, "View the shop menu");
	
	if (g_bLate) {
		for (int nCurrentPlayer = 1; nCurrentPlayer <= MaxClients; nCurrentPlayer++) {
			if (IsClientInGame(nCurrentPlayer)) {
				OnClientPostAdminCheck(nCurrentPlayer);
			}
		}
	}
	
	HookEvent("player_connect_full", Event_PlayerConnectFull, EventHookMode_Post);
}

public Action Event_PlayerConnectFull(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	g_aPlayers[client].cash = GetCash(client);
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
	
	CreateNative("ZShop_CreateItem", Native_CreateItem);
	
	g_fwdItemSelected = CreateGlobalForward("ZShop_OnItemSelected", ET_Event, Param_Cell, Param_Cell);
	
	RegPluginLibrary("[CSGO] ZombieEscape - ZShop");
	return APLRes_Success;
}

public int Native_CreateItem(Handle plugin, int numParams) {
	GetNativeString(1, g_aShop[g_nItemCount].unique, sizeof(g_aShop[].unique));
	if (getItemId(g_aShop[g_nItemCount].unique) != -1)
		return getItemId(g_aShop[g_nItemCount].unique);
	
	GetNativeString(2, g_aShop[g_nItemCount].name, sizeof(g_aShop[].name));
	GetNativeString(3, g_aShop[g_nItemCount].description, sizeof(g_aShop[].description));
	GetNativeString(4, g_aShop[g_nItemCount].itemtag, sizeof(g_aShop[].itemtag));
	
	char sInfo[32];
	
	GetNativeString(5, sInfo, sizeof(sInfo));
	g_aShop[g_nItemCount].price = StringToInt(sInfo);
	
	GetNativeString(6, sInfo, sizeof(sInfo));
	g_aShop[g_nItemCount].vip = StringToInt(sInfo);
	
	g_nItemCount++;
	return g_nItemCount - 1;
}


public void Cash_OnCashUpdate(int nPlayerIndex, int nCash) {
	g_aPlayers[nPlayerIndex].cash = nCash;
}

public Action Command_Shop(int nPlayerIndex, int args) {
	if (!ZE_IsZeEnabled()) {
		PrintToChat(nPlayerIndex, "%s Zombie Escape is not enabled!", PREFIX);
		return Plugin_Handled;
	}
	
	if (GetClientTeam(nPlayerIndex) == CS_TEAM_T) {
		return Plugin_Handled;
	}
	
	Menus_ShowMain(nPlayerIndex);
	return Plugin_Handled;
}

void Menus_ShowMain(int nPlayerIndex) {
	Menu menu = new Menu(Handler_MainMenu);
	menu.SetTitle("%s Zombie Escape - Shop \nBalance: %s Zold", PREFIX_MENU, addCommas(g_aPlayers[nPlayerIndex].cash));
	
	for (int i = 0; i < g_nItemCount; i++) {
		char szName[128];
		if (g_aShop[i].vip > 0) {
			if (VIP_CheckClientVip(nPlayerIndex)) {
				Format(szName, sizeof(szName), "%s [%s Zold]", g_aShop[i].name, addCommas(g_aShop[i].price));
				
				menu.AddItem(g_aShop[i].unique, szName);
			}
			continue;		
		}
		
		Format(szName, sizeof(szName), "%s [%s Zold]", g_aShop[i].name, addCommas(g_aShop[i].price));
		
		menu.AddItem(g_aShop[i].unique, szName);
	}
	
	if (g_nItemCount <= 0)
		menu.AddItem("", "No Items were found.", ITEMDRAW_DISABLED);
	
	menu.ExitBackButton = true;
	menu.Display(nPlayerIndex, MENU_TIME_FOREVER);
}

public int Handler_MainMenu(Menu menu, MenuAction action, int nClient, int itemNum) {
	if (action == MenuAction_Select) {
		
		if (GetClientTeam(nClient) == CS_TEAM_T) {
			return;
		}
		
		char szInfo[32];
		menu.GetItem(itemNum, szInfo, sizeof(szInfo));
		
		int nItem = getItemId(szInfo);
		
		if (g_aPlayers[nClient].cash - g_aShop[nItem].price >= 0) {
			
			g_aPlayers[nClient].cash -= g_aShop[nItem].price;
			SetCash(nClient, g_aPlayers[nClient].cash);
			
			Call_StartForward(g_fwdItemSelected);
			Call_PushCell(nClient);
			Call_PushCell(nItem);
			Call_Finish();
			
			makeLog("Player %N has bought %s for the price of %d Zold", nClient, g_aShop[nItem].name, g_aShop[nItem].price);
			PrintToChat(nClient, "%s You have purchased \x02%s\x01", PREFIX, g_aShop[nItem].name);
		}
		else {
			PrintToChat(nClient, "%s You don't have enough money (missing %d Zold)", PREFIX, (g_aShop[nItem].price - g_aPlayers[nClient].cash));
		}
	}
}

int getItemId(char[] unique) {
	int id = -1;
	for (int nCurrentItem = 0; nCurrentItem < g_nItemCount && id == -1; nCurrentItem++) {
		if (!strcmp(g_aShop[nCurrentItem].unique, unique)) {
			id = nCurrentItem;
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


char addCommas(int value, const char[] seperator = ",") {
	char buffer[MAX_NAME_LENGTH];
	buffer[0] = 0;
	
	int divisor = 1000;
	while (value >= 1000 || value <= -1000) {
		int offcut = value % divisor;
		value = RoundToFloor(float(value) / float(divisor));
		Format(buffer, MAX_NAME_LENGTH, "%c%03.d%s", seperator, offcut, buffer);
	}
	
	Format(buffer, MAX_NAME_LENGTH, "%d%s", value, buffer);
	return buffer;
} 