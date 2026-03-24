CREATE TABLE `compensation_codes` (
	`id` INT(11) NOT NULL AUTO_INCREMENT,
	`code` VARCHAR(255) NOT NULL COLLATE 'latin1_swedish_ci',
	`items` LONGTEXT NOT NULL COLLATE 'utf8mb4_bin',
	PRIMARY KEY (`id`) USING BTREE,
	UNIQUE INDEX `code` (`code`) USING BTREE,
	CONSTRAINT `items` CHECK (json_valid(`items`))
)
COLLATE='latin1_swedish_ci'
ENGINE=InnoDB
AUTO_INCREMENT=79
;
