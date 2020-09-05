/*
**
*/
#if defined _ZombieEscapeVip_included
#endinput
#endif
#define _ZombieEscapeVip_included

native bool VIP_CheckClientVip(int client);

#if !defined REQUIRE_PLUGIN
public __pl_ZombieEscapeVip_SetNTVOptional()
{
	MarkNativeAsOptional("VIP_CheckClientVip");
}
#endif

public SharedPlugin __pl_ZombieEscapeVip = 
{
	name = "[CSGO] ZombieEscape - VIP", 
	file = "[ZE]Shop_Vip.smx", 
	#if defined REQUIRE_PLUGIN
	required = 1, 
	#else
	required = 0, 
	#endif
};
