#if defined _furious_notifications_included
 #endinput
#endif
#define _furious_notifications_included

native Furious_Notifications_AddNew(char[] server_type, char[] server_target, char[] user_type, char[] user_target, char[] message_title, char[] message_body, bool automatic_spaces = false);
native Furious_Notifications_RefreshClient(int client);

#if !defined REQUIRE_PLUGIN
public void __pl_player_news_SetNTVOptional()
{
	MarkNativeAsOptional("Furious_Notifications_AddNew");
}
#endif

public SharedPlugin __pl_player_notifications =
{
	name = "furious_notifications",
	file = "furious-notifications.smx",
	#if defined REQUIRE_PLUGIN
	required = 1,
	#else
	required = 0,
	#endif
};
