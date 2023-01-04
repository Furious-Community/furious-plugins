#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>

public Plugin myinfo = 
{
	name = "[Furious] Command list", 
	author = "FrAgOrDiE", 
	description = "", 
	version = "1.0", 
	url = "furious-clan.com"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_commands", Command_Commands, "List available commands");
}

public Action Command_Commands(int client, int args)
{
	ShowMainMenu(client);
	return Plugin_Handled;
}

public int MH_Main(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 1:
				{
					ShowCategory1Menu(param1);
				}
				case 2:
				{
					
				}
			}
		}
		case MenuAction_End:delete menu;
	}

	return 0;
}

public int MH_Category1(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 1:
				{
					Menu menu2 = new Menu(MH_Category1CommandOne);
					menu2.ExitBackButton = true;
					menu2.SetTitle("Furious commands\n -Menu One - Command One\n \n!command\n \nDescription");
					menu2.AddItem("", "spacer", ITEMDRAW_SPACER);
					menu2.Display(param1, MENU_TIME_FOREVER);
				}
				case 2:
				{
					
				}
			}
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				ShowMainMenu(param1);
			}
		}
		case MenuAction_End:delete menu;
	}

	return 0;
}

public int MH_Category1CommandOne(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				ShowCategory1Menu(param1);
			}
		}
		case MenuAction_End:delete menu;
	}

	return 0;
}

void ShowCategory1Menu(int client)
{
	Menu menu = new Menu(MH_Category1);
	menu.ExitBackButton = true;
	menu.SetTitle("Furious commands\n -Menu One");
	menu.AddItem("", "spacer", ITEMDRAW_SPACER);
	menu.AddItem("", "Command One");
	menu.AddItem("", "Command Two");
	menu.Display(client, MENU_TIME_FOREVER);
}

void ShowMainMenu(int client)
{
	Menu menu = new Menu(MH_Main);
	menu.SetTitle("Furious commands");
	menu.AddItem("", "spacer", ITEMDRAW_SPACER);
	menu.AddItem("", "Menu One");
	menu.AddItem("", "Menu Two");
	menu.Display(client, MENU_TIME_FOREVER);
}