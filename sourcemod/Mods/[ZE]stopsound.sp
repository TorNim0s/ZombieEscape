#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR ""
#define PLUGIN_VERSION "0.00"

#include <sourcemod>
#include <sdktools>
#include <clientprefs>

#define PREFIX " \x04[Play-IL]\x01"

#pragma newdecls required

bool g_bDisablePlayerSound[MAXPLAYERS];

public Plugin myinfo = 
{
	name = "", 
	author = PLUGIN_AUTHOR, 
	description = "", 
	version = PLUGIN_VERSION, 
	url = ""
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_stopmusic", Command_StopMusic);
	AddAmbientSoundHook(AmbientSoundHook);
}

public Action AmbientSoundHook(char sample[PLATFORM_MAX_PATH], int &entity, float &volume, int &level, int &pitch, float pos[3], int &flags, float &delay)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (g_bDisablePlayerSound[i] && IsClientConnected(i) && IsClientInGame(i))
		{
			ClientCommand(i, "snd_playsounds Music.StopAllExceptMusic");
		}
	}
	
	return Plugin_Continue;
}

public Action Command_StopMusic(int client, int args)
{
	checkPlayerSound(client);
}

void checkPlayerSound(int client) {
	g_bDisablePlayerSound[client] = !g_bDisablePlayerSound[client];
	if (g_bDisablePlayerSound[client])
	{
		ClientCommand(client, "snd_playsounds Music.StopAllExceptMusic");
	}
	PrintToChat(client, "%s Map music is now %s", PREFIX, g_bDisablePlayerSound[client] ? "\x02Off\x01":"\x04ON\x01");
	return;
} 