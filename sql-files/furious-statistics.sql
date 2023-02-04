CREATE TABLE `furious_global_server_data` (
	`id` int(12) NOT NULL AUTO_INCREMENT,
	`hostname` varchar(128) NOT NULL DEFAULT '',
	`ip` varchar(64) NOT NULL DEFAULT '',
	`season_number` int(12) NOT NULL DEFAULT 0,
	`next_season` int(12) NOT NULL DEFAULT 0,
	`first_created` int(12) NOT NULL,
	`last_updated` int(12) NOT NULL,
	PRIMARY KEY (`id`),
	UNIQUE KEY `id` (`id`),
	UNIQUE KEY `ip` (`ip`))
	ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 DEFAULT COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `furious_global_statistics` (
	`id` int(12) NOT NULL AUTO_INCREMENT,
	`name` varchar(64) NOT NULL DEFAULT '',
	`accountid` int(32) NOT NULL DEFAULT 0,
	`steamid2` varchar(64) NOT NULL DEFAULT '',
	`steamid3` varchar(64) NOT NULL DEFAULT '',
	`steamid64` varchar(64) NOT NULL DEFAULT '',
	`ip` varchar(64) NOT NULL DEFAULT '',
	`country` varchar(45) NOT NULL DEFAULT '',
	`clan_tag` varchar(32) NOT NULL DEFAULT '',
	`clan_name` varchar(32) NOT NULL DEFAULT '',
	`credits` int(12) NOT NULL DEFAULT 0,
	`credits_earned` int(12) NOT NULL DEFAULT 0,
	`credits_timer` FLOAT NOT NULL DEFAULT '0.0' ,
	`kills` int(12) NOT NULL DEFAULT 0,
	`deaths` int(12) NOT NULL DEFAULT 0,
	`assists` int(12) NOT NULL DEFAULT 0,
	`headshots` int(12) NOT NULL DEFAULT 0,
	`points` float NOT NULL DEFAULT 0,
	`longest_killstreak` int(12) NOT NULL DEFAULT 0,
	`hits` int(12) NOT NULL DEFAULT 0,
	`shots` int(12) NOT NULL DEFAULT 0,
	`kdr` float NOT NULL DEFAULT 0.0,
	`accuracy` float NOT NULL DEFAULT 0.0,
	`playtime` float NOT NULL DEFAULT 0.0,
	`converted` int(12) NOT NULL DEFAULT 0,
	`first_created` int(12) NOT NULL,
	`last_updated` int(12) NOT NULL,
	`joined_times` int(12) NOT NULL DEFAULT 0,
	PRIMARY KEY (`id`),
	UNIQUE KEY `id` (`id`),
	UNIQUE KEY `steamid2` (`steamid2`))
	ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 DEFAULT COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `furious_global_map_statistics` (
	`id` int(12) NOT NULL AUTO_INCREMENT,
	`map` varchar(32) NOT NULL DEFAULT '',
	`map_loads` int(12) NOT NULL DEFAULT 0,
	`map_playtime` float NOT NULL DEFAULT 0.0,
	`first_created` int(12) NOT NULL,
	`last_updated` int(12) NOT NULL,
	PRIMARY KEY (`id`),
	UNIQUE KEY `id` (`id`),
	UNIQUE KEY `map` (`map`))
	ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 DEFAULT COLLATE=utf8mb4_unicode_ci;