/*
**
*/
#if defined _ZombieEscapeCash_included
#endinput
#endif
#define _ZombieEscapeCash_included

native int GetCash(int client);
native int SetCash(int client, int nCash);

forward void Cash_OnCashUpdate(int client, int cash);

#if !defined REQUIRE_PLUGIN
public __pl_ZombieEscapeCash_SetNTVOptional()
{
	MarkNativeAsOptional("GetCash");
	MarkNativeAsOptional("SetCash");
}
#endif

public SharedPlugin __pl_ZombieEscapeCash = 
{
	name = "[CSGO] ZombieEscape - Zold", 
	file = "[ZE]Shop_Cash.smx", 
	#if defined REQUIRE_PLUGIN
	required = 1, 
	#else
	required = 0, 
	#endif
};
