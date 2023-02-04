CREATE TABLE `furious_global_store_items` (
	`id` int(12) NOT NULL AUTO_INCREMENT,
	`name` varchar(64) NOT NULL DEFAULT '',
	`accountid` int(12) NOT NULL DEFAULT 0,
	`steamid2` varchar(64) NOT NULL DEFAULT '',
	`steamid3` varchar(64) NOT NULL DEFAULT '',
	`steamid64` varchar(64) NOT NULL DEFAULT '',
	`item_name` varchar(64) NOT NULL DEFAULT '',
	`item_type` varchar(64) NOT NULL DEFAULT '',
	`item_description` varchar(256) NOT NULL DEFAULT '',
	`price` int(12) NOT NULL DEFAULT 0,
	`charges` int(12) DEFAULT NULL DEFAULT 0,
	`first_created` int(12) NOT NULL,
	`last_updated` int(12) NOT NULL,
	PRIMARY KEY (`id`),
	UNIQUE KEY `id` (`id`),
	UNIQUE KEY `item_ident` (`accountid`, `item_name`, `item_type`))
	ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 DEFAULT COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `furious_global_store_items_equipped` (
	`id` int(12) NOT NULL AUTO_INCREMENT,
	`name` varchar(64) NOT NULL DEFAULT '',
	`accountid` int(32) NOT NULL DEFAULT 0,
	`steamid2` varchar(64) NOT NULL DEFAULT '',
	`steamid3` varchar(64) NOT NULL DEFAULT '',
	`steamid64` varchar(64) NOT NULL DEFAULT '',
	`ip` varchar(64) NOT NULL DEFAULT '',
	`item_type` varchar(64) NOT NULL DEFAULT '',
	`item_name` varchar(64) NOT NULL DEFAULT '',
	`data` varchar(8192) NOT NULL DEFAULT 0,
	`map` varchar(64) NOT NULL DEFAULT '' ,
	`first_created` int(12) NOT NULL,
	`last_updated` int(12) NOT NULL,
	PRIMARY KEY (`id`),
	UNIQUE KEY `id` (`id`),
	UNIQUE KEY `equipped_ident` (`accountid`, `item_type`, `map`))
	ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 DEFAULT COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `furious_global_store_welcome_gifts` (
	`steam_account_id` INT(11) UNSIGNED NULL DEFAULT NULL ,
	`welcome_gift_pending` TINYINT(1) UNSIGNED NOT NULL DEFAULT '1' ,
	PRIMARY KEY (`steam_account_id`) USING BTREE)
	ENGINE = InnoDB CHARSET=utf8mb4 COLLATE utf8mb4_unicode_ci;