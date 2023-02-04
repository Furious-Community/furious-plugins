# furious-plugins
The plugins which powered Furious servers.

Each plugin with details can be found with pages in the wiki for this repository.

# Installation Instructions

Install Sourcemod

    You can download the latest version of SourceMod from the official website: https://www.sourcemod.net/downloads.php.
    Follow the instructions provided on the website to install SourceMod on your server.

Install a Database

    Furious supports MySQL and SQLite. You can choose any one of these based on your requirements.
    For MySQL, you can install it using the official instructions available at https://dev.mysql.com/doc/refman/8.0/en/installing.html or through the Linux command line.
    For SQLite, it's built into Sourcemod by default when you install it.

Create a database for the plugin(s).

    Connect to your database server and create a new database for one/any of the plugin(s).
    Create a new database user and grant them access to the newly created database.

Configure SourceMod to connect to the database for one/any of the plugin(s) if necessary.

    Navigate to the "configs" folder in the SourceMod directory.
    Open the "databases.cfg" file in a text editor.
    Add the following code to the file, replacing the placeholder values of the database information for the plugin:

    "furious-placeholder"
    {
       "driver"           "mysql"
       "host"             "your-database-host"
       "database"         "your-database-name"
       "user"             "your-database-user"
       "pass"             "your-database-password"
       "port"             "3306"
    }

Download and install the SourceMod plugin(s).

    Download the plugin from this repository through this plugins folder.
    Place the plugin(s) in the "plugins" folder in the SourceMod directory.
    Start or restart the server to activate the plugin.

Verify if the plugin is working correctly.

    Connect to the server and check if the plugin is working as expected.
    You can also check the log files in the "logs" folder in the SourceMod directory to see if there are any errors.

That's it! You've successfully installed one or more of the plugin(s) on your server. Be sure to check the wiki for specific pages relating to each plugin for dependencies you might need and more specific instructions in-general.

Happy Surfing!
