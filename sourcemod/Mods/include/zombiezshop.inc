/*
**
*/
#if defined _ZombieEscapeZShop_included
#endinput
#endif
#define _ZombieEscapeZShop_included

native int ZShop_CreateItem(char[] unique, char[] name, char[] description, char[] itemtag, char[] price, char[] vip);

forward void ZShop_OnItemSelected(int client, int item);

#if !defined REQUIRE_PLUGIN
public __pl_ZombieEscapeZShop_SetNTVOptional()
{
	MarkNativeAsOptional("ZShop_CreateItem");
}
#endif

public SharedPlugin __pl_ZombieEscapeZShop = 
{
	name = "[CSGO] ZombieEscape - ZShop", 
	file = "[ZE]ZShop.smx", 
	#if defined REQUIRE_PLUGIN
	required = 1, 
	#else
	required = 0, 
	#endif
};
