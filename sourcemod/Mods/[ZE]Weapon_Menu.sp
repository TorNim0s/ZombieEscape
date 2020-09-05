#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "TorNim0s"
#define PLUGIN_VERSION "1.00"
#define PLUGIN_URL "play-il.co.il"

#define PREFIX " \x04[Play-IL Zombie Escape]\x01"
#define MENU_PREFIX "[Play-IL Zombie Escape]"

#define DEFAULT_WEAPON_INDEX 0
#define MENU_EVENT_DELIMITER "-"

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <sdkhooks>
#include <zombiecore>

#pragma newdecls required

enum struct Player {
	int primaryindex;
	int secondaryindex;
	bool firstimeweapon;
	
	void reset() {
		this.primaryindex = DEFAULT_WEAPON_INDEX;
		this.secondaryindex = DEFAULT_WEAPON_INDEX;
		this.firstimeweapon = true;
	}
}

char g_sPrimaryWeaponTags[][] =  { "Negev", "M249", "PP-Bizon", "P-90", "Scar-20", "G3SG1", "M4A4", "M4A1-S", "AK-47", "AUG", "SG 553", "Galil AR", "FAMAS", 
	"AWP", "UMP-45", "MP7", "MP9", "Mac-10", "Nova", "XM1014", "Sawed-Off", "Mag-7", "SSG 08" };

char g_sPrimaryWeapon[][] =  { "weapon_negev", "weapon_m249", "weapon_bizon", "weapon_p90", "weapon_scar20", "weapon_g3sg1", "weapon_m4a1", "weapon_m4a1_silencer", "weapon_ak47", 
	"weapon_aug", "weapon_sg556", "weapon_galilar", "weapon_famas", "weapon_awp", "weapon_ump45", "weapon_mp7", "weapon_mp9", "weapon_mac10", "weapon_nova", "weapon_xm1014", 
	"weapon_sawedoff", "weapon_mag7", "weapon_ssg08" };

char g_sSecondaryWeaponTags[][] =  { "Glock-18", "P250", "CZ75-A", "USP-S", "Five-SeveN", "Desert Eagle", "R8", "Dual Berettas", "Tec-9", "P2000" };
char g_sSecondaryWeapon[][] =  { "weapon_glock", "weapon_p250", "weapon_cz75a", "weapon_usp_silencer", "weapon_fiveseven", "weapon_deagle", "weapon_revolver", "weapon_elite", "weapon_tec9", "weapon_hkp2000" };

Player g_aPlayers[MAXPLAYERS];

public Plugin myinfo = 
{
	name = "[CSGO] ZombieEscape - WeaponMenu", 
	author = PLUGIN_AUTHOR, 
	description = "Zombie Escape for CS:GO", 
	version = PLUGIN_VERSION, 
	url = PLUGIN_URL
};


public void OnPluginStart()
{
	RegConsoleCmd("sm_guns", Command_Guns);
	
	HookEvent("player_spawn", OnPlayerSpawn);
}


public void OnClientPostAdminCheck(int client) {
	g_aPlayers[client].reset();
}

public Action OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
	if (ZE_IsZeEnabled()) {
		int nPlayerIndex = GetClientOfUserId(GetEventInt(event, "userid"));
		if (GetClientTeam(nPlayerIndex) == CS_TEAM_CT) {
			if (IsClientInGame(nPlayerIndex) && IsPlayerAlive(nPlayerIndex))
			{
				if (g_aPlayers[nPlayerIndex].firstimeweapon) {
					openWeaponSelect(nPlayerIndex, DEFAULT_WEAPON_INDEX, DEFAULT_WEAPON_INDEX);
				}
				else {
					giveWeaponToPlayer(nPlayerIndex, g_aPlayers[nPlayerIndex].primaryindex, g_aPlayers[nPlayerIndex].secondaryindex);
				}
			}
		}
	}
}

void disarmTarget(int target)
{
	for (int currentWeapon = 0; currentWeapon <= 5; currentWeapon++)
	{
		int targetWeapon = GetPlayerWeaponSlot(target, currentWeapon);
		if (IsValidEntity(targetWeapon))
			RemovePlayerItem(target, targetWeapon);
	}
}

public Action Command_Guns(int client, int args) {
	if (GetClientTeam(client) == CS_TEAM_CT) {
		openWeaponSelect(client, DEFAULT_WEAPON_INDEX, DEFAULT_WEAPON_INDEX);
	}
	
	return Plugin_Handled;
}

void openWeaponSelect(int client, int nPrimaryIndex, int nSecondryIndex) {
	char sItem[64];
	char sItemInfo[32];
	
	Menu eventMenu = new Menu(MenuHandle_Weapons);
	
	eventMenu.SetTitle("%s - Weapon Chooser\n \n", MENU_PREFIX);
	
	Format(sItemInfo, sizeof(sItemInfo), "%d%s%d", nPrimaryIndex, MENU_EVENT_DELIMITER, nSecondryIndex);
	
	Format(sItem, sizeof(sItem), "Select primary weapon \nCurrent primary weapon: %s \n", g_sPrimaryWeaponTags[nPrimaryIndex]);
	eventMenu.AddItem(sItemInfo, sItem);
	
	Format(sItem, sizeof(sItem), "Select secondary weapon \nCurrent secondary weapon: %s \n", g_sSecondaryWeaponTags[nSecondryIndex]);
	eventMenu.AddItem(sItemInfo, sItem);
	
	Format(sItem, sizeof(sItem), "Random Guns \n \n \n");
	eventMenu.AddItem(sItemInfo, sItem);
	
	eventMenu.AddItem(sItemInfo, "Collect Selected Weapons");
	
	eventMenu.ExitBackButton = true;
	eventMenu.Display(client, 20);
}

int MenuHandle_Weapons(Menu menu, MenuAction action, int client, int position) {
	if (action == MenuAction_Select)
	{
		char sItemInfo[32];
		menu.GetItem(position, sItemInfo, sizeof(sItemInfo));
		char infoExploded[32][32];
		ExplodeString(sItemInfo, MENU_EVENT_DELIMITER, infoExploded, sizeof(infoExploded), sizeof(infoExploded[]));
		
		int nPrimaryIndex = StringToInt(infoExploded[0]);
		int nSecondryIndex = StringToInt(infoExploded[1]);
		switch (position)
		{
			case 0:
			{
				openPrimarySelect(client, nSecondryIndex);
			}
			case 1:
			{
				openSecondarySelect(client, nPrimaryIndex);
			}
			case 2:
			{
				int nRandomPrimary = GetRandomInt(0, sizeof(g_sPrimaryWeapon) - 1);
				int nRandomSecondry = GetRandomInt(0, sizeof(g_sSecondaryWeapon) - 1);
				
				giveWeaponToPlayer(client, nRandomPrimary, nRandomSecondry);
				g_aPlayers[client].primaryindex = nRandomPrimary;
				g_aPlayers[client].secondaryindex = nRandomSecondry;
				g_aPlayers[client].firstimeweapon = false;
			}
			case 3:
			{
				giveWeaponToPlayer(client, nPrimaryIndex, nSecondryIndex);
				g_aPlayers[client].primaryindex = nPrimaryIndex;
				g_aPlayers[client].secondaryindex = nSecondryIndex;
				g_aPlayers[client].firstimeweapon = false;
			}
		}
	}
	
	if (action == MenuAction_Cancel) {
		g_aPlayers[client].primaryindex = DEFAULT_WEAPON_INDEX;
		g_aPlayers[client].secondaryindex = DEFAULT_WEAPON_INDEX;
		g_aPlayers[client].firstimeweapon = false;
		giveWeaponToPlayer(client, DEFAULT_WEAPON_INDEX, DEFAULT_WEAPON_INDEX);
	}
}

void openPrimarySelect(int client, int nSecondryIndex) {
	
	char sItemInfo[32];
	
	Menu weaponMenu = new Menu(MenuHandle_PrimaryWeapon);
	weaponMenu.SetTitle("%s Select your primary weapon\n \n", MENU_PREFIX);
	
	for (int nCurrentPrimaryIndex = 0; nCurrentPrimaryIndex < sizeof(g_sPrimaryWeaponTags); nCurrentPrimaryIndex++) {
		IntToString(nSecondryIndex, sItemInfo, sizeof(sItemInfo));
		weaponMenu.AddItem(sItemInfo, g_sPrimaryWeaponTags[nCurrentPrimaryIndex]);
	}
	
	weaponMenu.ExitBackButton = true;
	weaponMenu.Display(client, 20); // MENU_TIME_FOREVER
}

int MenuHandle_PrimaryWeapon(Menu menu, MenuAction action, int client, int position)
{
	if (action == MenuAction_Select)
	{
		char sItemInfo[32];
		
		menu.GetItem(position, sItemInfo, sizeof(sItemInfo));
		
		openWeaponSelect(client, position, StringToInt(sItemInfo));
	}
}

void openSecondarySelect(int client, int nPrimaryIndex) {
	
	char sItemInfo[32];
	
	Menu mSecondaryWeapon = new Menu(MenuHandle_SecondaryWeapon);
	mSecondaryWeapon.SetTitle("%s Select your secondary weapon\n \n", MENU_PREFIX);
	
	for (int nCurrentSecondaryIndex = 0; nCurrentSecondaryIndex < sizeof(g_sSecondaryWeaponTags); nCurrentSecondaryIndex++) {
		IntToString(nPrimaryIndex, sItemInfo, sizeof(sItemInfo));
		mSecondaryWeapon.AddItem(sItemInfo, g_sSecondaryWeaponTags[nCurrentSecondaryIndex]);
	}
	
	mSecondaryWeapon.ExitBackButton = true;
	mSecondaryWeapon.Display(client, 20);
}

int MenuHandle_SecondaryWeapon(Menu menu, MenuAction action, int client, int position)
{
	if (action == MenuAction_Select)
	{
		char sItemInfo[32];
		
		menu.GetItem(position, sItemInfo, sizeof(sItemInfo));
		
		openWeaponSelect(client, StringToInt(sItemInfo), position);
	}
}

void giveWeaponToPlayer(int client, int nPrimaryIndex, int nSecondryIndex) {
	if (IsClientInGame(client)) {
		disarmTarget(client);
		
		int nPrimaryWeaponEntity;
		int nSecondaryWeaponEntity;
		
		nPrimaryWeaponEntity = GivePlayerItem(client, g_sPrimaryWeapon[nPrimaryIndex]);
		nSecondaryWeaponEntity = GivePlayerItem(client, g_sSecondaryWeapon[nSecondryIndex]);
		
		GivePlayerItem(client, "weapon_knife");
		
		SetEntProp(nPrimaryWeaponEntity, Prop_Send, "m_iPrimaryReserveAmmoCount", 1000);
		SetEntProp(nSecondaryWeaponEntity, Prop_Send, "m_iPrimaryReserveAmmoCount", 1000);
		
		if (ZE_IsRoundStarted()) {
			SetEntProp(nPrimaryWeaponEntity, Prop_Send, "m_iClip1", 0);
			SetEntProp(nSecondaryWeaponEntity, Prop_Send, "m_iClip1", 0);
		}
	}
} 